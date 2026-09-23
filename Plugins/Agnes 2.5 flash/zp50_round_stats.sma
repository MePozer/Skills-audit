/*
 * Round & Player Statistics Manager
 * Part of Zombie Plague 5.0.8a ecosystem
 *
 * Tracks per-player and per-team statistics across rounds and maps.
 * Provides natives and forwards for other plugins to query and react.
 */

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <cs_ham_bots_api>
#include <nvault>
#include <zp50_core>
#include <zp50_gamemodes>
#include "zp50_round_stats.inc"

#if AMXX_VERSION_NUM < 175
	#error "Requires AMX Mod X 1.75+"
#endif

// в”Ђв”Ђв”Ђ Constants в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
#define MAX_NAME_LENGTH     32
#define VAULT_KEY_PREFIX    "zp_rs_"
#define VAULT_FILE          "zp_round_stats"
#define PREFIX              "^x04[ZP Stats]"

// в”Ђв”Ђв”Ђ Globals в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
	new g_cvar_save_maps
	new g_cvar_auto_reset
	new g_cvar_count_self_death
	new g_cvar_count_suicide
	new g_cvar_track_world

new g_PlayerStats[MAX_PLAYERS + 1][SP_STATS_COUNT]
new g_RoundStats[MAX_PLAYERS + 1][SP_STATS_COUNT]
new g_TeamRoundStats[2][ST_STATS_COUNT]

new g_RoundPhase
new g_RoundNumber
new g_MapRounds

new g_Vault
new g_PlayerUserId[MAX_PLAYERS + 1]

new g_fwPlayerKilled
new g_fwPlayerInfected
new g_fwPlayerCured
new g_fwRoundStart
new g_fwRoundEnd
new g_ForwardResult

// в”Ђв”Ђв”Ђ Plugin init в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
public plugin_init()
{
	register_plugin("[ZP] Round Statistics", "1.0.0", "Agnes/AI")

	register_event("DeathMsg",   "event_death",      "a")
	register_event("SendAudio",  "event_round_end",  "a", "2=%!MRAD_terwin", "2=%!MRAD_ctwin", "2=%!MRAD_rounddraw")
	register_event("ResetHUD",   "event_reset_hud",  "b")
	register_event("TextMsg",    "event_textmsg",    "a")

	RegisterHam(Ham_TakeDamage, "player", "Ham_TakeDamage_Post", 1)
	RegisterHamBots(Ham_TakeDamage, "Ham_TakeDamage_Post", 1)
	RegisterHam(Ham_Killed, "player", "Ham_Killed_Post", 1)
	RegisterHamBots(Ham_Killed, "Ham_Killed_Post", 1)
	RegisterHam(Ham_Spawn, "player", "Ham_Spawn_Post", 1)
	RegisterHamBots(Ham_Spawn, "Ham_Spawn_Post", 1)

	g_Vault = nvault_open(VAULT_FILE)
	if (g_Vault == INVALID_HANDLE)
		log_to_file("zp_round_stats.log", "[ZP RS] ERROR: Could not open vault '%s'", VAULT_FILE)
	else
		log_to_file("zp_round_stats.log", "[ZP RS] Vault opened")

	log_to_file("zp_round_stats.log", "[ZP RS] plugin_init done")
}

public plugin_cfg()
{
	g_cvar_save_maps        = create_cvar("zp_stats_save_maps",     "1", FCVAR_SERVER, "Save stats between maps")
	g_cvar_auto_reset       = create_cvar("zp_stats_auto_reset",    "1", FCVAR_SERVER, "Auto-reset round stats on round start")
	g_cvar_count_self_death = create_cvar("zp_stats_self_death",    "1", FCVAR_SERVER, "Count self-inflicted deaths")
	g_cvar_count_suicide    = create_cvar("zp_stats_suicide",       "1", FCVAR_SERVER, "Count suicides")
	g_cvar_track_world      = create_cvar("zp_stats_world_dmg",     "1", FCVAR_SERVER, "Track world/lava damage")

	register_concmd("amx_statsme",   "cmd_stats_me",    read_flags("t"))
	register_concmd("amx_statsall",  "cmd_stats_all",   read_flags("t"))
	register_concmd("amx_statsreset","cmd_stats_reset", read_flags("r"))

	register_clcmd("say /statsme",   "cmd_stats_me")
	register_clcmd("say /statsall",  "cmd_stats_all")
	register_clcmd("say /statsreset","cmd_stats_reset")

	log_to_file("zp_round_stats.log", "[ZP RS] CVARs registered")
}

