#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

/******************************************************************
*
* L4D2 Hittable Stabilization
* ------------------------
* ------- Details: -------
* ------------------------
* > Stabilizes hittable physics when Tank punches them
* > Ensures hittables fly in the direction the Tank is looking
* > Reduces random angular velocity that causes unpredictable flight paths
* > Per-class speed/vertical multipliers (lightweight, cars, dumpsters)
* > Optional launch-speed scale toward official 30-tick feel
*
******************************************************************/

#define L4D2Team_Infected 3
#define L4D2Infected_Tank 8

enum HittableClass
{
	HittableClass_Default = 0,
	HittableClass_Lightweight,
	HittableClass_Car,
	HittableClass_Dumpster
}

ConVar hStabilizationEnabled;
ConVar hStabilizationDelay;
ConVar hAngularVelocityDamping;
ConVar hForceDirection;
ConVar hDebug;
ConVar hLightweightSpeedMultiplier;
ConVar hLightweightVerticalMultiplier;
ConVar hCarSpeedMultiplier;
ConVar hCarVerticalMultiplier;
ConVar hDumpsterSpeedMultiplier;
ConVar hDumpsterVerticalMultiplier;
ConVar hTickrateCompensate;
ConVar hTickrateRef;
ConVar hTickrateCompensatePower;

bool g_bStabilizationEnabled;
float g_fStabilizationDelay;
float g_fAngularVelocityDamping;
bool g_bForceDirection;
bool g_bDebug;
float g_fLightweightSpeedMultiplier;
float g_fLightweightVerticalMultiplier;
float g_fCarSpeedMultiplier;
float g_fCarVerticalMultiplier;
float g_fDumpsterSpeedMultiplier;
float g_fDumpsterVerticalMultiplier;
bool g_bTickrateCompensate;
float g_fTickrateRef;
float g_fTickrateCompensatePower;

public Plugin myinfo = 
{
	name = "L4D2 Hittable Stabilization",
	author = "Auto",
	description = "Stabilizes hittable physics to make tank throws more predictable",
	version = "1.1",
	url = ""
};

