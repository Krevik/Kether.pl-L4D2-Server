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
	version = "2.0.2",
	url = "https://kether.pl"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_sub", CMD_Sub, "Let's call for a sub");
	RegAdminCmd("sm_sub_undelay", Admin_CMD_Sub_UnDelay, ADMFLAG_ROOT, "Let's call for a sub again so quickly!");
}

public void OnClientPutInServer(int client)
{
	canCallForSub[client] = true;
}

public Action CMD_Sub(int client, int args)
{
	if(canCallForSub[client]){
		postCallForSubRequest(client);
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
		LogError("Call For Sub HTTP request failed! Status: %s", response.Status);
        return;
    }
	CPrintToChatAll("{blue}%N{default} called for a sub.", clientID);
	canCallForSub[clientID] = false;
	delayAllowCallForSub(clientID);
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

public Action Admin_CMD_Sub_UnDelay(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_sub_undelay <#userid|name>");
		return Plugin_Handled;
	}
	else if(args > 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_sub_undelay <#userid|name>");
		return Plugin_Handled;		
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		if (!IsClientAndInGame(target_list[i])) {return Plugin_Handled;}
		canCallForSub[target_list[i]] = true;
		CPrintToChat(client, "[Call For Sub] 5min delay removed for {blue}%N{default}", target_list[i]);
	}

	return Plugin_Handled;
}