public plugin_natives()
{
	g_fwPlayerKilled  = CreateMultiForward("zp_stats_fw_player_killed", ET_IGNORE, FP_CELL, FP_CELL, FP_STRING, FP_CELL)
	g_fwPlayerInfected = CreateMultiForward("zp_stats_fw_player_infected", ET_IGNORE, FP_CELL, FP_CELL)
	g_fwPlayerCured   = CreateMultiForward("zp_stats_fw_player_cured", ET_IGNORE, FP_CELL, FP_CELL)
	g_fwRoundStart    = CreateMultiForward("zp_stats_fw_round_start", ET_IGNORE)
	g_fwRoundEnd      = CreateMultiForward("zp_stats_fw_round_end", ET_IGNORE, FP_CELL)

	register_library("zp50_round_stats")

	register_native("zp_stats_get_user_kills",             "native_get_user_kills")
	register_native("zp_stats_get_user_deaths",            "native_get_user_deaths")
	register_native("zp_stats_get_user_infected",          "native_get_user_infected")
	register_native("zp_stats_get_user_damage_done",       "native_get_user_damage_done")
	register_native("zp_stats_get_user_damage_taken",      "native_get_user_damage_taken")
	register_native("zp_stats_get_user_headshots",         "native_get_user_headshots")
	register_native("zp_stats_get_user_round_kills",       "native_get_user_round_kills")
	register_native("zp_stats_get_user_round_deaths",      "native_get_user_round_deaths")
	register_native("zp_stats_get_user_round_infected",    "native_get_user_round_infected")
	register_native("zp_stats_get_user_round_damage_done", "native_get_user_round_damage_done")
	register_native("zp_stats_get_user_round_damage_taken","native_get_user_round_damage_taken")
	register_native("zp_stats_get_user_round_headshots",   "native_get_user_round_headshots")
	register_native("zp_stats_get_team_round_kills",       "native_get_team_round_kills")
	register_native("zp_stats_get_team_round_deaths",      "native_get_team_round_deaths")
	register_native("zp_stats_get_team_round_wins",        "native_get_team_round_wins")
	register_native("zp_stats_get_round_phase",            "native_get_round_phase")
	register_native("zp_stats_get_round_number",           "native_get_round_number")
	register_native("zp_stats_get_map_rounds",             "native_get_map_rounds")
	register_native("zp_stats_reset_user",                 "native_reset_user")
	register_native("zp_stats_reset_round",                "native_reset_round")
	register_native("zp_stats_get_player_stats_count",     "native_get_stats_count")
}

public plugin_precache()
{
	log_to_file("zp_round_stats.log", "[ZP RS] plugin_precache done")
}

public plugin_end()
{
	save_all_player_stats()
	if (g_Vault != INVALID_HANDLE)
		nvault_close(g_Vault)
	log_to_file("zp_round_stats.log", "[ZP RS] plugin_end done")
}

// в”Ђв”Ђв”Ђ ZP Forwards в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
public zp_fw_core_infect_post(id, attacker)
{
	g_PlayerStats[id][SP_INFECTED]++
	g_RoundStats[id][SP_ROUND_INFECTED]++

	if (g_fwPlayerInfected != -1)
		ExecuteForward(g_fwPlayerInfected, g_ForwardResult, id, attacker)

	log_to_file("zp_round_stats.log", "#%d infected by #%d", id, attacker)
}

public zp_fw_core_cure_post(id, attacker)
{
	if (g_fwPlayerCured != -1)
		ExecuteForward(g_fwPlayerCured, g_ForwardResult, id, attacker)
}

