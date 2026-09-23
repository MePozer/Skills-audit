/*
 * Round & Player Statistics Manager (RPS)
 *
 * Environment: AMX Mod X 1.10.0.5484, ReAPI 5.29, ReHLDS/ReGameDLL,
 * Counter-Strike 1.6 + Zombie Plague 5.0.8a.
 *
 * Tracks round phases, player and round statistics, exposes them through the
 * rps_stats.inc API (natives + forwards) and gives admins commands and menus
 * to inspect them. Statistics of counted rounds are kept for the map and,
 * optionally, on disk with nvault.
 */

#include <amxmodx>
#include <amxmisc>
#include <newmenus>
#include <reapi>
#include <nvault>
#include <zp50_core>
#include <zp50_gamemodes>
#include <rps_stats>

#define PLUGIN_NAME    "Round & Player Statistics Manager"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_AUTHOR  "RPS"
#define PLUGIN_LOG     "rps_stats.log" // goes into the AMXX logs directory
#define VAULT_NAME     "rps_stats"     // short literal, never built from config

#define MAX_AUTHID_LEN 35
#define MAX_KEY_LEN    72  // authid + '@' + name
#define MAX_VALUE_LEN  96
#define MAX_MENU_LINE  160

// Statistic storage. Index 0 is unused, player slots are 1..MAX_PLAYERS.
new g_iRoundStats[MAX_PLAYERS + 1][RPS_STAT];   // current round
new g_iSessionStats[MAX_PLAYERS + 1][RPS_STAT]; // this map, counted rounds only
new g_iSavedStats[MAX_PLAYERS + 1][RPS_STAT];   // cross map (nvault)

new g_szAuthKey[MAX_PLAYERS + 1][MAX_KEY_LEN];  // vault key of the slot's player

// Round state.
new g_iRoundNumber;
new RPS_ROUND_STATE:g_iRoundState = RPS_ROUND_INACTIVE;
new g_iRoundGameMode = ZP_NO_GAME_MODE;
new WinStatus:g_iRoundWinner = WINSTATUS_NONE;
new Float:g_flRoundStart;
new Float:g_flRoundDuration;
new bool:g_bRoundCounted;
new g_iRoundInfections;
new g_iRoundDamage;
new g_iHumansAtStart, g_iZombiesAtStart, g_iHumansAtEnd, g_iZombiesAtEnd;

// Extension points.
new g_iFwdRoundStart;
new g_iFwdRoundEnd;
new g_iFwdScoreUpdated;

// Storage.
new g_iVault = INVALID_HANDLE;

// Cvars.
new g_pCvarScoreKill;
new g_pCvarScoreInfect;
new g_pCvarScoreHeadshot;
new g_pCvarScoreDamageDiv;
new g_pCvarMinPlayers;
new g_pCvarSave;
new g_pCvarAnnounce;
new g_pCvarLog;
new g_pFreezetime;

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

	// Scoring (points).
	g_pCvarScoreKill      = create_cvar("rps_score_kill",      "100", FCVAR_NONE, "Очки за убийство");
	g_pCvarScoreInfect    = create_cvar("rps_score_infect",    "50",  FCVAR_NONE, "Очки за заражение человека");
	g_pCvarScoreHeadshot  = create_cvar("rps_score_headshot",  "25",  FCVAR_NONE, "Очки за убийство в голову");
	g_pCvarScoreDamageDiv = create_cvar("rps_score_damage_div", "100", FCVAR_NONE, "Очки начисляются за каждые столько единиц урона (0 - не учитывать)");

	// Behaviour.
	g_pCvarMinPlayers = create_cvar("rps_min_players", "4", FCVAR_NONE, "Минимальное число игроков, чтобы статистика раунда учитывалась", true, 0.0, true, 32.0);
	g_pCvarSave       = create_cvar("rps_save", "1", FCVAR_NONE, "Сохранять статистику на диск (nvault) между картами", true, 0.0, true, 1.0);
	g_pCvarAnnounce   = create_cvar("rps_announce_round_end", "1", FCVAR_NONE, "Показывать итоги раунда в чат", true, 0.0, true, 1.0);
	g_pCvarLog        = create_cvar("rps_log", "1", FCVAR_NONE, "Вести лог плагина (rps_stats.log)", true, 0.0, true, 1.0);

	g_pFreezetime = get_cvar_pointer("mp_freezetime");

	// Round events, same sources Zombie Plague itself uses.
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0");
	register_logevent("logevent_round_end", 2, "1=Round_End");
	register_event("TextMsg", "event_game_restart", "a", "2=#Game_will_restart_in");

	// ReAPI hooks (no signature hooks, hook chains only).
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "OnTakeDamage_Post", 1);
	RegisterHookChain(RG_CBasePlayer_Killed, "OnKilled_Post", 1);
	RegisterHookChain(RG_RoundEnd, "OnRoundEnd_Post", 1);
	RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "OnRoundFreezeEnd_Post", 1);

	// Admin commands.
	register_concmd("rps_stats", "cmd_stats", ADMIN_KICK, "- меню статистики игроков");
	register_concmd("rps_top", "cmd_top", ADMIN_KICK, "- лучшие игроки карты");
	register_concmd("rps_round", "cmd_round", ADMIN_KICK, "- информация о текущем раунде");
	register_concmd("rps_reset", "cmd_reset", ADMIN_CVAR, "- сбросить статистику сессии");

	// Public API.
	register_native("rps_get_user_stat", "native_get_user_stat");
	register_native("rps_get_user_score", "native_get_user_score");
	register_native("rps_get_saved_stat", "native_get_saved_stat");
	register_native("rps_reset_user_stats", "native_reset_user_stats");
	register_native("rps_get_round_number", "native_get_round_number");
	register_native("rps_get_round_state", "native_get_round_state");
	register_native("rps_get_round_gamemode", "native_get_round_gamemode");
	register_native("rps_get_round_gamemode_name", "native_get_round_gamemode_name");
	register_native("rps_get_round_winner", "native_get_round_winner");
	register_native("rps_get_round_time", "native_get_round_time");

	g_iFwdRoundStart  = CreateMultiForward("rps_fw_round_start", ET_IGNORE, FP_CELL, FP_CELL);
	g_iFwdRoundEnd    = CreateMultiForward("rps_fw_round_end", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
	g_iFwdScoreUpdated = CreateMultiForward("rps_fw_score_updated", ET_IGNORE, FP_CELL);

	RPS_Log("Плагин загружен (версия %s).", PLUGIN_VERSION);
}

