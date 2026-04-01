/**
 * L4D2 No Hit Slowdown
 *
 * Disables the survivor movement slowdown that occurs when hit by infected
 * (special infected or common infected). Records the player's speed before
 * the hit (including limp from low HP) and re-applies it so only the extra
 * hit slowdown is removed.
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

// How long to keep re-applying speed after a hit (game may re-apply slowdown over multiple frames)
#define RESTORE_DURATION 0.4
#define RESTORE_INTERVAL 0.03

// Speed to restore to (recorded before hit; fallback if never set)
float g_fSpeedBeforeHit[MAXPLAYERS + 1] = { 1.0, ... };

public Plugin myinfo = {
	name        = "L4D2 No Hit Slowdown",
	author      = "StarterX4, Cursor AI, Kether.pl",
	description = "Disables survivor slowdown when hit by infected or common infected.",
	version     = "0.3.0",
	url         = "https://github.com/Krevik/Kether.pl-L4D2-Server"
};

public void OnPluginStart()
{
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamagePre);
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
	g_fSpeedBeforeHit[client] = 1.0;
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamagePre);
	SDKUnhook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

// Record the victim's current speed before the game applies hit slowdown
public Action OnTakeDamagePre(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!IsSurvivorVictim(victim)) {
		return Plugin_Continue;
	}
	if (!IsDamageFromInfected(attacker, inflictor)) {
		return Plugin_Continue;
	}
	g_fSpeedBeforeHit[victim] = GetEntPropFloat(victim, Prop_Send, "m_flLaggedMovementValue");
	return Plugin_Continue;
}

public void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	if (!IsSurvivorVictim(victim)) {
		return;
	}
	if (!IsDamageFromInfected(attacker, inflictor)) {
		return;
	}
	RestoreSpeedAndKeepRestoring(victim);
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (!IsSurvivorVictim(victim)) {
		return;
	}
	// attacker 0 = world / common infected / witch; non-survivor = infected
	if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && GetClientTeam(attacker) == TEAM_SURVIVOR) {
		return; // Friendly fire - leave slowdown as-is (or set to 1.0 if you want no FF slowdown too)
	}
	RestoreSpeedAndKeepRestoring(victim);
}

void RestoreSpeedAndKeepRestoring(int client)
{
	float speed = g_fSpeedBeforeHit[client];
	if (speed <= 0.0) {
		speed = 1.0;
	}
	SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", speed);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteFloat(GetGameTime());
	pack.WriteFloat(speed);
	pack.Reset();
	CreateTimer(RESTORE_INTERVAL, Timer_KeepRestoringSpeed, pack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_KeepRestoringSpeed(Handle timer, DataPack pack)
{
	pack.Reset();
	int userid = pack.ReadCell();
	float startTime = pack.ReadFloat();
	float speed = pack.ReadFloat();
	int client = GetClientOfUserId(userid);

	if (client <= 0 || !IsClientInGame(client) || !IsPlayerAlive(client) || GetClientTeam(client) != TEAM_SURVIVOR) {
		delete pack;
		return Plugin_Stop;
	}
	if (GetGameTime() - startTime >= RESTORE_DURATION) {
		delete pack;
		return Plugin_Stop;
	}
	if (speed <= 0.0) {
		speed = 1.0;
	}
	SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", speed);
	return Plugin_Continue;
}

bool IsSurvivorVictim(int client)
{
	return (client >= 1 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == TEAM_SURVIVOR);
}

bool IsDamageFromInfected(int attacker, int inflictor)
{
	// Attacker 0 = common infected / witch / world (no client)
	if (attacker == 0) {
		return true;
	}

	// Special infected: attacker is a client on infected team
	if (attacker >= 1 && attacker <= MaxClients && IsClientInGame(attacker) && GetClientTeam(attacker) == TEAM_INFECTED) {
		return true;
	}

	// Common infected or witch: attacker is the entity (edict index > MaxClients)
	if (attacker > MaxClients && IsValidEntity(attacker)) {
		char classname[64];
		if (GetEdictClassname(attacker, classname, sizeof(classname))) {
			if (strcmp(classname, "infected") == 0 || strcmp(classname, "witch") == 0) {
				return true;
			}
		}
	}

	// Inflictor is SI weapon/ability
	if (inflictor > 0 && inflictor <= MaxClients && IsClientInGame(inflictor) && GetClientTeam(inflictor) == TEAM_INFECTED) {
		return true;
	}
	if (inflictor > MaxClients && IsValidEntity(inflictor)) {
		char classname[64];
		if (GetEdictClassname(inflictor, classname, sizeof(classname))) {
			if (StrContains(classname, "hunter_claw") != -1
				|| StrContains(classname, "smoker_tongue") != -1
				|| StrContains(classname, "charger_fist") != -1
				|| StrContains(classname, "jockey_claw") != -1
				|| StrContains(classname, "tank_rock") != -1
				|| StrEqual(classname, "insect_swarm")) {
				return true;
			}
		}
	}

	return false;
}