public zp_fw_gamemodes_start(game_mode_id)
{
	g_RoundPhase = RP_FREEZE
	g_MapRounds++
	g_RoundNumber++

	if (g_fwRoundStart != -1)
		ExecuteForward(g_fwRoundStart, g_ForwardResult)

	log_to_file("zp_round_stats.log", "Round %d start (phase=freeze)", g_RoundNumber)
}

public zp_fw_gamemodes_end(game_mode_id)
{
	g_RoundPhase = RP_END

	new winner = 2
	if (zp_core_get_zombie_count() == 0)
	{
		winner = 1
		g_TeamRoundStats[1][ST_ROUND_WINS]++
	}
	else if (zp_core_get_human_count() == 0)
	{
		winner = 0
		g_TeamRoundStats[0][ST_ROUND_WINS]++
	}

	if (g_fwRoundEnd != -1)
		ExecuteForward(g_fwRoundEnd, g_ForwardResult, winner)

	log_to_file("zp_round_stats.log", "Round %d end (winner=%d)", g_RoundNumber, winner)
}

// в”Ђв”Ђв”Ђ Player lifecycle в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
public client_connect(id)
{
	g_PlayerUserId[id] = 0
	log_to_file("zp_round_stats.log", "#%d client_connect (userid pending)", id)
}

public client_putinserver(id)
{
	g_PlayerUserId[id] = get_user_userid(id)

	if (get_pcvar_num(g_cvar_save_maps) && g_PlayerUserId[id] != 0)
		load_player_stats(id)

	log_to_file("zp_round_stats.log", "#%d putinserver userid=%d", id, g_PlayerUserId[id])
}

public client_disconnected(id)
{
	if (get_pcvar_num(g_cvar_save_maps) && g_PlayerUserId[id] != 0)
		save_player_stats(id)

	g_PlayerUserId[id] = 0

	for (new i = 0; i < SP_STATS_COUNT; i++)
	{
		g_PlayerStats[id][i] = 0
		g_RoundStats[id][i] = 0
	}

	log_to_file("zp_round_stats.log", "#%d disconnect вЂ” stats saved and slot cleared", id)
}

// в”Ђв”Ђв”Ђ Ham hooks в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
public Ham_TakeDamage_Post(victim, inflictor, attacker, Float:damage, damagetype)
{
	if (!is_user_connected(victim) || !is_user_alive(victim))
		return HAM_IGNORED

	new atk = attacker

	if (atk >= 1 && atk <= MAX_PLAYERS && is_user_connected(atk))
	{
		g_PlayerStats[atk][SP_DAMAGED_DONE] += floatround(damage)
		g_RoundStats[atk][SP_ROUND_DAMAGE_DONE] += floatround(damage)
		g_PlayerStats[victim][SP_DAMAGED_TAKEN] += floatround(damage)
		g_RoundStats[victim][SP_ROUND_DAMAGE_TAKEN] += floatround(damage)
	}
	else if (get_pcvar_num(g_cvar_track_world))
	{
		g_PlayerStats[victim][SP_DAMAGED_TAKEN] += floatround(damage)
		g_RoundStats[victim][SP_ROUND_DAMAGE_TAKEN] += floatround(damage)
	}

	return HAM_IGNORED
}

public Ham_Killed_Post(victim, attacker, shouldgib)
{
	new atk = attacker
	new vic = victim

	if (atk >= 1 && atk <= MAX_PLAYERS && is_user_connected(atk) && atk != vic)
	{
		g_PlayerStats[vic][SP_DEATHS]++
		g_RoundStats[vic][SP_ROUND_DEATHS]++
		g_PlayerStats[atk][SP_KILLS]++
		g_RoundStats[atk][SP_ROUND_KILLS]++

		new vicTeam = get_user_team(vic)
		if (any:vicTeam == CS_TEAM_T)
			g_TeamRoundStats[0][ST_DEATHS]++
		else if (any:vicTeam == CS_TEAM_CT)
			g_TeamRoundStats[1][ST_DEATHS]++

		new atkTeam = get_user_team(atk)
		if (any:atkTeam == CS_TEAM_T)
			g_TeamRoundStats[0][ST_KILLS]++
		else if (any:atkTeam == CS_TEAM_CT)
			g_TeamRoundStats[1][ST_KILLS]++

		if (g_fwPlayerKilled != -1)
			ExecuteForward(g_fwPlayerKilled, g_ForwardResult, vic, atk, "", zp_core_is_zombie(atk) ? 1 : 0)
	}
	else if (atk == vic)
	{
		if (get_pcvar_num(g_cvar_count_suicide))
		{
			g_PlayerStats[vic][SP_DEATHS]++
			g_RoundStats[vic][SP_ROUND_DEATHS]++
		}
	}
	else if (atk == 0)
	{
		if (get_pcvar_num(g_cvar_count_self_death))
		{
			g_PlayerStats[vic][SP_DEATHS]++
			g_RoundStats[vic][SP_ROUND_DEATHS]++
		}
	}

	return HAM_IGNORED
}

