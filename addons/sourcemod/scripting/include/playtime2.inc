/** Double-include prevention */
#if defined _playtime_included_
 #endinput
#endif
#define _playtime_included_

//Defines
#define STATUS_NOT_LOADED -1
#define STATUS_LOAD_FAILED -2
#define STATUS_LOAD_SUCCESSFUL -3
#define SESSION_NOT_STARTED -4

/**
 * Retrieves the current playtime of a player.
 *
 * @param client    The client that you want to get the playtime from.
 * @return        The playtime of the client in secounds.
 */
native int PT2_GetPlayTime(int client);

/**
 * Retrieves the current session time of a player.
 *
 * @param client    The client that you want the session from.
 * @return        The session time of the client in secounds.
 */
native int PT2_GetSession(int client);