public plugin_end()
{
	// Everything that has to survive the map is flushed here.
	if (g_iVault != INVALID_HANDLE && get_pcvar_num(g_pCvarSave))
	{
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		for (new i; i < iNum; i++)
			SavePlayerStats(iPlayers[i]);
	}

	DestroyForward(g_iFwdRoundStart);
	DestroyForward(g_iFwdRoundEnd);
	DestroyForward(g_iFwdScoreUpdated);
}

public plugin_cfg()
{
	// Optional config. Tried in configs/, then next to the plugin itself.
	new szDir[128], szCfg[160];
	get_configsdir(szDir, charsmax(szDir));
	formatex(szCfg, charsmax(szCfg), "%s/rps_stats.cfg", szDir);

	if (!file_exists(szCfg))
	{
		get_localinfo("amxx_pluginsdir", szDir, charsmax(szDir));
		formatex(szCfg, charsmax(szCfg), "%s/rps_stats.cfg", szDir);
	}

	if (file_exists(szCfg))
	{
		server_cmd("exec ^"%s^"", szCfg);
		server_exec();
		RPS_Log("Конфиг применён: %s", szCfg);
	}
	else
	{
		RPS_Log("Конфиг не найден, используются значения по умолчанию: %s", szCfg);
	}

	if (get_pcvar_float(g_pCvarScoreDamageDiv) <= 0.0)
		RPS_Log("Внимание: rps_score_damage_div <= 0, урон в очки не идёт.");

	if (get_pcvar_num(g_pCvarMinPlayers) < 0)
		set_pcvar_num(g_pCvarMinPlayers, 0);
}

/***********************************************************
 * Lifecycle
 ***********************************************************/

public client_putinserver(id)
{
	// The slot may still hold the data of the previous player: clear it.
	ClearPlayerStats(id);
	ClearSavedStats(id);

	if (get_pcvar_num(g_pCvarSave))
		LoadPlayerStats(id);
}

public client_disconnected(id)
{
	if (get_pcvar_num(g_pCvarSave))
		SavePlayerStats(id);

	ClearPlayerStats(id);
	g_szAuthKey[id][0] = EOS;
}

/***********************************************************
 * Round phases
 ***********************************************************/

