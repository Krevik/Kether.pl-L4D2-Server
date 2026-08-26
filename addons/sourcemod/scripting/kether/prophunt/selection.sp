#if defined __ph_selection_included
	#endinput
#endif
#define __ph_selection_included

// Buttons: +use picks a prop, +reload toggles the rotation/position lock, +attack taunts,
// +attack2 toggles first/third person manually. Props never hold a weapon, so all four are
// otherwise idle for this team.
//
// Press-edge detection is done by hand against the previous tick's buttons rather than reading
// the "m_afButtonPressed" netprop - that prop isn't reliably populated yet for the current tick
// at the point OnPlayerRunCmd fires, so comparing it against the live "buttons" bitmask could
// miss the edge and require mashing a key a few times before a press actually registered.
void PH_Selection_OnPlayerRunCmd(int client, int buttons)
{
	if (!PH_IsProp(client) || !IsPlayerAlive(client))
	{
		g_iLastButtons[client] = 0;
		return;
	}

	if (g_ePhase != PHPhase_Hide && g_ePhase != PHPhase_Seek)
		return;

	int pressed = buttons & ~g_iLastButtons[client];
	g_iLastButtons[client] = buttons;

	if (pressed & IN_USE)
	{
		// Doors take priority over prop selection when aimed at - a door is never a valid
		// disguise candidate anyway (PH_FindEntityProp only matches prop_dynamic/prop_physics),
		// so there's no ambiguity in which action +use should perform.
		if (!PH_TryUseDoor(client))
			PH_TrySelectProp(client);
	}

	if (g_bCvarProplockEnabled && (pressed & IN_RELOAD))
		PH_ToggleLock(client);

	if (g_bCvarTauntEnabled && (pressed & IN_ATTACK))
		PH_DoTaunt(client);

	// Held, not just the press-edge, so bashing a stuck door repeats at ph_doorbash_interval for
	// as long as +attack stays down, like a normal melee weapon's swing cadence.
	if (buttons & IN_ATTACK)
		PH_Selection_TryBashDoor(client);

	if (pressed & IN_ATTACK2)
		PH_UpdateThirdperson(client, !g_bThirdperson[client]);

	PH_Selection_UpdateAutoFreeze(client, buttons);
}

// L4D2's Hunter claw weapon has no way to swing without also pushing the attacker forward (see
// stealth.sp's PH_Stealth_BlockPropButtons for why IN_ATTACK is fully blocked before it reaches
// the game), so a disguised Prop can never bash "stuck" doors the normal way. Instead we drive
// the same underlying mechanism ourselves: those doors are plain prop_door_rotating entities
// with a health pool that a melee swing just damages directly, so trace for one and apply the
// damage server-side - ported from the trace+SDKHooks_TakeDamage pattern in the repo's own
// archive/tankdoorfix.sp.
void PH_Selection_TryBashDoor(int client)
{
	float now = GetGameTime();
	if (now < g_flNextDoorBashTime[client])
		return;

	float direction[3];
	int door = PH_FindBashableDoor(client, direction);
	if (door == -1)
		return;

	g_flNextDoorBashTime[client] = now + g_flCvarDoorBashInterval;
	SDKHooks_TakeDamage(door, client, client, g_flCvarDoorBashDamage, DMG_CLUB, _, direction);
}

// Returns the prop_door_rotating (not prop_door_rotating_checkpoint - saferoom doors use a
// different lock/+use mechanism entirely) the client is aiming at and within melee range of, or
// -1 if none. Range check and damage-force direction match archive/tankdoorfix.sp's
// IsLookingAtBreakableDoor().
int PH_FindBashableDoor(int client, float direction[3])
{
	int target = GetClientAimTarget(client, false);
	if (target <= 0)
		return -1;

	char classname[64];
	if (!GetEntityClassname(target, classname, sizeof(classname)))
		return -1;

	if (!StrEqual(classname, "prop_door_rotating"))
		return -1;

	// Our Open/bash paths fire directly on the entity, bypassing the engine's own team-gated
	// Use() handler entirely (see PH_TryUseDoor) - which means they'd otherwise also bypass any
	// mapper-intended lock (a one-way door, an area not meant to be reachable this way, etc.)
	// that the engine's own handler would normally respect for a real Survivor.
	if (Entity_IsLocked(target))
		return -1;

	float clientPos[3], doorPos[3];
	GetClientAbsOrigin(client, clientPos);
	GetEntPropVector(target, Prop_Send, "m_vecOrigin", doorPos);

	if (GetVectorDistance(clientPos, doorPos, true) > 8100.0) // 90.0 units
		return -1;

	SubtractVectors(doorPos, clientPos, direction);
	return target;
}

