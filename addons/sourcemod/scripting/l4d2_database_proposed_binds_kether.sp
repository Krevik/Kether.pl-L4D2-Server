#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define BINDS_DB "l4d2_binds_kether"
#define CREATE_STATS_TABLE "\
CREATE TABLE IF NOT EXISTS `l4d2_binds_kether` (\
 `SteamID` varchar(64) NOT NULL DEFAULT '',\
 `Content` varchar(256) NOT NULL DEFAULT '0',\
 PRIMARY KEY (`SteamID`)\
) ENGINE=MyISAM DEFAULT CHARSET=utf8;\
"

Database KETHER_BINDS_DB;
char sql_error_buffer[512];
char sql_query[1024];
char sql_query2[1024];
int commonsKilled[128];

public Plugin myinfo =
{
	name = "[L4D2] Play Stats",
	author = "Krevik",
	description = "L4D2 Coop Stats",
	version = "1.0",
	url = "https://kether.pl"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	return APLRes_Success;
}

public void OnPluginStart()
{
	KETHER_BINDS_DB = null;
	RegAdminCmd("sm_createBindsSQL", CMD_CreateBindsDataTable, ADMFLAG_CHEATS, "");
	RegConsoleCmd("sm_binds", CMD_Binds, "Let's add that bind");
}

public Action CMD_Binds(int client, int args)
{
	char Content[512];
	GetCmdArgString(Content, sizeof(Content));
	addDatabaseRecord(Content,client);
	return Plugin_Handled;
}


public void addDatabaseRecord(char Content[512], int clientID){

	if(clientID > 0 && clientID < MaxClients +1 && Content){
		if(IsClientAndInGame(clientID)){
			if(!IsFakeClient(clientID)){
				char steamID[24];
				GetClientAuthId(clientID, AuthId_SteamID64, steamID, sizeof(steamID)-1);
				if(KETHER_BINDS_DB){
					sql_query2[0] = '\0';
					Format(sql_query, sizeof(sql_query)-1, "INSERT IGNORE INTO `l4d2_binds_kether` SET `SteamID` = '%s'", steamID);
					SQL_TQuery(KETHER_BINDS_DB, dbErrorLogger, sql_query2, 0);
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




