#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "good_live"
#define PLUGIN_VERSION "1.01"

#include <sourcemod>
#include <sdktools>
#include <playtime>
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
	RegConsoleCmd("sm_vip", Command_Vip, "Allows you to see your playtime");
	RegConsoleCmd("sm_session", Command_Session, "Allows the player to see the current session Playtime");
	
	RegAdminCmd("sm_vipadd", Command_VipAdd, ADMFLAG_ROOT, "Allows the admin to add delete time from a player");
	
	LoadTranslations("playtime.phrases");
	LoadTranslations("common.phrases.txt");
}

public Action Command_VipAdd(int iClient, iArgs){
	if(iArgs != 2){
		ReplyToCommand(iClient, "[SM] Usage: sm_vipadd <#userid|name> <time>");
		return Plugin_Handled;
	}
	
	char sName[64];
	GetCmdArg(1, sName, sizeof(sName));
	
	int iTarget = FindTarget(iClient, sName, true);
	
	char sTime[64];
	GetCmdArg(2, sTime, sizeof(sTime));
	
	int iTime = StringToInt(sTime);
	
	char sName2[64];
	GetClientName(iTarget, sName2, sizeof(sName2));
	
	PT_AddPlayTime(iTarget, iTime);
	CPrintToChat(iClient, "%t %t", "Tag", "Time_Added", iTime, sName2);
	return Plugin_Handled;
}

public Action Command_Vip(int iClient, iArgs){
	if(iArgs > 1){
		ReplyToCommand(iClient, "[SM] Usage: sm_vip [name|#userid]");
		return Plugin_Handled;
	}
	int iTarget;
	if(iArgs == 1){
		if (!CheckCommandAccess(iClient, "pt_viother", ADMFLAG_GENERIC)){
			CPrintToChat(iClient, "%t %t", "Tag", "Not_Allowed");
			return Plugin_Handled;
		}
		char sName[256];
		GetCmdArg(1, sName, sizeof(sName));
		iTarget = FindTarget(iClient, sName, true);
	}
	
	if(iArgs == 0){
		iTarget = iClient;
	}
	char sName[21];
	GetClientName(iTarget, sName, sizeof(sName));
	CPrintToChatAll("%t %t", "Tag", "VICommand", sName, PT_GetPlayTime(iTarget)/60);
	return Plugin_Handled;
}

public Action Command_Session(int iClient, iArgs){
	if(iArgs > 1){
		ReplyToCommand(iClient, "[SM] Usage: sm_session [name|#userid]");
		return Plugin_Handled;
	}
	
	int iTarget;
	
	if(iArgs == 1){
		if (!CheckCommandAccess(iClient, "pt_session_other", ADMFLAG_GENERIC)){
			CPrintToChat(iClient, "%t %t", "Tag", "Not_Allowed");
			return Plugin_Handled;
		}
		char sName[256];
		GetCmdArg(1, sName, sizeof(sName));
		iTarget = FindTarget(iClient, sName, true);
	}
	
	if(iArgs == 0){
		iTarget = iClient;
	}
	
	char sName[21];
	GetClientName(iTarget, sName, sizeof(sName));
	
	char sDate[64];
	FormatTime(sDate, sizeof(sDate), ":%M:%S", PT_GetSession(iTarget));
	
	int iTime = PT_GetSession(iTarget) / 360;
	
	CPrintToChatAll("%t %t", "Tag", "Session", sName, iTime, sDate);
	return Plugin_Handled;
}