// The L4D2 engine restricts +use door interaction to the Survivor team - special infected
// players never receive door Use() callbacks at all, no matter what OnPlayerRunCmd does with
// IN_USE (confirmed by the existence of community workaround plugins like "SI Doors Use" for
// exactly this limitation). Props are forced onto the Infected team, so a normal door press
// would silently do nothing; we bypass the broken native path entirely by finding the door
// ourselves and firing its "Open" entity input directly, which isn't gated by team at all.
// Returns true if a door was found and opened (whether or not it was already open), so the
// caller can skip falling back to prop selection.
bool PH_TryUseDoor(int client)
{
	float now = GetGameTime();
	if (now < g_flNextDoorUseTime[client])
		return false;

	int door = PH_FindUsableDoor(client);
	if (door == -1)
		return false;

	g_flNextDoorUseTime[client] = now + g_flCvarDoorUseInterval;
	AcceptEntityInput(door, "Open", client, client);
	return true;
}

// Same aim-target + classname pattern as PH_FindBashableDoor(), but at the normal +use
// interaction distance (ph_dooruse_range) rather than melee-bash range.
int PH_FindUsableDoor(int client)
{
	int target = GetClientAimTarget(client, false);
	if (target <= 0)
		return -1;

	char classname[64];
	if (!GetEntityClassname(target, classname, sizeof(classname)))
		return -1;

	if (!StrEqual(classname, "prop_door_rotating"))
		return -1;

	// See the matching comment in PH_FindBashableDoor() - firing "Open" directly bypasses the
	// engine's own lock check too, so it must be done manually here.
	if (Entity_IsLocked(target))
		return -1;

	float clientPos[3], doorPos[3];
	GetClientAbsOrigin(client, clientPos);
	GetEntPropVector(target, Prop_Send, "m_vecOrigin", doorPos);

	if (GetVectorDistance(clientPos, doorPos) > g_flCvarDoorUseRange)
		return -1;

	return target;
}

// Only ever auto-clears the *idle* auto-freeze - a manual +reload/!lock lock (g_bPropManualLock)
// is deliberate and must not be undone just because the player is holding a movement key (which
// happens easily, e.g. leaning on "W" while looking around) even though MOVETYPE_NONE means they
// don't actually go anywhere while locked. Only another manual toggle, a new disguise, or round
// end should clear a manual lock.
void PH_Selection_UpdateAutoFreeze(int client, int buttons)
{
	if (g_flCvarAutoFreezeTime <= 0.0 || !g_bPropDisguised[client])
		return;

	bool moving = (buttons & (IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT | IN_JUMP)) != 0;

	if (moving)
	{
		g_flAutoFreezeIdleSince[client] = 0.0;
		if (g_bPropFrozen[client] && !g_bPropManualLock[client])
			PH_SetPropFrozen(client, false);
		return;
	}

	if (g_bPropFrozen[client])
		return;

	if (g_flAutoFreezeIdleSince[client] <= 0.0)
	{
		g_flAutoFreezeIdleSince[client] = GetGameTime();
		return;
	}

	if (GetGameTime() - g_flAutoFreezeIdleSince[client] >= g_flCvarAutoFreezeTime)
	{
		if (!PH_IsStandingOverHazard(client))
			PH_SetPropFrozen(client, true);
	}
}