public Ham_Spawn_Post(id)
{
	if (!is_user_alive(id))
		return HAM_IGNORED
	return HAM_IGNORED
}

// в”Ђв”Ђв”Ђ AMXX Events в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
public event_death()
{
	new killer   = read_data(1)
	new victim   = read_data(2)
	new headshot = read_data(3)
	new weapon[32]
	read_data(4, weapon, charsmax(weapon))

	if (!is_user_connected(victim) || !is_user_connected(killer))
		return PLUGIN_CONTINUE
	if (killer == victim)
		return PLUGIN_CONTINUE

	if (headshot)
	{
		g_PlayerStats[killer][SP_HEADSHOTS]++
		g_RoundStats[killer][SP_ROUND_HEADSHOTS]++
	}

	log_to_file("zp_round_stats.log", "#%d kills #%d with %s", killer, victim, weapon)
	return PLUGIN_CONTINUE
}

public event_textmsg()
{
	new textmsg[32]
	read_data(2, textmsg, charsmax(textmsg))

	if (equal(textmsg, "#Game_Commencing"))
	{
		reset_all_stats()
		g_RoundNumber = 0
		g_MapRounds = 0
	}
	else if (equal(textmsg, "#Game_will_restart_in"))
	{
		// restart countdown вЂ” do not reset yet
	}
	else
	{
		if (get_pcvar_num(g_cvar_auto_reset))
			reset_round_stats()
	}

	g_RoundPhase = RP_PLAYING
	return PLUGIN_CONTINUE
}

public event_round_end()
{
	new textmsg[32]
	read_data(2, textmsg, charsmax(textmsg))

	new winner = 2
	if (equal(textmsg, "#Terrorists_Win"))
		winner = 0
	else if (equal(textmsg, "#CTs_Win"))
		winner = 1

	log_to_file("zp_round_stats.log", "Round end event: winner=%d", winner)
	return PLUGIN_CONTINUE
}

public event_reset_hud(id)
{
	// Round stats are cleared on round start via event_textmsg
}

// в”Ђв”Ђв”Ђ Command handlers в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
public cmd_stats_me(id)
{
	if (!is_user_connected(id))
		return PLUGIN_HANDLED
	show_player_stats_menu(id, 0)
	return PLUGIN_HANDLED
}

public cmd_stats_all(id)
{
	if (!is_user_connected(id))
		return PLUGIN_HANDLED
	show_all_stats_menu(id, 0)
	return PLUGIN_HANDLED
}

public cmd_stats_reset(id)
{
	if (!cmd_access(id, 'r', 0, 0))
		return PLUGIN_HANDLED

	reset_all_stats()
	color_chat_all("%s All statistics have been reset.", PREFIX)
	log_to_file("zp_round_stats.log", "Admin #%d reset all stats", id)
	return PLUGIN_HANDLED
}

// в”Ђв”Ђв”Ђ Menu system в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
enum _:MENU_STATE
{
	MENU_NONE = 0,
	MENU_PLAYER_STATS,
	MENU_ALL_STATS
}

new g_MenuState[MAX_PLAYERS + 1]
new g_MenuPage[MAX_PLAYERS + 1]