public event_round_start()
{
	g_iRoundNumber++;
	g_iRoundWinner = WINSTATUS_NONE;
	g_iRoundGameMode = ZP_NO_GAME_MODE;
	g_flRoundStart = get_gametime();
	g_flRoundDuration = 0.0;
	g_bRoundCounted = false;
	g_iRoundInfections = 0;
	g_iRoundDamage = 0;

	// With a freezetime the round starts frozen and goes live on freeze end.
	g_iRoundState = (g_pFreezetime && get_pcvar_float(g_pFreezetime) > 0.0) ? RPS_ROUND_FREEZE : RPS_ROUND_LIVE;

	for (new id = 1; id <= MAX_PLAYERS; id++)
		ClearRoundStats(id);

	g_iHumansAtStart = zp_core_get_human_count();
	g_iZombiesAtStart = zp_core_get_zombie_count();

	new szState[24];
	GetStateName(g_iRoundState, szState, charsmax(szState));

	new iRet;
	ExecuteForward(g_iFwdRoundStart, iRet, g_iRoundNumber, g_iRoundGameMode);

	RPS_Log("Раунд #%d начался (фаза: %s, игроков: %d).", g_iRoundNumber, szState, GetConnectedCount());
}

public OnRoundFreezeEnd_Post()
{
	if (g_iRoundState == RPS_ROUND_FREEZE)
	{
		g_iRoundState = RPS_ROUND_LIVE;
		RPS_Log("Раунд #%d: заморозка закончилась, раунд идёт.", g_iRoundNumber);
	}

	return HC_CONTINUE;
}

public OnRoundEnd_Post(WinStatus:iStatus, ScenarioEventEndRound:iEvent, Float:flDelay)
{
	g_iRoundWinner = iStatus;
	FinalizeRound();

	return HC_CONTINUE;
}

public logevent_round_end()
{
	// Backup path: finalise if the ReAPI hook never fired.
	FinalizeRound();
}

public event_game_restart()
{
	g_iRoundNumber = 0;
	g_iRoundState = RPS_ROUND_INACTIVE;
	g_iRoundWinner = WINSTATUS_NONE;
	g_iRoundGameMode = ZP_NO_GAME_MODE;
	g_flRoundStart = 0.0;
	g_flRoundDuration = 0.0;
	g_bRoundCounted = false;
	g_iRoundInfections = 0;
	g_iRoundDamage = 0;

	for (new id = 1; id <= MAX_PLAYERS; id++)
		ClearPlayerStats(id);

	RPS_Log("Полный рестарт игры: номер раунда и статистика сессии сброшены.");
}

FinalizeRound()
{
	// Runs once per round: the ReAPI hook and the logevent can both fire.
	if (g_iRoundState == RPS_ROUND_ENDED)
		return;

	g_iRoundState = RPS_ROUND_ENDED;
	g_flRoundDuration = get_gametime() - g_flRoundStart;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	g_bRoundCounted = (iNum >= get_pcvar_num(g_pCvarMinPlayers));

	if (g_bRoundCounted)
	{
		for (new i; i < iNum; i++)
		{
			new id = iPlayers[i];
			for (new RPS_STAT:sStat = RPS_STAT_KILLS; sStat <= RPS_STAT_DMG_TAKEN; sStat++)
			{
				g_iSessionStats[id][sStat] += g_iRoundStats[id][sStat];
				g_iSavedStats[id][sStat] += g_iRoundStats[id][sStat];
			}
		}
	}

	g_iHumansAtEnd = zp_core_get_human_count();
	g_iZombiesAtEnd = zp_core_get_zombie_count();

	if (get_pcvar_num(g_pCvarAnnounce))
		AnnounceRoundEnd();

	if (get_pcvar_num(g_pCvarSave))
	{
		for (new i; i < iNum; i++)
			SavePlayerStats(iPlayers[i]);
	}

	new iRet;
	ExecuteForward(g_iFwdRoundEnd, iRet, g_iRoundNumber, _:g_iRoundWinner, g_iRoundGameMode);

	RPS_Log("Раунд #%d завершён: победитель %d, режим %d, длительность %.1f с, людей %d->%d, зомби %d->%d, игроков %d, статистика %s.",
		g_iRoundNumber, _:g_iRoundWinner, g_iRoundGameMode, g_flRoundDuration,
		g_iHumansAtStart, g_iHumansAtEnd, g_iZombiesAtStart, g_iZombiesAtEnd,
		iNum, g_bRoundCounted ? "учтена" : "не учтена");
}

/***********************************************************
 * Zombie Plague forwards (ET_IGNORE: nothing is blocked here)
 ***********************************************************/

public zp_fw_core_infect(id, attacker)
{
	if (attacker && attacker != id && is_user_connected(attacker))
	{
		g_iRoundStats[attacker][RPS_STAT_INFECT]++;
		g_iRoundInfections++;

		new iRet;
		ExecuteForward(g_iFwdScoreUpdated, iRet, attacker);
	}
}

