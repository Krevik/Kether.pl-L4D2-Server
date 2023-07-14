#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define STATS_DB "l4d2_stats_kether"
#define TEAM_SPECTATOR          1 
#define TEAM_SURVIVOR           2 
#define TEAM_INFECTED           3
#define ZC_SMOKER               1
#define ZC_BOOMER               2
#define ZC_HUNTER               3
#define ZC_SPITTER              4
#define ZC_JOCKEY               5
#define ZC_CHARGER              6
#define ZC_WITCH                7
#define ZC_TANK                 8
#define CREATE_STATS_TABLE "\
CREATE TABLE IF NOT EXISTS `l4d2_stats_kether` (\
 `SteamID` varchar(64) NOT NULL DEFAULT '',\
 `LastKnownSteamName` varchar(256) NOT NULL DEFAULT 'Undefined',\
 `Hunter_Skeets` int(11) NOT NULL DEFAULT '0',\
 `Witch_Crowns` int(11) NOT NULL DEFAULT '0',\
 `Tongue_Cuts` int(11) NOT NULL DEFAULT '0',\
 `Smoker_Self_Clears` int(11) NOT NULL DEFAULT '0',\
 `Tank_Rocks_Skeeted` int(11) NOT NULL DEFAULT '0',\
 `Hunter_High_Pounces_25` int(11) NOT NULL DEFAULT '0',\
 `Death_Charges` int(11) NOT NULL DEFAULT '0',\
 `Commons_Killed` int(11) NOT NULL DEFAULT '0',\
 `Friendly_Fire_Received` int(11) NOT NULL DEFAULT '0',\
 `Friendly_Fire_Done` int(11) NOT NULL DEFAULT '0',\
 `Damage_Done_To_Survivors` int(11) NOT NULL DEFAULT '0',\
 `Damage_Done_To_SI` int(11) NOT NULL DEFAULT '0',\
 `Damage_Done_To_Tanks` int(11) NOT NULL DEFAULT '0',\
 `Gameplay_Time` int(11) NOT NULL DEFAULT '0',\
 PRIMARY KEY (`SteamID`)\
) ENGINE=MyISAM DEFAULT CHARSET=utf8;\
"

Database KETHER_STATS_DB;
char sql_error_buffer[512];
char sql_query[1024];
char sql_query2[1024];
int commonsKilled[128];
int damageDoneToSI[128];
int damageDoneToTank[128];
int damageDoneToSurvivors[128];
ArrayList survivorsFromRoundBeggining;
Handle commonsKilledPerRoundHandle = INVALID_HANDLE;
Handle huntersSkeetedPerRoundHandle = INVALID_HANDLE;
Handle damageDoneToSIPerRoundHandle = INVALID_HANDLE;
Handle friendlyFireDonePerRoundHandle = INVALID_HANDLE;
Handle friendlyRecoversPerRoundHandle = INVALID_HANDLE;

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
	CreateNative("Kether_AddDatabaseStatRecord", Kether_AddDatabaseStatRecord);
	return APLRes_Success;
}

public void OnPluginStart()
{
	KETHER_STATS_DB = null;
	commonsKilledPerRoundHandle = CreateTrie();
	huntersSkeetedPerRoundHandle = CreateTrie();
	damageDoneToSIPerRoundHandle = CreateTrie();
	friendlyFireDonePerRoundHandle = CreateTrie();
	friendlyRecoversPerRoundHandle = CreateTrie();
	survivorsFromRoundBeggining = new ArrayList(ByteCountToCells(512));
	RegAdminCmd("sm_createStatsSQL", CMD_CreateStatsDataTable, ADMFLAG_CHEATS, "");
    HookEvent("infected_death", InfectedDeath_Event, EventHookMode_Post);
	HookEvent("player_hurt", PlayerHurt_Event, EventHookMode_Post);
	HookEvent("player_left_start_area", PlayerLeftStartArea_Event, EventHookMode_PostNoCopy);
	HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("revive_success", ReviveSuccess_Event, EventHookMode_Post);
	CreateTimer(30.0, databaseUpdateGamePlayTime, _, TIMER_REPEAT);

}

public int Kether_AddDatabaseStatRecord(Handle plugin, int numParams)
{
	char columnName[512];
	int clientID;
	int amount;
	
	GetNativeString(1, columnName, sizeof(columnName));
	clientID = GetNativeCell(2);
	amount = GetNativeCell(3);
	addDatabaseRecord(columnName, clientID, amount);
	return -1;
}

