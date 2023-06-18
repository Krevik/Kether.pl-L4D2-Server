#pragma semicolon 1
#include <sourcemod>
#include <colors>
#include <tentdev>

new bool:g_bLog[MAXPLAYERS+1];
new String:g_sPath[PLATFORM_MAX_PATH];
new Handle:g_hFile[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name 		= "tEntDev - log",
	author 		= "Thrawn",
	description = "Log output for tEntDev",
	version 	= VERSION,
};

public OnPluginStart() {
	CreateConVar("sm_tentdev_log_version", VERSION, "", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	BuildPath(Path_SM, g_sPath, sizeof(g_sPath), "logs/");
	RegAdminCmd("sm_ted_log", Command_SetLog, ADMFLAG_ROOT);
}

public OnAllPluginsLoaded() {
	if (!LibraryExists("ted")) {
		SetFailState("tEntDev plugin not loaded!");
	}
}

public OnClientDisconnect(client) {
	g_bLog[client] = false;
	CloseFile(client);
}

public CloseFile(client) {
	if(g_hFile[client] != INVALID_HANDLE) {
		CloseHandle(g_hFile[client]);
		g_hFile[client] = INVALID_HANDLE;
	}
}

public Action:Command_SetLog(client,args) {
	if(args == 1 && !g_bLog[client]) {
		new String:sFileName[32];
		GetCmdArg(1, sFileName, sizeof(sFileName));

		new String:sPath[PLATFORM_MAX_PATH];
		Format(sPath, sizeof(sPath), "%s%s.log", g_sPath, sFileName);

		g_hFile[client] = OpenFile(sPath, "w");
		g_bLog[client] = true;

		ReplyToCommand(client, "Started logging to %s", sPath);
	} else {
		if(g_bLog[client]) {
			g_bLog[client] = false;
			CloseFile(client);
			ReplyToCommand(client, "Stopped Logging");
		} else {
			ReplyToCommand(client, "Usage: sm_ted_log <filename>");
		}
	}

	return Plugin_Handled;
}

public TED_OnNetpropHint(client, const String:sText[], const String:sNetprop[]) {
	if(!g_bLog[client])return;
	WriteFileLine(g_hFile[client], "%s %s", sText, sNetprop);
}

public TED_OnInfo(client, const String:sText[]) {
	if(!g_bLog[client])return;
	WriteFileLine(g_hFile[client], "%s", sText);
}

public TED_OnCompare(client, const String:sNetprop[], const String:sOld[], const String:sNow[], iOffset) {
	if(!g_bLog[client])return;
	WriteFileLine(g_hFile[client], "%s (%i) changed from %s to %s", sNetprop, iOffset, sOld, sNow);
}

public TED_OnShow(client, const String:sNetprop[], const String:sNow[], iOffset) {
	if(!g_bLog[client])return;
	WriteFileLine(g_hFile[client], "%s (%i) is %s", sNetprop, iOffset, sNow);
}