public zp_fw_core_cure(id, attacker)
{
	if (attacker && attacker != id && is_user_connected(attacker))
	{
		g_iRoundStats[attacker][RPS_STAT_CURE]++;

		new iRet;
		ExecuteForward(g_iFwdScoreUpdated, iRet, attacker);
	}
}

public zp_fw_gamemodes_start(game_mode_id)
{
	g_iRoundGameMode = game_mode_id;
}

/***********************************************************
 * ReAPI hooks
 ***********************************************************/

public OnTakeDamage_Post(victim, inflictor, attacker, Float:flDamage, iDamageType)
{
	// Non-player damage or self damage: checked first, same rule as zp50_human_armor.
	if (victim == attacker || !is_user_alive(attacker))
		return HC_CONTINUE;

	new iDamage = floatround(flDamage, floatround_floor);
	if (iDamage <= 0)
		return HC_CONTINUE;

	g_iRoundStats[attacker][RPS_STAT_DMG_DEALT] += iDamage;
	g_iRoundStats[victim][RPS_STAT_DMG_TAKEN] += iDamage;
	g_iRoundDamage += iDamage;

	return HC_CONTINUE;
}

public OnKilled_Post(victim, killer, iGib)
{
	if (!is_user_connected(victim))
		return HC_CONTINUE;

	g_iRoundStats[victim][RPS_STAT_DEATHS]++;

	if (killer >= 1 && killer <= MAX_PLAYERS && killer != victim && is_user_connected(killer))
	{
		g_iRoundStats[killer][RPS_STAT_KILLS]++;

		if (get_member(victim, m_bHeadshotKilled))
			g_iRoundStats[killer][RPS_STAT_HEADSHOTS]++;

		new iRet;
		ExecuteForward(g_iFwdScoreUpdated, iRet, killer);
	}

	return HC_CONTINUE;
}

/***********************************************************
 * Admin commands
 ***********************************************************/

public cmd_stats(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	ShowPlayersMenu(id);

	return PLUGIN_HANDLED;
}

public cmd_top(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	SortPlayersByScore(iPlayers, iNum, RPS_SCOPE_SESSION);

	new iMenu = menu_create("\r[RPS] \yЛучшие игроки карты", "TopMenu_Handler");

	new szLine[MAX_MENU_LINE], szInfo[8];
	new iShown = (iNum > 10) ? 10 : iNum;

	for (new i; i < iShown; i++)
	{
		new iTarget = iPlayers[i];
		formatex(szInfo, charsmax(szInfo), "%d", iTarget);
		formatex(szLine, charsmax(szLine), "%d. %n \y%d очков \w| \rK:%d D:%d I:%d",
			i + 1, iTarget, CalcScore(iTarget, RPS_SCOPE_SESSION),
			GetStat(iTarget, RPS_STAT_KILLS, RPS_SCOPE_SESSION),
			GetStat(iTarget, RPS_STAT_DEATHS, RPS_SCOPE_SESSION),
			GetStat(iTarget, RPS_STAT_INFECT, RPS_SCOPE_SESSION));
		menu_additem(iMenu, szLine, szInfo);
	}

	if (!iShown)
		menu_additem(iMenu, "Нет игроков", "0");

	menu_setprop(iMenu, MPROP_EXITNAME, "Закрыть");
	menu_display(id, iMenu, 0);

	return PLUGIN_HANDLED;
}

public cmd_round(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	new szState[24], szMode[32], szTime[12], szWinner[48];
	GetStateName(g_iRoundState, szState, charsmax(szState));
	rps_get_round_gamemode_name(szMode, charsmax(szMode));
	FormatTime(rps_get_round_time(), szTime, charsmax(szTime));
	GetWinnerName(szWinner, charsmax(szWinner));

	client_print(id, print_chat, "[RPS] Раунд #%d | Фаза: %s | Режим: %s", g_iRoundNumber, szState, szMode);
	client_print(id, print_chat, "[RPS] Время: %s | Людей: %d (в начале %d) | Зомби: %d (в начале %d)",
		szTime, zp_core_get_human_count(), g_iHumansAtStart, zp_core_get_zombie_count(), g_iZombiesAtStart);
	client_print(id, print_chat, "[RPS] Итог прошлого раунда: %s | Заражений: %d | Урон: %d", szWinner, g_iRoundInfections, g_iRoundDamage);

	return PLUGIN_HANDLED;
}