public void OnPluginStart()
{
	hStabilizationEnabled = CreateConVar("hc_stabilization_enabled", "1",
		"Enable hittable stabilization (1: enabled, 0: disabled)",
		FCVAR_NONE, true, 0.0, true, 1.0);
	
	hStabilizationDelay = CreateConVar("hc_stabilization_delay", "0.05",
		"Delay in seconds before applying stabilization (allows game physics to initialize)",
		FCVAR_NONE, true, 0.0, true, 0.5);
	
	hAngularVelocityDamping = CreateConVar("hc_angular_velocity_damping", "0.3",
		"Angular velocity damping factor (0.0 = no rotation, 1.0 = full rotation)",
		FCVAR_NONE, true, 0.0, true, 1.0);
	
	hForceDirection = CreateConVar("hc_force_direction", "1",
		"Force hittable to fly in Tank's view direction (1: enabled, 0: only stabilize current velocity)",
		FCVAR_NONE, true, 0.0, true, 1.0);
	
	hDebug = CreateConVar("hc_stabilization_debug", "0",
		"Enable debug output (1: enabled, 0: disabled)",
		FCVAR_NONE, true, 0.0, true, 1.0);
	
	hLightweightSpeedMultiplier = CreateConVar("hc_lightweight_speed_mult", "0.7",
		"Speed multiplier for lightweight hittables (forklifts, logs, pallets, etc.) - lower = slower",
		FCVAR_NONE, true, 0.1, true, 2.0);
	
	hLightweightVerticalMultiplier = CreateConVar("hc_lightweight_vertical_mult", "0.3",
		"Vertical velocity multiplier for lightweight hittables - lower = less upward flight",
		FCVAR_NONE, true, 0.0, true, 2.0);

	hCarSpeedMultiplier = CreateConVar("hc_car_speed_mult", "0.75",
		"Speed multiplier for cars, vans, taxis, alarm cars - lower = slower",
		FCVAR_NONE, true, 0.1, true, 2.0);

	hCarVerticalMultiplier = CreateConVar("hc_car_vertical_mult", "0.5",
		"Vertical velocity multiplier for cars - lower = less upward flight",
		FCVAR_NONE, true, 0.0, true, 2.0);

	hDumpsterSpeedMultiplier = CreateConVar("hc_dumpster_speed_mult", "0.7",
		"Speed multiplier for dumpsters/containers - lower = slower",
		FCVAR_NONE, true, 0.1, true, 2.0);

	hDumpsterVerticalMultiplier = CreateConVar("hc_dumpster_vertical_mult", "0.4",
		"Vertical velocity multiplier for dumpsters/containers - lower = less upward flight",
		FCVAR_NONE, true, 0.0, true, 2.0);

	hTickrateCompensate = CreateConVar("hc_tickrate_compensate", "0",
		"Scale launch speed toward official 30-tick feel. Does not rewind VPhysics (bounces/rolling stay high-tick). 0: off, 1: on",
		FCVAR_NONE, true, 0.0, true, 1.0);

	hTickrateRef = CreateConVar("hc_tickrate_ref", "30",
		"Reference tickrate used when hc_tickrate_compensate is enabled (official Valve servers are 30)",
		FCVAR_NONE, true, 10.0, true, 128.0);

	hTickrateCompensatePower = CreateConVar("hc_tickrate_compensate_power", "0.4",
		"Exponent for tickrate scale: (ref/current)^power. 1.0 is linear (too strong on 108 tick). 0.4 on 108 tick is ~0.62",
		FCVAR_NONE, true, 0.0, true, 2.0);
	
	hStabilizationEnabled.AddChangeHook(OnConVarChanged);
	hStabilizationDelay.AddChangeHook(OnConVarChanged);
	hAngularVelocityDamping.AddChangeHook(OnConVarChanged);
	hForceDirection.AddChangeHook(OnConVarChanged);
	hDebug.AddChangeHook(OnConVarChanged);
	hLightweightSpeedMultiplier.AddChangeHook(OnConVarChanged);
	hLightweightVerticalMultiplier.AddChangeHook(OnConVarChanged);
	hCarSpeedMultiplier.AddChangeHook(OnConVarChanged);
	hCarVerticalMultiplier.AddChangeHook(OnConVarChanged);
	hDumpsterSpeedMultiplier.AddChangeHook(OnConVarChanged);
	hDumpsterVerticalMultiplier.AddChangeHook(OnConVarChanged);
	hTickrateCompensate.AddChangeHook(OnConVarChanged);
	hTickrateRef.AddChangeHook(OnConVarChanged);
	hTickrateCompensatePower.AddChangeHook(OnConVarChanged);
	
	GetCvars();
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!g_bStabilizationEnabled)
		return;
	
	if (entity <= 0 || entity > 2048)
		return;
	
	// Hook new hittable entities as they are created
	if (StrEqual(classname, "prop_physics") || StrEqual(classname, "prop_car_alarm"))
	{
		// Small delay to ensure entity is fully initialized
		DataPack pack;
		CreateDataTimer(0.1, Timer_HookNewEntity, pack);
		pack.WriteCell(entity);
		
		if (g_bDebug)
		{
			PrintToServer("[HittableStabilization] Found new entity %d (%s)", entity, classname);
		}
	}
}

