#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <multicolors>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "Playtime",
	author = "good_live",
	description = "A full player tracking system.",
	version = "2.0.0",
	url = "painlessgaming.eu"
};

//Defines
#define STATUS_NOT_LOADED -1
#define STATUS_LOAD_FAILED -2
#define STATUS_LOAD_SUCCESSFUL -3

#define SESSION_NOT_STARTED -1

//Global Variables

//ConVars
ConVar g_cServerId;
ConVar g_cMinPlayers;

//Handles
Database g_hDatabase;

//booleans
bool g_bConnected = false; //Connected to the database?
bool g_bActive = false;

//integers
int g_iPlayerStatus[MAXPLAYERS + 1] = { STATUS_NOT_LOADED, ... };
int g_iPlayerID[MAXPLAYERS + 1] = { -1, ... };
int g_iPlayerTime[MAXPLAYERS + 1] = { -1, ... };
int g_iPlayerSessionStarted[MAXPLAYERS + 1] =  { SESSION_NOT_STARTED, ... };

public void OnPluginStart()
{
	//Translation
	LoadTranslations("playtime");
	
	//Config
	g_cServerId = CreateConVar("pt_serverid", "-1", "The servers database id");
	g_cMinPlayers = CreateConVar("pt_min_players", "2", "The minimal amount of active (T/CT) players needed to start tracking");
	AutoExecConfig(true);
	
	//Connect to database
	DB_Connect();
	
	//Events
	HookEvent("switch_team", Event_SwitchTeam, EventHookMode_Post);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);
}

//*************************** EVENTS *************************************/

//This one only gets called internal so it doesn't have to be public
void OnDatabaseConnected()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientValid(i))
			continue;
		
		DB_LoadPlayerInfo(i);
	}
}

//This is a CS:GO specific Event.
public Action Event_SwitchTeam(Event event, const char[] name, bool dontBroadcast)
{
	//Check if we got enough players now
	if(event.GetInt("numPlayers") >= g_cMinPlayers.IntValue && !g_bActive){
		g_bActive = true;
		
		for (int i; i <= MaxClients + 1; i++) {
			if(IsClientValid(i) && GetClientTeam(i) >= 1)
				StartSession(i);
		}
	}
	
	//Check if there aren't enough Players left.
	if(event.GetInt("numPlayers") < g_cMinPlayers.IntValue && g_bActive){
		CPrintToChatAll("%t %t", "Tag", "Not_Enough_Players");
		
		g_bActive = false;
		
		for (int i; i <= MaxClients + 1; i++) {
			if(IsClientValid(i) && g_iPlayerSessionStarted[i] != SESSION_NOT_STARTED){
				EndSession(i);
			}
		}
	}
}

//This is a general event
public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	//Do nothing when the system is not active yet.
	if(!g_bActive)
		return Plugin_Continue;
		
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsClientValid(client))
		return Plugin_Continue;
	
	//The client has a previous session, that we should save!
	if(g_iPlayerSessionStarted[client] != SESSION_NOT_STARTED)
		EndSession(client);
	
	//The client joined in a team that gets tracked. Start a session!
	if(event.GetInt("team") >= 1)
		StartSession(client);
	
	return Plugin_Continue;
}

public void OnClientPostAdminCheck(int client)
{
	g_iPlayerStatus[client] = STATUS_NOT_LOADED;
	g_iPlayerID[client] = -1;
	g_iPlayerTime[client] = -1;
	g_iPlayerSessionStarted[client] = SESSION_NOT_STARTED;
	DB_LoadPlayerInfo(client);
}

public void OnClientDisconnect(int client){
	if(g_iPlayerSessionStarted[client] != SESSION_NOT_STARTED)
		EndSession(client);
}

//************************* Functions ************************************/
void StartSession(int client)
{
	CPrintToChat(client, "%t %t", "Tag", "Session_Start");
	g_iPlayerSessionStarted[client] = GetTime();
}

void EndSession(int client)
{
	DB_SaveSession(client);
	g_iPlayerSessionStarted[client] = SESSION_NOT_STARTED;
}

//*********************** DATABASE STUFF *********************************/
void DB_Connect()
{
	if(!SQL_CheckConfig("playtime"))
		SetFailState("Couldn't find the database entry 'playtime'!");
	else
		Database.Connect(DB_Connect_Callback, "playtime");
}

public void DB_Connect_Callback(Database db, const char[] error, any data)
{
	if(db == null)
		SetFailState("Database connection failed!: %s", error);
	
	g_hDatabase = db;
	
	g_hDatabase.SetCharset("utf8mb4");
	
	g_bConnected = true;
	//TODO Add a check if the serverid exists
	OnDatabaseConnected();
}