public cmd_reset(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	ResetStats(0);

	client_print(id, print_chat, "[RPS] Статистика сессии сброшена.");

	new szName[32];
	get_user_name(id, szName, charsmax(szName));
	RPS_Log("Админ ^"%s^" сбросил статистику сессии.", szName);

	return PLUGIN_HANDLED;
}

/***********************************************************
 * Menus
 ***********************************************************/

ShowPlayersMenu(id)
{
	new iMenu = menu_create("\r[RPS] \yСтатистика игроков", "PlayersMenu_Handler");

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	new szName[32], szInfo[8], szLine[MAX_MENU_LINE];

	for (new i; i < iNum; i++)
	{
		new iTarget = iPlayers[i];
		get_user_name(iTarget, szName, charsmax(szName));
		formatex(szInfo, charsmax(szInfo), "%d", iTarget);
		formatex(szLine, charsmax(szLine), "%s \y[%d | %d] \w(K:%d D:%d I:%d)",
			szName, CalcScore(iTarget, RPS_SCOPE_ROUND), CalcScore(iTarget, RPS_SCOPE_SESSION),
			GetStat(iTarget, RPS_STAT_KILLS, RPS_SCOPE_SESSION),
			GetStat(iTarget, RPS_STAT_DEATHS, RPS_SCOPE_SESSION),
			GetStat(iTarget, RPS_STAT_INFECT, RPS_SCOPE_SESSION));
		menu_additem(iMenu, szLine, szInfo);
	}

	if (!iNum)
		menu_additem(iMenu, "Нет игроков", "0");

	menu_setprop(iMenu, MPROP_EXITNAME, "Выход");
	menu_display(id, iMenu, 0);
}

public PlayersMenu_Handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new szInfo[8], szName[32], iAccess, iCallback;
	menu_item_getinfo(menu, item, iAccess, szInfo, charsmax(szInfo), szName, charsmax(szName), iCallback);

	new iTarget = str_to_num(szInfo);

	menu_destroy(menu);

	// The player may have left between the menu being built and now.
	if (!is_user_connected(iTarget))
	{
		client_print_color(id, print_team_red, "^4[RPS]^1 Игрок покинул сервер.");
		ShowPlayersMenu(id);
		return PLUGIN_HANDLED;
	}

	ShowPlayerStats(id, iTarget);

	return PLUGIN_HANDLED;
}

ShowPlayerStats(id, iTarget)
{
	new szTitle[96];
	formatex(szTitle, charsmax(szTitle), "\r[RPS] \y%N", iTarget);

	new iMenu = menu_create(szTitle, "StatsMenu_Handler");

	new szLine[MAX_MENU_LINE];

	formatex(szLine, charsmax(szLine), "\yРаунд #%d \w(текущий)", g_iRoundNumber);
	menu_additem(iMenu, szLine, "0");

	AddStatLine(iMenu, "Убийств", GetStat(iTarget, RPS_STAT_KILLS, RPS_SCOPE_ROUND));
	AddStatLine(iMenu, "Смертей", GetStat(iTarget, RPS_STAT_DEATHS, RPS_SCOPE_ROUND));
	AddStatLine(iMenu, "Хедшотов", GetStat(iTarget, RPS_STAT_HEADSHOTS, RPS_SCOPE_ROUND));
	AddStatLine(iMenu, "Заражений", GetStat(iTarget, RPS_STAT_INFECT, RPS_SCOPE_ROUND));
	AddStatLine(iMenu, "Исцелений", GetStat(iTarget, RPS_STAT_CURE, RPS_SCOPE_ROUND));
	AddStatLine(iMenu, "Урон нанесён", GetStat(iTarget, RPS_STAT_DMG_DEALT, RPS_SCOPE_ROUND));
	AddStatLine(iMenu, "Урон получен", GetStat(iTarget, RPS_STAT_DMG_TAKEN, RPS_SCOPE_ROUND));
	AddStatLine(iMenu, "Очки", CalcScore(iTarget, RPS_SCOPE_ROUND));

	formatex(szLine, charsmax(szLine), "\yСессия (карта)");
	menu_additem(iMenu, szLine, "0");

	AddStatLine(iMenu, "Убийств", GetStat(iTarget, RPS_STAT_KILLS, RPS_SCOPE_SESSION));
	AddStatLine(iMenu, "Смертей", GetStat(iTarget, RPS_STAT_DEATHS, RPS_SCOPE_SESSION));
	AddStatLine(iMenu, "Заражений", GetStat(iTarget, RPS_STAT_INFECT, RPS_SCOPE_SESSION));
	AddStatLine(iMenu, "Урон нанесён", GetStat(iTarget, RPS_STAT_DMG_DEALT, RPS_SCOPE_SESSION));
	AddStatLine(iMenu, "Очки", CalcScore(iTarget, RPS_SCOPE_SESSION));

	formatex(szLine, charsmax(szLine), "\yВсего (сохранено)");
	menu_additem(iMenu, szLine, "0");

	AddStatLine(iMenu, "Убийств", g_iSavedStats[iTarget][RPS_STAT_KILLS]);
	AddStatLine(iMenu, "Смертей", g_iSavedStats[iTarget][RPS_STAT_DEATHS]);
	AddStatLine(iMenu, "Заражений", g_iSavedStats[iTarget][RPS_STAT_INFECT]);
	AddStatLine(iMenu, "Урон нанесён", g_iSavedStats[iTarget][RPS_STAT_DMG_DEALT]);

	menu_additem(iMenu, "\yНазад к списку", "back");

	menu_setprop(iMenu, MPROP_EXITNAME, "Закрыть");
	menu_display(id, iMenu, 0);
}

