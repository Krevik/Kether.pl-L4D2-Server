#if defined __ph_selection_included
	#endinput
#endif
#define __ph_selection_included

// Buttons: +use picks a prop, +reload toggles the rotation/position lock, +attack taunts,
// +attack2 toggles first/third person manually. Props never hold a weapon, so all four are
// otherwise idle for this team.
void PH_Selection_OnPlayerRunCmd(int client, int buttons)
{
	if (!PH_IsProp(client) || !IsPlayerAlive(client))
		return;

	if (g_ePhase != PHPhase_Hide && g_ePhase != PHPhase_Seek)
		return;

	int changed = GetEntProp(client, Prop_Data, "m_afButtonPressed");

	if ((buttons & IN_USE) && (changed & IN_USE))
		PH_TrySelectProp(client);

	if (g_bCvarProplockEnabled && (buttons & IN_RELOAD) && (changed & IN_RELOAD))
		PH_ToggleLock(client);

	if (g_bCvarTauntEnabled && (buttons & IN_ATTACK) && (changed & IN_ATTACK))
		PH_DoTaunt(client);

	if ((buttons & IN_ATTACK2) && (changed & IN_ATTACK2))
		PH_UpdateThirdperson(client, !g_bThirdperson[client]);

	PH_Selection_UpdateAutoFreeze(client, buttons);
}

void PH_Selection_UpdateAutoFreeze(int client, int buttons)
{
	if (g_flCvarAutoFreezeTime <= 0.0 || !g_bPropDisguised[client])
		return;

	bool moving = (buttons & (IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT | IN_JUMP)) != 0;

	if (moving)
	{
		g_flAutoFreezeIdleSince[client] = 0.0;
		if (g_bPropFrozen[client])
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
