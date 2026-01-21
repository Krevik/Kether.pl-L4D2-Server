#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#undef REQUIRE_PLUGIN
#include <readyup>
#include <l4d2_skill_detect>

#define PLUGIN_VERSION "3.0"
#define DATABASE_NAME "l4d2_balance"

#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

#define DEFAULT_MU 25.0
#define DEFAULT_SIGMA 8.333
#define MAX_SIGMA 12.0
#define BETA 4.1667
#define TAU 0.0833

#define VOTE_DURATION 15
#define MIN_PLAYERS_FOR_VOTE 4
#define AFK_TIMEOUT 30.0
#define LEDGE_CAUSE_WINDOW 5.0
#define FLOW_CHECK_INTERVAL 1.0

stock float FloatMin(float a, float b)
{
    return (a < b) ? a : b;
}

stock float FloatMax(float a, float b)
{
    return (a > b) ? a : b;
}

stock float Exp(float x)
{
    return Pow(2.7182818, x);
}

Database g_Database = null;

ConVar g_CvarEnabled;
ConVar g_CvarVotePct;
ConVar g_CvarCooldown;
ConVar g_CvarTolerance;
ConVar g_CvarWeightTeam;
ConVar g_CvarMinGames;
ConVar g_CvarDecayDays;
ConVar g_CvarNormalizationMode;
ConVar g_CvarTrackAfk;

Menu g_hVoteMenu = null;
bool g_bVoteInProgress = false;
float g_fLastVoteTime = 0.0;

bool g_bRoundActive = false;
bool g_bRoundLive = false;
bool g_bPaused = false;
int g_iCurrentRound = 0;
Handle g_hLiveTimer = null;

bool g_bReadyUpAvailable = false;

float g_fRatingMu[MAXPLAYERS + 1];
float g_fRatingSigma[MAXPLAYERS + 1];
int g_iGamesPlayed[MAXPLAYERS + 1];
int g_iLastSeen[MAXPLAYERS + 1];

int g_iDamageDealtInfected[MAXPLAYERS + 1];
int g_iDamageDealtSurvivor[MAXPLAYERS + 1];
int g_iDamageTaken[MAXPLAYERS + 1];
int g_iKills[MAXPLAYERS + 1];
int g_iDeaths[MAXPLAYERS + 1];
int g_iIncaps[MAXPLAYERS + 1];
int g_iLedgeGrabsCaused[MAXPLAYERS + 1];

int g_iHunterPounceDamage[MAXPLAYERS + 1];
int g_iHunter25Pounces[MAXPLAYERS + 1];
int g_iBoomerHits[MAXPLAYERS + 1];
int g_iBoomerQuadHits[MAXPLAYERS + 1];
int g_iChargerImpactDamage[MAXPLAYERS + 1];
bool g_bChargerCarrying[MAXPLAYERS + 1];
float g_fChargerCarryStartPos[MAXPLAYERS + 1][3];
float g_fSmokerConstrictTime[MAXPLAYERS + 1];
float g_fSmokerConstrictStart[MAXPLAYERS + 1];
float g_fJockeyRideTime[MAXPLAYERS + 1];
float g_fJockeyRideStart[MAXPLAYERS + 1];
int g_iTankDamage[MAXPLAYERS + 1];
int g_iHunterDeadstops[MAXPLAYERS + 1];
int g_iSmokerTongueCuts[MAXPLAYERS + 1];
int g_iJockeyLongRides[MAXPLAYERS + 1];

float g_fRoundMaxFlowPercent[MAXPLAYERS + 1];
float g_fActiveTime[MAXPLAYERS + 1];
float g_fLastInputTime[MAXPLAYERS + 1];

int g_iLastInfectedAttacker[MAXPLAYERS + 1];
float g_fLastInfectedAttackTime[MAXPLAYERS + 1];

bool g_bRestarted = false;
int g_iMapHalf = 0;
bool g_bHalfCompleted[2] = {false, false};

int g_iLogicalTeam[MAXPLAYERS + 1];
int g_iTeamSteamIdCount[2];
char g_sTeamSteamIds[2][MAXPLAYERS + 1][32];

int g_iMapRoundsPlayed[MAXPLAYERS + 1];
int g_iMapDamageDealtSurvivor[MAXPLAYERS + 1];
int g_iMapDamageDealtInfected[MAXPLAYERS + 1];
int g_iMapTankDamage[MAXPLAYERS + 1];
int g_iMapHunterPounceDamage[MAXPLAYERS + 1];
int g_iMapHunter25Pounces[MAXPLAYERS + 1];
int g_iMapBoomerHits[MAXPLAYERS + 1];
int g_iMapChargerImpactDamage[MAXPLAYERS + 1];
int g_iMapSmokerTongueCuts[MAXPLAYERS + 1];
int g_iMapHunterDeadstops[MAXPLAYERS + 1];
int g_iMapDeaths[MAXPLAYERS + 1];
int g_iMapIncaps[MAXPLAYERS + 1];
int g_iMapDamageTaken[MAXPLAYERS + 1];
float g_fMapSmokerConstrictTime[MAXPLAYERS + 1];
float g_fMapJockeyRideTime[MAXPLAYERS + 1];
float g_fMapDistanceSum[MAXPLAYERS + 1];
int g_iMapJockeyLongRides[MAXPLAYERS + 1];

int g_iMapSessionId = 0;
char g_sCurrentMapName[64];

int g_iMatchCount[2];
char g_sMatchSteamId[2][MAXPLAYERS + 1][32];
float g_fMatchMu[2][MAXPLAYERS + 1];
float g_fMatchSigma[2][MAXPLAYERS + 1];
float g_fMatchPerf[2][MAXPLAYERS + 1];
int g_iMatchRounds[2][MAXPLAYERS + 1];
bool g_bMatchQueryDone[2];
int g_iMatchScores[2];
bool g_bMatchUpdateInProgress = false;

StringMap g_hRoundSavedSteamIds = null;

public Plugin myinfo =
{
    name = "L4D2 Balance Tracker",
    author = "TwojaOsoba + gpt-5.2",
    description = "Tracks player stats and balances teams using TrueSkill",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    char error[256];
    g_Database = SQLite_UseDatabase(DATABASE_NAME, error, sizeof(error));

    if (g_Database == null)
    {
        SetFailState("Failed to connect to database: %s", error);
    }

    CreateTables();
    EnsureColumns();

    g_hRoundSavedSteamIds = new StringMap();

    g_CvarEnabled = CreateConVar("sm_balance_enabled", "1", "Enable or disable team balance system", FCVAR_NONE, true, 0.0, true, 1.0);
    g_CvarVotePct = CreateConVar("sm_balance_vote_percentage", "51", "Vote percentage required to pass", FCVAR_NONE, true, 1.0, true, 100.0);
    g_CvarCooldown = CreateConVar("sm_balance_cooldown", "120", "Cooldown between votes in seconds", FCVAR_NONE, true, 0.0, false);
    g_CvarTolerance = CreateConVar("sm_balance_team_tolerance", "5", "Warn if teams differ more than this percent", FCVAR_NONE, true, 0.0, true, 100.0);
    g_CvarWeightTeam = CreateConVar("sm_balance_weight_team", "0.7", "Weight of team result in rating update", FCVAR_NONE, true, 0.0, true, 1.0);
    g_CvarMinGames = CreateConVar("sm_balance_min_games", "5", "Min games before rating is trusted in balancing", FCVAR_NONE, true, 0.0, false);
    g_CvarDecayDays = CreateConVar("sm_balance_decay_days", "30", "Days of inactivity before sigma increases", FCVAR_NONE, true, 1.0, false);
    g_CvarNormalizationMode = CreateConVar("sm_balance_normalization_mode", "0", "0=per-round,1=per-distance,2=absolute", FCVAR_NONE, true, 0.0, true, 2.0);
    g_CvarTrackAfk = CreateConVar("sm_balance_track_afk", "1", "Exclude AFK time from live time tracking", FCVAR_NONE, true, 0.0, true, 1.0);

    AutoExecConfig(true, "l4d2_balance");

    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_hurt", Event_PlayerHurt);
    HookEvent("player_incapacitated", Event_PlayerIncap);
    HookEvent("player_ledge_grab", Event_LedgeGrab);

    HookEvent("tongue_grab", Event_TongueGrab, EventHookMode_Post);
    HookEvent("tongue_pull_stopped", Event_TonguePullStopped, EventHookMode_Post);
    HookEvent("choke_start", Event_ChokeStart, EventHookMode_Post);
    HookEvent("choke_stopped", Event_ChokeStopped, EventHookMode_Post);
    HookEvent("jockey_ride", Event_JockeyRideStart, EventHookMode_Post);
    HookEvent("jockey_ride_end", Event_JockeyRideEnd, EventHookMode_Post);
    HookEvent("charger_carry_start", Event_ChargerCarryStart, EventHookMode_Post);
    HookEvent("charger_carry_end", Event_ChargerCarryEnd, EventHookMode_Post);
    HookEvent("charger_pummel_start", Event_ChargerPummelStart, EventHookMode_Post);

    RegConsoleCmd("sm_scoremix", Command_ScoreMix, "Start team balance vote");
    RegConsoleCmd("sm_rating", Command_Rating, "View rating and stats");
    RegConsoleCmd("sm_toprating", Command_TopRating, "View top ratings");
    RegConsoleCmd("sm_balancepreview", Command_BalancePreview, "Preview team balance");
    RegAdminCmd("sm_resetrating", Command_ResetRating, ADMFLAG_ROOT, "Reset player rating");
    RegAdminCmd("sm_forcebalance", Command_ForceBalance, ADMFLAG_ROOT, "Force team balance");

    RegConsoleCmd("sm_playerstats", Command_Rating, "View rating and stats");

    PrintToServer("[L4D2 Balance] Plugin loaded with embedded SQLite database");
}