AddStatLine(iMenu, const szName[], iValue)
{
	new szLine[MAX_MENU_LINE];
	formatex(szLine, charsmax(szLine), "%s: \r%d", szName, iValue);
	menu_additem(iMenu, szLine, "0");
}

public StatsMenu_Handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new szInfo[8], szName[32], iAccess, iCallback;
	menu_item_getinfo(menu, item, iAccess, szInfo, charsmax(szInfo), szName, charsmax(szName), iCallback);

	menu_destroy(menu);

	if (equal(szInfo, "back"))
		ShowPlayersMenu(id);

	return PLUGIN_HANDLED;
}

public TopMenu_Handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new szInfo[8], szName[32], iAccess, iCallback;
	menu_item_getinfo(menu, item, iAccess, szInfo, charsmax(szInfo), szName, charsmax(szName), iCallback);

	new iTarget = str_to_num(szInfo);

	menu_destroy(menu);

	if (!is_user_connected(iTarget))
	{
		client_print_color(id, print_team_red, "^4[RPS]^1 Игрок покинул сервер.");
		return PLUGIN_HANDLED;
	}

	ShowPlayerStats(id, iTarget);

	return PLUGIN_HANDLED;
}

/***********************************************************
 * Round end announcement
 ***********************************************************/

AnnounceRoundEnd()
{
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	new iTopId = 0, iTopScore = 0;
	for (new i; i < iNum; i++)
	{
		new iScore = CalcScore(iPlayers[i], RPS_SCOPE_ROUND);
		if (iScore > iTopScore)
		{
			iTopScore = iScore;
			iTopId = iPlayers[i];
		}
	}

	new szWinner[48], szMode[32];
	GetWinnerName(szWinner, charsmax(szWinner));
	rps_get_round_gamemode_name(szMode, charsmax(szMode));

	client_print_color(0, print_team_default, "^4[RPS]^1 Раунд #%d завершён ^3%s^1. Режим: ^3%s^1.", g_iRoundNumber, szWinner, szMode);

	if (iTopId && iTopScore > 0)
		client_print_color(0, print_team_default, "^4[RPS]^1 Лучший за раунд: ^3%n^1 — ^4%d^1 очков.", iTopId, iTopScore);

	client_print_color(0, print_team_default, "^4[RPS]^1 Заражений: ^3%d^1. Всего урона: ^3%d^1.", g_iRoundInfections, g_iRoundDamage);

	if (!g_bRoundCounted)
		client_print_color(0, print_team_red, "^4[RPS]^1 Статистика раунда не учтена: мало игроков на сервере.");
}

/***********************************************************
 * Statistics helpers
 ***********************************************************/

GetStat(id, RPS_STAT:sStat, iScope)
{
	return (iScope == RPS_SCOPE_ROUND) ? g_iRoundStats[id][sStat] : g_iSessionStats[id][sStat];
}

CalcScore(id, iScope)
{
	new Float:flScore = 0.0;

	flScore += GetStat(id, RPS_STAT_KILLS, iScope) * get_pcvar_float(g_pCvarScoreKill);
	flScore += GetStat(id, RPS_STAT_HEADSHOTS, iScope) * get_pcvar_float(g_pCvarScoreHeadshot);
	flScore += GetStat(id, RPS_STAT_INFECT, iScope) * get_pcvar_float(g_pCvarScoreInfect);

	new Float:flDiv = get_pcvar_float(g_pCvarScoreDamageDiv);
	if (flDiv > 0.0)
		flScore += float(GetStat(id, RPS_STAT_DMG_DEALT, iScope)) / flDiv;

	return floatround(flScore, floatround_floor);
}

