#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#undef REQUIRE_PLUGIN
#include <l4d2_lagcomp_manager>
#define REQUIRE_PLUGIN

#define PLUGIN_VERSION "1.0"

bool g_bLagCompAvailable = false;
bool g_bHunterPouncing[MAXPLAYERS + 1] = {false, ...};
bool g_bJockeyRiding[MAXPLAYERS + 1] = {false, ...};
bool g_bSmokerGrabbing[MAXPLAYERS + 1] = {false, ...};
bool g_bChargerCarrying[MAXPLAYERS + 1] = {false, ...};

public Plugin myinfo =
{
	name = "[L4D2] SI Lag Compensation Fix",
	author = "Kether.pl",
	description = "Adds lag compensation for Special Infected during grab/ride to fix hit registration issues",
	version = PLUGIN_VERSION,
	url = "kether.pl"
};

public void OnPluginStart()
{
	HookEvent("pounce_end", Event_PounceEnd);
	HookEvent("jockey_ride", Event_JockeyRide);
	HookEvent("jockey_ride_end", Event_JockeyRideEnd);
	HookEvent("tongue_grab", Event_TongueGrab);
	HookEvent("tongue_release", Event_TongueRelease);
	HookEvent("choke_start", Event_ChokeStart);
	HookEvent("choke_stopped", Event_ChokeStopped);
	HookEvent("charger_carry_start", Event_ChargerCarryStart);
	HookEvent("charger_carry_end", Event_ChargerCarryEnd);
	HookEvent("charger_pummel_start", Event_ChargerPummelStart);
	HookEvent("charger_pummel_end", Event_ChargerPummelEnd);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
}

public void OnAllPluginsLoaded()
{
	g_bLagCompAvailable = LibraryExists("l4d2_lagcomp_manager");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "l4d2_lagcomp_manager"))
	{
		g_bLagCompAvailable = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "l4d2_lagcomp_manager"))
	{
		g_bLagCompAvailable = false;
	}
}

public void OnClientDisconnect(int client)
{
	RemoveFromLagComp(client);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		RemoveFromLagComp(i);
	}
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		RemoveFromLagComp(i);
	}
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0)
	{
		RemoveFromLagComp(client);
	}
}

// Hunter events
void Event_PounceEnd(Event event, const char[] name, bool dontBroadcast)
{
	int hunter = GetClientOfUserId(event.GetInt("userid"));
	if (hunter > 0)
	{
		RemoveFromLagComp(hunter);
		g_bHunterPouncing[hunter] = false;
	}
}

// Jockey events
void Event_JockeyRide(Event event, const char[] name, bool dontBroadcast)
{
	int jockey = GetClientOfUserId(event.GetInt("userid"));
	if (jockey > 0 && IsValidClient(jockey) && GetClientTeam(jockey) == 3)
	{
		AddToLagComp(jockey);
		g_bJockeyRiding[jockey] = true;
	}
}

void Event_JockeyRideEnd(Event event, const char[] name, bool dontBroadcast)
{
	int jockey = GetClientOfUserId(event.GetInt("userid"));
	if (jockey > 0)
	{
		RemoveFromLagComp(jockey);
		g_bJockeyRiding[jockey] = false;
	}
}

// Smoker events
void Event_TongueGrab(Event event, const char[] name, bool dontBroadcast)
{
	int smoker = GetClientOfUserId(event.GetInt("userid"));
	if (smoker > 0 && IsValidClient(smoker) && GetClientTeam(smoker) == 3)
	{
		AddToLagComp(smoker);
		g_bSmokerGrabbing[smoker] = true;
	}
}

void Event_TongueRelease(Event event, const char[] name, bool dontBroadcast)
{
	int smoker = GetClientOfUserId(event.GetInt("userid"));
	if (smoker > 0)
	{
		RemoveFromLagComp(smoker);
		g_bSmokerGrabbing[smoker] = false;
	}
}

void Event_ChokeStart(Event event, const char[] name, bool dontBroadcast)
{
	int smoker = GetClientOfUserId(event.GetInt("userid"));
	if (smoker > 0 && IsValidClient(smoker) && GetClientTeam(smoker) == 3)
	{
		AddToLagComp(smoker);
		g_bSmokerGrabbing[smoker] = true;
	}
}