public void OnAllPluginsLoaded()
{
    g_bReadyUpAvailable = LibraryExists("readyup");
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "readyup"))
    {
        g_bReadyUpAvailable = true;
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "readyup"))
    {
        g_bReadyUpAvailable = false;
    }
}

public void OnMapStart()
{
    ResetMatchTracking();
}

public void OnMapEnd()
{
    if (g_bHalfCompleted[0] && g_bHalfCompleted[1])
    {
        UpdateMatchRatingsAndSave();
    }
}


public void OnClientPostAdminCheck(int client)
{
    if (!IsValidClient(client))
    {
        return;
    }

    ResetPlayerStats(client);
    InitPlayerRating(client);

    char steamid[32];
    GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));

    char name[MAX_NAME_LENGTH];
    GetClientName(client, name, sizeof(name));

    char escapedName[MAX_NAME_LENGTH * 2 + 1];
    g_Database.Escape(name, escapedName, sizeof(escapedName));

    char query[512];
    Format(query, sizeof(query),
        "INSERT OR IGNORE INTO players (steamid, name, last_seen) "
        ... "VALUES ('%s', '%s', strftime('%%s', 'now')); "
        ... "UPDATE players SET name='%s', last_seen=strftime('%%s', 'now') WHERE steamid='%s';",
        steamid, escapedName, escapedName, steamid);

    g_Database.Query(SQL_ErrorCheck, query);
}

public void OnClientDisconnect(int client)
{
    ResetPlayerStats(client);
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
    if (!IsValidClient(client))
    {
        return;
    }

    if (buttons || impulse || mouse[0] || mouse[1])
    {
        g_fLastInputTime[client] = GetEngineTime();
    }
}

public void OnRoundIsLive()
{
    StartRoundLive();
}

public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client)
{
    StartRoundLive();
}

public void OnPause()
{
    g_bPaused = true;
}

public void OnUnpause()
{
    g_bPaused = false;
}

void StartRoundLive()
{
    if (g_bRoundLive)
    {
        return;
    }

    if (g_bReadyUpAvailable)
    {
        if (IsInReady())
        {
            return;
        }
    }

    g_bRoundLive = true;

    if (g_hLiveTimer == null)
    {
        g_hLiveTimer = CreateTimer(FLOW_CHECK_INTERVAL, Timer_LiveTick, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
}

Action Timer_LiveTick(Handle timer)
{
    if (!g_bRoundLive || !g_bRoundActive)
    {
        return Plugin_Continue;
    }

    float now = GetEngineTime();

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidClient(i))
        {
            continue;
        }

        if (GetClientTeam(i) == TEAM_SURVIVOR)
        {
            float flowPercent = GetPlayerFlowPercent(i);
            if (flowPercent > g_fRoundMaxFlowPercent[i])
            {
                g_fRoundMaxFlowPercent[i] = flowPercent;
            }
        }

        if (ShouldCountLiveTime(i, now))
        {
            g_fActiveTime[i] += FLOW_CHECK_INTERVAL;
        }
    }

    return Plugin_Continue;
}

bool ShouldCountLiveTime(int client, float now)
{
    if (!g_bRoundLive || g_bPaused)
    {
        return false;
    }

    int team = GetClientTeam(client);
    if (team != TEAM_SURVIVOR && team != TEAM_INFECTED)
    {
        return false;
    }

    if (g_CvarTrackAfk.BoolValue && (now - g_fLastInputTime[client]) > AFK_TIMEOUT)
    {
        return false;
    }

    return true;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_bRoundActive = true;
    g_bRoundLive = false;
    g_bPaused = false;
    g_iCurrentRound++;

    if (g_bRestarted)
    {
        ResetMatchTracking();
        g_bRestarted = false;
    }

    if (g_hRoundSavedSteamIds != null)
    {
        g_hRoundSavedSteamIds.Clear();
    }

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i))
        {
            ResetPlayerStats(i);
            g_fLastInputTime[i] = GetEngineTime();
            g_fActiveTime[i] = 0.0;
            g_fRoundMaxFlowPercent[i] = 0.0;
        }
    }

    CacheLogicalTeamsForHalf();
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    g_bRoundActive = false;
    g_bRoundLive = false;

    if (g_bRestarted)
    {
        return;
    }

    SaveAllPlayerStats();
    AccumulateMapTotals();

    if (g_iMapHalf < 2)
    {
        g_bHalfCompleted[g_iMapHalf] = true;
        g_iMapHalf++;
    }
}


public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (IsValidClient(victim))
    {
        g_iDeaths[victim]++;
    }

    if (IsValidClient(attacker) && attacker != victim)
    {
        g_iKills[attacker]++;
    }
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int damage = event.GetInt("dmg_health");
    int damagetype = event.GetInt("type");

    if (!IsValidClient(victim))
    {
        return;
    }

    int victimTeam = GetClientTeam(victim);
    if (victimTeam == TEAM_SURVIVOR)
    {
        g_iDamageTaken[victim] += damage;
    }

    if (IsValidClient(attacker) && attacker != victim)
    {
        int attackerTeam = GetClientTeam(attacker);
        if (attackerTeam == TEAM_INFECTED)
        {
            g_iDamageDealtInfected[attacker] += damage;

            if (victimTeam == TEAM_SURVIVOR)
            {
                g_iLastInfectedAttacker[victim] = attacker;
                g_fLastInfectedAttackTime[victim] = GetEngineTime();
            }

            int zClass = GetEntProp(attacker, Prop_Send, "m_zombieClass");
            if (zClass == 8 && victimTeam == TEAM_SURVIVOR)
            {
                g_iTankDamage[attacker] += damage;
            }
            else if (zClass == 3 && (damagetype & (1 << 0)))
            {
                g_iHunterPounceDamage[attacker] += damage;
                if (damage >= 25)
                {
                    g_iHunter25Pounces[attacker]++;
                }
            }
            else if (zClass == 6 && victimTeam == TEAM_SURVIVOR)
            {
                g_iChargerImpactDamage[attacker] += damage;
            }
        }
        else if (attackerTeam == TEAM_SURVIVOR)
        {
            g_iDamageDealtSurvivor[attacker] += damage;
        }
    }
}

public void Event_PlayerIncap(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidClient(victim))
    {
        g_iIncaps[victim]++;
    }
}

public void Event_LedgeGrab(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client))
    {
        return;
    }

    float now = GetEngineTime();
    int attacker = g_iLastInfectedAttacker[client];
    if (IsValidClient(attacker) && GetClientTeam(attacker) == TEAM_INFECTED && (now - g_fLastInfectedAttackTime[client]) <= LEDGE_CAUSE_WINDOW)
    {
        g_iLedgeGrabsCaused[attacker]++;
    }
}

public void Event_TongueGrab(Event event, const char[] name, bool dontBroadcast)
{
    int smoker = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidClient(smoker) && GetClientTeam(smoker) == TEAM_INFECTED)
    {
        g_fSmokerConstrictStart[smoker] = GetEngineTime();
    }
}

public void Event_TonguePullStopped(Event event, const char[] name, bool dontBroadcast)
{
    int smoker = GetClientOfUserId(event.GetInt("smoker"));
    if (IsValidClient(smoker) && g_fSmokerConstrictStart[smoker] > 0.0)
    {
        g_fSmokerConstrictTime[smoker] += GetEngineTime() - g_fSmokerConstrictStart[smoker];
        g_fSmokerConstrictStart[smoker] = 0.0;
    }
}

