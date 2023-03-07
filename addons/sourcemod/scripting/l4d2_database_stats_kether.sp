#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#pragma newdecls required

#define STATS_DB "l4d2_stats_kether"
#define TEAM_SPECTATOR          1 
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

#define CREATE_STATS_TABLE "\
CREATE TABLE IF NOT EXISTS `l4d2_stats_kether` (\
 `SteamID` varchar(64) NOT NULL DEFAULT '',\
 `Hunter_Skeets` int(11) NOT NULL DEFAULT '0',\
 `Witch_Crowns` int(11) NOT NULL DEFAULT '0',\
 `Tongue_Cuts` int(11) NOT NULL DEFAULT '0',\
 `Smoker_Self_Clears` int(11) NOT NULL DEFAULT '0',\
 `Tank_Rocks_Skeeted` int(11) NOT NULL DEFAULT '0',\
 `Hunter_High_Pounces_25` int(11) NOT NULL DEFAULT '0',\
 `Death_Charges` int(11) NOT NULL DEFAULT '0',\
 `Common_Infected_Killed` int(11) NOT NULL DEFAULT '0',\
 `Friendly_Fire_Done` int(11) NOT NULL DEFAULT '0',\
 `Friendly_Fire_Received` int(11) NOT NULL DEFAULT '0',\
 PRIMARY KEY (`SteamID`)\
) ENGINE=MyISAM DEFAULT CHARSET=utf8;\
"

Database KETHER_STATS_DB;
char sql_error_buffer[512];
char sql_query[1024];
char sql_query2[1024];
Handle hRUPActive = INVALID_HANDLE;
bool bRUPActive;
bool bPlayerLeftStartArea;

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
    HookEvent("infected_death", InfectedDeath_Event, EventHookMode_Post);
	HookEvent("player_hurt", PlayerHurt_Event, EventHookMode_Post);
	HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);

	hRUPActive = FindConVar("l4d_ready_enabled");
    if (hRUPActive != INVALID_HANDLE)
    {
        bRUPActive = GetConVarBool(hRUPActive);
    } else {
        // not loaded
        bRUPActive = false;
    }
    bPlayerLeftStartArea = false;
}

public Action PlayerLeftStartArea(Handle event, const char[] name, bool dontBroadcast)
{
    bPlayerLeftStartArea = true;
}

public void OnMapStart()
{
    bPlayerLeftStartArea = false;
}