show_player_stats_menu(id, page)
{
	if (!is_user_connected(id))
		return

	g_MenuState[id] = MENU_PLAYER_STATS
	g_MenuPage[id] = page

	new menu[512]
	new len = 0
	new name[MAX_NAME_LENGTH]
	get_user_name(id, name, charsmax(name))

	len += formatex(menu[len], charsmax(menu) - len, ^"^n^n\y%s вЂ” Round Statistics^n\w^n^n^n\yMap Statistics:^n\w^n^n^n^n^n^n", name)

	new rkills     = g_RoundStats[id][SP_ROUND_KILLS]
	new rdeaths    = g_RoundStats[id][SP_ROUND_DEATHS]
	new rinfect    = g_RoundStats[id][SP_ROUND_INFECTED]
	new rdamage    = g_RoundStats[id][SP_ROUND_DAMAGE_DONE]
	new rhs        = g_RoundStats[id][SP_ROUND_HEADSHOTS]

	len += formatex(menu[len], charsmax(menu) - len, "  \dRound %d:^n", g_RoundNumber)
	len += formatex(menu[len], charsmax(menu) - len, "  \rKills:\w %d   \rDeaths:\w %d^n", rkills, rdeaths)
	len += formatex(menu[len], charsmax(menu) - len, "  \rInfections:\w %d   \rDmg Dealt:\w %d^n", rinfect, rdamage)
	len += formatex(menu[len], charsmax(menu) - len, "  \rHeadshots:\w %d^n^n", rhs)

	new mkills    = g_PlayerStats[id][SP_KILLS]
	new mdeaths   = g_PlayerStats[id][SP_DEATHS]
	new minfect   = g_PlayerStats[id][SP_INFECTED]
	new mdamage   = g_PlayerStats[id][SP_DAMAGED_DONE]
	new mhs       = g_PlayerStats[id][SP_HEADSHOTS]

	len += formatex(menu[len], charsmax(menu) - len, "  \dMap total:^n")
	len += formatex(menu[len], charsmax(menu) - len, "  \rKills:\w %d   \rDeaths:\w %d^n", mkills, mdeaths)
	len += formatex(menu[len], charsmax(menu) - len, "  \rInfections:\w %d   \rDmg Dealt:\w %d^n", minfect, mdamage)
	len += formatex(menu[len], charsmax(menu) - len, "  \rHeadshots:\w %d^n^n", mhs)

	len += formatex(menu[len], charsmax(menu) - len, "^n\r0.\w Back")

	new menuid = menu_create(menu, "menu_player_stats_handler")
	menu_additem(menuid, "\r0.\w Back")
	menu_setprop(menuid, MPROP_EXITNAME, "Exit")
	menu_display(id, menuid, g_MenuPage[id])
}

show_all_stats_menu(id, page)
{
	if (!is_user_connected(id))
		return

	g_MenuState[id] = MENU_ALL_STATS
	g_MenuPage[id] = page

	new menu[512]
	new len = 0
	new players[MAX_PLAYERS], pcount, p
	new pname[MAX_NAME_LENGTH]

	len += formatex(menu[len], charsmax(menu) - len, ^"^n^n\yAll Players вЂ” Map Statistics^n\w^n")

	get_players(players, pcount)

	for (p = 0; p < pcount; p++)
	{
		if (!is_user_connected(players[p]))
			continue
		get_user_name(players[p], pname, charsmax(pname))
		len += formatex(menu[len], charsmax(menu) - len, "\r%d.\w %s вЂ” K:%d D:%d HS:%d Inf:%d Dmg:%d^n",
			p + 1, pname,
			g_PlayerStats[players[p]][SP_KILLS],
			g_PlayerStats[players[p]][SP_DEATHS],
			g_PlayerStats[players[p]][SP_HEADSHOTS],
			g_PlayerStats[players[p]][SP_INFECTED],
			g_PlayerStats[players[p]][SP_DAMAGED_DONE])
	}

	len += formatex(menu[len], charsmax(menu) - len, "^n\r0.\w Back")

	new menuid = menu_create(menu, "menu_all_stats_handler")
	menu_additem(menuid, "\r0.\w Back")
	menu_setprop(menuid, MPROP_EXITNAME, "Exit")
	menu_display(id, menuid, g_MenuPage[id])
}

public menu_player_stats_handler(id, menuid, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menuid)
		g_MenuState[id] = MENU_NONE
		return PLUGIN_HANDLED
	}
	show_player_stats_menu(id, g_MenuPage[id])
	return PLUGIN_HANDLED
}