public void Event_ChokeStart(Event event, const char[] name, bool dontBroadcast)
{
    int smoker = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidClient(smoker) && GetClientTeam(smoker) == TEAM_INFECTED)
    {
        g_fSmokerConstrictStart[smoker] = GetEngineTime();
    }
}

public void Event_ChokeStopped(Event event, const char[] name, bool dontBroadcast)
{
    int smoker = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidClient(smoker) && g_fSmokerConstrictStart[smoker] > 0.0)
    {
        g_fSmokerConstrictTime[smoker] += GetEngineTime() - g_fSmokerConstrictStart[smoker];
        g_fSmokerConstrictStart[smoker] = 0.0;
    }
}

public void Event_JockeyRideStart(Event event, const char[] name, bool dontBroadcast)
{
    int jockey = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidClient(jockey) && GetClientTeam(jockey) == TEAM_INFECTED)
    {
        g_fJockeyRideStart[jockey] = GetEngineTime();
    }
}

public void Event_JockeyRideEnd(Event event, const char[] name, bool dontBroadcast)
{
    int jockey = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidClient(jockey) && g_fJockeyRideStart[jockey] > 0.0)
    {
        g_fJockeyRideTime[jockey] += GetEngineTime() - g_fJockeyRideStart[jockey];
        g_fJockeyRideStart[jockey] = 0.0;
    }
}

public void Event_ChargerCarryStart(Event event, const char[] name, bool dontBroadcast)
{
    int charger = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(charger) || GetClientTeam(charger) != TEAM_INFECTED)
    {
        return;
    }

    g_bChargerCarrying[charger] = true;
    GetClientAbsOrigin(charger, g_fChargerCarryStartPos[charger]);
    g_iChargerImpactDamage[charger] += 10;
}

public void Event_ChargerCarryEnd(Event event, const char[] name, bool dontBroadcast)
{
    int charger = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(charger) || !g_bChargerCarrying[charger])
    {
        return;
    }

    float endPos[3];
    GetClientAbsOrigin(charger, endPos);
    float distance = GetVectorDistance(g_fChargerCarryStartPos[charger], endPos);
    g_iChargerImpactDamage[charger] += RoundToNearest(distance);
    g_bChargerCarrying[charger] = false;
}

public void Event_ChargerPummelStart(Event event, const char[] name, bool dontBroadcast)
{
    int charger = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(charger) || GetClientTeam(charger) != TEAM_INFECTED)
    {
        return;
    }

    g_iChargerImpactDamage[charger] += 15;
}

public void OnBoomerVomitLanded(int boomer, int amount)
{
    if (IsValidClient(boomer))
    {
        g_iBoomerHits[boomer] += amount;
        if (amount >= 4)
        {
            g_iBoomerQuadHits[boomer]++;
        }
    }
}

public void OnHunterDeadstop(int survivor, int hunter)
{
    if (IsValidClient(survivor))
    {
        g_iHunterDeadstops[survivor]++;
    }
}

public void OnTongueCut(int survivor, int smoker)
{
    if (IsValidClient(survivor))
    {
        g_iSmokerTongueCuts[survivor]++;
    }
}

void SaveAllPlayerStats()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i))
        {
            SavePlayerStats(i);
        }
    }
}

void SavePlayerStats(int client)
{
    char steamid[32];
    GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));

    if (g_hRoundSavedSteamIds != null)
    {
        int dummy;
        if (g_hRoundSavedSteamIds.GetValue(steamid, dummy))
        {
            return;
        }
    }

    int team = GetClientTeam(client);
    float distancePercent = g_fRoundMaxFlowPercent[client];

    char query[2048];
    Format(query, sizeof(query),
        "INSERT INTO round_stats (player_id, round_id, team, map_session_id, map_name, damage_dealt_infected, damage_dealt_survivor, "
        ... "damage_taken, kills, deaths, incaps, ledge_grabs_caused, hunter_pounce_damage, hunter_25_pounces, "
        ... "boomer_hits, boomer_quad_hits, charger_impact_damage, smoker_constrict_time, jockey_ride_time, tank_damage, hunter_deadstops, "
        ... "smoker_tongue_cuts, survivor_distance_percent, active_time) "
        ... "SELECT id, %d, %d, %d, '%s', %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %f, %f, %d, %d, %d, %f, %f "
        ... "FROM players WHERE steamid='%s';",
        g_iCurrentRound,
        team,
        g_iMapSessionId,
        g_sCurrentMapName,
        g_iDamageDealtInfected[client],
        g_iDamageDealtSurvivor[client],
        g_iDamageTaken[client],
        g_iKills[client],
        g_iDeaths[client],
        g_iIncaps[client],
        g_iLedgeGrabsCaused[client],
        g_iHunterPounceDamage[client],
        g_iHunter25Pounces[client],
        g_iBoomerHits[client],
        g_iBoomerQuadHits[client],
        g_iChargerImpactDamage[client],
        g_fSmokerConstrictTime[client],
        g_fJockeyRideTime[client],
        g_iTankDamage[client],
        g_iHunterDeadstops[client],
        g_iSmokerTongueCuts[client],
        distancePercent,
        g_fActiveTime[client],
        steamid);

    g_Database.Query(SQL_ErrorCheck, query);

    if (g_hRoundSavedSteamIds != null)
    {
        g_hRoundSavedSteamIds.SetValue(steamid, 1, true);
    }
}

public Action Command_ScoreMix(int client, int args)
{
    if (!g_CvarEnabled.BoolValue)
    {
        ReplyToCommand(client, "[Balance] System is disabled.");
        return Plugin_Handled;
    }

    if (g_bVoteInProgress)
    {
        ReplyToCommand(client, "[Balance] Vote already in progress.");
        return Plugin_Handled;
    }

    if (client == 0)
    {
        ReplyToCommand(client, "[Balance] This command can only be used in game.");
        return Plugin_Handled;
    }

    if (GetClientTeam(client) == TEAM_SPECTATOR)
    {
        ReplyToCommand(client, "[Balance] Spectators cannot start a vote.");
        return Plugin_Handled;
    }

    int playerCount = CountEligiblePlayers();
    if (playerCount < MIN_PLAYERS_FOR_VOTE)
    {
        ReplyToCommand(client, "[Balance] Not enough players to start a vote.");
        return Plugin_Handled;
    }

    float now = GetEngineTime();
    float cooldown = g_CvarCooldown.FloatValue;
    if (now - g_fLastVoteTime < cooldown)
    {
        ReplyToCommand(client, "[Balance] Vote is on cooldown.");
        return Plugin_Handled;
    }

    StartBalanceVote();
    return Plugin_Handled;
}

public Action Command_ForceBalance(int client, int args)
{
    if (!g_CvarEnabled.BoolValue)
    {
        ReplyToCommand(client, "[Balance] System is disabled.");
        return Plugin_Handled;
    }

    ForceBalance(false);
    return Plugin_Handled;
}

public Action Command_BalancePreview(int client, int args)
{
    if (!g_CvarEnabled.BoolValue)
    {
        ReplyToCommand(client, "[Balance] System is disabled.");
        return Plugin_Handled;
    }

    ForceBalance(true);
    return Plugin_Handled;
}

public Action Command_Rating(int client, int args)
{
    char targetName[MAX_NAME_LENGTH];
    char steamid[32];

    if (args < 1)
    {
        GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
    }
    else
    {
        GetCmdArg(1, targetName, sizeof(targetName));
        int target = FindTarget(client, targetName);
        if (target == -1)
        {
            return Plugin_Handled;
        }
        GetClientAuthId(target, AuthId_Steam2, steamid, sizeof(steamid));
    }

    char query[1024];
    Format(query, sizeof(query),
        "SELECT name, rating_mu, rating_sigma, games_played, "
        ... "SUM(damage_dealt_infected), SUM(damage_dealt_survivor), SUM(damage_taken), "
        ... "SUM(kills), SUM(deaths), SUM(incaps) "
        ... "FROM players "
        ... "LEFT JOIN round_stats ON players.id = round_stats.player_id "
        ... "WHERE steamid='%s' "
        ... "GROUP BY players.id",
        steamid);

    DataPack pack = new DataPack();
    pack.WriteCell(client);
    g_Database.Query(SQL_ShowStats, query, pack);

    return Plugin_Handled;
}

