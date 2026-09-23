/*
 * Round & Player Statistics Manager (RPS)
 * Public API for AMX Mod X / ReAPI, Counter-Strike 1.6 + Zombie Plague 5.0.8a
 *
 * Include this file to read statistics gathered by the rps_stats plugin and to
 * subscribe to its round phase forwards.
 */

#if defined _rps_stats_included
  #endinput
#endif
#define _rps_stats_included

#include <cssdk_const>

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib rps_stats
#else
	#pragma library rps_stats
#endif

/*
 * Returned by rps_get_round_gamemode() when no Zombie Plague game mode is
 * running (warmup, game commencing, game restart). Matches ZP's ZP_NO_GAME_MODE.
 */
#define RPS_NO_GAME_MODE (-2)

/*
 * Round phases. The manager tracks the round as a state machine:
 *
 *   INACTIVE -> FREEZE -> LIVE -> ENDED -> (next round: FREEZE ...)
 *
 * INACTIVE is used before the first round and during a full game restart.
 */
enum RPS_ROUND_STATE (+=1)
{
	RPS_ROUND_INACTIVE = 0, // no round in progress
	RPS_ROUND_FREEZE,       // freezetime of a round
	RPS_ROUND_LIVE,         // freezetime is over, round is being played
	RPS_ROUND_ENDED         // round finished, waiting for the next one
}

/*
 * Stat identifiers, usable with rps_get_user_stat() / rps_get_saved_stat().
 */
enum RPS_STAT (+=1)
{
	RPS_STAT_KILLS = 0,     // kills
	RPS_STAT_DEATHS,        // deaths
	RPS_STAT_HEADSHOTS,     // headshot kills
	RPS_STAT_INFECT,        // humans infected by this player (as a zombie)
	RPS_STAT_CURE,          // zombies cured by this player (as a human)
	RPS_STAT_DMG_DEALT,     // damage dealt to other players
	RPS_STAT_DMG_TAKEN      // damage taken from other players
}
#define RPS_STAT_MAX (RPS_STAT_DMG_TAKEN + 1)

/*
 * Stat scope, passed as the third argument of rps_get_user_stat() and
 * rps_get_user_score().
 */
#define RPS_SCOPE_ROUND  (1) // current (in progress / just finished) round
#define RPS_SCOPE_SESSION (0) // this map, all counted rounds so far

/**
 * Returns a player's stat.
 *
 * @param id       Player index.
 * @param stat     Stat identifier, see RPS_STAT.
 * @param scope    RPS_SCOPE_ROUND for the current round, RPS_SCOPE_SESSION for
 *                 the whole map (only counted rounds, see rps_min_players).
 * @return         Stat value, 0 on bad arguments or disconnected player.
 */
native rps_get_user_stat(id, RPS_STAT:stat, scope = RPS_SCOPE_SESSION)

/**
 * Returns a player's score. The score is derived from the stats with the
 * rps_score_* cvars of the rps_stats plugin (kills, infections, headshots and
 * damage dealt are rewarded).
 *
 * @param id       Player index.
 * @param scope    RPS_SCOPE_ROUND or RPS_SCOPE_SESSION.
 * @return         Score, 0 on bad arguments or disconnected player.
 */
native rps_get_user_score(id, scope = RPS_SCOPE_SESSION)

/**
 * Returns a player's stat saved on disk (kept across maps).
 *
 * @param id       Player index.
 * @param stat     Stat identifier, see RPS_STAT.
 * @return         Stat value, 0 if nothing is saved or saving is disabled.
 */
native rps_get_saved_stat(id, RPS_STAT:stat)

/**
 * Resets statistics of one player or of everybody.
 *
 * @param id       Player index, 0 to reset all players.
 * @return         1 on success.
 */
native rps_reset_user_stats(id = 0)

/**
 * Returns the number of the current round. Counts from 1, 0 before the first
 * round or after a full game restart.
 *
 * @return         Round number.
 */
native rps_get_round_number()

/**
 * Returns the current round phase.
 *
 * @return         RPS_ROUND_STATE value.
 */
native RPS_ROUND_STATE:rps_get_round_state()

/**
 * Returns the Zombie Plague game mode of the current round.
 *
 * @return         Internal game mode id, or RPS_NO_GAME_MODE.
 */
native rps_get_round_gamemode()

/**
 * Retrieves the name of the game mode of the current round.
 *
 * @param dest     Buffer to store the string in.
 * @param len      Character size of the output buffer.
 * @return         1 if a game mode name was copied, 0 otherwise.
 */
native rps_get_round_gamemode_name(dest[], len)

/**
 * Returns the winner of the last finished round.
 *
 * @return         WinStatus value (see cssdk_const), WINSTATUS_NONE if the
 *                 round is still in progress or no round has finished yet.
 */
native WinStatus:rps_get_round_winner()

/**
 * Returns the elapsed time of the current round, or the duration of the last
 * finished round.
 *
 * @return         Time in seconds.
 */
native Float:rps_get_round_time()

/*
 * Forwards. All of them are ET_IGNORE: they inform about something that
 * already happened, nothing can be blocked through them.
 */

/**
 * Called when a round starts (on the HLTV round start event, during freezetime
 * if the server has one). The game mode of the round is chosen a moment later,
 * so it is usually RPS_NO_GAME_MODE here. Use rps_fw_round_end or the ZP
 * forwards to know the running game mode.
 *
 * @param round_number     Number of the round that just started.
 * @param game_mode_id     RPS_NO_GAME_MODE (chosen afterwards).
 */
forward rps_fw_round_start(round_number, game_mode_id)

/**
 * Called when a round is finished and its statistics are final.
 *
 * @param round_number     Number of the round that just finished.
 * @param winner_status    WinStatus of the round (see cssdk_const).
 * @param game_mode_id     Game mode that was running, or RPS_NO_GAME_MODE.
 */
forward rps_fw_round_end(round_number, winner_status, game_mode_id)

/**
 * Called when a player's score increases during a round (kill, headshot,
 * infection or cure). Not called for damage alone.
 *
 * @param id               Player index whose score changed.
 */
forward rps_fw_score_updated(id)

/**
 * Convenience stock: is a round currently being played?
 *
 * @return                 True if the round phase is RPS_ROUND_LIVE.
 */
stock bool:rps_is_round_live()
{
	return (rps_get_round_state() == RPS_ROUND_LIVE)
}