public menu_all_stats_handler(id, menuid, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menuid)
		g_MenuState[id] = MENU_NONE
		return PLUGIN_HANDLED
	}
	show_all_stats_menu(id, g_MenuPage[id])
	return PLUGIN_HANDLED
}

// в”Ђв”Ђв”Ђ Vault persistence в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
save_player_stats(id)
{
	if (g_Vault == INVALID_HANDLE || g_PlayerUserId[id] == 0)
		return

	new key[64], value[512], name[MAX_NAME_LENGTH]
	get_user_name(id, name, charsmax(name))
	formatex(key, charsmax(key), "%s_%d", VAULT_KEY_PREFIX, g_PlayerUserId[id])

	formatex(value, charsmax(value), "%d %d %d %d %d %d %d",
		g_PlayerStats[id][SP_KILLS],
		g_PlayerStats[id][SP_DEATHS],
		g_PlayerStats[id][SP_INFECTED],
		g_PlayerStats[id][SP_DAMAGED_DONE],
		g_PlayerStats[id][SP_DAMAGED_TAKEN],
		g_PlayerStats[id][SP_HEADSHOTS],
		g_MapRounds)

	nvault_set(g_Vault, key, value)
	log_to_file("zp_round_stats.log", "Saved stats for #%d (%s)", id, name)
}

load_player_stats(id)
{
	if (g_Vault == INVALID_HANDLE || g_PlayerUserId[id] == 0)
		return

	new key[64], value[512], name[MAX_NAME_LENGTH]
	get_user_name(id, name, charsmax(name))
	formatex(key, charsmax(key), "%s_%d", VAULT_KEY_PREFIX, g_PlayerUserId[id])

	if (nvault_get(g_Vault, key, value, charsmax(value)))
	{
		new stats[7]
		parse(value, stats[0], 16, stats[1], 16, stats[2], 16, stats[3], 16, stats[4], 16, stats[5], 16, stats[6], 16)

		g_PlayerStats[id][SP_KILLS]         = str_to_num(stats[0])
		g_PlayerStats[id][SP_DEATHS]        = str_to_num(stats[1])
		g_PlayerStats[id][SP_INFECTED]      = str_to_num(stats[2])
		g_PlayerStats[id][SP_DAMAGED_DONE]  = str_to_num(stats[3])
		g_PlayerStats[id][SP_DAMAGED_TAKEN] = str_to_num(stats[4])
		g_PlayerStats[id][SP_HEADSHOTS]     = str_to_num(stats[5])
		g_MapRounds                         = str_to_num(stats[6])

		log_to_file("zp_round_stats.log", "Loaded stats for #%d (%s): K=%d D=%d HS=%d",
			id, name, g_PlayerStats[id][SP_KILLS], g_PlayerStats[id][SP_DEATHS], g_PlayerStats[id][SP_HEADSHOTS])
	}
	else
	{
		log_to_file("zp_round_stats.log", "No saved stats for #%d (%s)", id, name)
	}
}

save_all_player_stats()
{
	if (g_Vault == INVALID_HANDLE)
		return

	new ids = get_maxplayers()
	for (new id = 1; id <= ids; id++)
	{
		if (is_user_connected(id) && g_PlayerUserId[id] != 0)
			save_player_stats(id)
	}
	log_to_file("zp_round_stats.log", "All player stats saved")
}

// в”Ђв”Ђв”Ђ Reset functions в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
reset_round_stats()
{
	new ids = get_maxplayers()
	for (new id = 1; id <= ids; id++)
	{
		for (new i = 0; i < SP_STATS_COUNT; i++)
			g_RoundStats[id][i] = 0
	}
	for (new t = 0; t < 2; t++)
	{
		for (new i = 0; i < ST_STATS_COUNT; i++)
			g_TeamRoundStats[t][i] = 0
	}
	log_to_file("zp_round_stats.log", "Round stats reset")
}

