#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0.0"

#define TEAM_INFECTED 3
#define ZC_CHARGER 6

ConVar g_hEnable;
ConVar g_hCheckInterval;
ConVar g_hMinChargeAge;
ConVar g_hMinMoveDistance;
ConVar g_hMaxStationaryTime;
ConVar g_hFallbackHardStop;

float g_flChargeStartTime[MAXPLAYERS + 1];
float g_flLastOrigin[MAXPLAYERS + 1][3];
float g_flStationaryTime[MAXPLAYERS + 1];
Handle g_hMonitorTimer[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "[L4D2] Charger Stuck Finish",
	author = "Cursor Assistant",
	description = "Finishes Charger charge when charging in place on props (no teleport).",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	g_hEnable = CreateConVar("l4d2_charger_stuck_finish_enable", "1", "Enable Charger stuck finish fix.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCheckInterval = CreateConVar("l4d2_charger_stuck_finish_check_interval", "0.10", "How often to check active charges (seconds).", FCVAR_NOTIFY, true, 0.05, true, 0.5);
	g_hMinChargeAge = CreateConVar("l4d2_charger_stuck_finish_min_charge_age", "0.35", "Minimum charge age before stuck checks begin (seconds).", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	g_hMinMoveDistance = CreateConVar("l4d2_charger_stuck_finish_min_move_distance", "10.0", "Minimum horizontal distance moved per check to be considered not stuck.", FCVAR_NOTIFY, true, 0.1, true, 128.0);
	g_hMaxStationaryTime = CreateConVar("l4d2_charger_stuck_finish_max_stationary_time", "0.30", "How long charger can stay almost still during charge before force finish (seconds).", FCVAR_NOTIFY, true, 0.1, true, 2.0);
	g_hFallbackHardStop = CreateConVar("l4d2_charger_stuck_finish_fallback_hard_stop", "1", "Use m_isCharging fallback if stagger does not end charge on next frame.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	CreateConVar("l4d2_charger_stuck_finish_version", PLUGIN_VERSION, "Charger stuck finish plugin version.", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	AutoExecConfig(true, "l4d2_charger_stuck_finish");

	HookEvent("charger_charge_start", Event_ChargeStart);
	HookEvent("charger_charge_end", Event_ChargeEnd);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
}

public void OnClientDisconnect(int client)
{
	ResetClientState(client);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ResetAllClients();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetAllClients();
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0)
	{
		ResetClientState(client);
	}
}

void Event_ChargeStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_hEnable.BoolValue)
	{
		return;
	}

	int charger = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidCharger(charger))
	{
		return;
	}

	ResetClientState(charger);

	g_flChargeStartTime[charger] = GetGameTime();
	GetClientAbsOrigin(charger, g_flLastOrigin[charger]);
	g_flStationaryTime[charger] = 0.0;

	float interval = g_hCheckInterval.FloatValue;
	g_hMonitorTimer[charger] = CreateTimer(interval, Timer_MonitorCharge, GetClientUserId(charger), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

void Event_ChargeEnd(Event event, const char[] name, bool dontBroadcast)
{
	int charger = GetClientOfUserId(event.GetInt("userid"));
	if (charger > 0)
	{
		ResetClientState(charger);
	}
}

Action Timer_MonitorCharge(Handle timer, int userid)
{
	int charger = GetClientOfUserId(userid);
	if (!g_hEnable.BoolValue || !IsValidCharger(charger))
	{
		return Plugin_Stop;
	}

	if (g_hMonitorTimer[charger] != timer)
	{
		return Plugin_Stop;
	}

	int ability = GetEntPropEnt(charger, Prop_Send, "m_customAbility");
	if (!IsValidEntity(ability) || GetEntProp(ability, Prop_Send, "m_isCharging", 1) <= 0)
	{
		ResetClientState(charger);
		return Plugin_Stop;
	}

	float gameTime = GetGameTime();
	if ((gameTime - g_flChargeStartTime[charger]) < g_hMinChargeAge.FloatValue)
	{
		GetClientAbsOrigin(charger, g_flLastOrigin[charger]);
		g_flStationaryTime[charger] = 0.0;
		return Plugin_Continue;
	}

	float currentOrigin[3];
	GetClientAbsOrigin(charger, currentOrigin);

	float moved2D = GetVectorDistance2D(currentOrigin, g_flLastOrigin[charger]);
	if (moved2D < g_hMinMoveDistance.FloatValue)
	{
		g_flStationaryTime[charger] += g_hCheckInterval.FloatValue;
	}
	else
	{
		g_flStationaryTime[charger] = 0.0;
	}

	g_flLastOrigin[charger] = currentOrigin;

	if (g_flStationaryTime[charger] < g_hMaxStationaryTime.FloatValue)
	{
		return Plugin_Continue;
	}

	ForceFinishCharge(charger);
	g_flStationaryTime[charger] = 0.0;

	return Plugin_Continue;
}

void ForceFinishCharge(int charger)
{
	int victim = GetEntPropEnt(charger, Prop_Send, "m_carryVictim");
	if (IsValidSurvivor(victim))
	{
		// Prefer pummel transition to mimic hitting a wall while carrying.
		L4D2_Charger_PummelVictim(victim, charger);
	}
	else
	{
		float source[3];
		GetClientAbsOrigin(charger, source);
		L4D_StaggerPlayer(charger, charger, source);
	}

	if (g_hFallbackHardStop.BoolValue)
	{
		RequestFrame(OnNextFrame_EnsureChargeEnded, GetClientUserId(charger));
	}
}

void OnNextFrame_EnsureChargeEnded(int userid)
{
	int charger = GetClientOfUserId(userid);
	if (!IsValidCharger(charger))
	{
		return;
	}

	int ability = GetEntPropEnt(charger, Prop_Send, "m_customAbility");
	if (!IsValidEntity(ability))
	{
		return;
	}

	if (GetEntProp(ability, Prop_Send, "m_isCharging", 1) > 0)
	{
		SetEntProp(ability, Prop_Send, "m_isCharging", 0, 1);
	}
}

void ResetAllClients()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		ResetClientState(i);
	}
}

void ResetClientState(int client)
{
	if (client <= 0 || client > MaxClients)
	{
		return;
	}

	g_flChargeStartTime[client] = 0.0;
	g_flStationaryTime[client] = 0.0;
	g_flLastOrigin[client][0] = 0.0;
	g_flLastOrigin[client][1] = 0.0;
	g_flLastOrigin[client][2] = 0.0;

	if (g_hMonitorTimer[client] != null)
	{
		delete g_hMonitorTimer[client];
		g_hMonitorTimer[client] = null;
	}
}

bool IsValidCharger(int client)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return false;
	}

	if (GetClientTeam(client) != TEAM_INFECTED)
	{
		return false;
	}

	return GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_CHARGER;
}

bool IsValidSurvivor(int client)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return false;
	}

	return GetClientTeam(client) == 2;
}

float GetVectorDistance2D(const float a[3], const float b[3])
{
	float dx = a[0] - b[0];
	float dy = a[1] - b[1];
	return SquareRoot((dx * dx) + (dy * dy));
}