Action Timer_HookNewEntity(Handle timer, DataPack pack)
{
	pack.Reset();
	int entity = pack.ReadCell();
	
	if (IsValidEntity(entity) && IsTankHittable(entity))
	{
		HookSingleEntityOutput(entity, "OnHitByTank", OnHittablePunched, true);
		
		if (g_bDebug)
		{
			PrintToServer("[HittableStabilization] Hooked new hittable entity %d", entity);
		}
	}
	
	return Plugin_Stop;
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bStabilizationEnabled = hStabilizationEnabled.BoolValue;
	g_fStabilizationDelay = hStabilizationDelay.FloatValue;
	g_fAngularVelocityDamping = hAngularVelocityDamping.FloatValue;
	g_bForceDirection = hForceDirection.BoolValue;
	g_bDebug = hDebug.BoolValue;
	g_fLightweightSpeedMultiplier = hLightweightSpeedMultiplier.FloatValue;
	g_fLightweightVerticalMultiplier = hLightweightVerticalMultiplier.FloatValue;
	g_fCarSpeedMultiplier = hCarSpeedMultiplier.FloatValue;
	g_fCarVerticalMultiplier = hCarVerticalMultiplier.FloatValue;
	g_fDumpsterSpeedMultiplier = hDumpsterSpeedMultiplier.FloatValue;
	g_fDumpsterVerticalMultiplier = hDumpsterVerticalMultiplier.FloatValue;
	g_bTickrateCompensate = hTickrateCompensate.BoolValue;
	g_fTickrateRef = hTickrateRef.FloatValue;
	g_fTickrateCompensatePower = hTickrateCompensatePower.FloatValue;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	// Hook all hittable props on round start
	CreateTimer(0.2, HookHittables);
}

Action HookHittables(Handle timer)
{
	if (!g_bStabilizationEnabled)
		return Plugin_Stop;
	
	int entity = -1;
	
	// Hook prop_physics hittables
	while ((entity = FindEntityByClassname(entity, "prop_physics")) != -1)
	{
		if (IsTankHittable(entity))
		{
			HookSingleEntityOutput(entity, "OnHitByTank", OnHittablePunched, true);
			
			if (g_bDebug)
			{
				PrintToServer("[HittableStabilization] Hooked prop_physics entity %d", entity);
			}
		}
	}
	
	entity = -1;
	
	// Hook prop_car_alarm hittables
	while ((entity = FindEntityByClassname(entity, "prop_car_alarm")) != -1)
	{
		HookSingleEntityOutput(entity, "OnHitByTank", OnHittablePunched, true);
		
		if (g_bDebug)
		{
			PrintToServer("[HittableStabilization] Hooked prop_car_alarm entity %d", entity);
		}
	}
	
	return Plugin_Stop;
}

public void OnHittablePunched(const char[] output, int caller, int activator, float delay)
{
	if (!g_bStabilizationEnabled)
		return;
	
	if (caller <= 0 || !IsValidEntity(caller))
		return;
	
	if (activator <= 0 || activator > MaxClients || !IsClientInGame(activator))
		return;
	
	if (!IsTank(activator))
		return;
	
	// Delay stabilization to allow game physics to initialize
	CreateTimer(g_fStabilizationDelay, StabilizeHittable, GetClientUserId(activator) | (caller << 16));
	
	if (g_bDebug)
	{
		PrintToServer("[HittableStabilization] Tank %d punched hittable %d", activator, caller);
	}
}

