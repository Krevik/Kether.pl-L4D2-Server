#pragma semicolon 1
#pragma newdecls optional
#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <ripext> 

bool canCallForSub[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "[ANY] Call For Sub",
	author = "Krevik, StarterX4",
	description = "Lets players to call for a sub.",
	version = "2.0.1",
	url = "https://kether.pl"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_sub", CMD_Sub, "Let's call for a sub");
}

public void OnClientPutInServer(int client)
{
	canCallForSub[client] = true;
}

public Action CMD_Sub(int client, int args)
{
	if(canCallForSub[client]){
		postCallForSubRequest(client);
		canCallForSub[client] = false;
		delayAllowCallForSub(client);
	}else{
		CPrintToChat(client, "Cooldown for calling for a sub: 5 minutes");
	}
	return Plugin_Handled;
}

public void postCallForSubRequest(int clientID)
{
	if(clientID > 0 && clientID < MaxClients +1){
		if(IsClientAndInGame(clientID)){
			if(!IsFakeClient(clientID)){
				char steamID[24];
				GetClientAuthId(clientID, AuthId_SteamID64, steamID, sizeof(steamID)-1);

				JSONObject cfs = new JSONObject();
				cfs.SetInt64("steamID", steamID);

				HTTPRequest request = new HTTPRequest("http://21370000.xyz/api/callForSub");
				request.Post(cfs, OnCalledForSub, clientID);

				// JSON objects and arrays must be deleted when you are done with them
    			delete cfs;
			}
		}
	}
}

void OnCalledForSub(HTTPResponse response, int clientID)
{
	if (response.Status != HTTPStatus_OK) {
        CPrintToChat(clientID, "Failed to call for sub.");
        return;
    }
	CPrintToChatAll("{blue}%N{default} called for a sub.", clientID);
}

public void delayAllowCallForSub(int client){
	DataPack pack;
	CreateDataTimer(300.0, AllowCallSub, pack);
	pack.WriteCell(client);
}

public Action AllowCallSub(Handle timer, DataPack pack)
{
	int client;
	pack.Reset();
	client = pack.ReadCell();
	canCallForSub[client] = true;
	return Plugin_Continue;
}

bool IsClientAndInGame(int index)
{
    return (index > 0 && index <= MaxClients && IsClientInGame(index));
}
