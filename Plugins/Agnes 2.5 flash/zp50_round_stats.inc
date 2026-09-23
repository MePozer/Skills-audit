// Round & Player Statistics Manager for Zombie Plague 5.0.8a
// Public API: natives and forwards for other plugins

#if defined _zp50_round_stats_included
	#endinput
#endif
#define _zp50_round_stats_included

#include <amxmodx>

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib zp50_round_stats
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib zp50_round_stats
	#endif
#else
	#pragma library zp50_round_stats
#endif

enum _:STATS_PLAYER
{
	SP_KILLS,
	SP_DEATHS,
	SP_INFECTED,
	SP_DAMAGED_DONE,
	SP_DAMAGED_TAKEN,
	SP_HEADSHOTS,
	SP_ROUND_KILLS,
	SP_ROUND_DEATHS,
	SP_ROUND_INFECTED,
	SP_ROUND_DAMAGE_DONE,
	SP_ROUND_DAMAGE_TAKEN,
	SP_ROUND_HEADSHOTS,
	SP_STATS_COUNT
}

enum _:STATS_TEAM
{
	ST_KILLS,
	ST_DEATHS,
	ST_ROUND_WINS,
	ST_STATS_COUNT
}

enum _:ROUND_PHASE
{
	RP_NONE = 0,
	RP_FREEZE,
	RP_PLAYING,
	RP_END
}

native zp_stats_get_user_kills(id)
native zp_stats_get_user_deaths(id)
native zp_stats_get_user_infected(id)
native zp_stats_get_user_damage_done(id)
native zp_stats_get_user_damage_taken(id)
native zp_stats_get_user_headshots(id)
native zp_stats_get_user_round_kills(id)
native zp_stats_get_user_round_deaths(id)
native zp_stats_get_user_round_infected(id)
native zp_stats_get_user_round_damage_done(id)
native zp_stats_get_user_round_damage_taken(id)
native zp_stats_get_user_round_headshots(id)
native zp_stats_get_team_round_kills(team)
native zp_stats_get_team_round_deaths(team)
native zp_stats_get_team_round_wins(team)
native zp_stats_get_round_phase()
native zp_stats_get_round_number()
native zp_stats_get_map_rounds()
native zp_stats_reset_user(id)
native zp_stats_reset_round()
native zp_stats_get_stats_count()

forward zp_stats_fw_player_killed(id, attacker, const weapon[], is_zombie_kill)
forward zp_stats_fw_player_infected(id, attacker)
forward zp_stats_fw_player_cured(id, attacker)
forward zp_stats_fw_round_start()
forward zp_stats_fw_round_end(winner_team)