public Action Command_TopRating(int client, int args)
{
    char query[512];
    Format(query, sizeof(query),
        "SELECT name, rating_mu, rating_sigma, games_played "
        ... "FROM players ORDER BY (rating_mu - 3.0 * rating_sigma) DESC LIMIT 10;");

    DataPack pack = new DataPack();
    pack.WriteCell(client);
    g_Database.Query(SQL_ShowTopRatings, query, pack);

    return Plugin_Handled;
}

public Action Command_ResetRating(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[Balance] Usage: sm_resetrating <player>");
        return Plugin_Handled;
    }

    char targetName[MAX_NAME_LENGTH];
    GetCmdArg(1, targetName, sizeof(targetName));
    int target = FindTarget(client, targetName);
    if (target == -1)
    {
        return Plugin_Handled;
    }

    char steamid[32];
    GetClientAuthId(target, AuthId_Steam2, steamid, sizeof(steamid));

    char query[512];
    Format(query, sizeof(query),
        "UPDATE players SET rating_mu=%.3f, rating_sigma=%.3f, games_played=0 WHERE steamid='%s';",
        DEFAULT_MU, DEFAULT_SIGMA, steamid);

    g_Database.Query(SQL_ErrorCheck, query);
    ReplyToCommand(client, "[Balance] Rating reset for %N", target);

    g_fRatingMu[target] = DEFAULT_MU;
    g_fRatingSigma[target] = DEFAULT_SIGMA;
    g_iGamesPlayed[target] = 0;

    return Plugin_Handled;
}

void StartBalanceVote()
{
    g_hVoteMenu = new Menu(Handle_BalanceVote, MENU_ACTIONS_ALL);
    g_hVoteMenu.SetTitle("Balance teams?");
    g_hVoteMenu.AddItem("yes", "Yes");
    g_hVoteMenu.AddItem("no", "No");
    g_hVoteMenu.ExitButton = false;

    g_bVoteInProgress = true;
    g_fLastVoteTime = GetEngineTime();

    g_hVoteMenu.DisplayVoteToAll(VOTE_DURATION);
}

public int Handle_BalanceVote(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete g_hVoteMenu;
        g_hVoteMenu = null;
        g_bVoteInProgress = false;
    }
    else if (action == MenuAction_VoteCancel && param1 == VoteCancel_NoVotes)
    {
        PrintToChatAll("[Balance] No votes were cast.");
    }
    else if (action == MenuAction_VoteEnd)
    {
        char item[64];
        float percent;
        int votes, totalVotes;

        GetMenuVoteInfo(param2, votes, totalVotes);
        menu.GetItem(param1, item, sizeof(item));

        if (StrEqual(item, "no", false) && param1 == 1)
        {
            votes = totalVotes - votes;
        }

        if (totalVotes <= 0)
        {
            PrintToChatAll("[Balance] Vote failed (no votes).");
            return 0;
        }

        percent = float(votes) / float(totalVotes) * 100.0;
        float required = g_CvarVotePct.FloatValue;

        if (!StrEqual(item, "yes", false) || percent < required)
        {
            PrintToChatAll("[Balance] Vote failed (%.0f%% needed, %.0f%% received).", required, percent);
            return 0;
        }

        PrintToChatAll("[Balance] Vote passed (%.0f%%). Balancing teams...", percent);
        ForceBalance(false);
    }

    return 0;
}

void ForceBalance(bool previewOnly)
{
    int players[MAXPLAYERS + 1];
    int count = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i))
        {
            int team = GetClientTeam(i);
            if (team == TEAM_SURVIVOR || team == TEAM_INFECTED)
            {
                players[count++] = i;
            }
        }
    }

    if (count < MIN_PLAYERS_FOR_VOTE)
    {
        PrintToChatAll("[Balance] Not enough players to balance.");
        return;
    }

    int spectator = 0;
    if (count % 2 == 1)
    {
        spectator = FindLowestRated(players, count);
    }

    int teamA[MAXPLAYERS + 1];
    int teamB[MAXPLAYERS + 1];
    int teamACount = 0;
    int teamBCount = 0;

    BuildBalancedTeams(players, count, teamA, teamACount, teamB, teamBCount, spectator);

    float sumA = SumTeamRating(teamA, teamACount);
    float sumB = SumTeamRating(teamB, teamBCount);
    float diffPercent = ComputeDiffPercent(sumA, sumB);

    PrintBalancePreview(teamA, teamACount, teamB, teamBCount, sumA, sumB, diffPercent);

    if (diffPercent > g_CvarTolerance.FloatValue)
    {
        PrintToChatAll("[Balance] Warning: teams may be unbalanced (difference: %.1f%%).", diffPercent);
    }

    if (previewOnly)
    {
        return;
    }

    CreateTimer(5.0, Timer_ApplyBalance, CreateBalancePack(teamA, teamACount, teamB, teamBCount, spectator), TIMER_FLAG_NO_MAPCHANGE);
}

Handle CreateBalancePack(int teamA[MAXPLAYERS + 1], int teamACount, int teamB[MAXPLAYERS + 1], int teamBCount, int spectator)
{
    DataPack pack = new DataPack();
    pack.WriteCell(teamACount);
    for (int i = 0; i < teamACount; i++)
    {
        pack.WriteCell(teamA[i]);
    }

    pack.WriteCell(teamBCount);
    for (int i = 0; i < teamBCount; i++)
    {
        pack.WriteCell(teamB[i]);
    }

    pack.WriteCell(spectator);
    return pack;
}

public Action Timer_ApplyBalance(Handle timer, any data)
{
    DataPack pack = view_as<DataPack>(data);
    pack.Reset();

    int teamACount = pack.ReadCell();
    int teamA[MAXPLAYERS + 1];
    for (int i = 0; i < teamACount; i++)
    {
        teamA[i] = pack.ReadCell();
    }

    int teamBCount = pack.ReadCell();
    int teamB[MAXPLAYERS + 1];
    for (int i = 0; i < teamBCount; i++)
    {
        teamB[i] = pack.ReadCell();
    }

    int spectator = pack.ReadCell();
    delete pack;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && GetClientTeam(i) != TEAM_SPECTATOR)
        {
            ChangeClientTeam(i, TEAM_SPECTATOR);
        }
    }

    for (int i = 0; i < teamACount; i++)
    {
        ChangeClientTeam(teamA[i], TEAM_SURVIVOR);
    }

    for (int i = 0; i < teamBCount; i++)
    {
        ChangeClientTeam(teamB[i], TEAM_INFECTED);
    }

    if (spectator > 0 && IsValidClient(spectator))
    {
        ChangeClientTeam(spectator, TEAM_SPECTATOR);
        PrintToChatAll("[Balance] %N moved to spectators due to odd player count.", spectator);
    }

    if (g_bRoundActive)
    {
        ForceRoundRestart();
    }

    return Plugin_Stop;
}

void ForceRoundRestart()
{
    g_bRestarted = true;
    ServerCommand("mp_restartgame 1");
}

void PrintBalancePreview(int teamA[MAXPLAYERS + 1], int teamACount, int teamB[MAXPLAYERS + 1], int teamBCount, float sumA, float sumB, float diffPercent)
{
    PrintToChatAll("[Balance] Team 1 (%.1f):", sumA);
    for (int i = 0; i < teamACount; i++)
    {
        PrintToChatAll("[Balance]  - %N", teamA[i]);
    }

    PrintToChatAll("[Balance] Team 2 (%.1f):", sumB);
    for (int i = 0; i < teamBCount; i++)
    {
        PrintToChatAll("[Balance]  - %N", teamB[i]);
    }

    PrintToChatAll("[Balance] Difference: %.1f%%", diffPercent);
}

int FindLowestRated(int players[MAXPLAYERS + 1], int count)
{
    float minRating = 999999.0;
    int minClient = 0;

    for (int i = 0; i < count; i++)
    {
        int client = players[i];
        float rating = GetPlayerRatingValue(client);
        if (rating < minRating)
        {
            minRating = rating;
            minClient = client;
        }
    }

    return minClient;
}

void BuildBalancedTeams(int players[MAXPLAYERS + 1], int count, int teamA[MAXPLAYERS + 1], int &teamACount, int teamB[MAXPLAYERS + 1], int &teamBCount, int spectator)
{
    int pool[MAXPLAYERS + 1];
    int poolCount = 0;

    for (int i = 0; i < count; i++)
    {
        if (players[i] == spectator)
        {
            continue;
        }
        pool[poolCount++] = players[i];
    }

    SortPlayersByRating(pool, poolCount);

    teamACount = 0;
    teamBCount = 0;

    for (int i = 0; i < poolCount; i++)
    {
        float sumA = SumTeamRating(teamA, teamACount);
        float sumB = SumTeamRating(teamB, teamBCount);

        if (sumA <= sumB)
        {
            teamA[teamACount++] = pool[i];
        }
        else
        {
            teamB[teamBCount++] = pool[i];
        }
    }
}