void DB_LoadPlayerInfo(int client)
{
	if(!g_bConnected)
		return;
	
	//Get the players SteamID
	char sSteamID[20];
	if(!GetClientAuthId(client, AuthId_Steam3, sSteamID, sizeof(sSteamID)))
	{
		g_iPlayerStatus[client] = STATUS_LOAD_FAILED;
		LogError("Failed to load the SteamID from %L. This session is not tracked", client);
		return;
	}
	
	//Send Query
	char sQuery[512];
	Format(sQuery, sizeof(sQuery), "SELECT id, playtime FROM players JOIN playtime ON players.id = playtime.playerid WHERE steamid = '%s'");
	g_hDatabase.Query(DB_LoadPlayerID_Callback, sQuery, GetClientUserId(client));
}

public void DB_LoadPlayerID_Callback(Database db, DBResultSet results, const char[] error, int userid)
{
	//Check if the client is still there
	int client = GetClientOfUserId(userid);
	if(!IsClientValid(client))
		return;
		
	//Check if there was an error
	if(strlen(error) > 0 || results == INVALID_HANDLE)
	{
		LogError("Failed to load the id from %L", client);
		g_iPlayerStatus[client] = STATUS_LOAD_FAILED;
		return;
	}
	
	//Check if the player isn't in the database and add him if not
	results.FetchRow();
	if(!results.RowCount)
	{
		DB_AddPlayerToDatabase(client);
		return;
	}
	
	g_iPlayerID[client] = results.FetchInt(0);
	g_iPlayerTime[client] = results.FetchInt(1);
	g_iPlayerStatus[client] = STATUS_LOAD_SUCCESSFUL;
}

void DB_AddPlayerToDatabase(int client)
{
	//Get the players SteamID
	char sSteamID[20];
	if(!GetClientAuthId(client, AuthId_Steam3, sSteamID, sizeof(sSteamID)))
	{
		g_iPlayerStatus[client] = STATUS_LOAD_FAILED;
		LogError("Failed to load the SteamID from %L. This session is not tracked", client);
		return;
	}
	
	//Get the players name
	char sName[64];
	if(!GetClientName(client, sSteamID, sizeof(sSteamID)))
	{
		g_iPlayerStatus[client] = STATUS_LOAD_FAILED;
		LogError("Failed to load the name from %L. This session is not tracked", client);
		return;
	}
	
	//Escape the players name
	char sNameE[sizeof(sName) * 2];
	g_hDatabase.Escape(sName, sNameE, sizeof(sNameE));
	
	//Send the query
	char sQuery[512];
	Format(sQuery, sizeof(sQuery), "INSERT INTO players (steamid, name, first_seen) VALUES ('%s', '%s', %i)", sSteamID, sName, GetTime());
	g_hDatabase.Query(DB_AddPlayerToDatabase_Callback, sQuery, GetClientUserId(client));
}

public void DB_AddPlayerToDatabase_Callback(Database db, DBResultSet results, const char[] error, int userid)
{
	//Check if the client is still there
	int client = GetClientOfUserId(userid);
	if(!IsClientValid(client))
		return;
		
	//Check if there was an error
	if(strlen(error) > 0 || results == INVALID_HANDLE)
	{
		LogError("Failed to add %L to the database", client);
		g_iPlayerStatus[client] = STATUS_LOAD_FAILED;
		return;
	}
	
	g_iPlayerID[client] = results.InsertId;
	g_iPlayerTime[client] = 0;
	g_iPlayerStatus[client] = STATUS_LOAD_SUCCESSFUL;
}

public void DB_SaveSession(int client)
{
	if(g_iPlayerSessionStarted[client] == SESSION_NOT_STARTED)
		return;
	
	g_iPlayerTime[client] += GetTime() - g_iPlayerSessionStarted[client];
	
	char sQuery[512];
	Format(sQuery, sizeof(sQuery), "INSERT INTO sessions (playerid, serverid, starttime, endtime, length) VALUES (%i, %i, %i, %i, %i)", g_iPlayerID[client], g_cServerId.IntValue, g_iPlayerSessionStarted[client], GetTime(), GetTime() - g_iPlayerSessionStarted[client]);
	g_hDatabase.Query(DB_SaveDatabase_Callback, sQuery, GetClientUserId(client));
}

public void DB_SaveDatabase_Callback(Database db, DBResultSet results, const char[] error, int userid)
{
	//Check if there was an error
	if(strlen(error) > 0 || results == INVALID_HANDLE)
	{
		//Check if the client is still there
		int client = GetClientOfUserId(userid);
		if(!IsClientValid(client))
			return;
			
		LogError("Failed to save session from %L to the database: %s", client, error);
			
		CPrintToChat(client, "%t %t", "Tag", "PT_AN_ERROR_OCCURED");
	}
}

//*********************** UTIL STUFF *********************************/

bool IsClientValid(int client)
{
	if(1 <= client <= MaxClients && IsClientConnected(client))
		return true;
	return false;
}