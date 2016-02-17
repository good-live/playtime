/** Double-include prevention */
#if defined _playtime_included_
 #endinput
#endif
#define _playtime_included_

/**
 * Retrieves the current playtime of a player.
 *
 * @param client    The client that you want to get the playtime from.
 * @return        The playtime of the client in secounds.
 */
native int PT_GetPlayTime(int client);

/**
 * Retrieves the current session time of a player.
 *
 * @param client    The client that you want the session from.
 * @return        The session time of the client in secounds.
 */
native int PT_GetSession(int client);

/**
 * Retrieves the current playtime of a player.
 *
 * @param client    The client that should recieve the time.
 * @param amount    Amount of secounds to add to the player (can be negative).
 * @return        True on success and False otherwise.
 */
native bool PT_AddPlayTime(int client, int amount);