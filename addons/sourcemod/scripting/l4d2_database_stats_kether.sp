#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#pragma newdecls required

#define STATS_DB "l4d2_stats_kether"

#define CREATE_STATS_TABLE "\
CREATE TABLE IF NOT EXISTS `l4d2_stats_kether` (\
 `SteamID` varchar(32) NOT NULL DEFAULT '',\
 `Hunter_Skeets` int(11) NOT NULL DEFAULT '0',\
 `Witch_Crowns` int(11) NOT NULL DEFAULT '0',\
 PRIMARY KEY (`SteamID`)\
) ENGINE=MyISAM DEFAULT CHARSET=utf8;\
"

Database KETHER_STATS_DB;
char sql_error_buffer[512];
int database_values[MAXPLAYERS+1][16];
#define DB_POINTER_HUNTER_SKEETS   0
#define DB_POINTER_WITCH_CROWNS   1
char sql_query[1024];
char sql_query2[1024];

public Plugin myinfo =
{
	name = "[L4D2] Play Stats",
	author = "Krevik",
	description = "L4D2 Coop Stats",
	version = "1.0",
	url = "https://kether.pl"
};


public void OnPluginStart()
{
	KETHER_STATS_DB = null;
	RegAdminCmd("sm_createStatsSQL", CMD_CreateStatsDataTable, ADMFLAG_CHEATS, "");

}

public Action CMD_CreateStatsDataTable(int client, int args)
{
	if (client)
	{
		if (KETHER_STATS_DB)
		{
			SQL_TQuery(KETHER_STATS_DB, dbErrorLogger, CREATE_STATS_TABLE, 0);
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

public void OnConfigsExecuted()
{
	if (!KETHER_STATS_DB)
	{
		if (SQL_CheckConfig(STATS_DB))
		{
			KETHER_STATS_DB = SQL_Connect(STATS_DB, true, sql_error_buffer, sizeof(sql_error_buffer));
			if (!KETHER_STATS_DB)
			{
				LogError("%s", sql_error_buffer);
			}
		}
	}
}

public void StatsSQLregisterClient(Handle owner, Handle handle, const char[] error, any data)
{
	int client = data;
	if (IsClientInGame(client))
	{
		if (handle)
		{
			if (SQL_FetchRow(handle))
			{
				database_values[client][DB_POINTER_HUNTER_SKEETS]   = SQL_FetchInt(handle, DB_POINTER_HUNTER_SKEETS);
				database_values[client][DB_POINTER_WITCH_CROWNS]     = SQL_FetchInt(handle, DB_POINTER_WITCH_CROWNS);
			}
			else
			{
				char sTeamID[24];
				sql_query[0] = '\0';
				if (KETHER_STATS_DB)
				{
					GetClientAuthId(client, AuthId_Steam2, sTeamID, sizeof(sTeamID)-1);
					Format(sql_query, sizeof(sql_query)-1, "INSERT IGNORE INTO `l4d2_stats_kether` SET `SteamID` = '%s'", sTeamID);
					SQL_TQuery(KETHER_STATS_DB, dbErrorLogger, sql_query, 0);
				}
			}
		}
	}
}

public Action SQLTimerClientPost(Handle timer, any client)
{
	if (IsClientInGame(client))
	{
		if (KETHER_STATS_DB)
		{
			char sTeamID[24];
			sql_query[0] = '\0';
			GetClientAuthId(client, AuthId_Steam2, sTeamID, sizeof(sTeamID)-1);
			Format(sql_query, sizeof(sql_query)-1
			 , "SELECT \
				Hunter_Skeets, \
				Witch_Crowns \
				FROM `l4d2_stats_kether` WHERE `SteamID` = '%s'", sTeamID);

			SQL_TQuery(KETHER_STATS_DB, StatsSQLregisterClient, sql_query, client);
		}
	}

	return Plugin_Stop;
}

void CleanLocalValues(int &client)
{
	database_values[client][DB_POINTER_HUNTER_SKEETS] = 0;
	database_values[client][DB_POINTER_WITCH_CROWNS] = 0;
}

public void OnClientPostAdminCheck(int client)
{
	if (!IsFakeClient(client))
	{
		CleanLocalValues(client);
		CreateTimer(0.5, SQLTimerClientPost, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void OnClientDisconnect(int client)
{
	if (!IsFakeClient(client))
	{
		if (database_values[client][DB_POINTER_HUNTER_SKEETS])
		{
			if (KETHER_STATS_DB)
			{
				char sTeamID[24];

				sql_query2[0] = '\0';
				GetClientAuthId(client, AuthId_Steam2, sTeamID, sizeof(sTeamID)-1);
				Format(sql_query2, sizeof(sql_query2)
				 , "UPDATE `l4d2_stats_kether` SET \
					Hunter_Skeets = Hunter_Skeets + %d, \
					Witch_Crowns = Witch_Crowns + %d \
					WHERE `SteamID` = '%s'"
				, database_values[client][DB_POINTER_HUNTER_SKEETS]
				, database_values[client][DB_POINTER_WITCH_CROWNS]
				, sTeamID);

				SQL_TQuery(KETHER_STATS_DB, dbErrorLogger, sql_query2, 0);
			}
		}

		CleanLocalValues(client);
	}
}

public void grantWitchCrown(int clientID){
	if(!IsFakeClient(clientID)){
		char steamID[24];
		GetClientAuthId(clientID, AuthId_Steam2, steamID, sizeof(steamID)-1);
		if(KETHER_STATS_DB){
			sql_query2[0] = '\0';
			Format(sql_query2, sizeof(sql_query2)
			 , "UPDATE `l4d2_stats_kether` SET \
				Witch_Crowns = Witch_Crowns + %d \
				WHERE `SteamID` = '%s'"
			, 1
			, steamID);

			SQL_TQuery(KETHER_STATS_DB, dbErrorLogger, sql_query2, 0);
		}
	}
}

public void Kether_OnWitchCrown(int clientID)
{
	grantWitchCrown(clientID);
}

public void Kether_OnWitchDrawCrown(int clientID)
{
	grantWitchCrown(clientID);
}