ResetStats(id)
{
	if (id == 0)
	{
		for (new i = 1; i <= MAX_PLAYERS; i++)
			ClearPlayerStats(i);
	}
	else
	{
		ClearPlayerStats(id);
	}
}

ClearPlayerStats(id)
{
	ClearRoundStats(id);

	for (new RPS_STAT:s = RPS_STAT_KILLS; s <= RPS_STAT_DMG_TAKEN; s++)
		g_iSessionStats[id][s] = 0;
}

ClearRoundStats(id)
{
	for (new RPS_STAT:s = RPS_STAT_KILLS; s <= RPS_STAT_DMG_TAKEN; s++)
		g_iRoundStats[id][s] = 0;
}

ClearSavedStats(id)
{
	for (new RPS_STAT:s = RPS_STAT_KILLS; s <= RPS_STAT_DMG_TAKEN; s++)
		g_iSavedStats[id][s] = 0;
}

SortPlayersByScore(iPlayers[], iNum, iScope)
{
	for (new i = 1; i < iNum; i++)
	{
		new j = i, iTemp = iPlayers[i];
		while (j > 0 && CalcScore(iPlayers[j - 1], iScope) < CalcScore(iTemp, iScope))
		{
			iPlayers[j] = iPlayers[j - 1];
			j--;
		}
		iPlayers[j] = iTemp;
	}
}

GetConnectedCount()
{
	new iCount;
	for (new id = 1; id <= MAX_PLAYERS; id++)
	{
		if (is_user_connected(id))
			iCount++;
	}

	return iCount;
}

FormatTime(Float:flSeconds, dest[], len)
{
	new iSeconds = floatround(flSeconds, floatround_floor);
	formatex(dest, len, "%02d:%02d", iSeconds / 60, iSeconds % 60);
}

GetStateName(RPS_ROUND_STATE:iState, dest[], len)
{
	switch (iState)
	{
		case RPS_ROUND_INACTIVE: formatex(dest, len, "нет раунда");
		case RPS_ROUND_FREEZE:   formatex(dest, len, "заморозка");
		case RPS_ROUND_LIVE:     formatex(dest, len, "идёт раунд");
		case RPS_ROUND_ENDED:    formatex(dest, len, "завершён");
	}
}

GetWinnerName(dest[], len)
{
	switch (g_iRoundWinner)
	{
		case WINSTATUS_CTS:        formatex(dest, len, "Победа людей (CT)");
		case WINSTATUS_TERRORISTS: formatex(dest, len, "Победа зомби (T)");
		case WINSTATUS_DRAW:       formatex(dest, len, "Ничья");
		default:                   formatex(dest, len, "не определён");
	}
}

/***********************************************************
 * Storage (nvault)
 ***********************************************************/

BuildAuthKey(id)
{
	g_szAuthKey[id][0] = EOS;

	new szAuthid[MAX_AUTHID_LEN];
	if (!get_user_authid(id, szAuthid, charsmax(szAuthid)) || szAuthid[0] == EOS)
		return;

	// LAN servers and bots would all share one authid: keep them apart.
	if (equal(szAuthid, "STEAM_ID_LAN") || equal(szAuthid, "BOT"))
	{
		new szName[32];
		get_user_name(id, szName, charsmax(szName));
		formatex(g_szAuthKey[id], MAX_KEY_LEN - 1, "%s@%s", szAuthid, szName);
	}
	else
	{
		formatex(g_szAuthKey[id], MAX_KEY_LEN - 1, "%s", szAuthid);
	}

	// The key is at most MAX_KEY_LEN (72) characters: well under the 255 limit of nvault.
}

OpenVault()
{
	if (g_iVault == INVALID_HANDLE)
		g_iVault = nvault_open(VAULT_NAME);
}

