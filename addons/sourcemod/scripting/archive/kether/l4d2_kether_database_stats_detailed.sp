#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2_utils>
#define STATS_DB "l4d2_stats_kether"
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == 2)

/**
 * TABLE DEFINITION
 */
#define CREATE_STATS_TABLE "\
CREATE TABLE IF NOT EXISTS `l4d2_stats_kether_detailed` (\
 `steamID` varchar(64) NOT NULL DEFAULT '',\
 `lastKnownSteamName` varchar(256) NOT NULL DEFAULT 'Undefined',\
 `profileUrl` int(11) NOT NULL DEFAULT '0',\
 `avatarMediumSrc` int(11) NOT NULL DEFAULT '0',\
 `hunterSkeets` int(11) NOT NULL DEFAULT '0',\
 `witchCrowns` int(11) NOT NULL DEFAULT '0',\
 `tongueCuts` int(11) NOT NULL DEFAULT '0',\
 `smokerSelfClears` int(11) NOT NULL DEFAULT '0',\
 `tankRockSkeets` int(11) NOT NULL DEFAULT '0',\
 `hunterHighPounces` int(11) NOT NULL DEFAULT '0',\
 `deathCharges` int(11) NOT NULL DEFAULT '0',\
 `commonsKilled` int(11) NOT NULL DEFAULT '0',\
 `commonsKilledPercent` int(11) NOT NULL DEFAULT '0',\
 `friendlyFireReceived` int(11) NOT NULL DEFAULT '0',\
 `friendlyFireDone` int(11) NOT NULL DEFAULT '0',\
 `friendlyFireDonePercent` int(11) NOT NULL DEFAULT '0',\
 `damageDoneToSurvivorsAsSI` int(11) NOT NULL DEFAULT '0',\
 `damageDoneToSurvivorsAsSIPercent` int(11) NOT NULL DEFAULT '0',\
 `damageDoneToSurvivorsAsTank` int(11) NOT NULL DEFAULT '0',\
 `numberOfKilledSurvivors` int(11) NOT NULL DEFAULT '0',\
 `damageDoneToSI` int(11) NOT NULL DEFAULT '0',\
 `damageDoneToSIPercent` int(11) NOT NULL DEFAULT '0',\
 `damageDoneToTanks` int(11) NOT NULL DEFAULT '0',\
 `damageDoneToTanksPercent` int(11) NOT NULL DEFAULT '0',\
 `boomerClears` int(11) NOT NULL DEFAULT '0',\
 `numberOfShots` int(11) NOT NULL DEFAULT '0',\
 `numberOfShotsHitOnSI` int(11) NOT NULL DEFAULT '0',\
 `numberOfShotsHitOnFF` int(11) NOT NULL DEFAULT '0',\
 `numberOfShotsHitOnTanks` int(11) NOT NULL DEFAULT '0',\
 `numberOfHeadshotsDoneToSI` int(11) NOT NULL DEFAULT '0',\
 `numberofHeadshotsDoneToCommons` int(11) NOT NULL DEFAULT '0',\
 `healthLost` int(11) NOT NULL DEFAULT '0',\
 `medkitsUsed` int(11) NOT NULL DEFAULT '0',\
 `medkitsReceived` int(11) NOT NULL DEFAULT '0',\
 `medkitsUsedOnTeammates` int(11) NOT NULL DEFAULT '0',\
 `pillsUsed` int(11) NOT NULL DEFAULT '0',\
 `friendRescues` int(11) NOT NULL DEFAULT '0',\
 `incapsReceived` int(11) NOT NULL DEFAULT '0',\
 `playerOverallScore` int(11) NOT NULL DEFAULT '0',\
 `gameplayTime` int(11) NOT NULL DEFAULT '0',\
 PRIMARY KEY (`steamID`)\
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4;\
"
/**
 * VARIABLES
 */
Database KETHER_STATS_DB;
char sql_error_buffer[512];
char sql_query[1024];
int commonsKilled[128];

/**
 * INITIALIZATION and database setup and basic functions setup
 */
public Plugin myinfo =
{
	name = "[L4D2] Kether GamePlay Advanced Stats",
	author = "Krevik",
	description = "L4D2 Coop Stats",
	version = "1.0",
	url = "https://kether.pl"
};

public void OnPluginStart()
{
	/**
	 * VARIABLES INITIALIZATION
	 */
	KETHER_STATS_DB = null;
	/**
	 * COMMANDS
	 */
	RegAdminCmd("sm_createDetailedStatsSQL", CMD_CreateStatsDataTable, ADMFLAG_CHEATS, "");


	/**
	 * EVENTS
	 */
    // HookEvent("player_left_start_area", PlayerLeftStartArea_Event, EventHookMode_PostNoCopy);
    //HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
    // HookEvent("player_team", PlayerTeamChange_Event, EventHookMode_PostNoCopy);
    // HookEvent("infected_death", InfectedDeath_Event, EventHookMode_Post);

	/**
	 * TIMERS
	 */
	//CreateTimer(5.0, updateGamePlayTime, _, TIMER_REPEAT);

}

public void connectToDatabase(){
	KETHER_STATS_DB = SQL_Connect(STATS_DB, true, sql_error_buffer, sizeof(sql_error_buffer));
}

public void dbErrorLogger(Handle owner, Handle hndl, const char [] error, any data)
{
	if (error[0])
	{
		LogError("SQL Error: %s", error);
	}
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

public void updateDatabaseRecord(char columnName[512], int clientID, int amount){
	if(clientID > 0 && clientID < MaxClients +1 && amount > 0){
		if(IsClientAndInGame(clientID)){
			if(!IsFakeClient(clientID)){
				char steamID[24];
				GetClientAuthId(clientID, AuthId_SteamID64, steamID, sizeof(steamID)-1);
				if(KETHER_STATS_DB){
					sql_query[0] = '\0';
					Format(sql_query, sizeof(sql_query)
					 , "UPDATE `l4d2_stats_kether` SET \
						%s = %s + %d \
						WHERE `steamID` = '%s'"
					, columnName, columnName, amount
					, steamID);
					SQL_TQuery(KETHER_STATS_DB, dbErrorLogger, sql_query, 0);
				}
			}
		}
	}
}

public void OnConfigsExecuted()
{
	if (!KETHER_STATS_DB)
	{
		if (SQL_CheckConfig(STATS_DB))
		{
			connectToDatabase();
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
		char sTeamID[24];
		sql_query[0] = '\0';
		GetClientAuthId(client, AuthId_SteamID64, sTeamID, sizeof(sTeamID)-1);
		Format(sql_query, sizeof(sql_query)-1, "INSERT IGNORE INTO `l4d2_stats_kether` SET `steamID` = '%s'", sTeamID);
		SQL_TQuery(KETHER_STATS_DB, dbErrorLogger, sql_query, 0);
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
			GetClientAuthId(client, AuthId_SteamID64, sTeamID, sizeof(sTeamID)-1);
			Format(sql_query, sizeof(sql_query)-1
			 , "SELECT \
				*\
				FROM `l4d2_stats_kether` WHERE `steamID` = '%s'", sTeamID);

			SQL_TQuery(KETHER_STATS_DB, StatsSQLregisterClient, sql_query, client);
		}
	}

	return Plugin_Stop;
}

public void OnClientPostAdminCheck(int client)
{
	if (!IsFakeClient(client))
	{
		CreateTimer(0.5, SQLTimerClientPost, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public int getPlayerBySteamID(const char[] steamID) 
{
    char tmpSteamID[64];
   
    for (int client = 1; client <= MaxClients; client++) 
    {
        if (!IsClientInGame(client))
            continue;
        
        GetClientAuthId(client, AuthId_Steam2, tmpSteamID, sizeof(tmpSteamID));     
        
        if (strcmp(steamID, tmpSteamID) == 0)
            return client;
    }
    
    return -1;
}

bool IsValidPlayer(int index)
{
    return (index > 0 && index <= MaxClients && IsClientInGame(index) && !IsFakeClient(client) && (IS_INFECTED(client) || IS_SURVIVOR(client)) );
}

bool isValidForDatabaseUpdate(int player){
	return IsValidPlayer(player);
}

/**
 * FUNCTIONALITIES
 */

