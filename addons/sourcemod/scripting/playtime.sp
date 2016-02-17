#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "good_live"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <logdebug>
#include <multicolors>
#include <playtime>

public Plugin myinfo = 
{
	name = "Playtime",
	author = PLUGIN_AUTHOR,
	description = "A system that tracks the playtime of all Players in a Database",
	version = PLUGIN_VERSION,
	url = "painlessgaming.eu"
};

//Convar
ConVar g_cNeeded_Players;

//Database
Database g_hDatabase;

//bools

bool g_bIsActive = false;

//LocalStorage
//playtime = Time played since the start of the session.
//connecttime = Time when the player got active (Joined a Team or enough Players)
enum PlayerInfos
{
	iPlaytime,
	iConnecttime
}
g_ePlayerInfos[MAXPLAYERS + 1][PlayerInfos];


public void OnPluginStart()
{
	InitDebugLog("pt_debug", "Playtime", ADMFLAG_ROOT);
	LogDebug("Started.");
	
	DBConnect();
	
	g_cNeeded_Players = CreateConVar("pt_needed_players", "2", "The minimum number of players to start tracking", 0, true, 2.0);
	
	HookEvent("switch_team", Event_SwitchTeam, EventHookMode_Post);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);
	
	LoadTranslations("playtime.phrases");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
   CreateNative("PT_GetPlayTime", Native_GetPlayTime);
   CreateNative("PT_GetSession", Native_GetSessionTime);
   CreateNative("PT_AddPlayTime", Native_AddPlayTime);
   return APLRes_Success;
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if(event.GetInt("oldteam") <= 1 && event.GetInt("team") >= 2 && g_bIsActive){
		int p_iClient = GetClientOfUserId(event.GetInt("userid"));
		if(!IsClientValid(p_iClient))
			return;
		g_ePlayerInfos[p_iClient][iConnecttime] = GetTime();
		LogDebug("Saved Connecttime for client %i", p_iClient);
	}
	if(event.GetInt("team") <= 1 && event.GetInt("oldteam") >= 2 && g_bIsActive){
		int p_iClient = GetClientOfUserId(event.GetInt("userid"));
		if(!IsClientValid(p_iClient))
			return;
		SavePlaytime(p_iClient);
	}
}

public void OnClientPostAdminCheck(int p_iClient)
{
	if(!IsClientValid(p_iClient))
		return;
	
	int p_iUserID = GetClientUserId(p_iClient);
	
	char p_sID[21];
	if(!GetClientAuthId(p_iClient, AuthId_Steam2, p_sID, sizeof(p_sID))){
		LogDebug("Error retriving SteamID from a joining client");
		return;
	}
	
	g_ePlayerInfos[p_iClient][iPlaytime] = 0;
	
	char p_sQuery[256];
	Format(p_sQuery, sizeof(p_sQuery), "SELECT `playtime` FROM `playtime` WHERE `steamid` = \"%s\"", p_sID);
	g_hDatabase.Query(DBLoadPlaytime_Callback, p_sQuery, p_iUserID);
}

public void DBLoadPlaytime_Callback(Database db, DBResultSet results, const char[] error, any userid)
{
	if(db == INVALID_HANDLE || results == INVALID_HANDLE)
	{
		LogDebug("SaveLoadTime Query failed: %s. Unloading ...)", error);
		SetFailState("SaveLoadTime Query failed: %s", error);
	}
	
	results.FetchRow();
	if(!results.RowCount)
		return;
	
	int p_iTime = results.FetchInt(0);
	int p_iClient = GetClientOfUserId(userid);
	if(!IsClientValid(p_iClient))
		return;
	g_ePlayerInfos[p_iClient][iPlaytime] = p_iTime;
	LogDebug("Stored playtime: %i for client: %i", p_iTime, p_iClient);
}

public void OnClientDisconnect(int p_iClient){
	if(IsClientValid(p_iClient) && g_ePlayerInfos[p_iClient][iConnecttime] != 0)
		SavePlaytime(p_iClient);
}

public Action Event_SwitchTeam(Event event, const char[] name, bool dontBroadcast)
{
	LogDebug("A player switched the team");
	if(event.GetInt("numPlayers") >= g_cNeeded_Players.IntValue && !g_bIsActive){
		CPrintToChatAll("%t", "Enough_Players");
		
		g_bIsActive = true;
		
		for (int i; i <= MaxClients + 1; i++) {
			if(IsClientValid(i) && GetClientTeam(i) >= 2){
				g_ePlayerInfos[i][iConnecttime] = GetTime();
				LogDebug("Saved connecttime for %i", i);
			}
		}
	}
	
	if(event.GetInt("numPlayers") < g_cNeeded_Players.IntValue && g_bIsActive){
		CPrintToChatAll("%t", "Not_Enough_Players");
		
		g_bIsActive = false;
		
		for (int i; i <= MaxClients + 1; i++) {
			if(IsClientValid(i) && g_ePlayerInfos[i][iConnecttime] != 0){
				SavePlaytime(i);
			}
		}
	}
}