void PH_ToggleLock(int client)
{
	if (!g_bPropDisguised[client])
	{
		PrintHintText(client, "%t", "PropHunt_NotDisguisedYet");
		return;
	}

	if (!g_bPropFrozen[client] && PH_IsStandingOverHazard(client))
	{
		PrintHintText(client, "%t", "PropHunt_HazardBelow");
		return;
	}

	PH_SetPropFrozen(client, !g_bPropFrozen[client]);
	g_bPropManualLock[client] = g_bPropFrozen[client];
	EmitSoundToClient(client, g_bPropFrozen[client] ? "buttons/button3.wav" : "buttons/button24.wav");
	PrintHintText(client, "%t", g_bPropFrozen[client] ? "PropHunt_Locked" : "PropHunt_Unlocked");
}

bool PH_TrySelectProp(int client)
{
	if (g_iCvarPropChangeLimit > 0 && g_iPropChanges[client] >= g_iCvarPropChangeLimit)
	{
		PrintHintText(client, "%t", "PropHunt_ChangeLimitReached");
		return false;
	}

	char model[PLATFORM_MAX_PATH];
	PHPropType type;
	float offset[3];

	bool found = PH_FindEntityProp(client, model, sizeof(model), type, offset);
	if (!found)
		found = PH_FindStaticProp(client, model, sizeof(model), type, offset);

	if (!found)
	{
		PrintHintText(client, "%t", "PropHunt_NoPropFound");
		return false;
	}

	if (!PH_ApplyDisguise(client, model, type, offset))
	{
		PrintHintText(client, "%t", "PropHunt_DisguiseFailed");
		return false;
	}

	g_iPropChanges[client]++;

	char pretty[PLATFORM_MAX_PATH];
	PH_GetPrettyModelName(model, pretty, sizeof(pretty));
	PrintHintText(client, "%t", "PropHunt_Disguised", pretty);
	return true;
}

// Live prop_dynamic / prop_physics entities can be identified directly through a normal
// aim trace - this is the exact, authoritative path.
bool PH_FindEntityProp(int client, char[] model, int maxlen, PHPropType &type, float offset[3])
{
	int entity = GetClientAimTarget(client, false);
	if (entity <= 0 || !IsValidEntity(entity) || entity <= MaxClients)
		return false;

	char classname[64];
	GetEdictClassname(entity, classname, sizeof(classname));

	if (StrEqual(classname, "prop_dynamic") || StrEqual(classname, "prop_dynamic_override"))
		type = PHProp_Dynamic;
	else if (StrEqual(classname, "prop_physics") || StrEqual(classname, "prop_physics_override") || StrEqual(classname, "prop_physics_multiplayer"))
		type = PHProp_Physics;
	else
		return false;

	char rawModel[PLATFORM_MAX_PATH];
	GetEntPropString(entity, Prop_Data, "m_ModelName", rawModel, sizeof(rawModel));
	if (rawModel[0] == '\0' || rawModel[0] == '*')
		return false;

	float entOrigin[3], clientOrigin[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", entOrigin);
	GetClientAbsOrigin(client, clientOrigin);
	if (GetVectorDistance(clientOrigin, entOrigin) > g_flCvarPropSelectDistance)
		return false;

	float mins[3], maxs[3];
	GetEntPropVector(entity, Prop_Send, "m_vecMins", mins);
	GetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxs);
	if (!PH_IsSizeAllowed(GetVectorDistance(mins, maxs)))
		return false;

	float allowOffset[3];
	if (!PH_IsModelAllowed(rawModel, allowOffset))
		return false;

	strcopy(model, maxlen, rawModel);
	offset[0] = allowOffset[0];
	offset[1] = allowOffset[1];
	offset[2] = allowOffset[2];
	return true;
}

