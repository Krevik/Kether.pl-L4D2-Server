#if defined __ph_disguise_included
	#endinput
#endif
#define __ph_disguise_included

#define PH_SOLID_NONE			0
#define PH_SOLID_VPHYSICS		6
#define PH_FSOLID_NOT_SOLID		0x0004
#define PH_COLLISION_DEBRIS		1

// Swaps the client's own model (so bullet traces line up with something roughly prop-sized)
// and attaches a non-solid visual child entity carrying the real model, per the CS:GO Prop
// Hunt port's technique (see plan section "Disguise mechanism"). The player keeps a normal
// player hull for hit detection - no plugin in the reference ports resizes it either.
bool PH_ApplyDisguise(int client, const char[] model, PHPropType type, const float offset[3])
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client))
		return false;

	if (!PrecacheModel(model, true))
		return false;

	PH_ClearDisguise(client);

	SetEntityModel(client, model);
	SetEntProp(client, Prop_Data, "m_bloodColor", -1); // DONT_BLEED
	AcceptEntityInput(client, "DisableShadow");
	SetEntityRenderMode(client, RENDER_NONE);

	int prop = CreateEntityByName("prop_dynamic_override");
	if (prop == -1)
		prop = CreateEntityByName("prop_dynamic");

	if (prop == -1)
	{
		SetEntityRenderMode(client, RENDER_NORMAL);
		return false;
	}

	float origin[3], angles[3];
	GetClientAbsOrigin(client, origin);
	GetClientEyeAngles(client, angles);
	angles[0] = 0.0;
	angles[2] = 0.0;
	origin[0] += offset[0];
	origin[1] += offset[1];
	origin[2] += offset[2];

	SetEntityModel(prop, model);
	TeleportEntity(prop, origin, angles, NULL_VECTOR);
	DispatchSpawn(prop);

	SetEntProp(prop, Prop_Send, "m_nSolidType", PH_SOLID_NONE);
	SetEntProp(prop, Prop_Send, "m_usSolidFlags", PH_FSOLID_NOT_SOLID, 2);
	SetEntProp(prop, Prop_Send, "m_CollisionGroup", PH_COLLISION_DEBRIS);
	SetEntityMoveType(prop, MOVETYPE_NONE);
	SetEntPropEnt(prop, Prop_Data, "m_hOwnerEntity", client);

	SetVariantString("!activator");
	AcceptEntityInput(prop, "SetParent", client, prop, 0);

	g_iVisualProp[client] = EntIndexToEntRef(prop);
	strcopy(g_sDisguiseModel[client], sizeof(g_sDisguiseModel[]), model);
	g_ePropType[client] = type;
	g_bPropDisguised[client] = true;
	g_bPropFrozen[client] = false;

	if (g_bCvarThirdperson)
		PH_UpdateThirdperson(client, true);

	return true;
}

void PH_ClearDisguise(int client)
{
	int prop = EntRefToEntIndex(g_iVisualProp[client]);
	if (prop != -1 && IsValidEntity(prop))
		AcceptEntityInput(prop, "Kill");

	g_iVisualProp[client] = -1;
	g_bPropDisguised[client] = false;
	g_bPropFrozen[client] = false;
	g_sDisguiseModel[client][0] = '\0';
	g_ePropType[client] = PHProp_None;

	if (IsClientInGame(client))
	{
		SetEntityRenderMode(client, RENDER_NORMAL);
		PH_UpdateThirdperson(client, false);
	}
}

// Rotation/position lock: detaching the visual child from the player leaves it standing
// perfectly still at its current world transform (the CS:GO Prop Hunt port's technique),
// while MOVETYPE_NONE stops the underlying (invisible) player from drifting away from it.
void PH_SetPropFrozen(int client, bool freeze)
{
	if (!g_bPropDisguised[client])
		return;

	g_bPropFrozen[client] = freeze;
	int prop = EntRefToEntIndex(g_iVisualProp[client]);

	if (freeze)
	{
		SetEntityMoveType(client, MOVETYPE_NONE);
		SetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", NULL_VECTOR);

		if (prop != -1)
		{
			SetVariantString("");
			AcceptEntityInput(prop, "ClearParent");
		}
	}
	else
	{
		SetEntityMoveType(client, MOVETYPE_WALK);

		if (prop != -1)
		{
			float origin[3], angles[3];
			GetClientAbsOrigin(client, origin);
			GetClientEyeAngles(client, angles);
			angles[0] = 0.0;
			angles[2] = 0.0;
			TeleportEntity(prop, origin, angles, NULL_VECTOR);

			SetVariantString("!activator");
			AcceptEntityInput(prop, "SetParent", client, prop, 0);
		}
	}
}

void PH_UpdateThirdperson(int client, bool enable)
{
	g_bThirdperson[client] = enable;
	SetEntPropFloat(client, Prop_Send, "m_TimeForceExternalView", enable ? 99999.3 : 0.0);
}

// Ported from PropHunt Neu: refuse a lock while the player is standing over an active
// trigger_hurt, so nobody can freeze themselves into a permanently-ticking hazard by accident.
bool PH_IsStandingOverHazard(int client)
{
	float origin[3];
	GetClientAbsOrigin(client, origin);

	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "trigger_hurt")) != -1)
	{
		if (GetEntProp(ent, Prop_Data, "m_bDisabled"))
			continue;

		float entOrigin[3], mins[3], maxs[3];
		GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", entOrigin);
		GetEntPropVector(ent, Prop_Data, "m_vecMins", mins);
		GetEntPropVector(ent, Prop_Data, "m_vecMaxs", maxs);

		float relMin[3], relMax[3];
		AddVectors(entOrigin, mins, relMin);
		AddVectors(entOrigin, maxs, relMax);

		if (origin[0] >= relMin[0] && origin[0] <= relMax[0]
			&& origin[1] >= relMin[1] && origin[1] <= relMax[1]
			&& origin[2] >= relMin[2] - 64.0 && origin[2] <= relMax[2] + 64.0)
		{
			return true;
		}
	}

	return false;
}