LoadPlayerStats(id)
{
	BuildAuthKey(id);

	if (g_szAuthKey[id][0] == EOS)
		return;

	OpenVault();
	if (g_iVault == INVALID_HANDLE)
	{
		RPS_Log("Не удалось открыть хранилище ^"%s^".", VAULT_NAME);
		return;
	}

	new szValue[MAX_VALUE_LEN];
	if (nvault_get(g_iVault, g_szAuthKey[id], szValue, charsmax(szValue)) < 0)
		return;

	new szKills[12], szDeaths[12], szHeadshots[12], szInfect[12], szCure[12], szDealt[12], szTaken[12];
	parse(szValue, szKills, charsmax(szKills), szDeaths, charsmax(szDeaths), szHeadshots, charsmax(szHeadshots),
		szInfect, charsmax(szInfect), szCure, charsmax(szCure), szDealt, charsmax(szDealt), szTaken, charsmax(szTaken));

	g_iSavedStats[id][RPS_STAT_KILLS]     = str_to_num(szKills);
	g_iSavedStats[id][RPS_STAT_DEATHS]    = str_to_num(szDeaths);
	g_iSavedStats[id][RPS_STAT_HEADSHOTS] = str_to_num(szHeadshots);
	g_iSavedStats[id][RPS_STAT_INFECT]    = str_to_num(szInfect);
	g_iSavedStats[id][RPS_STAT_CURE]      = str_to_num(szCure);
	g_iSavedStats[id][RPS_STAT_DMG_DEALT] = str_to_num(szDealt);
	g_iSavedStats[id][RPS_STAT_DMG_TAKEN] = str_to_num(szTaken);
}

SavePlayerStats(id)
{
	if (g_szAuthKey[id][0] == EOS)
		BuildAuthKey(id);

	if (g_szAuthKey[id][0] == EOS)
		return;

	OpenVault();
	if (g_iVault == INVALID_HANDLE)
		return;

	new szValue[MAX_VALUE_LEN];
	formatex(szValue, charsmax(szValue), "%d %d %d %d %d %d %d",
		g_iSavedStats[id][RPS_STAT_KILLS],
		g_iSavedStats[id][RPS_STAT_DEATHS],
		g_iSavedStats[id][RPS_STAT_HEADSHOTS],
		g_iSavedStats[id][RPS_STAT_INFECT],
		g_iSavedStats[id][RPS_STAT_CURE],
		g_iSavedStats[id][RPS_STAT_DMG_DEALT],
		g_iSavedStats[id][RPS_STAT_DMG_TAKEN]);

	nvault_set(g_iVault, g_szAuthKey[id], szValue);
}

/***********************************************************
 * Logging
 ***********************************************************/

RPS_Log(const szMessage[], any:...)
{
	if (!get_pcvar_num(g_pCvarLog))
		return;

	new szBuffer[256];
	vformat(szBuffer, charsmax(szBuffer), szMessage, 2);

	log_to_file(PLUGIN_LOG, "[RPS] %s", szBuffer);
}

/***********************************************************
 * Natives
 ***********************************************************/

public native_get_user_stat(plugin, params)
{
	new id = get_param(1);
	if (id < 1 || id > MAX_PLAYERS || !is_user_connected(id))
		return 0;

	new RPS_STAT:sStat = RPS_STAT:get_param(2);
	if (sStat < RPS_STAT_KILLS || sStat > RPS_STAT_DMG_TAKEN)
		return 0;

	return GetStat(id, sStat, get_param(3));
}

public native_get_user_score(plugin, params)
{
	new id = get_param(1);
	if (id < 1 || id > MAX_PLAYERS || !is_user_connected(id))
		return 0;

	return CalcScore(id, get_param(2));
}

public native_get_saved_stat(plugin, params)
{
	new id = get_param(1);
	if (id < 1 || id > MAX_PLAYERS || !is_user_connected(id))
		return 0;

	new RPS_STAT:sStat = RPS_STAT:get_param(2);
	if (sStat < RPS_STAT_KILLS || sStat > RPS_STAT_DMG_TAKEN)
		return 0;

	return g_iSavedStats[id][sStat];
}

public native_reset_user_stats(plugin, params)
{
	new id = get_param(1);

	if (id != 0 && (id < 1 || id > MAX_PLAYERS))
		return 0;

	ResetStats(id);

	return 1;
}

public native_get_round_number(plugin, params)
{
	return g_iRoundNumber;
}

public native_get_round_state(plugin, params)
{
	return _:g_iRoundState;
}

public native_get_round_gamemode(plugin, params)
{
	return g_iRoundGameMode;
}

public native_get_round_gamemode_name(plugin, params)
{
	new iLen = get_param(2);
	if (iLen <= 0)
		return 0;

	if (g_iRoundGameMode < 0)
	{
		set_string(1, "нет режима", iLen);
		return 0;
	}

	new szName[32];
	zp_gamemodes_get_name(g_iRoundGameMode, szName, charsmax(szName));
	set_string(1, szName, iLen);

	return 1;
}

public native_get_round_winner(plugin, params)
{
	return _:g_iRoundWinner;
}

public Float:native_get_round_time(plugin, params)
{
	return (g_iRoundState == RPS_ROUND_ENDED) ? g_flRoundDuration : (get_gametime() - g_flRoundStart);
}
