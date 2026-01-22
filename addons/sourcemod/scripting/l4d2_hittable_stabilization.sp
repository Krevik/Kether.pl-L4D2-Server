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
*
******************************************************************/

#define L4D2Team_Infected 3
#define L4D2Infected_Tank 8

ConVar hStabilizationEnabled;
ConVar hStabilizationDelay;
ConVar hAngularVelocityDamping;
ConVar hForceDirection;
ConVar hDebug;

bool g_bStabilizationEnabled;
float g_fStabilizationDelay;
float g_fAngularVelocityDamping;
bool g_bForceDirection;
bool g_bDebug;

public Plugin myinfo = 
{
	name = "L4D2 Hittable Stabilization",
	author = "Auto",
	description = "Stabilizes hittable physics to make tank throws more predictable",
	version = "1.0",
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
	
	hStabilizationEnabled.AddChangeHook(OnConVarChanged);
	hStabilizationDelay.AddChangeHook(OnConVarChanged);
	hAngularVelocityDamping.AddChangeHook(OnConVarChanged);
	hForceDirection.AddChangeHook(OnConVarChanged);
	hDebug.AddChangeHook(OnConVarChanged);
	
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
	GetEntPropVector(hittable, Prop_Data, "m_vecVelocity", currentVelocity);
	
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
			float horizontalSpeed = SquareRoot(currentVelocity[0] * currentVelocity[0] + currentVelocity[1] * currentVelocity[1]);
			newVelocity[2] = horizontalSpeed * 0.15 + 50.0; // Small upward component
		}
		else
		{
			newVelocity[2] = currentVelocity[2];
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
		newVelocity[2] = currentVelocity[2]; // Keep Z component as-is
		
		if (g_bDebug)
		{
			PrintToServer("[HittableStabilization] Stabilizing velocity for hittable %d: (%.2f,%.2f,%.2f) speed=%.2f",
				hittable, newVelocity[0], newVelocity[1], newVelocity[2], speed);
		}
	}
	
	// Apply new velocity
	SetEntPropVector(hittable, Prop_Data, "m_vecVelocity", newVelocity);
	
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
