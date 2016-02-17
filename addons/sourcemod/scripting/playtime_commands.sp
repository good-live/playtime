#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "good_live"
#define PLUGIN_VERSION "0.00"

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

public Action Command_VipAdd(int p_iClient, p_iArgs){
	if(p_iArgs != 2){
		ReplyToCommand(p_iClient, "[SM] Usage: sm_vipadd <#userid|name> <time>");
		return Plugin_Handled;
	}
	
	char p_sName[64];
	GetCmdArg(1, p_sName, sizeof(p_sName));
	
	int p_iTarget = FindTarget(p_iClient, p_sName, true);
	
	char p_sTime[64];
	GetCmdArg(2, p_sTime, sizeof(p_sTime));
	
	int p_iTime = StringToInt(p_sTime);
	
	char p_sName2[64];
	GetClientName(p_iTarget, p_sName2, sizeof(p_sName2));
	
	PT_AddPlayTime(p_iTarget, p_iTime);
	CPrintToChat(p_iClient, "%t", "Time_Added", p_iTime, p_sName2);
	return Plugin_Handled;
}

public Action Command_Vip(int p_iClient, p_iArgs){
	if(p_iArgs > 1){
		ReplyToCommand(p_iClient, "[SM] Usage: sm_vip [name|#userid]");
		return Plugin_Handled;
	}
	int p_iTarget;
	if(p_iArgs == 1){
		if (!CheckCommandAccess(p_iClient, "pt_vip_other", ADMFLAG_GENERIC)){
			CPrintToChat(p_iClient, "%t", "Not_Allowed");
			return Plugin_Handled;
		}
		char p_sName[256];
		GetCmdArg(1, p_sName, sizeof(p_sName));
		p_iTarget = FindTarget(p_iClient, p_sName, true);
	}
	
	if(p_iArgs == 0){
		p_iTarget = p_iClient;
	}
	char p_sName[21];
	GetClientName(p_iTarget, p_sName, sizeof(p_sName));
	CPrintToChatAll("%t", "VIP_Command", p_sName, PT_GetPlayTime(p_iTarget)/60);
	return Plugin_Handled;
}

public Action Command_Session(int p_iClient, p_iArgs){
	if(p_iArgs > 1){
		ReplyToCommand(p_iClient, "[SM] Usage: sm_session [name|#userid]");
		return Plugin_Handled;
	}
	
	int p_iTarget;
	
	if(p_iArgs == 1){
		if (!CheckCommandAccess(p_iClient, "pt_session_other", ADMFLAG_GENERIC)){
			CPrintToChat(p_iClient, "%t", "Not_Allowed");
			return Plugin_Handled;
		}
		char p_sName[256];
		GetCmdArg(1, p_sName, sizeof(p_sName));
		p_iTarget = FindTarget(p_iClient, p_sName, true);
	}
	
	if(p_iArgs == 0){
		p_iTarget = p_iClient;
	}
	
	char p_sName[21];
	GetClientName(p_iTarget, p_sName, sizeof(p_sName));
	
	char p_sDate[64];
	FormatTime(p_sDate, sizeof(p_sDate), ":%M:%S", PT_GetSession(p_iTarget));
	
	int p_iTime = PT_GetSession(p_iTarget) / 360;
	
	CPrintToChatAll("%t", "Session", p_sName, p_iTime, p_sDate);
	return Plugin_Handled;
}