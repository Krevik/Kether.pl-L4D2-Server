#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <l4d2util>

#define TEAM_SURVIVOR		  2
#define TEAM_INFECTED		  3
#define ARRAY_INDEX_TIMESTAMP 0
int damageCollector[MAXPLAYERS + 1][MAXPLAYERS + 1];	//[infected][survivor]
public Plugin myinfo =
{
	name		= "L4D2 Display damage done to SI",
	author		= "Krevik",
	version		= "2.0",
	description = "Dislpay damage reports if SI was hurt by the player he capped",
	url			= "kether.pl"
};

public void OnPluginStart()
{
	HookEvent("jockey_ride", Event_CappedPlayer, EventHookMode_Post);
	HookEvent("lunge_pounce", Event_CappedPlayer, EventHookMode_Post);
	HookEvent("charger_carry_start", Event_CappedPlayer, EventHookMode_Post);
	HookEvent("choke_start", Event_CappedPlayer, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("round_start", Event_ResetAllDamage, EventHookMode_Post);
	HookEvent("round_end", Event_ResetAllDamage, EventHookMode_Post);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	HookEvent("tongue_grab", Event_SmokerAttackFirst, EventHookMode_Post);
}

bool isValidInfectedAttacker(int client)
{
	return (client > 0 && GetClientTeam(client) == TEAM_INFECTED);
}

bool isValidSurvivorVictim(int client)
{
	return (client > 0 && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR && !IsFakeClient(client) && IsPlayerAlive(client));
}

bool isValidForReportCount(int infectedAttacker, int survivorVictim, int zombieClass)
{
	return (isValidInfectedAttacker(infectedAttacker) && isValidSurvivorVictim(survivorVictim) && (zombieClass > 0 && zombieClass < 7));
}

void TryReportDoneDamage(int infected, int survivor)
{
	int damage		 = damageCollector[infected][survivor];
	int zombieHealth = GetClientHealth(infected);
	if (damage > 0)
	{
		CPrintToChat(survivor, "{blue}[DmgReport] {green}%N's {default}took {olive}%d {default}damage from you. Had {olive}%d {default}HP remaining!", infected, damage, zombieHealth);
		resetDamage(infected, survivor);
	}
}

void resetDamage(int infected, int survivor)
{
	damageCollector[infected][survivor] = 0;
}

void clearAllDamage()
{
	for (int client1 = 1; client1 <= MAXPLAYERS; client1++)
	{
		for (int client2 = 1; client2 <= MAXPLAYERS; client2++)
		{
			damageCollector[client1][client2] = 0;
		}
	}
}

void resetDamageDoneToInfected(int infected)
{
	for (int client = 1; client <= MAXPLAYERS; client++)
	{
		damageCollector[infected][client] = 0;
	}
}

public Action Event_PlayerHurt(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int infectedAttacker	 = GetClientOfUserId(hEvent.GetInt("userid"));
	int survivorVictim		 = GetClientOfUserId(hEvent.GetInt("attacker"));
	int damageDoneToInfected = hEvent.GetInt("dmg_health") + hEvent.GetInt("dmg_armor");
	int infectedClass		 = GetEntProp(infectedAttacker, Prop_Send, "m_zombieClass");
	if (isValidForReportCount(infectedAttacker, survivorVictim, infectedClass))
	{
		damageCollector[infectedAttacker][survivorVictim] += damageDoneToInfected;
	}
	return Plugin_Continue;
}

public Action Event_SmokerAttackFirst(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int iAttackerUserid = hEvent.GetInt("userid");
	int iAttacker		= GetClientOfUserId(iAttackerUserid);
	int iVictimUserid	= hEvent.GetInt("victim");
	int iVictim			= GetClientOfUserId(iVictimUserid);

	if (isValidInfectedAttacker(iAttacker) && isValidSurvivorVictim(iVictim))
	{
		// It takes exactly 1.0s of dragging to get paralyzed, so we'll give the timer additional 0.1s to update
		DataPack pack;
		CreateDataTimer(1.1, ReportDamageDoneToSmoker, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_HNDL_CLOSE);
		pack.WriteCell(iAttacker);
		pack.WriteCell(iVictim);
	}
	return Plugin_Continue;
}

public Action ReportDamageDoneToSmoker(Handle timer, DataPack pack)
{
	int infectedAttacker;
	int survivorVictim;
	pack.Reset();
	infectedAttacker = pack.ReadCell();
	survivorVictim	 = pack.ReadCell();
	if (IsSurvivorParalyzed(survivorVictim))
	{
		TryReportDoneDamage(infectedAttacker, survivorVictim);
	}

	return Plugin_Continue;
}

public Action Event_CappedPlayer(Event event, const char[] name, bool dontBroadcast)
{
	int survivor = GetClientOfUserId(GetEventInt(event, "victim"));
	int infected = GetClientOfUserId(GetEventInt(event, "userid"));
	if (isValidSurvivorVictim(survivor))
	{
		TryReportDoneDamage(infected, survivor);
	}
	return Plugin_Continue;
}

public void Event_PlayerDeath(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int infected = GetClientOfUserId(hEvent.GetInt("userid"));
	if (isValidInfectedAttacker(infected))
	{
		resetDamageDoneToInfected(infected);
	}
}

// despawn case
public void L4D_OnEnterGhostState(int infected)
{
	resetDamageDoneToInfected(infected);
}

public Action Event_ResetAllDamage(Event event, const char[] name, bool dontBroadcast)
{
	clearAllDamage();
	return Plugin_Continue;
}

bool IsSurvivorParalyzed(int iClient)
{
	int iTongueOwner = GetEntProp(iClient, Prop_Send, "m_tongueOwner");
	if (iTongueOwner != -1)
	{
		float fVictimTimer = GetGameTime() - GetEntPropFloat(iClient, Prop_Send, "m_tongueVictimTimer", ARRAY_INDEX_TIMESTAMP);
		return (fVictimTimer >= 1.0);
	}

	return false;
}