// prop_static props aren't real entities, so a plain trace can't identify which one was hit
// (see the PropHunt Neu research notes). Instead we search the per-map data dumped by
// tools/prophunt_propscan.py for the candidate whose origin is closest to the aim ray, bounded
// by the distance to the nearest solid surface so nothing is picked through a wall. Each
// candidate's hit radius is an approximation (half its model's bounding-box diagonal, ignoring
// rotation) rather than a true rotated OBB test.
bool PH_FindStaticProp(int client, char[] model, int maxlen, PHPropType &type, float offset[3])
{
	int propCount = PH_PropData_Count();
	if (propCount == 0)
		return false;

	float eyePos[3], eyeAng[3], fwd[3];
	GetClientEyePosition(client, eyePos);
	GetClientEyeAngles(client, eyeAng);
	GetAngleVectors(eyeAng, fwd, NULL_VECTOR, NULL_VECTOR);

	float maxDist = g_flCvarPropSelectDistance;
	float endPos[3];
	endPos[0] = eyePos[0] + fwd[0] * maxDist;
	endPos[1] = eyePos[1] + fwd[1] * maxDist;
	endPos[2] = eyePos[2] + fwd[2] * maxDist;

	Handle trace = TR_TraceRayFilterEx(eyePos, endPos, MASK_SOLID, RayType_EndPoint, PH_TraceFilter_IgnorePlayers, client);
	if (TR_DidHit(trace))
	{
		float hitPos[3];
		TR_GetEndPosition(hitPos, trace);
		float hitDist = GetVectorDistance(eyePos, hitPos);
		if (hitDist < maxDist)
			maxDist = hitDist;
	}
	delete trace;

	int bestIndex = -1;
	float bestScore = 999999.0;

	char candidateModel[PLATFORM_MAX_PATH];
	float candOrigin[3], candAngles[3];
	PHPropType candScanType;

	for (int i = 0; i < propCount; i++)
	{
		PH_PropData_Get(i, candidateModel, candOrigin, candAngles, candScanType);

		float toProp[3];
		SubtractVectors(candOrigin, eyePos, toProp);
		float along = GetVectorDotProduct(toProp, fwd);
		if (along < 0.0 || along > maxDist + 48.0)
			continue;

		float closest[3];
		closest[0] = eyePos[0] + fwd[0] * along;
		closest[1] = eyePos[1] + fwd[1] * along;
		closest[2] = eyePos[2] + fwd[2] * along;
		float perp = GetVectorDistance(candOrigin, closest);

		float diagonal;
		if (!PH_GetModelBoundsDiagonal(candidateModel, diagonal))
			continue;

		float radius = diagonal * 0.5;
		if (radius < 10.0)
			radius = 10.0;

		if (perp > radius)
			continue;

		float score = perp + (along * 0.05);
		if (score < bestScore)
		{
			bestScore = score;
			bestIndex = i;
		}
	}

	if (bestIndex == -1)
		return false;

	PH_PropData_Get(bestIndex, candidateModel, candOrigin, candAngles, candScanType);
	type = candScanType;

	float diagonal;
	PH_GetModelBoundsDiagonal(candidateModel, diagonal);
	if (!PH_IsSizeAllowed(diagonal))
		return false;

	float allowOffset[3];
	if (!PH_IsModelAllowed(candidateModel, allowOffset))
		return false;

	strcopy(model, maxlen, candidateModel);
	offset[0] = allowOffset[0];
	offset[1] = allowOffset[1];
	offset[2] = allowOffset[2];
	return true;
}

public bool PH_TraceFilter_IgnorePlayers(int entity, int contentsMask, any client)
{
	return entity < 1 || entity > MaxClients;
}

stock void PH_GetPrettyModelName(const char[] model, char[] pretty, int maxlen)
{
	char work[PLATFORM_MAX_PATH];
	strcopy(work, sizeof(work), model);

	int len = strlen(work);
	if (len > 4 && StrEqual(work[len - 4], ".mdl", false))
		work[len - 4] = '\0';

	int slash = FindCharInString(work, '/', true);
	char base[PLATFORM_MAX_PATH];
	if (slash == -1)
		strcopy(base, sizeof(base), work);
	else
		strcopy(base, sizeof(base), work[slash + 1]);

	len = strlen(base);
	for (int i = 0; i < len; i++)
	{
		if (base[i] == '_' || base[i] == '-')
			base[i] = ' ';
	}

	strcopy(pretty, maxlen, base);
}