reset_all_stats()
{
	save_all_player_stats()
	new ids = get_maxplayers()
	for (new id = 1; id <= ids; id++)
	{
		for (new i = 0; i < SP_STATS_COUNT; i++)
		{
			g_PlayerStats[id][i] = 0
			g_RoundStats[id][i] = 0
		}
	}
	for (new t = 0; t < 2; t++)
	{
		for (new i = 0; i < ST_STATS_COUNT; i++)
			g_TeamRoundStats[t][i] = 0
	}
	g_RoundNumber = 0
	g_MapRounds = 0
	g_RoundPhase = RP_NONE
	log_to_file("zp_round_stats.log", "All stats reset by admin")
}

// в”Ђв”Ђв”Ђ Native implementations в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
public native_get_user_kills(id)
{
	if (!is_user_connected(id)) return 0
	return g_PlayerStats[id][SP_KILLS]
}
public native_get_user_deaths(id)
{
	if (!is_user_connected(id)) return 0
	return g_PlayerStats[id][SP_DEATHS]
}
public native_get_user_infected(id)
{
	if (!is_user_connected(id)) return 0
	return g_PlayerStats[id][SP_INFECTED]
}
public native_get_user_damage_done(id)
{
	if (!is_user_connected(id)) return 0
	return g_PlayerStats[id][SP_DAMAGED_DONE]
}
public native_get_user_damage_taken(id)
{
	if (!is_user_connected(id)) return 0
	return g_PlayerStats[id][SP_DAMAGED_TAKEN]
}
public native_get_user_headshots(id)
{
	if (!is_user_connected(id)) return 0
	return g_PlayerStats[id][SP_HEADSHOTS]
}
public native_get_user_round_kills(id)
{
	if (!is_user_connected(id)) return 0
	return g_RoundStats[id][SP_ROUND_KILLS]
}
public native_get_user_round_deaths(id)
{
	if (!is_user_connected(id)) return 0
	return g_RoundStats[id][SP_ROUND_DEATHS]
}
public native_get_user_round_infected(id)
{
	if (!is_user_connected(id)) return 0
	return g_RoundStats[id][SP_ROUND_INFECTED]
}
public native_get_user_round_damage_done(id)
{
	if (!is_user_connected(id)) return 0
	return g_RoundStats[id][SP_ROUND_DAMAGE_DONE]
}
public native_get_user_round_damage_taken(id)
{
	if (!is_user_connected(id)) return 0
	return g_RoundStats[id][SP_ROUND_DAMAGE_TAKEN]
}
public native_get_user_round_headshots(id)
{
	if (!is_user_connected(id)) return 0
	return g_RoundStats[id][SP_ROUND_HEADSHOTS]
}
public native_get_team_round_kills(team)
{
	if (team < 0 || team > 1) return 0
	return g_TeamRoundStats[team][ST_KILLS]
}
public native_get_team_round_deaths(team)
{
	if (team < 0 || team > 1) return 0
	return g_TeamRoundStats[team][ST_DEATHS]
}
public native_get_team_round_wins(team)
{
	if (team < 0 || team > 1) return 0
	return g_TeamRoundStats[team][ST_ROUND_WINS]
}
public native_get_round_phase()
{
	return g_RoundPhase
}
public native_get_round_number()
{
	return g_RoundNumber
}
public native_get_map_rounds()
{
	return g_MapRounds
}
public native_reset_user(id)
{
	if (!is_user_connected(id)) return
	for (new i = 0; i < SP_STATS_COUNT; i++)
	{
		g_PlayerStats[id][i] = 0
		g_RoundStats[id][i] = 0
	}
}
public native_reset_round()
{
	reset_round_stats()
}
public native_get_stats_count()
{
	return SP_STATS_COUNT
}

// в”Ђв”Ђв”Ђ Utility в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
color_chat_all(const msg[], {Float,Sql,Result,_}:...)
{
	new szMsg[256]
	vformat(szMsg, charsmax(szMsg), msg, 3)
	new iPlayers[MAX_PLAYERS], iCount
	get_players(iPlayers, iCount, "ch")
	for (new i = 0; i < iCount; i++)
	{
		new pid = iPlayers[i]
		message_begin(MSG_ONE, get_user_msgid("SayText"), _, pid)
		write_byte(0)
		write_string(szMsg)
		message_end()
	}
}