public void addDatabaseRecord(char columnName[512], int clientID, int amount){
	if(clientID > 0 && clientID < MaxClients +1 && amount > 0){
		if(IsClientAndInGame(clientID)){
			if(!IsFakeClient(clientID)){
				char steamID[24];
				GetClientAuthId(clientID, AuthId_SteamID64, steamID, sizeof(steamID)-1);
				if(KETHER_STATS_DB){
					sql_query2[0] = '\0';
					Format(sql_query2, sizeof(sql_query2)
					 , "UPDATE `l4d2_stats_kether` SET \
						%s = %s + %d \
						WHERE `SteamID` = '%s'"
					, columnName, columnName, amount
					, steamID);
					SQL_TQuery(KETHER_STATS_DB, dbErrorLogger, sql_query2, 0);
				}
			}
		}
	}
}

public void addCommonsKilledAverageEntry(char steamID[64], int amount){
	if(KETHER_STATS_DB){
		sql_query2[0] = '\0';
		Format(sql_query2, sizeof(sql_query2)-1, "INSERT INTO `l4d2_stats_kether_commons_killed_averages` SET `SteamID` = '%s', `Commons_Killed_In_Round_Entry` = '%d' ", steamID, amount);
		SQL_TQuery(KETHER_STATS_DB, dbErrorLogger, sql_query2, 0);
	}
}

public void addHunterSkeetsAverageEntry(char steamID[64], int amount){
	if(KETHER_STATS_DB){
		sql_query2[0] = '\0';
		Format(sql_query2, sizeof(sql_query2)-1, "INSERT INTO `l4d2_stats_kether_hunter_skeets_averages` SET `SteamID` = '%s', `Hunters_Skeeted_In_Round_Entry` = '%d' ", steamID, amount);
		SQL_TQuery(KETHER_STATS_DB, dbErrorLogger, sql_query2, 0);
	}
}

public void addDamageDoneToSIAverageEntry(char steamID[64], int amount){
	if(KETHER_STATS_DB){
		sql_query2[0] = '\0';
		Format(sql_query2, sizeof(sql_query2)-1, "INSERT INTO `l4d2_stats_kether_damage_done_to_si_averages` SET `SteamID` = '%s', `Damage_Done_To_SI_In_Round_Entry` = '%d' ", steamID, amount);
		SQL_TQuery(KETHER_STATS_DB, dbErrorLogger, sql_query2, 0);
	}
}

public void addFriendlyFireDoneAverageEntry(char steamID[64], int amount){
	if(KETHER_STATS_DB){
		sql_query2[0] = '\0';
		Format(sql_query2, sizeof(sql_query2)-1, "INSERT INTO `l4d2_stats_kether_friendly_fire_done_averages` SET `SteamID` = '%s', `Friendly_Fire_Done_In_Round_Entry` = '%d' ", steamID, amount);
		SQL_TQuery(KETHER_STATS_DB, dbErrorLogger, sql_query2, 0);
	}
}