void SortPlayersByRating(int players[MAXPLAYERS + 1], int count)
{
    for (int i = 0; i < count; i++)
    {
        for (int j = i + 1; j < count; j++)
        {
            if (GetPlayerRatingValue(players[j]) > GetPlayerRatingValue(players[i]))
            {
                int tmp = players[i];
                players[i] = players[j];
                players[j] = tmp;
            }
        }
    }
}

float SumTeamRating(int team[MAXPLAYERS + 1], int count)
{
    float sum = 0.0;
    for (int i = 0; i < count; i++)
    {
        sum += GetPlayerRatingValue(team[i]);
    }
    return sum;
}

float ComputeDiffPercent(float a, float b)
{
    float avg = (a + b) / 2.0;
    if (avg <= 0.0)
    {
        return 0.0;
    }
    return FloatAbs(a - b) / avg * 100.0;
}

float GetPlayerRatingValue(int client)
{
    float mu = g_fRatingMu[client];
    float sigma = g_fRatingSigma[client];
    int games = g_iGamesPlayed[client];

    if (games < g_CvarMinGames.IntValue)
    {
        mu = DEFAULT_MU;
        sigma = DEFAULT_SIGMA;
    }

    return mu - 3.0 * sigma;
}



float TrueskillV(float t)
{
    float denom = NormalCDF(t);
    if (denom < 0.0001)
    {
        denom = 0.0001;
    }
    return NormalPDF(t) / denom;
}

float TrueskillW(float t, float v)
{
    return v * (v + t);
}

float NormalPDF(float x)
{
    return 0.3989423 * Exp(-0.5 * x * x);
}

float NormalCDF(float x)
{
    float absX = FloatAbs(x);
    float t = 1.0 / (1.0 + 0.2316419 * absX);
    float d = 0.3989423 * Exp(-absX * absX / 2.0);
    float prob = d * t * (0.3193815 + t * (-0.3565638 + t * (1.781478 + t * (-1.821256 + t * 1.330274))));
    if (x > 0.0)
    {
        return 1.0 - prob;
    }
    return prob;
}




void InitPlayerRating(int client)
{
    g_fRatingMu[client] = DEFAULT_MU;
    g_fRatingSigma[client] = DEFAULT_SIGMA;
    g_iGamesPlayed[client] = 0;
    g_iLastSeen[client] = 0;

    char steamid[32];
    GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));

    char query[256];
    Format(query, sizeof(query),
        "SELECT rating_mu, rating_sigma, games_played, last_seen FROM players WHERE steamid='%s';",
        steamid);

    DataPack pack = new DataPack();
    pack.WriteCell(client);
    g_Database.Query(SQL_LoadPlayerRating, query, pack);
}

public void SQL_LoadPlayerRating(Database db, DBResultSet results, const char[] error, DataPack pack)
{
    pack.Reset();
    int client = pack.ReadCell();
    delete pack;

    if (!IsValidClient(client))
    {
        return;
    }

    if (results == null || !results.FetchRow())
    {
        return;
    }

    g_fRatingMu[client] = results.FetchFloat(0);
    g_fRatingSigma[client] = results.FetchFloat(1);
    g_iGamesPlayed[client] = results.FetchInt(2);
    g_iLastSeen[client] = results.FetchInt(3);

    ApplyDecay(client);
}

void ApplyDecay(int client)
{
    int lastSeen = g_iLastSeen[client];
    if (lastSeen <= 0)
    {
        return;
    }

    int now = GetTime();
    int days = (now - lastSeen) / 86400;
    int decayDays = g_CvarDecayDays.IntValue;
    if (days <= decayDays)
    {
        return;
    }

    int extraDays = days - decayDays;
    float sigma = g_fRatingSigma[client] + float(extraDays) * 0.1;
    g_fRatingSigma[client] = FloatMin(sigma, MAX_SIGMA);
}

public void SQL_ShowStats(Database db, DBResultSet results, const char[] error, DataPack pack)
{
    pack.Reset();
    int client = pack.ReadCell();
    delete pack;

    if (!IsValidClient(client))
    {
        return;
    }

    if (results == null || !results.FetchRow())
    {
        PrintToChat(client, "[Balance] No data found for this player.");
        return;
    }

    char name[MAX_NAME_LENGTH];
    results.FetchString(0, name, sizeof(name));

    float rating_mu = results.FetchFloat(1);
    float rating_sigma = results.FetchFloat(2);
    int games = results.FetchInt(3);
    int dmg_inf = results.FetchInt(4);
    int dmg_surv = results.FetchInt(5);
    int dmg_taken = results.FetchInt(6);
    int kills = results.FetchInt(7);
    int deaths = results.FetchInt(8);
    int incaps = results.FetchInt(9);

    PrintToChat(client, "[Balance] Stats for %s", name);
    PrintToChat(client, "[Balance] Rating: %.1f (sigma %.1f) | Games: %d", rating_mu, rating_sigma, games);
    PrintToChat(client, "[Balance] Dmg Inf: %d | Dmg Surv: %d | Dmg Taken: %d", dmg_inf, dmg_surv, dmg_taken);
    PrintToChat(client, "[Balance] K/D/I: %d/%d/%d", kills, deaths, incaps);
}

public void SQL_ShowTopRatings(Database db, DBResultSet results, const char[] error, DataPack pack)
{
    pack.Reset();
    int client = pack.ReadCell();
    delete pack;

    if (!IsValidClient(client))
    {
        return;
    }

    if (results == null)
    {
        PrintToChat(client, "[Balance] No data.");
        return;
    }

    PrintToChat(client, "[Balance] Top ratings:");
    while (results.FetchRow())
    {
        char name[MAX_NAME_LENGTH];
        results.FetchString(0, name, sizeof(name));
        float mu = results.FetchFloat(1);
        float sigma = results.FetchFloat(2);
        int games = results.FetchInt(3);

        PrintToChat(client, "[Balance] %s | %.1f (sigma %.1f) | games %d", name, mu, sigma, games);
    }
}

void ResetPlayerStats(int client)
{
    g_iDamageDealtInfected[client] = 0;
    g_iDamageDealtSurvivor[client] = 0;
    g_iDamageTaken[client] = 0;
    g_iKills[client] = 0;
    g_iDeaths[client] = 0;
    g_iIncaps[client] = 0;
    g_iLedgeGrabsCaused[client] = 0;

    g_iHunterPounceDamage[client] = 0;
    g_iHunter25Pounces[client] = 0;
    g_iBoomerHits[client] = 0;
    g_iBoomerQuadHits[client] = 0;
    g_iChargerImpactDamage[client] = 0;
    g_bChargerCarrying[client] = false;
    g_fChargerCarryStartPos[client][0] = 0.0;
    g_fChargerCarryStartPos[client][1] = 0.0;
    g_fChargerCarryStartPos[client][2] = 0.0;
    g_fSmokerConstrictTime[client] = 0.0;
    g_fSmokerConstrictStart[client] = 0.0;
    g_fJockeyRideTime[client] = 0.0;
    g_fJockeyRideStart[client] = 0.0;
    g_iTankDamage[client] = 0;
    g_iHunterDeadstops[client] = 0;
    g_iSmokerTongueCuts[client] = 0;

    g_fRoundMaxFlowPercent[client] = 0.0;
    g_fActiveTime[client] = 0.0;
    g_fLastInputTime[client] = GetEngineTime();

    g_iLastInfectedAttacker[client] = 0;
    g_fLastInfectedAttackTime[client] = 0.0;
}
void ResetMatchTracking()
{
    g_bRoundActive = false;
    g_bRoundLive = false;
    g_bPaused = false;
    g_iMapHalf = 0;
    g_bHalfCompleted[0] = false;
    g_bHalfCompleted[1] = false;
    g_iTeamSteamIdCount[0] = 0;
    g_iTeamSteamIdCount[1] = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        g_iLogicalTeam[i] = -1;
        g_iMapRoundsPlayed[i] = 0;
        g_iMapDamageDealtSurvivor[i] = 0;
        g_iMapDamageDealtInfected[i] = 0;
        g_iMapTankDamage[i] = 0;
        g_iMapHunterPounceDamage[i] = 0;
        g_iMapHunter25Pounces[i] = 0;
        g_iMapBoomerHits[i] = 0;
        g_iMapChargerImpactDamage[i] = 0;
        g_iMapSmokerTongueCuts[i] = 0;
        g_iMapHunterDeadstops[i] = 0;
        g_iMapJockeyLongRides[i] = 0;
        g_iMapDeaths[i] = 0;
        g_iMapIncaps[i] = 0;
        g_iMapDamageTaken[i] = 0;
        g_fMapSmokerConstrictTime[i] = 0.0;
        g_fMapJockeyRideTime[i] = 0.0;
        g_fMapDistanceSum[i] = 0.0;
    }
}

