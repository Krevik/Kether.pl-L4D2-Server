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
float max_chat = 2.0;

enum struct PlayerInfo {
	float lastTime; /* Last time player used say or say_team */
	int tokenCount; /* Number of flood tokens player has */
}

PlayerInfo playerinfo[MAXPLAYERS+1];


public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
    MarkNativeAsOptional("GetUserMessageType");
    return APLRes_Success;
} 

public void OnClientPutInServer(int client)
{
	playerinfo[client].lastTime = 0.0;
	playerinfo[client].tokenCount = 0;
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

public bool OnClientFloodCheck(int client)
{
	max_chat = 2.0;
	
	if (max_chat <= 0.0 || CheckCommandAccess(client, "sm_flood_access", ADMFLAG_ROOT, true))
	{
		return false;
	}
	
	if (playerinfo[client].lastTime >= GetGameTime())
	{
		if (playerinfo[client].tokenCount >= 3)
		{
			return true;
		}
	}
	
	return false;
}

public void OnClientFloodResult(int client, bool blocked)
{
	if (max_chat <= 0.0 
 		|| CheckCommandAccess(client, "sm_flood_access", ADMFLAG_ROOT, true))
	{
		return;
	}
	
	float curTime = GetGameTime();
	float newTime = curTime + max_chat;
	
	if (playerinfo[client].lastTime >= curTime)
	{
		/* If the last message was blocked, update their time limit */
		if (blocked)
		{
			newTime += 3.0;
		}
		/* Add one flood token when player goes over chat time limit */
		else if (playerinfo[client].tokenCount < 3)
		{
			playerinfo[client].tokenCount++;
		}
	}
	else if (playerinfo[client].tokenCount > 0)
	{
		/* Remove one flood token when player chats within time limit (slow decay) */
		playerinfo[client].tokenCount--;
	}
	
	playerinfo[client].lastTime = newTime;
}


stock bool IsValidClient(int client)
{ 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client)) return false; 
    return true;
}