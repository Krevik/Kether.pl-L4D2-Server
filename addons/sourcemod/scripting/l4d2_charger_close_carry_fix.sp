#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0.0"

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZC_CHARGER 6

ConVar g_hEnable;
ConVar g_hMaxDistance;
ConVar g_hMaxChargeTime;

float g_flChargeStartTime[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "[L4D2] Charger Close Carry Fix",
	author = "Kether",
	description = "Converts close-range charge bounces into a proper carry grab.",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	g_hEnable = CreateConVar(
		"l4d2_charger_close_carry_enable",
		"1",
		"Enable close-range charger bounce to carry conversion.",
		FCVAR_NOTIFY,
		true, 0.0, true, 1.0);
	g_hMaxDistance = CreateConVar(
		"l4d2_charger_close_carry_max_distance",
		"96.0",
		"Max distance between charger and victim to treat impact as a close bounce (Hammer units).",
		FCVAR_NOTIFY,
		true, 32.0, true, 256.0);
	g_hMaxChargeTime = CreateConVar(
		"l4d2_charger_close_carry_max_charge_time",
		"0.75",
		"Only convert impacts within this many seconds after charge start (avoids wall-splash false positives).",
		FCVAR_NOTIFY,
		true, 0.1, true, 2.0);

	CreateConVar(
		"l4d2_charger_close_carry_version",
		PLUGIN_VERSION,
		"Charger close carry fix plugin version.",
		FCVAR_NOTIFY | FCVAR_DONTRECORD);
	AutoExecConfig(true, "l4d2_charger_close_carry");

	HookEvent("charger_charge_start", Event_ChargeStart);
	HookEvent("charger_charge_end", Event_ChargeEnd);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ResetAllChargeTimes();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetAllChargeTimes();
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0)
	{
		g_flChargeStartTime[client] = 0.0;
	}
}

void Event_ChargeStart(Event event, const char[] name, bool dontBroadcast)
{
	int charger = GetClientOfUserId(event.GetInt("userid"));
	if (charger > 0)
	{
		g_flChargeStartTime[charger] = GetGameTime();
	}
}

void Event_ChargeEnd(Event event, const char[] name, bool dontBroadcast)
{
	int charger = GetClientOfUserId(event.GetInt("userid"));
	if (charger > 0)
	{
		g_flChargeStartTime[charger] = 0.0;
	}
}

public Action L4D2_OnThrowImpactedSurvivor(int attacker, int victim)
{
	if (!g_hEnable.BoolValue || !ShouldConvertToCarry(attacker, victim))
	{
		return Plugin_Continue;
	}

	return Plugin_Handled;
}

public void L4D2_OnThrowImpactedSurvivor_PostHandled(int attacker, int victim)
{
	DataPack pack;
	CreateDataTimer(0.0, Timer_StartCarry, pack, TIMER_FLAG_NO_MAPCHANGE);
	pack.WriteCell(GetClientUserId(attacker));
	pack.WriteCell(GetClientUserId(victim));
}

Action Timer_StartCarry(Handle timer, DataPack pack)
{
	pack.Reset();
	int attacker = GetClientOfUserId(pack.ReadCell());
	int victim = GetClientOfUserId(pack.ReadCell());

	if (!IsValidCharger(attacker) || !IsValidSurvivor(victim))
	{
		return Plugin_Stop;
	}

	if (!IsCharging(attacker) || IsCarryingAnyone(attacker) || IsCarriedByOtherCharger(victim, attacker))
	{
		return Plugin_Stop;
	}

	L4D2_Charger_StartCarryingVictim(victim, attacker);
	return Plugin_Stop;
}

bool ShouldConvertToCarry(int attacker, int victim)
{
	if (!IsValidCharger(attacker) || !IsValidSurvivor(victim))
	{
		return false;
	}

	if (!IsCharging(attacker) || IsCarryingAnyone(attacker) || IsCarriedByOtherCharger(victim, attacker))
	{
		return false;
	}

	float chargeAge = GetGameTime() - g_flChargeStartTime[attacker];
	if (g_flChargeStartTime[attacker] <= 0.0 || chargeAge > g_hMaxChargeTime.FloatValue)
	{
		return false;
	}

	float originA[3], originV[3];
	GetClientAbsOrigin(attacker, originA);
	GetClientAbsOrigin(victim, originV);

	return GetVectorDistance(originA, originV) <= g_hMaxDistance.FloatValue;
}

bool IsCharging(int charger)
{
	int ability = GetEntPropEnt(charger, Prop_Send, "m_customAbility");
	return IsValidEntity(ability) && GetEntProp(ability, Prop_Send, "m_isCharging", 1) > 0;
}

bool IsCarryingAnyone(int charger)
{
	int victim = GetEntPropEnt(charger, Prop_Send, "m_carryVictim");
	return victim > 0 && victim <= MaxClients && IsClientInGame(victim);
}

bool IsCarriedByOtherCharger(int victim, int charger)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i == charger || !IsValidCharger(i))
		{
			continue;
		}

		if (GetEntPropEnt(i, Prop_Send, "m_carryVictim") == victim)
		{
			return true;
		}
	}

	return false;
}

bool IsValidCharger(int client)
{
	return client > 0
		&& client <= MaxClients
		&& IsClientInGame(client)
		&& IsPlayerAlive(client)
		&& GetClientTeam(client) == TEAM_INFECTED
		&& GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_CHARGER;
}

bool IsValidSurvivor(int client)
{
	return client > 0
		&& client <= MaxClients
		&& IsClientInGame(client)
		&& IsPlayerAlive(client)
		&& GetClientTeam(client) == TEAM_SURVIVOR;
}

void ResetAllChargeTimes()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_flChargeStartTime[i] = 0.0;
	}
}