Action StabilizeHittable(Handle timer, int data)
{
	int tankUserId = data & 0xFFFF;
	int hittable = data >> 16;
	
	int tank = GetClientOfUserId(tankUserId);
	
	if (tank <= 0 || !IsClientInGame(tank) || !IsTank(tank))
		return Plugin_Stop;
	
	if (hittable <= 0 || !IsValidEntity(hittable))
		return Plugin_Stop;
	
	// Get Tank's eye angles
	float tankAngles[3];
	GetClientEyeAngles(tank, tankAngles);
	
	// Convert angles to direction vector
	float direction[3];
	GetAngleVectors(tankAngles, direction, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(direction, direction);
	
	// Get current velocity
	float currentVelocity[3];
	GetEntPropVector(hittable, Prop_Data, "m_vecAbsVelocity", currentVelocity);
	
	float speed = GetVectorLength(currentVelocity);
	
	// If speed is too low, the object hasn't been launched yet
	if (speed < 50.0)
	{
		if (g_bDebug)
		{
			PrintToServer("[HittableStabilization] Hittable %d velocity too low (%.2f), skipping", hittable, speed);
		}
		return Plugin_Stop;
	}

	HittableClass hittableClass = GetHittableClass(hittable);
	float speedMultiplier;
	float verticalMultiplier;
	GetClassMultipliers(hittableClass, speedMultiplier, verticalMultiplier);

	float tickrateScale = GetTickrateSpeedScale();
	speed *= speedMultiplier * tickrateScale;
	
	if (g_bDebug)
	{
		PrintToServer("[HittableStabilization] Class %d entity %d multipliers: speed=%.2f vertical=%.2f tickrate=%.2f -> launch=%.2f",
			view_as<int>(hittableClass), hittable, speedMultiplier, verticalMultiplier, tickrateScale, speed);
	}
	
	float newVelocity[3];
	
	if (g_bForceDirection)
	{
		// Force direction based on Tank's view angle
		// Keep the same speed but change direction
		newVelocity[0] = direction[0] * speed;
		newVelocity[1] = direction[1] * speed;
		// Preserve upward velocity component - use a more predictable upward arc
		if (currentVelocity[2] > 0.0)
		{
			// Use a consistent upward velocity based on horizontal speed
			// This creates a more predictable arc
			float horizontalSpeed = SquareRoot(newVelocity[0] * newVelocity[0] + newVelocity[1] * newVelocity[1]);
			float baseUpward = horizontalSpeed * 0.15 + 50.0; // Small upward component
			newVelocity[2] = baseUpward * verticalMultiplier;
		}
		else
		{
			newVelocity[2] = currentVelocity[2] * verticalMultiplier;
		}
		
		if (g_bDebug)
		{
			PrintToServer("[HittableStabilization] Forcing direction for hittable %d: old=(%.2f,%.2f,%.2f) new=(%.2f,%.2f,%.2f) speed=%.2f",
				hittable, currentVelocity[0], currentVelocity[1], currentVelocity[2],
				newVelocity[0], newVelocity[1], newVelocity[2], speed);
		}
	}
	else
	{
		// Just normalize and stabilize current velocity direction
		NormalizeVector(currentVelocity, newVelocity);
		newVelocity[0] *= speed;
		newVelocity[1] *= speed;
		newVelocity[2] = currentVelocity[2] * verticalMultiplier;
		
		if (g_bDebug)
		{
			PrintToServer("[HittableStabilization] Stabilizing velocity for hittable %d: (%.2f,%.2f,%.2f) speed=%.2f",
				hittable, newVelocity[0], newVelocity[1], newVelocity[2], speed);
		}
	}
	
	SetEntPropVector(hittable, Prop_Data, "m_vecAbsVelocity", newVelocity);
	TeleportEntity(hittable, NULL_VECTOR, NULL_VECTOR, newVelocity);
	
	// Reduce angular velocity to prevent spinning
	if (g_fAngularVelocityDamping < 1.0)
	{
		float angularVelocity[3];
		GetEntPropVector(hittable, Prop_Data, "m_vecAngVelocity", angularVelocity);
		
		// Dampen angular velocity
		angularVelocity[0] *= g_fAngularVelocityDamping;
		angularVelocity[1] *= g_fAngularVelocityDamping;
		angularVelocity[2] *= g_fAngularVelocityDamping;
		
		SetEntPropVector(hittable, Prop_Data, "m_vecAngVelocity", angularVelocity);
		
		if (g_bDebug)
		{
			PrintToServer("[HittableStabilization] Dampened angular velocity for hittable %d by factor %.2f",
				hittable, g_fAngularVelocityDamping);
		}
	}
	
	return Plugin_Stop;
}

void GetClassMultipliers(HittableClass hittableClass, float &speedMultiplier, float &verticalMultiplier)
{
	switch (hittableClass)
	{
		case HittableClass_Lightweight:
		{
			speedMultiplier = g_fLightweightSpeedMultiplier;
			verticalMultiplier = g_fLightweightVerticalMultiplier;
		}
		case HittableClass_Car:
		{
			speedMultiplier = g_fCarSpeedMultiplier;
			verticalMultiplier = g_fCarVerticalMultiplier;
		}
		case HittableClass_Dumpster:
		{
			speedMultiplier = g_fDumpsterSpeedMultiplier;
			verticalMultiplier = g_fDumpsterVerticalMultiplier;
		}
		default:
		{
			speedMultiplier = 1.0;
			verticalMultiplier = 1.0;
		}
	}
}

float GetTickrateSpeedScale()
{
	if (!g_bTickrateCompensate)
		return 1.0;

	float tickInterval = GetTickInterval();
	if (tickInterval <= 0.0)
		return 1.0;

	float currentTick = 1.0 / tickInterval;
	if (currentTick <= g_fTickrateRef)
		return 1.0;

	return Pow(g_fTickrateRef / currentTick, g_fTickrateCompensatePower);
}

bool IsTank(int client)
{
	return IsClientInGame(client) 
		&& GetClientTeam(client) == L4D2Team_Infected
		&& GetEntProp(client, Prop_Send, "m_zombieClass") == L4D2Infected_Tank;
}

bool IsTankHittable(int entity)
{
	if (!IsValidEntity(entity))
		return false;
	
	char className[64];
	GetEdictClassname(entity, className, sizeof(className));
	
	if (StrEqual(className, "prop_physics"))
	{
		if (GetEntProp(entity, Prop_Send, "m_hasTankGlow", 1))
			return true;
	}
	else if (StrEqual(className, "prop_car_alarm"))
		return true;
	
	return false;
}

HittableClass GetHittableClass(int entity)
{
	if (!IsValidEntity(entity))
		return HittableClass_Default;

	char className[64];
	GetEdictClassname(entity, className, sizeof(className));
	if (StrEqual(className, "prop_car_alarm"))
		return HittableClass_Car;

	char sModelName[PLATFORM_MAX_PATH];
	GetEntPropString(entity, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
	ReplaceString(sModelName, sizeof(sModelName), "\\", "/", false);

	if (StrContains(sModelName, "dumpster", false) != -1)
		return HittableClass_Dumpster;

	if (StrContains(sModelName, "cara_", false) != -1
	 || StrContains(sModelName, "taxi_", false) != -1
	 || StrContains(sModelName, "police_car", false) != -1
	 || StrContains(sModelName, "utility_truck", false) != -1
	 || StrEqual(sModelName, "models/props_vehicles/van.mdl", false)
	 || StrEqual(sModelName, "models/props_fairgrounds/bumpercar.mdl", false))
		return HittableClass_Car;

	if (IsLightweightModel(sModelName))
		return HittableClass_Lightweight;

	return HittableClass_Default;
}

bool IsLightweightModel(const char[] sModelName)
{
	// Forklifts (wózki widłowe)
	if (StrEqual(sModelName, "models/props/cs_assault/forklift.mdl", false))
		return true;
	if (StrContains(sModelName, "forklift_brokenlift", false) != -1)
		return true;
	
	// Handtrucks/Pallets (palety/wózki)
	if (StrEqual(sModelName, "models/props/cs_assault/handtruck.mdl", false))
		return true;
	
	// Baggage carts (bagażówki)
	if (StrEqual(sModelName, "models/props_vehicles/airport_baggage_cart2.mdl", false))
		return true;
	if (StrEqual(sModelName, "models/sblitz/field_equipment_cart.mdl", false))
		return true;
	
	// Haybales (siano)
	if (StrEqual(sModelName, "models/props_unique/haybails_single.mdl", false))
		return true;
	
	// Logs (kłody)
	if (StrEqual(sModelName, "models/props_foliage/swamp_fallentree01_bare.mdl", false))
		return true;
	if (StrEqual(sModelName, "models/props_foliage/tree_trunk_fallen.mdl", false))
		return true;
	
	// Generator trailer (przyczepa)
	if (StrEqual(sModelName, "models/props_vehicles/generatortrailer01.mdl", false))
		return true;
	
	// I-beams (belki)
	if (StrContains(sModelName, "ibeam_breakable01", false) != -1)
		return true;
	
	return false;
}
