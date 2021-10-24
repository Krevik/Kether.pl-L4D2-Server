#pragma semicolon 1

#include <sourcemod.inc>
#include <sdkhooks>
#include <sdktools>
#include <sdktools_functions>
#include <left4dhooks>
#include <timers.inc>
#include <colors>

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

public Plugin:myinfo =
{
    name = "Survivor MVP notification",
    author = "Tabun, Artifacial, Krevik",
    description = "Shows MVP for survivor team at end of round",
    version = "0.3",
    url = "nah"
};
// Temporary DMG track
new iDMGFromPlayerToPlayer[MAXPLAYERS + 1][MAXPLAYERS + 1];

// Track Kills
new SIKillsPerPlayer[MAXPLAYERS + 1][ZC_TANK + 1];
new CIKillsPerPlayer[MAXPLAYERS + 1];

// Track Dealt Damage
new SIDamagePerPlayer[MAXPLAYERS + 1][ZC_TANK + 1];
new FFDamagePerPlayer[MAXPLAYERS + 1];

// Track Other
new FFRevivesPerPlayer[MAXPLAYERS + 1];

// Misc variable helpers
new iRoundNumber;
new bool:bPlayerLeftStartArea;
new Handle:hGameMode = INVALID_HANDLE;

new String:sClientName[MAXPLAYERS + 1][64];
ConVar convarReportRemainingHP;
//TODO
//save data to database
//calculate MVP (SI+CI+Revives) / LVP
//print MVP LVP etc
//after catch, show them how much damage have they done in how many shots?
//record self clears


public OnPluginStart()
{
    hGameMode = FindConVar("mp_gamemode");
    bPlayerLeftStartArea = false;
	
	HookEvent("player_left_start_area", PlayerLeftStartArea);
    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
    HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
    HookEvent("map_transition", RoundEnd_Event, EventHookMode_PostNoCopy);

    // Tracking Data
    HookEvent("player_hurt", PlayerHurt_Event, EventHookMode_Post);
    HookEvent("player_death", PlayerDeath_Event, EventHookMode_Post);
    HookEvent("infected_death", InfectedDeath_Event, EventHookMode_Post);
    HookEvent("revive_success", ReviveSuccess_Event, EventHookMode_Post);
    
    // Other events
    HookEvent("charger_carry_start", ChargerCarryStart_Event, EventHookMode_Post);
    
    convarReportRemainingHP = CreateConVar("sm_mvp_track_remaining_hp", "1", "Tracks HP of infecteds in real time, and sometimes reports");
}

public void ClearAllPlayersData(){
	ClearTemporaryPlayerToPlayerDamage();
	new i, maxplayers = MaxClients;
    for (i = 1; i <= maxplayers; ++i)
    {
		ClearPlayerData(i);
    }
}

public void ClearPlayerData(int client){
	new i, maxplayers = MaxClients;
    for (i = 1; i <= ZC_TANK; ++i)
    {
		SIKillsPerPlayer[client][i] = 0;
		SIDamagePerPlayer[client][i] = 0;
    }
	CIKillsPerPlayer[client] = 0;
	FFDamagePerPlayer[client] = 0;
}

public void ClearTemporaryPlayerToPlayerDamage(){
	new c, i, maxplayers = MaxClients;
    for (i = 1; i <= maxplayers; ++i)
    {
		for (c = 1; c <= maxplayers; ++c)
		{
			iDMGFromPlayerToPlayer[i][c] = 0;
		}
    }
}

public void OnClientPutInServer(client)
{
    decl String:tmpBuffer[64];
    GetClientName(client, tmpBuffer, sizeof(tmpBuffer));
    
    // if previously stored name for same client is not the same, delete stats & overwrite name
    if(strcmp(tmpBuffer, sClientName[client], true) != 0)
    {
    	ClearPlayerData(client);
        // store name for later reference
        strcopy(sClientName[client], 64, tmpBuffer);
    }
}

public Action PlayerLeftStartArea(Handle:event, const String:name[], bool:dontBroadcast)
{
    bPlayerLeftStartArea = true;
}

public OnMapStart()
{
    bPlayerLeftStartArea = false;
}

public OnMapEnd()
{
    iRoundNumber = 0;
}

public Action RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    bPlayerLeftStartArea = false;
    iRoundNumber++;
    
	ClearAllPlayersData();
}

public RoundEnd_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	//CreateTimer(2.0, HandleActualMVP);
}

