#pragma semicolon 1

#include <multicolors>
#include <sourcemod>
#include "sdktools_functions.inc"
#define FADE_COLOR_R         128
#define FADE_COLOR_G         0
#define FADE_COLOR_B         0
#define FADE_ALPHA_LEVEL     128
public Plugin myinfo = 
{
    name = "!r alias",
    author = "Krevik",
    description = "changes !r to !ready",
    version = "1.0.0",
    url = ""
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
    MarkNativeAsOptional("GetUserMessageType");
    return APLRes_Success;
} 

public void OnPluginStart()
{
	RegConsoleCmd("sm_r", Ready_CMD, "Let's get ready!");
	RegConsoleCmd("sm_ready", Ready_CMD, "Let's get ready!");
	RegConsoleCmd("sm_nr", NReady_CMD, "Let's get ready!");
}

public Action:Ready_CMD(client, args)
{
	if(IsValidClient(client) && GetClientTeam(client) != 1 && args < 1){
	
		decl String:name[MAX_NAME_LENGTH];
		name = "Console???";
		GetClientName(client, name, sizeof(name));
		if(GetClientTeam(client) == 2){
			CPrintToChatAll("{blue}%s{default} : {olive}Ready!", name);
		}else if(GetClientTeam(client) == 3){
			CPrintToChatAll("{red}%s{default} : {olive}Ready!", name);
		}
	}
	if(args > 0){
	    decl String:arg[MAX_NAME_LENGTH];
		int i = 1;
		GetCmdArg(i, arg, sizeof(args))
		GetClientName(client, name, sizeof(name));
	}
	
	return Plugin_Handled;
}

public Action:NReady_CMD(client, args)
{
	if(IsValidClient(client) && GetClientTeam(client) != 1){
	
		decl String:name[MAX_NAME_LENGTH];
		name = "Console???";
		GetClientName(client, name, sizeof(name));
		if(GetClientTeam(client) == 2){
			CPrintToChatAll("{blue}%s{default} : {Darkred}Not Ready!", name);
		}else if(GetClientTeam(client) == 3){
			CPrintToChatAll("{red}%s{default} : {Darkred}Not Ready!", name);
		}
	}
	
	return Plugin_Handled;
}


stock bool IsValidClient(int client)
{ 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client)) return false; 
    return true;
}