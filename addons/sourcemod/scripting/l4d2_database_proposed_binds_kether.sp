#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define BINDS_DB "l4d2_binds_kether"
#define CREATE_BINDS_TABLE "\
CREATE TABLE IF NOT EXISTS `l4d2_binds_kether` (\
 `SteamID` varchar(64) NOT NULL DEFAULT '',\
 `Contents` varchar(128) NOT NULL DEFAULT '0',\
 PRIMARY KEY (`SteamID`)\
) ENGINE=MyISAM DEFAULT CHARSET=utf8;\
"

Database KETHER_BINDS_DB;
char sql_error_buffer[512];
char sql_query[1024];
char sql_query2[1024];

public Plugin myinfo =
{
	name = "[L4D2] Proposed binds database",
	author = "Krevik, StarterX4",
	description = "Lets players to suggest new binds to be added later in kether hall of fame.",
	version = "1.0",
	url = "https://kether.pl"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Kether_AddDatabaseBindRecord", Kether_AddDatabaseBindRecord);
	return APLRes_Success;
}

public void OnPluginStart()
{
	KETHER_BINDS_DB = null;
	RegAdminCmd("sm_createBindsSQL", CMD_CreateBindsDataTable, ADMFLAG_CHEATS, "");
	RegConsoleCmd("sm_bind", CMD_AddBind, "sm_bind <Your bind's contents>");
}

public int Kether_AddDatabaseBindRecord(Handle plugin, int numParams)
{
	char columnName[512];
	int clientID;
	char bind;
	char buffer[128];
	
	GetNativeString(1, columnName, sizeof(columnName));
	GetCmdArg(1, buffer, sizeof(buffer));
	clientID = GetNativeCell(2);
	bind = StringToInt(buffer);
	addDatabaseRecord(columnName, clientID, bind);
	return -1;
}

public void addDatabaseRecord(char columnName[512], int clientID, int bind){
	if(clientID > 0 && clientID < MaxClients +1 && bind > 0){
		if(IsClientAndInGame(clientID)){
			if(!IsFakeClient(clientID)){
				char steamID[24];
				GetClientAuthId(clientID, AuthId_SteamID64, steamID, sizeof(steamID)-1);
				if(KETHER_BINDS_DB){
					sql_query2[0] = '\0';
					Format(sql_query2, sizeof(sql_query2)
					 , "UPDATE `l4d2_binds_kether` SET \
						%s = %s + %d \
						WHERE `SteamID` = '%s'"
					, columnName, columnName, bind
					, steamID);
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
			SQL_TQuery(KETHER_BINDS_DB, dbErrorLogger, CREATE_BINDS_TABLE, 0);
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

public void BindsSQLregisterClient(Handle owner, Handle handle, const char[] error, any data)
{
	int client = data;
	if (IsClientInGame(client))
	{
		char sTeamID[24];
		sql_query[0] = '\0';
		GetClientAuthId(client, AuthId_SteamID64, sTeamID, sizeof(sTeamID)-1);
		Format(sql_query, sizeof(sql_query)-1, "INSERT IGNORE INTO `l4d2_binds_kether` SET `SteamID` = '%s'", sTeamID);
		SQL_TQuery(KETHER_BINDS_DB, dbErrorLogger, sql_query, 0);
	}
}

public Action CMD_AddBind(int clientID, int bind){
	addDatabaseRecord("Contents", clientID, bind);
	return Plugin_Handled;
}

bool IsClientAndInGame(int index)
{
    return (index > 0 && index <= MaxClients && IsClientInGame(index));
}