public void addFriendlyRecoverAverageEntry(char steamID[64], int amount){
	if(KETHER_STATS_DB){
		sql_query2[0] = '\0';
		Format(sql_query2, sizeof(sql_query2)-1, "INSERT INTO `l4d2_stats_kether_friendly_recover_averages` SET `SteamID` = '%s', `Friendly_Recover_In_Round_Entry` = '%d' ", steamID, amount);
		SQL_TQuery(KETHER_STATS_DB, dbErrorLogger, sql_query2, 0);
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

public void dbErrorLogger(Handle owner, Handle hndl, const char [] error, any data)
{
	if (error[0])
	{
		LogError("SQL Error: %s", error);
	}
}

public void connectToDatabase(){
	KETHER_STATS_DB = SQL_Connect(STATS_DB, true, sql_error_buffer, sizeof(sql_error_buffer));
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

public int getPlayerBySteamID(const char[] steamId) 
{
    char tmpSteamId[64];
   
    for (int i = 1; i <= MaxClients; i++) 
    {
        if (!IsClientInGame(i))
            continue;
        
        GetClientAuthId(i, AuthId_Steam2, tmpSteamId, sizeof(tmpSteamId));     
        
        if (strcmp(steamId, tmpSteamId) == 0)
            return i;
    }
    
    return -1;
}

public void StatsSQLregisterClient(Handle owner, Handle handle, const char[] error, any data)
{
	int client = data;
	if (IsClientInGame(client))
	{
		char sTeamID[24];
		sql_query[0] = '\0';
		GetClientAuthId(client, AuthId_SteamID64, sTeamID, sizeof(sTeamID)-1);
		Format(sql_query, sizeof(sql_query)-1, "INSERT IGNORE INTO `l4d2_stats_kether` SET `SteamID` = '%s'", sTeamID);
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
				Hunter_Skeets, \
				LastKnownSteamName \
				Witch_Crowns \
				Tongue_Cuts \
				Smoker_Self_Clears \
				Tank_Rocks_Skeeted \
				Hunter_High_Pounces_25 \
				Death_Charges \
				Commons_Killed \
				Friendly_Fire_Received \
				Friendly_Fire_Done \
				Damage_Done_To_Survivors \
				Damage_Done_To_SI \
				Damage_Done_To_Tanks \
				Gameplay_Time \
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

public void grantDamageDoneToSurvivors(int clientID, int amount){
	addDatabaseRecord("Damage_Done_To_Survivors", clientID, amount);
}

public void grantDamageDoneToSI(int clientID, int amount){
	addDatabaseRecord("Damage_Done_To_SI", clientID, amount);
}

public void Kether_OnWitchCrown(int clientID)
{
	addDatabaseRecord("Witch_Crowns", clientID, 1);
}

public void Kether_OnWitchDrawCrown(int clientID)
{
	addDatabaseRecord("Witch_Crowns", clientID, 1);
}

public void addSkeetToStoreTrie(int client){
	char playerSteamID[64];
    GetClientAuthId(client, AuthId_SteamID64, playerSteamID, sizeof(playerSteamID));
	
	int huntersSkeetedTMP[MAXPLAYERS+1];
	char huntersSkeetedPerRoundKey[128];
	Format(huntersSkeetedPerRoundKey, sizeof(huntersSkeetedPerRoundKey), "%x_huntersSkeetedSumPerRound", playerSteamID);
	GetTrieArray(huntersSkeetedPerRoundHandle, huntersSkeetedPerRoundKey, huntersSkeetedTMP, sizeof(huntersSkeetedTMP));
	huntersSkeetedTMP[client] += 1;
	SetTrieArray(huntersSkeetedPerRoundHandle, huntersSkeetedPerRoundKey, huntersSkeetedTMP, sizeof(huntersSkeetedTMP), true);
}

public void addFriendlyFireDoneToStoreTrie(int client, int amount){
	char playerSteamID[64];
    GetClientAuthId(client, AuthId_SteamID64, playerSteamID, sizeof(playerSteamID));

	int friendlyFireDoneTMP[MAXPLAYERS+1];
	char friendlyFireDonePerRoundKey[128];
	Format(friendlyFireDonePerRoundKey, sizeof(friendlyFireDonePerRoundKey), "%x_friendlyFireDoneSumPerRound", playerSteamID);
	GetTrieArray(friendlyFireDonePerRoundHandle, friendlyFireDonePerRoundKey, friendlyFireDoneTMP, sizeof(friendlyFireDoneTMP));
	friendlyFireDoneTMP[client] += amount;
	SetTrieArray(friendlyFireDonePerRoundHandle, friendlyFireDonePerRoundKey, friendlyFireDoneTMP, sizeof(friendlyFireDoneTMP), true);
}

public void addFriendlyRecoverToStoreTrie(int client){
	char playerSteamID[64];
    GetClientAuthId(client, AuthId_SteamID64, playerSteamID, sizeof(playerSteamID));

	int friendlyRecoverTMP[MAXPLAYERS+1];
	char friendlyRecoversPerRoundKey[128];
	Format(friendlyRecoversPerRoundKey, sizeof(friendlyRecoversPerRoundKey), "%x_friendlyRecoverSumPerRound", playerSteamID);
	GetTrieArray(friendlyRecoversPerRoundHandle, friendlyRecoversPerRoundKey, friendlyRecoverTMP, sizeof(friendlyRecoverTMP));
	friendlyRecoverTMP[client] += 1;
	SetTrieArray(friendlyRecoversPerRoundHandle, friendlyRecoversPerRoundKey, friendlyRecoverTMP, sizeof(friendlyRecoverTMP), true);
}


public void OnSkeet(int survivor){
	addSkeetToStoreTrie(survivor);
	addDatabaseRecord("Hunter_Skeets", survivor, 1);
}

public void OnSkeetMelee(int survivor){
	addSkeetToStoreTrie(survivor);
	addDatabaseRecord("Hunter_Skeets", survivor, 1);
}

public void OnSkeetSniper(int survivor){
	addSkeetToStoreTrie(survivor);
	addDatabaseRecord("Hunter_Skeets", survivor, 1);
}

public void OnTongueCut(int survivor){
	addDatabaseRecord("Tongue_Cuts", survivor, 1);
}

public void OnSmokerSelfClear(int survivor){
	addDatabaseRecord("Smoker_Self_Clears", survivor, 1);
}

public void OnTankRockSkeeted(int survivor){
	addDatabaseRecord("Tank_Rocks_Skeeted", survivor, 1);
}

public void OnHunterHighPounce(int survivor, int victim, int actualDamage){
	if(actualDamage == 25){
		addDatabaseRecord("Hunter_High_Pounces_25", survivor, 1);
	}
}

public void OnDeathCharge(int survivor){
	addDatabaseRecord("Death_Charges", survivor, 1);
}

public void InfectedDeath_Event(Handle event, const char[] name, bool dontBroadcast)
{
    int attackerId = GetEventInt(event, "attacker");
    int attacker = GetClientOfUserId(attackerId);
    
    if (attackerId && IsClientAndInGame(attacker) && GetClientTeam(attacker) == TEAM_SURVIVOR && !IsFakeClient(attacker))
    {
		commonsKilled[attacker] += 1;
		databaseAddKilledCommonsTimer(attacker, commonsKilled[attacker]);
    }
}

public void databaseAddKilledCommonsTimer(int client, int killedCommons){
	DataPack pack;
	CreateDataTimer(3.0, databaseAddKilledCommons, pack);
	pack.WriteCell(client);
	pack.WriteCell(killedCommons);
}

public Action databaseAddKilledCommons(Handle timer, DataPack pack)
{
	int client;
	int commonsFromTimerData;
	pack.Reset();
	client = pack.ReadCell();
	commonsFromTimerData = pack.ReadCell();
	
	if(commonsKilled[client] == commonsFromTimerData){
		if(IsClientAndInGame(client)){
			//populate trie for average commons killed per round
			char playerSteamID[64];
			GetClientAuthId(client, AuthId_SteamID64, playerSteamID, sizeof(playerSteamID));

			int commonsKilledTMP[MAXPLAYERS+1];
			char commonsKilledTrieKey[128];
			Format(commonsKilledTrieKey, sizeof(commonsKilledTrieKey), "%x_commonsKilledSumPerRound", playerSteamID);
			GetTrieArray(commonsKilledPerRoundHandle, commonsKilledTrieKey, commonsKilledTMP, sizeof(commonsKilledTMP));
			commonsKilledTMP[client] += commonsKilled[client];
			SetTrieArray(commonsKilledPerRoundHandle, commonsKilledTrieKey, commonsKilledTMP, sizeof(commonsKilledTMP), true);
			addDatabaseRecord("Commons_Killed", client, commonsKilled[client]);
			commonsKilled[client] = 0;
		}
	}
	return Plugin_Continue;
}


public void RoundEnd_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    //check current players if their steamID was here since beggining.
	//If yes, get proper array, populate table, and clear trie
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client)){
			int clientTeam = GetClientTeam(client);
			if(clientTeam == TEAM_SURVIVOR){
				char playerSteamID[64];
        		GetClientAuthId(client, AuthId_SteamID64, playerSteamID, sizeof(playerSteamID));
				
				//player was here since round beggining, add his commons for average calculation and clear everything
				if(FindStringInArray(survivorsFromRoundBeggining, playerSteamID) != -1){
					int commonsKilledTMP[MAXPLAYERS+1];
					char commonsKilledTrieKey[128];
					Format(commonsKilledTrieKey, sizeof(commonsKilledTrieKey), "%x_commonsKilledSumPerRound", playerSteamID);
					GetTrieArray(commonsKilledPerRoundHandle, commonsKilledTrieKey, commonsKilledTMP, sizeof(commonsKilledTMP));
					addCommonsKilledAverageEntry(playerSteamID, commonsKilledTMP[client]);

					int huntersSkeetedTMP[MAXPLAYERS+1];
					char huntersSkeetedPerRoundKey[128];
					Format(huntersSkeetedPerRoundKey, sizeof(huntersSkeetedPerRoundKey), "%x_huntersSkeetedSumPerRound", playerSteamID);
					GetTrieArray(huntersSkeetedPerRoundHandle, huntersSkeetedPerRoundKey, huntersSkeetedTMP, sizeof(huntersSkeetedTMP));
					addHunterSkeetsAverageEntry(playerSteamID, huntersSkeetedTMP[client]);

					int damageDoneToSITMP[MAXPLAYERS+1];
					char damageDoneToSIPerRoundKey[128];
					Format(damageDoneToSIPerRoundKey, sizeof(damageDoneToSIPerRoundKey), "%x_damageDoneToSIPerRound", playerSteamID);
					GetTrieArray(damageDoneToSIPerRoundHandle, damageDoneToSIPerRoundKey, damageDoneToSITMP, sizeof(damageDoneToSITMP));
					addDamageDoneToSIAverageEntry(playerSteamID, damageDoneToSITMP[client]);

					int friendlyFireDoneTMP[MAXPLAYERS+1];
					char friendlyFireDonePerRoundKey[128];
					Format(friendlyFireDonePerRoundKey, sizeof(friendlyFireDonePerRoundKey), "%x_friendlyFireDoneSumPerRound", playerSteamID);
					GetTrieArray(friendlyFireDonePerRoundHandle, friendlyFireDonePerRoundKey, friendlyFireDoneTMP, sizeof(friendlyFireDoneTMP));
					addFriendlyFireDoneAverageEntry(playerSteamID, friendlyFireDoneTMP[client]);

					int friendlyRecoverTMP[MAXPLAYERS+1];
					char friendlyRecoverPerRoundKey[128];
					Format(friendlyRecoverPerRoundKey, sizeof(friendlyRecoverPerRoundKey), "%x_friendlyRecoverSumPerRound", playerSteamID);
					GetTrieArray(friendlyRecoversPerRoundHandle, friendlyRecoverPerRoundKey, friendlyRecoverTMP, sizeof(friendlyRecoverTMP));
					addFriendlyRecoverAverageEntry(playerSteamID, friendlyRecoverTMP[client]);
				}
			}
		}
	}
	survivorsFromRoundBeggining = new ArrayList(ByteCountToCells(512));
	commonsKilledPerRoundHandle = CreateTrie();
	huntersSkeetedPerRoundHandle = CreateTrie();
	damageDoneToSIPerRoundHandle = CreateTrie();
	friendlyFireDonePerRoundHandle = CreateTrie();
	friendlyRecoversPerRoundHandle = CreateTrie();
}


public void PlayerHurt_Event(Handle event, const char[] name, bool dontBroadcast)
{    
    int victimId = GetEventInt(event, "userid");
    int victim = GetClientOfUserId(victimId);
    
    int attackerId = GetEventInt(event, "attacker");
    int attacker = GetClientOfUserId(attackerId);
    
    int damageDone = GetEventInt(event, "dmg_health");
    
    // no world damage or flukes or whatevs, no bot attackers, no infected-to-infected damage
    if (victimId && attackerId && IsClientAndInGame(victim) && IsClientAndInGame(attacker) && !IsFakeClient(victim) && !IsFakeClient(attacker) && !L4D_IsInFirstCheckpoint(attacker))
    {
        if (GetClientTeam(attacker) == TEAM_SURVIVOR && GetClientTeam(victim) == TEAM_SURVIVOR)
        {
			addDatabaseRecord("Friendly_Fire_Done", attacker, damageDone);
			addDatabaseRecord("Friendly_Fire_Received", victim, damageDone);
			addFriendlyFireDoneToStoreTrie(attacker, damageDone);
        }

		if (GetClientTeam(attacker) == TEAM_SURVIVOR && GetClientTeam(victim) == TEAM_INFECTED)
        {
			int zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
			if(zombieClass != ZC_TANK && zombieClass != ZC_WITCH){
				damageDoneToSI[attacker] += damageDone; 
				databaseAddDamageDoneToSI(attacker, damageDoneToSI[attacker]);
			}
			else if(zombieClass == ZC_TANK){
				damageDoneToTank[attacker] += damageDone;
				databaseAddDamageDoneToTanks(attacker, damageDoneToTank[attacker]);
			}
        }

		if(GetClientTeam(attacker) == TEAM_INFECTED && GetClientTeam(victim) == TEAM_SURVIVOR){
			damageDoneToSurvivors[attacker] += damageDone;
			databaseAddDamageDoneToSurvivors(attacker, damageDoneToSurvivors[attacker]);
		}
    }
}

public void PlayerLeftStartArea_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
	survivorsFromRoundBeggining = new ArrayList(ByteCountToCells(512));
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client)){
			int clientTeam = GetClientTeam(client);
			if(clientTeam == TEAM_SURVIVOR){
				char playerSteamID[64];
        		GetClientAuthId(client, AuthId_SteamID64, playerSteamID, sizeof(playerSteamID));
				PushArrayString(survivorsFromRoundBeggining, playerSteamID);
			}
		}
	}
	commonsKilledPerRoundHandle = CreateTrie();
	huntersSkeetedPerRoundHandle = CreateTrie();
	damageDoneToSIPerRoundHandle = CreateTrie();
	friendlyFireDonePerRoundHandle = CreateTrie();
	friendlyRecoversPerRoundHandle = CreateTrie();
}