void Event_ChokeStopped(Event event, const char[] name, bool dontBroadcast)
{
	int smoker = GetClientOfUserId(event.GetInt("userid"));
	if (smoker > 0)
	{
		RemoveFromLagComp(smoker);
		g_bSmokerGrabbing[smoker] = false;
	}
}

// Charger events
void Event_ChargerCarryStart(Event event, const char[] name, bool dontBroadcast)
{
	int charger = GetClientOfUserId(event.GetInt("userid"));
	if (charger > 0 && IsValidClient(charger) && GetClientTeam(charger) == 3)
	{
		AddToLagComp(charger);
		g_bChargerCarrying[charger] = true;
	}
}

void Event_ChargerCarryEnd(Event event, const char[] name, bool dontBroadcast)
{
	int charger = GetClientOfUserId(event.GetInt("userid"));
	if (charger > 0)
	{
		// Don't remove yet, wait for pummel end
		g_bChargerCarrying[charger] = false;
	}
}

void Event_ChargerPummelStart(Event event, const char[] name, bool dontBroadcast)
{
	int charger = GetClientOfUserId(event.GetInt("userid"));
	if (charger > 0 && IsValidClient(charger) && GetClientTeam(charger) == 3)
	{
		AddToLagComp(charger);
		g_bChargerCarrying[charger] = true;
	}
}

void Event_ChargerPummelEnd(Event event, const char[] name, bool dontBroadcast)
{
	int charger = GetClientOfUserId(event.GetInt("userid"));
	if (charger > 0)
	{
		RemoveFromLagComp(charger);
		g_bChargerCarrying[charger] = false;
	}
}

void AddToLagComp(int client)
{
	if (!g_bLagCompAvailable || !IsValidClient(client))
		return;
	
	// Check current state and add if needed
	int zClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	
	if (zClass == 3) // Hunter
	{
		int victim = GetEntPropEnt(client, Prop_Send, "m_pounceVictim");
		if (victim > 0 && !g_bHunterPouncing[client])
		{
			L4D2_LagComp_AddAdditionalEntity(client);
			g_bHunterPouncing[client] = true;
		}
	}
	else if (zClass == 5) // Jockey
	{
		int victim = GetEntPropEnt(client, Prop_Send, "m_jockeyVictim");
		if (victim > 0 && !g_bJockeyRiding[client])
		{
			L4D2_LagComp_AddAdditionalEntity(client);
			g_bJockeyRiding[client] = true;
		}
	}
	else if (zClass == 1) // Smoker
	{
		int victim = GetEntPropEnt(client, Prop_Send, "m_tongueVictim");
		if (victim > 0 && !g_bSmokerGrabbing[client])
		{
			L4D2_LagComp_AddAdditionalEntity(client);
			g_bSmokerGrabbing[client] = true;
		}
	}
	else if (zClass == 6) // Charger
	{
		int victim = GetEntPropEnt(client, Prop_Send, "m_carryVictim");
		if (victim <= 0)
			victim = GetEntPropEnt(client, Prop_Send, "m_pummelVictim");
		if (victim > 0 && !g_bChargerCarrying[client])
		{
			L4D2_LagComp_AddAdditionalEntity(client);
			g_bChargerCarrying[client] = true;
		}
	}
}

void RemoveFromLagComp(int client)
{
	if (!g_bLagCompAvailable || !IsValidClient(client))
		return;
	
	if (g_bHunterPouncing[client])
	{
		L4D2_LagComp_RemoveAdditionalEntity(client);
		g_bHunterPouncing[client] = false;
	}
	
	if (g_bJockeyRiding[client])
	{
		L4D2_LagComp_RemoveAdditionalEntity(client);
		g_bJockeyRiding[client] = false;
	}
	
	if (g_bSmokerGrabbing[client])
	{
		L4D2_LagComp_RemoveAdditionalEntity(client);
		g_bSmokerGrabbing[client] = false;
	}
	
	if (g_bChargerCarrying[client])
	{
		L4D2_LagComp_RemoveAdditionalEntity(client);
		g_bChargerCarrying[client] = false;
	}
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client);
}