public void RoundStart_Event(Handle event, const char[] name, bool dontBroadcast)
{
    bPlayerLeftStartArea = false;
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
			}
			else
			{
				char sTeamID[24];
				sql_query[0] = '\0';
				if (KETHER_STATS_DB)
				{
					GetClientAuthId(client, AuthId_SteamID64, sTeamID, sizeof(sTeamID)-1);
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
			GetClientAuthId(client, AuthId_SteamID64, sTeamID, sizeof(sTeamID)-1);
			Format(sql_query, sizeof(sql_query)-1
			 , "SELECT \
				Hunter_Skeets, \
				Witch_Crowns \
				Tongue_Cuts \
				Smoker_Self_Clears \
				Tank_Rocks_Skeeted \
				Hunter_High_Pounces_25 \
				Death_Charges \
				Common_Infected_Killed \
				Friendly_Fire_Done \
				Friendly_Fire_Received \
				FROM `l4d2_stats_kether` WHERE `SteamID` = '%s'", sTeamID);

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

public void grantWitchCrown(int clientID){
	if(!IsFakeClient(clientID)){
		char steamID[24];
		GetClientAuthId(clientID, AuthId_SteamID64, steamID, sizeof(steamID)-1);
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

public void grantHunterSkeet(int clientID){
	if(!IsFakeClient(clientID)){
		char steamID[24];
		GetClientAuthId(clientID, AuthId_SteamID64, steamID, sizeof(steamID)-1);
		if(KETHER_STATS_DB){
			sql_query2[0] = '\0';
			Format(sql_query2, sizeof(sql_query2)
			 , "UPDATE `l4d2_stats_kether` SET \
				Hunter_Skeets = Hunter_Skeets + %d \
				WHERE `SteamID` = '%s'"
			, 1
			, steamID);

			SQL_TQuery(KETHER_STATS_DB, dbErrorLogger, sql_query2, 0);
		}
	}
}

public void grantTongueCut(int clientID){
	if(!IsFakeClient(clientID)){
		char steamID[24];
		GetClientAuthId(clientID, AuthId_SteamID64, steamID, sizeof(steamID)-1);
		if(KETHER_STATS_DB){
			sql_query2[0] = '\0';
			Format(sql_query2, sizeof(sql_query2)
			 , "UPDATE `l4d2_stats_kether` SET \
				Tongue_Cuts = Tongue_Cuts + %d \
				WHERE `SteamID` = '%s'"
			, 1
			, steamID);

			SQL_TQuery(KETHER_STATS_DB, dbErrorLogger, sql_query2, 0);
		}
	}
}

public void grantSmokerSelfClear(int clientID){
	if(!IsFakeClient(clientID)){
		char steamID[24];
		GetClientAuthId(clientID, AuthId_SteamID64, steamID, sizeof(steamID)-1);
		if(KETHER_STATS_DB){
			sql_query2[0] = '\0';
			Format(sql_query2, sizeof(sql_query2)
			 , "UPDATE `l4d2_stats_kether` SET \
				Smoker_Self_Clears = Smoker_Self_Clears + %d \
				WHERE `SteamID` = '%s'"
			, 1
			, steamID);

			SQL_TQuery(KETHER_STATS_DB, dbErrorLogger, sql_query2, 0);
		}
	}
}

public void grantTankRockSkeet(int clientID){
	if(!IsFakeClient(clientID)){
		char steamID[24];
		GetClientAuthId(clientID, AuthId_SteamID64, steamID, sizeof(steamID)-1);
		if(KETHER_STATS_DB){
			sql_query2[0] = '\0';
			Format(sql_query2, sizeof(sql_query2)
			 , "UPDATE `l4d2_stats_kether` SET \
				Tank_Rocks_Skeeted = Tank_Rocks_Skeeted + %d \
				WHERE `SteamID` = '%s'"
			, 1
			, steamID);

			SQL_TQuery(KETHER_STATS_DB, dbErrorLogger, sql_query2, 0);
		}
	}
}

public void grantHunterHighPounce25(int clientID){
	if(!IsFakeClient(clientID)){
		char steamID[24];
		GetClientAuthId(clientID, AuthId_SteamID64, steamID, sizeof(steamID)-1);
		if(KETHER_STATS_DB){
			sql_query2[0] = '\0';
			Format(sql_query2, sizeof(sql_query2)
			 , "UPDATE `l4d2_stats_kether` SET \
				Hunter_High_Pounces_25 = Hunter_High_Pounces_25 + %d \
				WHERE `SteamID` = '%s'"
			, 1
			, steamID);

			SQL_TQuery(KETHER_STATS_DB, dbErrorLogger, sql_query2, 0);
		}
	}
}

public void grantDeathCharge(int clientID){
	if(!IsFakeClient(clientID)){
		char steamID[24];
		GetClientAuthId(clientID, AuthId_SteamID64, steamID, sizeof(steamID)-1);
		if(KETHER_STATS_DB){
			sql_query2[0] = '\0';
			Format(sql_query2, sizeof(sql_query2)
			 , "UPDATE `l4d2_stats_kether` SET \
				Death_Charges = Death_Charges + %d \
				WHERE `SteamID` = '%s'"
			, 1
			, steamID);

			SQL_TQuery(KETHER_STATS_DB, dbErrorLogger, sql_query2, 0);
		}
	}
}

public void grantInfectedKill(int clientID){
	if(!IsFakeClient(clientID)){
		char steamID[24];
		GetClientAuthId(clientID, AuthId_SteamID64, steamID, sizeof(steamID)-1);
		if(KETHER_STATS_DB){
			sql_query2[0] = '\0';
			Format(sql_query2, sizeof(sql_query2)
			 , "UPDATE `l4d2_stats_kether` SET \
				Common_Infected_Killed = Common_Infected_Killed + %d \
				WHERE `SteamID` = '%s'"
			, 1
			, steamID);

			SQL_TQuery(KETHER_STATS_DB, dbErrorLogger, sql_query2, 0);
		}
	}
}

public void grantFriendlyFireDone(int clientID, int amount){
	if(!IsFakeClient(clientID)){
		char steamID[24];
		GetClientAuthId(clientID, AuthId_SteamID64, steamID, sizeof(steamID)-1);
		if(KETHER_STATS_DB){
			sql_query2[0] = '\0';
			Format(sql_query2, sizeof(sql_query2)
			 , "UPDATE `l4d2_stats_kether` SET \
				Friendly_Fire_Done = Friendly_Fire_Done + %d \
				WHERE `SteamID` = '%s'"
			, amount
			, steamID);

			SQL_TQuery(KETHER_STATS_DB, dbErrorLogger, sql_query2, 0);
		}
	}
}

public void grantFriendlyFireReceived(int clientID, int amount){
	if(!IsFakeClient(clientID)){
		char steamID[24];
		GetClientAuthId(clientID, AuthId_SteamID64, steamID, sizeof(steamID)-1);
		if(KETHER_STATS_DB){
			sql_query2[0] = '\0';
			Format(sql_query2, sizeof(sql_query2)
			 , "UPDATE `l4d2_stats_kether` SET \
				Friendly_Fire_Received = Friendly_Fire_Received + %d \
				WHERE `SteamID` = '%s'"
			, amount
			, steamID);

			SQL_TQuery(KETHER_STATS_DB, dbErrorLogger, sql_query2, 0);
		}
	}
}


public void InfectedDeath_Event(Handle event, const char[] name, bool dontBroadcast)
{
    int attackerId = GetEventInt(event, "attacker");
    int attacker = GetClientOfUserId(attackerId);
    
    if (attackerId && IsClientAndInGame(attacker) && !IsFakeClient(attacker) && GetClientTeam(attacker) == TEAM_SURVIVOR)
    {
        grantInfectedKill(attackerId);
    }
}

public void PlayerHurt_Event(Handle event, const char[] name, bool dontBroadcast)
{    
    int victimId = GetEventInt(event, "userid");
    int victim = GetClientOfUserId(victimId);
    
    int attackerId = GetEventInt(event, "attacker");
    int attacker = GetClientOfUserId(attackerId);
    
    int damageDone = GetEventInt(event, "dmg_health");
    
    if(victimId && attackerId && IsClientAndInGame(victim) && IsClientAndInGame(attacker))
    {
        if(GetClientTeam(attacker) == TEAM_SURVIVOR && GetClientTeam(victim) == TEAM_SURVIVOR)
        {
            if (!bRUPActive || GetEntityMoveType(victim) != MOVETYPE_NONE || bPlayerLeftStartArea) {
				grantFriendlyFireDone(attacker, damageDone);
				grantFriendlyFireReceived(victim, damageDone);
            }
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

public void OnSkeet(int survivor){
	grantHunterSkeet(survivor);
}

public void OnTongueCut(int survivor){
	grantTongueCut(survivor);
}

public void OnSmokerSelfClear(int survivor){
	grantSmokerSelfClear(survivor);
}

public void OnTankRockSkeeted(int survivor){
	grantTankRockSkeet(survivor);
}

public void OnHunterHighPounce(int survivor, int victim, int actualDamage){
	if(actualDamage == 25){
		grantHunterHighPounce25(survivor);
	}
}

public void OnDeathCharge(int survivor){
	grantDeathCharge(survivor);
}


public bool IsClientAndInGame(int index)
{
    return (index > 0 && index <= MaxClients && IsClientInGame(index));
}