void CacheLogicalTeamsForHalf()
{
    if (g_iMapHalf > 1)
    {
        return;
    }

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidClient(i))
        {
            continue;
        }

        int team = GetClientTeam(i);
        if (team != TEAM_SURVIVOR && team != TEAM_INFECTED)
        {
            continue;
        }

        int logicalTeam = GetLogicalTeamForClient(team);
        AddClientToLogicalTeam(i, logicalTeam);
    }
}

int GetLogicalTeamForClient(int team)
{
    if (g_iMapHalf == 0)
    {
        return (team == TEAM_SURVIVOR) ? 0 : 1;
    }
    return (team == TEAM_SURVIVOR) ? 1 : 0;
}

void AddClientToLogicalTeam(int client, int logicalTeam)
{
    if (logicalTeam < 0 || logicalTeam > 1)
    {
        return;
    }

    if (g_iLogicalTeam[client] == -1)
    {
        g_iLogicalTeam[client] = logicalTeam;
    }

    char steamid[32];
    GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));

    for (int i = 0; i < g_iTeamSteamIdCount[logicalTeam]; i++)
    {
        if (StrEqual(g_sTeamSteamIds[logicalTeam][i], steamid, false))
        {
            return;
        }
    }

    strcopy(g_sTeamSteamIds[logicalTeam][g_iTeamSteamIdCount[logicalTeam]], sizeof(g_sTeamSteamIds[][]), steamid);
    g_iTeamSteamIdCount[logicalTeam]++;
}

void AccumulateMapTotals()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidClient(i))
        {
            continue;
        }

        int team = GetClientTeam(i);
        if (team != TEAM_SURVIVOR && team != TEAM_INFECTED)
        {
            continue;
        }

        g_iMapRoundsPlayed[i]++;
        g_iMapDamageDealtSurvivor[i] += g_iDamageDealtSurvivor[i];
        g_iMapDamageDealtInfected[i] += g_iDamageDealtInfected[i];
        g_iMapTankDamage[i] += g_iTankDamage[i];
        g_iMapHunterPounceDamage[i] += g_iHunterPounceDamage[i];
        g_iMapHunter25Pounces[i] += g_iHunter25Pounces[i];
        g_iMapBoomerHits[i] += g_iBoomerHits[i];
        g_iMapChargerImpactDamage[i] += g_iChargerImpactDamage[i];
        g_iMapSmokerTongueCuts[i] += g_iSmokerTongueCuts[i];
        g_iMapHunterDeadstops[i] += g_iHunterDeadstops[i];
        g_iMapJockeyLongRides[i] += g_iJockeyLongRides[i];
        g_iMapDeaths[i] += g_iDeaths[i];
        g_iMapIncaps[i] += g_iIncaps[i];
        g_iMapDamageTaken[i] += g_iDamageTaken[i];
        g_fMapSmokerConstrictTime[i] += g_fSmokerConstrictTime[i];
        g_fMapJockeyRideTime[i] += g_fJockeyRideTime[i];
        g_fMapDistanceSum[i] += g_fRoundMaxFlowPercent[i];
    }
}

void UpdateMatchRatingsAndSave()
{
    if (g_bMatchUpdateInProgress)
    {
        return;
    }

    int teamACount = g_iTeamSteamIdCount[0];
    int teamBCount = g_iTeamSteamIdCount[1];

    if (teamACount == 0 || teamBCount == 0)
    {
        return;
    }

    g_iMatchCount[0] = teamACount;
    g_iMatchCount[1] = teamBCount;

    for (int i = 0; i < teamACount; i++)
    {
        strcopy(g_sMatchSteamId[0][i], sizeof(g_sMatchSteamId[][]), g_sTeamSteamIds[0][i]);
    }

    for (int i = 0; i < teamBCount; i++)
    {
        strcopy(g_sMatchSteamId[1][i], sizeof(g_sMatchSteamId[][]), g_sTeamSteamIds[1][i]);
    }

    g_iMatchScores[0] = 0;
    g_iMatchScores[1] = 0;
    if (GetFeatureStatus(FeatureType_Native, "L4D2_GetVersusCampaignScores") == FeatureStatus_Available)
    {
        L4D2_GetVersusCampaignScores(g_iMatchScores);
    }

    g_bMatchUpdateInProgress = true;
    g_bMatchQueryDone[0] = false;
    g_bMatchQueryDone[1] = false;

    StartMatchTeamQuery(0);
    StartMatchTeamQuery(1);
}

void SaveMatchFromSteamIds(int scores[2], int winningTeam)
{
    char teamAPlayers[512];
    char teamBPlayers[512];
    BuildTeamListFromSteamIds(0, teamAPlayers, sizeof(teamAPlayers));
    BuildTeamListFromSteamIds(1, teamBPlayers, sizeof(teamBPlayers));

    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));

    char query[1024];
    Format(query, sizeof(query),
        "INSERT INTO matches (team1_score, team2_score, winner, team1_players, team2_players, map_name) "
        ... "VALUES (%d, %d, %d, '%s', '%s', '%s');",
        scores[0], scores[1], winningTeam, teamAPlayers, teamBPlayers, mapName);

    g_Database.Query(SQL_ErrorCheck, query);
}

void BuildTeamListFromSteamIds(int teamIndex, char[] buffer, int bufferSize)
{
    buffer[0] = '\0';

    for (int i = 0; i < g_iTeamSteamIdCount[teamIndex]; i++)
    {
        if (buffer[0] != '\0')
        {
            StrCat(buffer, bufferSize, ",");
        }
        StrCat(buffer, bufferSize, g_sTeamSteamIds[teamIndex][i]);
    }
}
void StartMatchTeamQuery(int teamIndex)
{
    if (g_iMatchCount[teamIndex] <= 0)
    {
        g_bMatchQueryDone[teamIndex] = true;
        FinalizeMatchUpdate();
        return;
    }

    char inClause[2048];
    BuildTeamInClause(teamIndex, inClause, sizeof(inClause));

    char query[4096];
    Format(query, sizeof(query),
        "SELECT players.steamid, players.rating_mu, players.rating_sigma, players.games_played, "
        ... "COUNT(round_stats.id), "
        ... "SUM(damage_dealt_infected), SUM(damage_dealt_survivor), SUM(damage_taken), "
        ... "SUM(kills), SUM(deaths), SUM(incaps), "
        ... "SUM(hunter_pounce_damage), SUM(hunter_25_pounces), SUM(boomer_hits), SUM(boomer_quad_hits), "
        ... "SUM(charger_impact_damage), SUM(smoker_constrict_time), SUM(jockey_ride_time), SUM(jockey_long_rides), "
        ... "SUM(tank_damage), SUM(hunter_deadstops), SUM(smoker_tongue_cuts), SUM(survivor_distance_percent) "
        ... "FROM players "
        ... "LEFT JOIN round_stats ON players.id = round_stats.player_id "
        ... "WHERE round_stats.map_session_id = %d AND players.steamid IN %s "
        ... "GROUP BY players.id;",
        g_iMapSessionId,
        inClause);

    DataPack pack = new DataPack();
    pack.WriteCell(teamIndex);
    g_Database.Query(SQL_LoadMatchTeam, query, pack);
}

void BuildTeamInClause(int teamIndex, char[] buffer, int bufferSize)
{
    buffer[0] = '\0';
    StrCat(buffer, bufferSize, "(");

    for (int i = 0; i < g_iMatchCount[teamIndex]; i++)
    {
        if (i > 0)
        {
            StrCat(buffer, bufferSize, ",");
        }
        StrCat(buffer, bufferSize, "'");
        StrCat(buffer, bufferSize, g_sMatchSteamId[teamIndex][i]);
        StrCat(buffer, bufferSize, "'");
    }

    StrCat(buffer, bufferSize, ")");
}

