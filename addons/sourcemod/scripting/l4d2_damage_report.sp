#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <l4d2util>

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

int damageCollector[MAXPLAYERS + 1][MAXPLAYERS + 1]; //[infected][survivor]

public Plugin myinfo =
{
	name = "L4D2 Display damage done to SI",
	author = "Krevik",
	version = "1.0.0",
	description = "Dislpay damage reports if SI was hurt by the player he capped",
	url = "kether.pl"
};

public void OnPluginStart()
{
	HookEvent("jockey_ride", Event_CappedPlayer);
	HookEvent("lunge_pounce", Event_CappedPlayer);
	HookEvent("charger_carry_start", Event_CappedPlayer);
	HookEvent("choke_start", Event_CappedPlayer);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", Event_ResetAllDamage);
	HookEvent("round_end", Event_ResetAllDamage);
}

bool isValidInfectedAttacker(int client){
    return ( client > 0 && IsClientInGame(client) && GetClientTeam(client) == TEAM_INFECTED );
}

bool isValidSurvivorVictim(int client){
    return ( client > 0 && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR && !IsFakeClient(client) && IsPlayerAlive(client) );
}

bool isValidForReportCount(int infectedAttacker, int survivorVictim, int zombieClass){
    return ( isValidInfectedAttacker(infectedAttacker) && isValidSurvivorVictim(survivorVictim) && (zombieClass > 0 && zombieClass < 7));
}

void TryReportDoneDamage(int infected, int survivor)
{
    int damage = damageCollector[infected][survivor];
	int zombieClass = GetEntProp(infected, Prop_Send, "m_zombieClass");
    int zombieHealth = GetClientHealth(infected);
	if(damage > 0){
        CPrintToChat(survivor, "{blue}[DmgReport] {green}%N {cyan}%s {default}took {cyan}%d {default}damage from you. Had {cyan}%d {default}HP remaining!", infected, L4D2_InfectedNames[zombieClass], damage, zombieHealth);
        resetDamage(infected, survivor);
    }
}

void resetDamage(int infected, int survivor){
    damageCollector[infected][survivor] = 0;
}
void clearAllDamage(){
    for (int client1 = 1; client1 <= MAXPLAYERS; client1++) {
        for(int client2 = 1; client2 <= MAXPLAYERS; client2++){
            damageCollector[client1][client2] = 0;
        }
    }
}

void resetDamageDoneToInfected(int infected){
    for (int client = 1; client <= MAXPLAYERS; client++) {
            damageCollector[infected][client] = 0;
    }
}

public void Event_PlayerHurt(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
    int infectedAttacker = GetClientOfUserId(hEvent.GetInt("userid"));
    int survivorVictim = GetClientOfUserId(hEvent.GetInt("attacker"));
    int damageDoneToInfected = hEvent.GetInt("dmg_health");
    int infectedClass = GetEntProp(infectedAttacker, Prop_Send, "m_zombieClass");

    if( isValidForReportCount(infectedAttacker, survivorVictim, infectedClass) ){
        damageCollector[infectedAttacker][survivorVictim] += damageDoneToInfected;
    } 
}

public void Event_CappedPlayer(Event event, const char[] name, bool dontBroadcast)
{
	int survivor = GetClientOfUserId(GetEventInt(event, "victim"));
    int infected = GetClientOfUserId(GetEventInt(event, "userid"));
    if( isValidSurvivorVictim(survivor) ){
        TryReportDoneDamage(infected, survivor);
    }
}

public void Event_PlayerDeath(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int infected = GetClientOfUserId(hEvent.GetInt("userid"));
    if( isValidInfectedAttacker(infected) ){
        resetDamageDoneToInfected(infected);
    }
}

//despawn case
public void L4D_OnEnterGhostState(int infected)
{
    resetDamageDoneToInfected(infected);
}

public void Event_ResetAllDamage(Event event, const char[] name, bool dontBroadcast)
{
    clearAllDamage();
}