public void ReviveSuccess_Event(Event event, const char[] eName, bool dontBroadcast)
{
    int userid = GetEventInt(event, "userid");
    int reviver = GetClientOfUserId(userid);
    
    int subject = GetEventInt(event, "subject");
    int revievedPerson = GetClientOfUserId(subject);
    
	addFriendlyRecoverToStoreTrie(reviver);
}

public void databaseAddDamageDoneToSI(int client, int damageDoneToSI){
	DataPack pack;
	CreateDataTimer(3.0, databaseAddSIDamage, pack);
	pack.WriteCell(client);
	pack.WriteCell(damageDoneToSI);
}

public Action databaseAddSIDamage(Handle timer, DataPack pack)
{
	int client;
	int damageFromTimerData;
	pack.Reset();
	client = pack.ReadCell();
	damageFromTimerData = pack.ReadCell();
	
	if(damageDoneToSI[client] == damageFromTimerData){
		addDatabaseRecord("Damage_Done_To_SI", client, damageDoneToSI[client]);
		char playerSteamID[64];
        GetClientAuthId(client, AuthId_SteamID64, playerSteamID, sizeof(playerSteamID));
		int damageDoneToSITMP[MAXPLAYERS+1];
		char damageDoneToSIPerRoundKey[128];
		Format(damageDoneToSIPerRoundKey, sizeof(damageDoneToSIPerRoundKey), "%x_damageDoneToSIPerRound", playerSteamID);
		GetTrieArray(damageDoneToSIPerRoundHandle, damageDoneToSIPerRoundKey, damageDoneToSITMP, sizeof(damageDoneToSITMP));
		damageDoneToSITMP[client] += damageDoneToSI[client];
		SetTrieArray(damageDoneToSIPerRoundHandle, damageDoneToSIPerRoundKey, damageDoneToSITMP, sizeof(damageDoneToSITMP), true);

		damageDoneToSI[client] = 0;
	}
	return Plugin_Continue;
}