public void SQL_LoadMatchTeam(Database db, DBResultSet results, const char[] error, DataPack pack)
{
    pack.Reset();
    int teamIndex = pack.ReadCell();
    delete pack;

    if (results == null)
    {
        LogError("[Balance] Match query failed: %s", error);
        g_bMatchQueryDone[teamIndex] = true;
        FinalizeMatchUpdate();
        return;
    }

    int count = 0;
    while (results.FetchRow())
    {
        char steamid[32];
        results.FetchString(0, steamid, sizeof(steamid));
        g_fMatchMu[teamIndex][count] = results.FetchFloat(1);
        g_fMatchSigma[teamIndex][count] = results.FetchFloat(2);
        g_iMatchRounds[teamIndex][count] = results.FetchInt(4);

        int dmgInf = results.FetchInt(5);
        int dmgSurv = results.FetchInt(6);
        int dmgTaken = results.FetchInt(7);
        int kills = results.FetchInt(8);
        int deaths = results.FetchInt(9);
        int incaps = results.FetchInt(10);
        int pounceDmg = results.FetchInt(11);
        int pounce25 = results.FetchInt(12);
        int boomerHits = results.FetchInt(13);
        int boomerQuads = results.FetchInt(14);
        int chargerDmg = results.FetchInt(15);
        float smokerTime = results.FetchFloat(16);
        float jockeyTime = results.FetchFloat(17);
        int jockeyLong = results.FetchInt(18);
        int tankDmg = results.FetchInt(19);
        int deadstops = results.FetchInt(20);
        int tongueCuts = results.FetchInt(21);
        float distanceSum = results.FetchFloat(22);

        g_fMatchPerf[teamIndex][count] = ComputePerformanceScoreFromTotals(
            dmgSurv,
            dmgInf,
            dmgTaken,
            kills,
            deaths,
            incaps,
            pounceDmg,
            pounce25,
            boomerHits,
            boomerQuads,
            chargerDmg,
            smokerTime,
            jockeyTime,
            jockeyLong,
            tankDmg,
            deadstops,
            tongueCuts,
            distanceSum,
            g_iMatchRounds[teamIndex][count]
        );

        strcopy(g_sMatchSteamId[teamIndex][count], sizeof(g_sMatchSteamId[][]), steamid);
        count++;
    }

    g_iMatchCount[teamIndex] = count;
    g_bMatchQueryDone[teamIndex] = true;
    FinalizeMatchUpdate();
}

void FinalizeMatchUpdate()
{
    if (!g_bMatchQueryDone[0] || !g_bMatchQueryDone[1])
    {
        return;
    }

    bool isDraw = (g_iMatchScores[0] == g_iMatchScores[1]);
    bool teamAWon = (g_iMatchScores[0] > g_iMatchScores[1]);

    float teamAvg[2] = {0.0, 0.0};
    for (int t = 0; t < 2; t++)
    {
        for (int i = 0; i < g_iMatchCount[t]; i++)
        {
            teamAvg[t] += g_fMatchPerf[t][i];
        }
        if (g_iMatchCount[t] > 0)
        {
            teamAvg[t] /= float(g_iMatchCount[t]);
        }
    }

    if (isDraw)
    {
        for (int t = 0; t < 2; t++)
        {
            for (int i = 0; i < g_iMatchCount[t]; i++)
            {
                float mu = g_fMatchMu[t][i];
                float sigma = g_fMatchSigma[t][i];
                ApplyDrawUpdateForMatch(mu, sigma);
                UpdatePlayerRatingInDbBySteamId(g_sMatchSteamId[t][i], mu, sigma);
            }
        }

        SaveMatchFromSteamIds(g_iMatchScores, 0);
        g_bMatchUpdateInProgress = false;
        return;
    }

    float muA = SumMuMatch(0);
    float muB = SumMuMatch(1);
    float sigmaA2 = SumSigma2Match(0);
    float sigmaB2 = SumSigma2Match(1);

    float c = SquareRoot(2.0 * BETA * BETA + sigmaA2 + sigmaB2);
    if (c <= 0.0001)
    {
        g_bMatchUpdateInProgress = false;
        return;
    }

    float t = (muA - muB) / c;
    if (!teamAWon)
    {
        t = -t;
    }

    float v = TrueskillV(t);
    float w = TrueskillW(t, v);

    float weightTeam = g_CvarWeightTeam.FloatValue;
    float weightIndividual = 1.0 - weightTeam;

    for (int i = 0; i < g_iMatchCount[0]; i++)
    {
        float perfDelta = ComputePerfDelta(g_fMatchPerf[0][i], teamAvg[0]);
        float mu = g_fMatchMu[0][i];
        float sigma = g_fMatchSigma[0][i];
        ApplyRatingUpdateForMatch(mu, sigma, c, v, w, teamAWon, weightTeam, weightIndividual, perfDelta);
        UpdatePlayerRatingInDbBySteamId(g_sMatchSteamId[0][i], mu, sigma);
    }

    for (int i = 0; i < g_iMatchCount[1]; i++)
    {
        float perfDelta = ComputePerfDelta(g_fMatchPerf[1][i], teamAvg[1]);
        float mu = g_fMatchMu[1][i];
        float sigma = g_fMatchSigma[1][i];
        ApplyRatingUpdateForMatch(mu, sigma, c, v, w, !teamAWon, weightTeam, weightIndividual, perfDelta);
        UpdatePlayerRatingInDbBySteamId(g_sMatchSteamId[1][i], mu, sigma);
    }

    SaveMatchFromSteamIds(g_iMatchScores, teamAWon ? 0 : 1);
    g_bMatchUpdateInProgress = false;
}

float ComputePerformanceScoreFromTotals(int dmgSurv, int dmgInf, int dmgTaken, int kills, int deaths, int incaps, int pounceDmg, int pounce25,
    int boomerHits, int boomerQuads, int chargerDmg, float smokerTime, float jockeyTime, int jockeyLong, int tankDmg, int deadstops, int tongueCuts, float distanceSum, int rounds)
{
    float norm = ComputeNormalizationFromTotals(distanceSum, rounds);
    float score = 0.0;

    score += (float(dmgSurv) / norm) * 0.01;
    score += (float(dmgInf) / norm) * 0.01;
    score += (float(tankDmg) / norm) * 0.01;
    score += (float(pounceDmg) / norm) * 0.02;
    score += float(kills) * 1.0;
    score += float(boomerHits) * 5.0;
    score += float(boomerQuads) * 10.0;
    score += float(tongueCuts) * 3.0;
    score += float(deadstops) * 3.0;
    score += float(pounce25) * 10.0;
    score += (float(chargerDmg) / norm) * 0.02;
    score += (smokerTime / norm) * 0.1;
    score += (jockeyTime / norm) * 0.1;
    score += float(jockeyLong) * 8.0;

    if (rounds > 0)
    {
        score += (distanceSum / float(rounds)) * 0.2;
    }

    score -= float(deaths) * 5.0;
    score -= float(incaps) * 2.0;
    score -= (float(dmgTaken) / norm) * 0.01;

    return score;
}

float ComputeNormalizationFromTotals(float distanceSum, int rounds)
{
    int mode = g_CvarNormalizationMode.IntValue;
    if (mode == 0)
    {
        if (rounds <= 0)
        {
            rounds = 1;
        }
        return float(rounds);
    }

    if (mode == 1)
    {
        float avgDistance = 0.0;
        if (rounds > 0)
        {
            avgDistance = distanceSum / float(rounds);
        }

        float distance = avgDistance / 100.0;
        if (distance < 0.1)
        {
            distance = 0.1;
        }
        return distance;
    }

    return 1.0;
}

float ComputePerfDelta(float score, float teamAvg)
{
    if (teamAvg <= 0.0)
    {
        return 0.0;
    }

    float diff = (score - teamAvg) / teamAvg;
    if (diff > 1.0)
    {
        diff = 1.0;
    }
    else if (diff < -1.0)
    {
        diff = -1.0;
    }

    return diff;
}

void ApplyRatingUpdateForMatch(float &mu, float &sigma, float c, float v, float w, bool won, float weightTeam, float weightIndividual, float perfDelta)
{
    float sigma2 = sigma * sigma;
    float rankMultiplier = won ? 1.0 : -1.0;
    float deltaMu = (sigma2 / c) * v * rankMultiplier;
    float deltaSigma = (sigma2 / (c * c)) * w;

    float perfMultiplier = 1.0 + (weightIndividual * perfDelta);

    mu = mu + (deltaMu * weightTeam * perfMultiplier);
    sigma = SquareRoot(sigma2 * (1.0 - deltaSigma));
    if (sigma < 0.5)
    {
        sigma = 0.5;
    }

    sigma += TAU;
    if (sigma > MAX_SIGMA)
    {
        sigma = MAX_SIGMA;
    }
}

