#pragma semicolon 1

#include <multicolors>
#include <sourcemod>
#include "sdktools_functions.inc"

public Plugin myinfo = 
{
    name = "!vip command",
    author = "Krevik",
    description = "Prints available vip commands to player",
    version = "1.0.0",
    url = ""
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
    MarkNativeAsOptional("GetUserMessageType");
    return APLRes_Success;
} 

public void OnPluginStart()
{
	RegConsoleCmd("sm_v", Vip_CMD, "Let's print those commands!");
	RegConsoleCmd("sm_vip", Vip_CMD, "Let's print those commands!");
}

public Action:Vip_CMD(client, args)
{
	if(IsValidClient(client) && GetClientTeam(client) != 1 && args == 0){
		CPrintToChat(client, "[{green}Vip Commands{default}] {olive}!hat ");
		CPrintToChat(client, "[{green}Vip Commands{default}] {olive}!wskin ");
	}
	
	return Plugin_Handled;
}

stock bool IsValidClient(int client)
{ 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client)) return false; 
    return true;
}