public Action databaseUpdateGamePlayTime(Handle timer)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client)){
			int clientTeam = GetClientTeam(client);
			if(clientTeam == TEAM_INFECTED || clientTeam == TEAM_SURVIVOR){
				addDatabaseRecord("Gameplay_Time",client, 30);
			}
		}
	}
	return Plugin_Continue;
}

public void databaseAddDamageDoneToTanks(int client, int damageDoneToTank){
	DataPack pack;
	CreateDataTimer(3.0, databaseAddTankDamage, pack);
	pack.WriteCell(client);
	pack.WriteCell(damageDoneToTank);
}

public Action databaseAddTankDamage(Handle timer, DataPack pack)
{
	int client;
	int dataFromTimer;
	pack.Reset();
	client = pack.ReadCell();
	dataFromTimer = pack.ReadCell();
	
	if(damageDoneToTank[client] == dataFromTimer){
		addDatabaseRecord("Damage_Done_To_Tanks", client, damageDoneToTank[client]);
		damageDoneToTank[client] = 0;
	}
	return Plugin_Continue;
}

public void databaseAddDamageDoneToSurvivors(int client, int damageDoneToSurvivors){
	DataPack pack;
	CreateDataTimer(3.0, databaseAddDamageDoneToSurvivorsTimer, pack);
	pack.WriteCell(client);
	pack.WriteCell(damageDoneToSurvivors);
}

public Action databaseAddDamageDoneToSurvivorsTimer(Handle timer, DataPack pack)
{
	int client;
	int dataFromTimer;
	pack.Reset();
	client = pack.ReadCell();
	dataFromTimer = pack.ReadCell();
	
	if(damageDoneToSurvivors[client] == dataFromTimer){
		addDatabaseRecord("Damage_Done_To_Survivors", client, damageDoneToSurvivors[client]);
		damageDoneToSurvivors[client] = 0;
	}
	return Plugin_Continue;
}


bool IsClientAndInGame(int index)
{
    return (index > 0 && index <= MaxClients && IsClientInGame(index));
}