void ApplyDrawUpdateForMatch(float &mu, float &sigma)
{
    sigma += TAU;
    if (sigma > MAX_SIGMA)
    {
        sigma = MAX_SIGMA;
    }
}

void UpdatePlayerRatingInDbBySteamId(const char[] steamid, float mu, float sigma)
{
    char query[256];
    Format(query, sizeof(query),
        "UPDATE players SET rating_mu=%.3f, rating_sigma=%.3f, games_played = games_played + 1, last_seen=strftime('%%s', 'now') WHERE steamid='%s';",
        mu, sigma, steamid);

    g_Database.Query(SQL_ErrorCheck, query);

    int client = FindClientBySteamId(steamid);
    if (client > 0)
    {
        g_fRatingMu[client] = mu;
        g_fRatingSigma[client] = sigma;
        g_iGamesPlayed[client]++;
    }
}

int FindClientBySteamId(const char[] steamid)
{
    char buffer[32];
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidClient(i))
        {
            continue;
        }

        GetClientAuthId(i, AuthId_Steam2, buffer, sizeof(buffer));
        if (StrEqual(buffer, steamid, false))
        {
            return i;
        }
    }

    return 0;
}

float SumMuMatch(int teamIndex)
{
    float sum = 0.0;
    for (int i = 0; i < g_iMatchCount[teamIndex]; i++)
    {
        sum += g_fMatchMu[teamIndex][i];
    }
    return sum;
}

float SumSigma2Match(int teamIndex)
{
    float sum = 0.0;
    for (int i = 0; i < g_iMatchCount[teamIndex]; i++)
    {
        float sigma = g_fMatchSigma[teamIndex][i];
        sum += sigma * sigma;
    }
    return sum;
}

int CountEligiblePlayers()
{
    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i))
        {
            int team = GetClientTeam(i);
            if (team == TEAM_SURVIVOR || team == TEAM_INFECTED)
            {
                count++;
            }
        }
    }
    return count;
}

float GetPlayerFlowPercent(int client)
{
    float maxFlow = L4D2Direct_GetMapMaxFlowDistance();
    if (maxFlow <= 0.0)
    {
        return 0.0;
    }

    float flow = L4D2Direct_GetFlowDistance(client);
    if (flow < 0.0)
    {
        flow = 0.0;
    }

    return (flow / maxFlow) * 100.0;
}

void CreateTables()
{
    char query[2048];

    Format(query, sizeof(query),
        "CREATE TABLE IF NOT EXISTS players ("
        ... "id INTEGER PRIMARY KEY AUTOINCREMENT, "
        ... "steamid VARCHAR(32) UNIQUE NOT NULL, "
        ... "name VARCHAR(64), "
        ... "rating_mu REAL DEFAULT 25.0, "
        ... "rating_sigma REAL DEFAULT 8.333, "
        ... "games_played INTEGER DEFAULT 0, "
        ... "last_seen INTEGER, "
        ... "created_at INTEGER DEFAULT (strftime('%%s', 'now'))"
        ... ")");

    g_Database.Query(SQL_ErrorCheck, query);

    Format(query, sizeof(query),
        "CREATE TABLE IF NOT EXISTS round_stats ("
        ... "id INTEGER PRIMARY KEY AUTOINCREMENT, "
        ... "player_id INTEGER, "
        ... "round_id INTEGER, "
        ... "team INTEGER, "
        ... "damage_dealt_infected INTEGER DEFAULT 0, "
        ... "damage_dealt_survivor INTEGER DEFAULT 0, "
        ... "damage_taken INTEGER DEFAULT 0, "
        ... "kills INTEGER DEFAULT 0, "
        ... "deaths INTEGER DEFAULT 0, "
        ... "incaps INTEGER DEFAULT 0, "
        ... "ledge_grabs_caused INTEGER DEFAULT 0, "
        ... "hunter_pounce_damage INTEGER DEFAULT 0, "
        ... "hunter_25_pounces INTEGER DEFAULT 0, "
        ... "boomer_hits INTEGER DEFAULT 0, "
        ... "boomer_quad_hits INTEGER DEFAULT 0, "
        ... "charger_impact_damage INTEGER DEFAULT 0, "
        ... "smoker_constrict_time REAL DEFAULT 0, "
        ... "jockey_ride_time REAL DEFAULT 0, "
        ... "tank_damage INTEGER DEFAULT 0, "
        ... "hunter_deadstops INTEGER DEFAULT 0, "
        ... "smoker_tongue_cuts INTEGER DEFAULT 0, "
        ... "survivor_distance_percent REAL DEFAULT 0, "
        ... "active_time REAL DEFAULT 0, "
        ... "timestamp INTEGER DEFAULT (strftime('%%s', 'now')), "
        ... "FOREIGN KEY(player_id) REFERENCES players(id)"
        ... ")");

    g_Database.Query(SQL_ErrorCheck, query);

    Format(query, sizeof(query),
        "CREATE TABLE IF NOT EXISTS matches ("
        ... "id INTEGER PRIMARY KEY AUTOINCREMENT, "
        ... "team1_score INTEGER, "
        ... "team2_score INTEGER, "
        ... "winner INTEGER, "
        ... "team1_players TEXT, "
        ... "team2_players TEXT, "
        ... "map_name VARCHAR(64), "
        ... "timestamp INTEGER DEFAULT (strftime('%%s', 'now'))"
        ... ")");

    g_Database.Query(SQL_ErrorCheck, query);
}

void EnsureColumns()
{
    EnsureColumn("round_stats", "team", "INTEGER DEFAULT 0");
    EnsureColumn("round_stats", "ledge_grabs_caused", "INTEGER DEFAULT 0");
    EnsureColumn("round_stats", "hunter_pounce_damage", "INTEGER DEFAULT 0");
    EnsureColumn("round_stats", "hunter_25_pounces", "INTEGER DEFAULT 0");
    EnsureColumn("round_stats", "boomer_hits", "INTEGER DEFAULT 0");
    EnsureColumn("round_stats", "boomer_quad_hits", "INTEGER DEFAULT 0");
    EnsureColumn("round_stats", "charger_impact_damage", "INTEGER DEFAULT 0");
    EnsureColumn("round_stats", "smoker_constrict_time", "REAL DEFAULT 0");
    EnsureColumn("round_stats", "jockey_ride_time", "REAL DEFAULT 0");
    EnsureColumn("round_stats", "tank_damage", "INTEGER DEFAULT 0");
    EnsureColumn("round_stats", "hunter_deadstops", "INTEGER DEFAULT 0");
    EnsureColumn("round_stats", "smoker_tongue_cuts", "INTEGER DEFAULT 0");
    EnsureColumn("round_stats", "survivor_distance_percent", "REAL DEFAULT 0");
    EnsureColumn("round_stats", "active_time", "REAL DEFAULT 0");

    EnsureColumn("matches", "team1_players", "TEXT");
    EnsureColumn("matches", "team2_players", "TEXT");
    EnsureColumn("matches", "map_name", "VARCHAR(64)");
}

void EnsureColumn(const char[] table, const char[] column, const char[] definition)
{
    char query[256];
    Format(query, sizeof(query), "PRAGMA table_info(%s);", table);

    DataPack pack = new DataPack();
    pack.WriteString(table);
    pack.WriteString(column);
    pack.WriteString(definition);

    g_Database.Query(SQL_CheckColumn, query, pack);
}

public void SQL_CheckColumn(Database db, DBResultSet results, const char[] error, DataPack pack)
{
    char table[64];
    char column[64];
    char definition[128];

    pack.Reset();
    pack.ReadString(table, sizeof(table));
    pack.ReadString(column, sizeof(column));
    pack.ReadString(definition, sizeof(definition));
    delete pack;

    if (results == null)
    {
        LogError("[Balance] PRAGMA table_info failed: %s", error);
        return;
    }

    bool found = false;
    while (results.FetchRow())
    {
        char colName[64];
        results.FetchString(1, colName, sizeof(colName));
        if (StrEqual(colName, column, false))
        {
            found = true;
            break;
        }
    }

    if (!found)
    {
        char alter[256];
        Format(alter, sizeof(alter), "ALTER TABLE %s ADD COLUMN %s %s;", table, column, definition);
        g_Database.Query(SQL_ErrorCheck, alter);
    }
}

public void SQL_ErrorCheck(Database db, DBResultSet results, const char[] error, any data)
{
    if (results == null)
    {
        LogError("[Balance] Query failed: %s", error);
    }
}

bool IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client);
}














































