#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "good_live"
#define PLUGIN_VERSION "1.01"

#include <sourcemod>
#include <sdktools>
#include <playtime2>
#include <multicolors>

public Plugin myinfo = 
{
	name = "Playtime Commands",
	author = PLUGIN_AUTHOR,
	description = "Implements the commands !vip and !session",
	version = PLUGIN_VERSION,
	url = "painlessgaming.eu"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_vip_new", Command_Vip, "Allows you to see your playtime");
	RegConsoleCmd("sm_session_new", Command_Session, "Allows the player to see the current session Playtime");
	
	LoadTranslations("playtime.phrases");
	LoadTranslations("common.phrases.txt");
}

public Action Command_Vip(int client, int args){
	if(args > 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_vip [name|#userid]");
		return Plugin_Handled;
	}
	int iTarget;
	if(args == 1)
	{
		if (!CheckCommandAccess(client, "pt_vipother", ADMFLAG_GENERIC))
		{
			CPrintToChat(client, "%t %t", "Tag", "Not_Allowed");
			return Plugin_Handled;
		}
		char sName[256];
		GetCmdArg(1, sName, sizeof(sName));
		iTarget = FindTarget(client, sName, true);
	}
	
	if(args == 0)
		iTarget = client;

	int iTime = PT2_GetPlayTime(iTarget);
	if(iTime == STATUS_NOT_LOADED)
	{
		CPrintToChat(client, "%t %t", "Tag", "PT_Status_Not_Loaded", iTarget);
		return Plugin_Handled;
	}
	
	if(iTime == STATUS_LOAD_FAILED)
	{
		CPrintToChat(client, "%t %t", "Tag", "PT_Status_Load_Failed", iTarget);
		return Plugin_Handled;
	}
	
	CPrintToChatAll("%t %t", "Tag", "VIP_Command", iTarget, PT2_GetPlayTime(iTarget)/60);
	return Plugin_Handled;
}

public Action Command_Session(int client, int args){
	if(args > 1){
		ReplyToCommand(client, "[SM] Usage: sm_session [name|#userid]");
		return Plugin_Handled;
	}
	
	int iTarget;
	
	if(args == 1){
		if (!CheckCommandAccess(client, "pt_session_other", ADMFLAG_GENERIC)){
			CPrintToChat(client, "%t %t", "Tag", "Not_Allowed");
			return Plugin_Handled;
		}
		char sName[256];
		GetCmdArg(1, sName, sizeof(sName));
		iTarget = FindTarget(client, sName, true);
	}
	
	if(args == 0){
		iTarget = client;
	}
	
	char sName[21];
	GetClientName(iTarget, sName, sizeof(sName));
	
	char sDate[64];
	FormatTime(sDate, sizeof(sDate), ":%M:%S", PT2_GetSession(iTarget));
	
	int iTime = PT2_GetSession(iTarget) / 360;
	
	CPrintToChatAll("%t %t", "Tag", "Session", sName, iTime, sDate);
	return Plugin_Handled;
}
