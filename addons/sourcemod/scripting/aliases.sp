#pragma semicolon 1

#include <multicolors>
#include <sourcemod>
#include "sdktools_functions.inc"

bool canReady[MAXPLAYERS + 1];

public Plugin myinfo = 
{
    name = "!r alias",
    author = "Krevik, StarterX4",
    description = "changes !r to !ready",
    version = "1.1.0",
    url = ""
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
    MarkNativeAsOptional("GetUserMessageType");
    return APLRes_Success;
} 

public void OnPluginStart()
{
	LoadTranslations("aliases.phrases");

	RegConsoleCmd("sm_r", Ready_CMD, "Let's get ready!");
	RegConsoleCmd("sm_ready", Ready_CMD, "Let's get ready!");
	RegConsoleCmd("sm_nr", NReady_CMD, "Let's get ready!");

	HookEvent("round_end", RoundEndEvent);
	initializeCanReady();
}

public void OnClientPutInServer(int client)
{
	canReady[client] = true;
}

public void RoundEndEvent(Handle event, const char[] name, bool dontBroadcast)
{
	initializeCanReady();
}

public Action:Ready_CMD(client, args)
{
	if(IsValidClient(client) && GetClientTeam(client) != 1 && args == 0){
	
		decl String:name[MAX_NAME_LENGTH];
		name = "Console???";
		GetClientName(client, name, sizeof(name));
		if(canReady[client]){
			if(GetClientTeam(client) == 2){
				CPrintToChatAll("%t", "RSurv", name);
				canReady[client] = false;
				delayAllowReady(client);
			}else if(GetClientTeam(client) == 3){
				CPrintToChatAll("%t", "RInf", name);
				canReady[client] = false;
				delayAllowReady(client);
			}
		}else{
			int team = GetClientTeam(client);
			if(team == 2 || team == 3){
				CPrintToChat(client, "%t", "Cooldown");
			}
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
		if(canReady[client]){
			if(GetClientTeam(client) == 2){
				CPrintToChatAll("%t", "NRSurv", name);
				canReady[client] = false;
				delayAllowReady(client);
			}else if(GetClientTeam(client) == 3){
				CPrintToChatAll("%t", "NRInf", name);
				canReady[client] = false;
				delayAllowReady(client);
			}
		}else{

		}
	}
	
	return Plugin_Handled;
}

stock bool IsValidClient(int client)
{ 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client)) return false; 
    return true;
}

public void initializeCanReady(){
	for (int x = 0; x <= MaxClients; x++) {
		canReady[x] = true;
	}
}

public void delayAllowReady(int client){
	DataPack pack;
	CreateDataTimer(3.0, AllowReady, pack);
	pack.WriteCell(client);
}

public Action AllowReady(Handle timer, DataPack pack)
{
	int client;
	pack.Reset();
	client = pack.ReadCell();
	canReady[client] = true;
	return Plugin_Continue;
}