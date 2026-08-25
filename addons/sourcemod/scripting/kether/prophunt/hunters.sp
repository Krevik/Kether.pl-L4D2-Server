#if defined __ph_hunters_included
	#endinput
#endif
#define __ph_hunters_included

#define PH_HUNTER_START_HEALTH 100

// Freeze + blind a Hunter for the hide phase. The screen fade uses FFADE_STAYOUT so it stays
// solid black regardless of the exact engine scaling of the "duration" field, and is cleared
// explicitly in PH_Hunters_ReleaseForSeek rather than relying on a timed fade-back.
void PH_Hunters_FreezeForHide(int client)
{
	if (!IsClientInGame(client))
		return;

	if (!IsPlayerAlive(client))
		L4D_RespawnPlayer(client, true);

	if (IsPlayerAlive(client))
	{
		SetEntityHealth(client, PH_HUNTER_START_HEALTH);
		SetEntityMoveType(client, MOVETYPE_NONE);
		SetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", NULL_VECTOR);
	}

	Client_ScreenFade(client, 1, FFADE_OUT | FFADE_STAYOUT | FFADE_PURGE, 0, 0, 0, 0, 255);
}

void PH_Hunters_ReleaseForSeek(int client)
{
	if (!IsClientInGame(client))
		return;

	if (IsPlayerAlive(client))
		SetEntityMoveType(client, MOVETYPE_WALK);

	Client_ScreenFade(client, 1, FFADE_IN | FFADE_PURGE, 0, 0, 0, 0, 0);
}

public void PH_Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	if (!PH_IsModeActive() || g_ePhase != PHPhase_Seek)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client <= 0 || !IsClientInGame(client) || !PH_IsHunter(client) || !IsPlayerAlive(client))
		return;

	if (g_iCvarHpHunterDec <= 0)
		return;

	int newHealth = GetClientHealth(client) - g_iCvarHpHunterDec;
	if (newHealth <= 0)
		ForcePlayerSuicide(client);
	else
		SetEntityHealth(client, newHealth);
}

// Registered on every prop (victim), checking the attacker - lets us both refund HP to the
// Hunter for landing a hit and, when ph_hide_blood is on, apply the damage ourselves so we
// can suppress the blood decal/particle without touching the underlying player's real HP.
public Action PH_OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if (!PH_IsModeActive() || g_ePhase != PHPhase_Seek)
		return Plugin_Continue;

	if (!PH_IsProp(victim) || attacker < 1 || attacker > MaxClients || !PH_IsHunter(attacker))
		return Plugin_Continue;

	if (g_iCvarHpHunterIncHit > 0 && IsPlayerAlive(attacker))
		SetEntityHealth(attacker, GetClientHealth(attacker) + g_iCvarHpHunterIncHit);

	if (!g_bCvarHideBlood)
		return Plugin_Continue;

	int remaining = GetClientHealth(victim) - RoundToCeil(damage);
	if (remaining > 0)
	{
		SetEntityHealth(victim, remaining);
		return Plugin_Handled; // Damage applied manually above - blocks the blood effect this trace would have caused.
	}

	return Plugin_Continue; // Let a lethal hit through normally so death/score triggers correctly.
}

// Props never fight back - zero any damage a disguised Prop would otherwise deal to a Hunter
// (pounce, claw, or anything else), independent of the button-stripping in stealth.sp.
public Action PH_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!PH_IsModeActive())
		return Plugin_Continue;

	if (PH_IsHunter(victim) && attacker >= 1 && attacker <= MaxClients && PH_IsProp(attacker))
	{
		damage = 0.0;
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void PH_Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!PH_IsModeActive())
		return;

	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (victim > 0 && IsClientInGame(victim) && PH_IsProp(victim))
	{
		if (attacker > 0 && attacker <= MaxClients && PH_IsHunter(attacker) && g_iCvarHpHunterBonus > 0)
			SetEntityHealth(attacker, GetClientHealth(attacker) + g_iCvarHpHunterBonus);

		PH_Rounds_OnPropDeath(victim);
	}
}
