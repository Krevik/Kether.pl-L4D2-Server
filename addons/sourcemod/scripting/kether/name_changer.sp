#pragma semicolon 1

#include <multicolors>
#include <sourcemod>
#include "sdktools_functions.inc"

public Plugin myinfo = 
{
    name = "Name changer",
    author = "Krevik",
    description = "Forces certain people to have certain nickname",
    version = "1.0.0",
    url = ""
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
    MarkNativeAsOptional("GetUserMessageType");
    return APLRes_Success;
} 

public void OnPluginStart()
{
	HookEvent("player_changename", OnNameChanged);
}

public void OnNameChanged(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("userid");
	int steamID = GetSteamAccountID(client, true);
	char[] steamIDString = "";
	IntToString(steamID, steamIDString, 128);
	char[] kuteSteamID = "0:37349827";
	char[] krevikSteamID = "0:23813599";
	if(StrContains(steamIDString, krevikSteamID, true) > 7){
		renameClient(client, "Krevik");
	}
	if(StrContains(steamIDString, kuteSteamID, true) > 7){
		renameClient(client, "potatekuwu");
	}
} 

public void OnClientPutInServer(int client)
{
	int steamID = GetSteamAccountID(client, true);
	char[] steamIDString = "";
	IntToString(steamID, steamIDString, 128);
	char[] kuteSteamID = "0:37349827";
	char[] krevikSteamID = "0:23813599";
	if(StrContains(steamIDString, krevikSteamID, true) > 7){
		renameClient(client, "Krevik");
	}
	if(StrContains(steamIDString, kuteSteamID, true) > 7){
		renameClient(client, "potatekuwu");
	}
}

public void renameClient(int client, char[] newName){
	if (IsValidClient(client))
	{	
		SetClientName(client, newName);
	}
}

stock bool IsValidClient(int client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}