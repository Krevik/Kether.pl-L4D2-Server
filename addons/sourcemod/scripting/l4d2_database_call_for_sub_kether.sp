#pragma semicolon 1
#pragma newdecls optional
#include <sourcemod>
#include <sdktools>
#include <multicolors>

#define SUBS_DB "l4d2_stats_kether"
#define CREATE_SUBS_TABLE "\
CREATE TABLE IF NOT EXISTS `l4d2_call_for_sub_kether` (\
 `LP` int(11) NOT NULL AUTO_INCREMENT,\
 `SteamID` varchar(64) NOT NULL DEFAULT '',\
 PRIMARY KEY (`LP`)\
) ENGINE=MyISAM DEFAULT CHARSET=utf8;\
"

Database KETHER_SUBS_DB;
char sql_error_buffer[512];
char sql_query[1024];
char sql_query2[1024];
bool canCallForSub[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "[ANY] Call For Sub",
	author = "Krevik, StarterX4",
	description = "Lets players to call for a sub.",
	version = "1.1",
	url = "https://kether.pl"
};

public void OnPluginStart()
{
	KETHER_SUBS_DB = null;
	RegAdminCmd("sm_createSubsSQL", CMD_CreateSubsDataTable, ADMFLAG_CHEATS, "");
	RegConsoleCmd("sm_sub", CMD_Sub, "Let's call for a sub");
}

public void OnClientPutInServer(int client)
{
	canCallForSub[client] = true;
}

public Action CMD_Sub(int client, int args)
{
	if(canCallForSub[client]){
		addDatabaseRecord(client);
		canCallForSub[client] = false;
		delayAllowCallForSub(client);
	}else{
		CPrintToChat(client, "Cooldown for calling for a sub: 5 minutes");
	}
	return Plugin_Handled;
}


public void addDatabaseRecord(int clientID){
	if(clientID > 0 && clientID < MaxClients +1){
		if(IsClientAndInGame(clientID)){
			if(!IsFakeClient(clientID)){
				char steamID[24];
				GetClientAuthId(clientID, AuthId_SteamID64, steamID, sizeof(steamID)-1);
				if(KETHER_SUBS_DB){
					sql_query[0] = '\0';
					Format(sql_query, sizeof(sql_query)-1, "INSERT IGNORE INTO `l4d2_call_for_sub_kether` (SteamID) VALUES ('%s')", steamID);
					SQL_TQuery(KETHER_SUBS_DB, dbErrorLogger, sql_query, 0);
					CPrintToChatAll("{blue}%N{default} called for a sub.", clientID);
				}
			}
		}
	}
}

public Action CMD_CreateSubsDataTable(int client, int args)
{
	if (client)
	{
		if (KETHER_SUBS_DB)
		{
			SQL_TQuery(KETHER_SUBS_DB, dbErrorLogger, CREATE_SUBS_TABLE, 0);
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
	KETHER_SUBS_DB = SQL_Connect(SUBS_DB, true, sql_error_buffer, sizeof(sql_error_buffer));
}

public void OnConfigsExecuted()
{
	if (!KETHER_SUBS_DB)
	{
		if (SQL_CheckConfig(SUBS_DB))
		{
			connectToDatabase();
			if (!KETHER_SUBS_DB)
			{
				LogError("%s", sql_error_buffer);
			}
		}
	}
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