public void SavePlaytime(int p_iClient){
	if(!IsClientValid(p_iClient) || g_ePlayerInfos[p_iClient][iConnecttime] <= 0)
		return;
	int p_iAmount = GetTime() - g_ePlayerInfos[p_iClient][iConnecttime];
	AddPlaytime(p_iClient, p_iAmount);
	
	g_ePlayerInfos[p_iClient][iConnecttime] = 0;
}

public void AddPlaytime(int p_iClient, int p_iAmount){
	if(!IsClientValid(p_iClient))
		return;
	
	char p_sName[64];
	char p_sNameE[sizeof(p_sName) * 2 + 1];
	if(!GetClientName(p_iClient, p_sName, sizeof(p_sName)))
		return;
	g_hDatabase.Escape(p_sName, p_sNameE, sizeof(p_sNameE));
	
	char p_sID[21];
	if(!GetClientAuthId(p_iClient, AuthId_Steam2, p_sID, sizeof(p_sName)))
		return;
	
	char p_sQuery[512];
	Format(p_sQuery, sizeof(p_sQuery), "INSERT INTO playtime (steamid, playtime, name) VALUES (\"%s\", %i, \"%s\") ON DUPLICATE KEY UPDATE playtime=playtime+VALUES(playtime), name=VALUES(name)", p_sID, p_iAmount, p_sName);
	g_hDatabase.Query(DBAddPlayTime_Callback, p_sQuery);
	g_ePlayerInfos[p_iClient][iPlaytime] = g_ePlayerInfos[p_iClient][iPlaytime] + p_iAmount;
	LogDebug("Stored Playtime for %s", p_sName);
}


public bool IsClientValid(int p_iClient)
{
	if(p_iClient > 0 && p_iClient <= MaxClients && IsClientInGame(p_iClient))
	{
		return true;
	}
	return false;
}

public void DBConnect()
{
	if(!SQL_CheckConfig("playtime")){
		LogDebug("Could not find the playtime Database entry");
		SetFailState("Couldn't find the database entry 'playtime'!");
	}else{
		LogDebug("Trying to connect to the database");
		Database.Connect(DBConnect_Callback, "playtime");
	}
}

public void DBConnect_Callback(Database db, const char[] error, any data)
{
	if(db == null){
		LogDebug("Database Connection Failed: %s . Unloading ...", error);
		SetFailState("Database connection failed!: %s", error);
		return;
	}
	
	LogDebug("Database Connect was succesfull");
	
	g_hDatabase = db;
	
	g_hDatabase.SetCharset("utf8mb4");
	
	LogDebug("Trying to Create Tables");
	
	char p_sQuery[512];
	Format(p_sQuery, sizeof(p_sQuery), "SET NAMES \"UTF8\"");
	g_hDatabase.Query(DBSetUtf8_Callback, p_sQuery );
	
	Format(p_sQuery, sizeof(p_sQuery), "CREATE TABLE IF NOT EXISTS `playtime` (`id` int(11) NOT NULL AUTO_INCREMENT, `steamid` varchar(21) NOT NULL, `playtime` int(11) NOT NULL, `name` varchar(64) CHARACTER SET utf8mb4 NOT NULL, UNIQUE (`steamid`), PRIMARY KEY (`id`))");
	g_hDatabase.Query(DBCreateTable_Callback, p_sQuery);
}

public void DBSetUtf8_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(strlen(error) > 0 || results == INVALID_HANDLE){
		LogDebug("Set Utf8 failed: %s .Unloading ...", error);
		SetFailState("Set Utf8 failed: %s", error);
	}
}


public void DBCreateTable_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(strlen(error) > 0 || results == INVALID_HANDLE){
		LogDebug("Table Creation failed: %s .Unloading ...", error);
		SetFailState("Table creation failed: %s", error);
	}
	
	LogDebug("Table Creation succesfull");
}

public void DBAddPlayTime_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(db == INVALID_HANDLE || results == INVALID_HANDLE)
	{
		LogDebug("SavePlayTime Query failed: %s. Unloading ...)", error);
		SetFailState("SavePlayTime Query failed: %s", error);
	}
}

public int Native_GetPlayTime(Handle plugin, int numParams)
{
	int p_iClient = GetNativeCell(1);
	
	if(!IsClientValid(p_iClient))
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%i)", p_iClient);
	
	int p_iTime = g_ePlayerInfos[p_iClient][iPlaytime];

	return p_iTime;
}

public int Native_GetSessionTime(Handle plugin, int numParams)
{
	int p_iClient = GetNativeCell(1);
	if(!IsClientValid(p_iClient))
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%i)", p_iClient);
	
	int p_iTime = g_ePlayerInfos[p_iClient][iConnecttime];
		
	int p_iSession;
	if(p_iTime == 0)
		p_iSession = 0;
	if(p_iTime != 0)
		p_iSession = GetTime() - p_iTime;

	return p_iSession;
}

public int Native_AddPlayTime(Handle plugin, int numParams)
{
	if(numParams != 2)
		return ThrowNativeError(SP_ERROR_NATIVE, "You have to pass 2 Arguments, but you passed %i", numParams);
	
	int p_iClient = GetNativeCell(1);
	int p_iAmount = GetNativeCell(2);
	
	AddPlaytime(p_iClient, p_iAmount);

	return true;
}