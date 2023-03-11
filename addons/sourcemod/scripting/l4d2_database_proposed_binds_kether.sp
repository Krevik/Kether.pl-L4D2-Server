#pragma semicolon 1
#pragma newdecls optional
#include <sourcemod>
#include <sdktools>
#include <multicolors>

#define BINDS_DB "l4d2_stats_kether"
#define CREATE_STATS_TABLE "\
CREATE TABLE IF NOT EXISTS `l4d2_binds_kether` (\
 `LP` int(11) NOT NULL AUTO_INCREMENT,\
 `SteamID` varchar(64) NOT NULL DEFAULT '',\
 `Content` varchar(256) NOT NULL DEFAULT '',\
 PRIMARY KEY (`LP`)\
) ENGINE=MyISAM DEFAULT CHARSET=utf8;\
"

Database KETHER_BINDS_DB;
char sql_error_buffer[512];
char sql_query[1024];
char sql_query2[1024];
bool canPropose[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "[ANY] Proposed binds database",
	author = "Krevik, StarterX4",
	description = "Lets players to suggest new binds to be added later in kether hall of fame.",
	version = "1.1",
	url = "https://kether.pl"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("GetUserMessageType");
	return APLRes_Success;
}

public void OnPluginStart()
{
	KETHER_BINDS_DB = null;
	RegAdminCmd("sm_createBindsSQL", CMD_CreateBindsDataTable, ADMFLAG_CHEATS, "");
	RegConsoleCmd("sm_bind", CMD_Binds, "Let's add that bind");
}

public void OnClientPutInServer(int client)
{
	canPropose[client] = true;
}

public void RoundEndEvent(Handle event, const char[] name, bool dontBroadcast)
{
	initializeCanPropose();
}

public Action CMD_Binds(int client, int args)
{
	char Content[512];
	if(IsValidClient(client) && args == 0){
		decl String:name[MAX_NAME_LENGTH];
		name = "No way! Console?";
		GetClientName(client, name, sizeof(name));
		if(canPropose[client]){
			GetCmdArgString(Content, sizeof(Content));
			addDatabaseRecord(Content,client);
			delayAllowPropose(client);
		}
		else{
		CPrintToChat(client, "Don't spam! Wait for 15 seconds and try again.");
		}
	}
	return Plugin_Handled;
}


public void addDatabaseRecord(char Content[512], int clientID){
	if(clientID > 0 && clientID < MaxClients +1){
		if(IsClientAndInGame(clientID)){
			if(!IsFakeClient(clientID)){
				char steamID[24];
				GetClientAuthId(clientID, AuthId_SteamID64, steamID, sizeof(steamID)-1);
				if(KETHER_BINDS_DB){
					sql_query[0] = '\0';
					Format(sql_query, sizeof(sql_query)-1, "INSERT IGNORE INTO `l4d2_binds_kether` (SteamID, Content) VALUES ('%s', '%s')", steamID, Content);
					SQL_TQuery(KETHER_BINDS_DB, dbErrorLogger, sql_query, 0);
				}
			}
		}
	}
}

public Action CMD_CreateBindsDataTable(int client, int args)
{
	if (client)
	{
		if (KETHER_BINDS_DB)
		{
			SQL_TQuery(KETHER_BINDS_DB, dbErrorLogger, CREATE_STATS_TABLE, 0);
		}
	}

	return Plugin_Handled;
}

public void dbErrorLogger(Handle owner, Handle hndl, const char [] error, any data)
{
	if (error[0])
	{
		LogError("SQL Error: %s", error);
	}
}

public void connectToDatabase(){
	KETHER_BINDS_DB = SQL_Connect(BINDS_DB, true, sql_error_buffer, sizeof(sql_error_buffer));
}

public void OnConfigsExecuted()
{
	if (!KETHER_BINDS_DB)
	{
		if (SQL_CheckConfig(BINDS_DB))
		{
			connectToDatabase();
			if (!KETHER_BINDS_DB)
			{
				LogError("%s", sql_error_buffer);
			}
		}
	}
}

bool IsClientAndInGame(int index)
{
    return (index > 0 && index <= MaxClients && IsClientInGame(index));
}

stock bool IsValidClient(int client)
{ 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client)) return false; 
    return true;
}

public void initializeCanPropose(){
	for (int x = 0; x <= MaxClients; x++) {
		canPropose[x] = true;
	}
}

public void delayAllowPropose(int client){
	DataPack pack;
	CreateDataTimer(15.0, AllowPropose, pack);
	pack.WriteCell(client);
}

public Action AllowPropose(Handle timer, DataPack pack)
{
	int client;
	pack.Reset();
	client = pack.ReadCell();
	canPropose[client] = true;
	return Plugin_Continue;
}
