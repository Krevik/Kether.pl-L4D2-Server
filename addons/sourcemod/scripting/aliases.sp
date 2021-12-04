#pragma semicolon 1

#include <multicolors>
#include <sourcemod>
#include "sdktools_functions.inc"

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
	if(IsValidClient(client) && GetClientTeam(client) != 1){
	
		decl String:name[MAX_NAME_LENGTH];
		name = "Console???";
		GetClientName(client, name, sizeof(name));
		if(GetClientTeam(client) == 2){
			CPrintToChatAll("{blue}%s{default} : {olive}Ready!", name);
		}else if(GetClientTeam(client) == 3){
			CPrintToChatAll("{red}%s{default} : {olive}Ready!", name);
		}
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