public PlayerHurt_Event(Handle:event, const String:name[], bool:dontBroadcast)
{    
	new zombieClass = -1;
    // Victim details
    new victimId = GetEventInt(event, "userid");
    new victim = GetClientOfUserId(victimId);
    
    // Attacker details
    new attackerId = GetEventInt(event, "attacker");
    new attacker = GetClientOfUserId(attackerId);
    
    // Misc details
    new damageDone = GetEventInt(event, "dmg_health");
    
    // no world damage or flukes or whatevs, no bot attackers, no infected-to-infected damage, round must have started and players have left starting area
    if (victimId && attackerId && IsClientAndInGame(victim) && IsClientAndInGame(attacker) && bPlayerLeftStartArea)
    {
        // If a survivor is attacking infected
        if (GetClientTeam(attacker) == TEAM_SURVIVOR && GetClientTeam(victim) == TEAM_INFECTED)
        {
            zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
            SIDamagePerPlayer[attacker][zombieClass] += damageDone;
            
            // Track Temporary DMG 
            iDMGFromPlayerToPlayer[attacker][victim] += damageDone;
        }
        
        // If a survivor is attacking survivor
        if(GetClientTeam(attacker) == TEAM_SURVIVOR && GetClientTeam(victim) == TEAM_SURVIVOR){
        	FFDamagePerPlayer[attacker] += damageDone;
        }
        
        // If an infected is attacking survivor
        if(convarReportRemainingHP.BoolValue){
	        if(GetClientTeam(attacker) == TEAM_INFECTED && GetClientTeam(victim) == TEAM_SURVIVOR){
	        	if(iDMGFromPlayerToPlayer[attacker][victim] > 0){
	        		if(zombieClass != ZC_CHARGER && zombieClass != ZC_TANK){
	        			PrintDamageThatSurvivorDoneToHisEnemy(attacker, victim, iDMGFromPlayerToPlayer[victim][attacker]);
	        		}
	        		iDMGFromPlayerToPlayer[attacker][victim] = 0;
	        	}
	        }
        }
    }
}



public PlayerDeath_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    // Get the victim details
    new zombieClass = 0;
    new victimId = GetEventInt(event, "userid");
    new victim = GetClientOfUserId(victimId);
    
    // Get the attacker details
    new attackerId = GetEventInt(event, "attacker");
    new attacker = GetClientOfUserId(attackerId);
    
    // no world kills or flukes or whatevs, no bot attackers
    if (victimId && attackerId && IsClientAndInGame(victim) && IsClientAndInGame(attacker) && GetClientTeam(attacker) == TEAM_SURVIVOR && bPlayerLeftStartArea)
    {
        zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
		SIKillsPerPlayer[attacker][zombieClass] += 1;
		
		if(convarReportRemainingHP.BoolValue){
			if(iDMGFromPlayerToPlayer[attacker][victim] > 0){
				iDMGFromPlayerToPlayer[attacker][victim] = 0;
			}
		}
    }
}


public ChargerCarryStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    new chargerID = GetEventInt(event, "userid");
    new charger = GetClientOfUserId(chargerID);
    
    new victimID = GetEventInt(event, "victim");
    new victim = GetClientOfUserId(victimID);
    
    if(convarReportRemainingHP.BoolValue){
	    if(iDMGFromPlayerToPlayer[victim][charger] > 0){
	    	PrintDamageThatSurvivorDoneToHisEnemy(victim, charger, iDMGFromPlayerToPlayer[victim][charger]);
	    	iDMGFromPlayerToPlayer[victim][charger] = 0;
	    }
    }
}



public InfectedDeath_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    new attackerId = GetEventInt(event, "attacker");
    new attacker = GetClientOfUserId(attackerId);
    
    if (attackerId && IsClientAndInGame(attacker) && GetClientTeam(attacker) == TEAM_SURVIVOR && bPlayerLeftStartArea)
    {
		CIKillsPerPlayer[attacker]++;
    }
}

public ReviveSuccess_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    new userid = GetEventInt(event, "userid");
    new reviver = GetClientOfUserId(userid);
    
    if (userid && IsClientAndInGame(reviver) && GetClientTeam(reviver) == TEAM_SURVIVOR && bPlayerLeftStartArea)
    {
		FFRevivesPerPlayer[reviver]++;
    }
}


///PRINTS
PrintDamageThatSurvivorDoneToHisEnemy(attacker, victim, dmg){
	int ZClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
	
	CPrintToChat(attacker, "★{green}[DmgReport]{olive} %N {default}took {blue}%d {default}damage from you!", ZClass, dmg);
}

HandleActualMVP(){
	new SIKillsSumPerPlayer[MAXPLAYERS + 1];
	new SIDamageSumPerPlayer[MAXPLAYERS + 1];
	for(new c = 1; c <= MAXPLAYERS; ++c){
		for(new i = 1; i < ZC_WITCH; ++i){
			SIKillsSumPerPlayer[c] += SIKillsPerPlayer[c][i];
			SIDamageSumPerPlayer[c] += SIDamagePerPlayer[c][i];
		}
	}
	
	
}

///STOCKS

stock bool IsClientAndInGame(index)
{
    return (index > 0 && index <= MaxClients && IsClientInGame(index));
}

stock bool IsSurvivor(client)
{
    return IsClientAndInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

stock bool IsInfected(client)
{
    return IsClientAndInGame(client) && GetClientTeam(client) == TEAM_INFECTED;
}

stock getSurvivor(exclude[4])
{
    for(new i=1; i <= MaxClients; i++) {
        if (IsSurvivor(i)) {
            new tagged = false;
            // exclude already tagged survs
            for (new j=0; j < 4; j++) {
                if (exclude[j] == i) { tagged = true; }
            }
            if (!tagged) {
                return i;
            }
        }
    }
    return 0;
}