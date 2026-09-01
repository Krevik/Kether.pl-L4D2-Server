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
* > Per-class speed/vertical multipliers (default, lightweight, cars, dumpsters)
* > Optional launch-speed scale toward official 30-tick feel
* > Short post-punch follow window to kill bounce energy and somersaults
*
******************************************************************/

#define L4D2Team_Infected 3
#define L4D2Infected_Tank 8
#define MAX_EDICTS 2048
#define FOLLOW_INTERVAL 0.08
#define BOUNCE_DOT_THRESHOLD 0.25
#define MIN_BOUNCE_SPEED 80.0

enum HittableClass
{
	HittableClass_Default = 0,
	HittableClass_Lightweight,
	HittableClass_Car,
	HittableClass_Dumpster
}

enum struct PunchFollow
{
	int ref;
	float until;
	float lastVel[3];
}

ConVar hStabilizationEnabled;
ConVar hStabilizationDelay;
ConVar hAngularVelocityDamping;
ConVar hForceDirection;
ConVar hDebug;
ConVar hDefaultSpeedMultiplier;
ConVar hDefaultVerticalMultiplier;
ConVar hLightweightSpeedMultiplier;
ConVar hLightweightVerticalMultiplier;
ConVar hCarSpeedMultiplier;
ConVar hCarVerticalMultiplier;
ConVar hDumpsterSpeedMultiplier;
ConVar hDumpsterVerticalMultiplier;
ConVar hTickrateCompensate;
ConVar hTickrateRef;
ConVar hTickrateCompensatePower;
ConVar hPostPunchTime;
ConVar hBounceRetain;
ConVar hFollowAngularDamp;

bool g_bStabilizationEnabled;
float g_fStabilizationDelay;
float g_fAngularVelocityDamping;
bool g_bForceDirection;
bool g_bDebug;
float g_fDefaultSpeedMultiplier;
float g_fDefaultVerticalMultiplier;
float g_fLightweightSpeedMultiplier;
float g_fLightweightVerticalMultiplier;
float g_fCarSpeedMultiplier;
float g_fCarVerticalMultiplier;
float g_fDumpsterSpeedMultiplier;
float g_fDumpsterVerticalMultiplier;
bool g_bTickrateCompensate;
float g_fTickrateRef;
float g_fTickrateCompensatePower;
float g_fPostPunchTime;
float g_fBounceRetain;
float g_fFollowAngularDamp;

bool g_bOutputHooked[MAX_EDICTS + 1];
ArrayList g_PunchFollows;
Handle g_hFollowTimer;

public Plugin myinfo =
{
	name = "L4D2 Hittable Stabilization",
	author = "Auto",
	description = "Stabilizes hittable physics to make tank throws more predictable",
	version = "1.2",
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

	hAngularVelocityDamping = CreateConVar("hc_angular_velocity_damping", "0.12",
		"Launch angular velocity damping (0.0 = no rotation, 1.0 = full rotation)",
		FCVAR_NONE, true, 0.0, true, 1.0);

	hForceDirection = CreateConVar("hc_force_direction", "1",
		"Force hittable to fly in Tank's view direction (1: enabled, 0: only stabilize current velocity)",
		FCVAR_NONE, true, 0.0, true, 1.0);

	hDebug = CreateConVar("hc_stabilization_debug", "0",
		"Enable debug output (1: enabled, 0: disabled)",
		FCVAR_NONE, true, 0.0, true, 1.0);

	hDefaultSpeedMultiplier = CreateConVar("hc_default_speed_mult", "0.8",
		"Speed multiplier for unclassified hittables - lower = slower",
		FCVAR_NONE, true, 0.1, true, 2.0);

	hDefaultVerticalMultiplier = CreateConVar("hc_default_vertical_mult", "0.55",
		"Vertical velocity multiplier for unclassified hittables - lower = less upward flight",
		FCVAR_NONE, true, 0.0, true, 2.0);

	hLightweightSpeedMultiplier = CreateConVar("hc_lightweight_speed_mult", "0.7",
		"Speed multiplier for lightweight hittables (forklifts, logs, pallets, etc.) - lower = slower",
		FCVAR_NONE, true, 0.1, true, 2.0);

	hLightweightVerticalMultiplier = CreateConVar("hc_lightweight_vertical_mult", "0.3",
		"Vertical velocity multiplier for lightweight hittables - lower = less upward flight",
		FCVAR_NONE, true, 0.0, true, 2.0);

	hCarSpeedMultiplier = CreateConVar("hc_car_speed_mult", "0.75",
		"Speed multiplier for cars, vans, taxis, alarm cars - lower = slower",
		FCVAR_NONE, true, 0.1, true, 2.0);

	hCarVerticalMultiplier = CreateConVar("hc_car_vertical_mult", "0.45",
		"Vertical velocity multiplier for cars - lower = less upward flight",
		FCVAR_NONE, true, 0.0, true, 2.0);

	hDumpsterSpeedMultiplier = CreateConVar("hc_dumpster_speed_mult", "0.7",
		"Speed multiplier for dumpsters/containers - lower = slower",
		FCVAR_NONE, true, 0.1, true, 2.0);

	hDumpsterVerticalMultiplier = CreateConVar("hc_dumpster_vertical_mult", "0.4",
		"Vertical velocity multiplier for dumpsters/containers - lower = less upward flight",
		FCVAR_NONE, true, 0.0, true, 2.0);

	hTickrateCompensate = CreateConVar("hc_tickrate_compensate", "1",
		"Scale launch speed toward official 30-tick feel for ALL hittable classes. Does not rewind VPhysics. 0: off, 1: on",
		FCVAR_NONE, true, 0.0, true, 1.0);

	hTickrateRef = CreateConVar("hc_tickrate_ref", "30",
		"Reference tickrate used when hc_tickrate_compensate is enabled (official Valve servers are 30)",
		FCVAR_NONE, true, 10.0, true, 128.0);

	hTickrateCompensatePower = CreateConVar("hc_tickrate_compensate_power", "0.4",
		"Exponent for tickrate scale: (ref/current)^power. 1.0 is linear (too strong on 108 tick). 0.4 on 108 tick is ~0.62",
		FCVAR_NONE, true, 0.0, true, 2.0);

	hPostPunchTime = CreateConVar("hc_post_punch_time", "2.0",
		"Seconds after punch to keep killing bounce energy and somersaults. 0 disables follow-up",
		FCVAR_NONE, true, 0.0, true, 5.0);

	hBounceRetain = CreateConVar("hc_bounce_retain", "0.5",
		"Speed kept after a bounce during post-punch window (0.0 = dead stop, 1.0 = vanilla bounce)",
		FCVAR_NONE, true, 0.0, true, 1.0);

	hFollowAngularDamp = CreateConVar("hc_follow_angular_damp", "0.55",
		"Extra angular damping applied each follow tick after punch (0.0 = freeze spin, 1.0 = no extra)",
		FCVAR_NONE, true, 0.0, true, 1.0);

	hStabilizationEnabled.AddChangeHook(OnConVarChanged);
	hStabilizationDelay.AddChangeHook(OnConVarChanged);
	hAngularVelocityDamping.AddChangeHook(OnConVarChanged);
	hForceDirection.AddChangeHook(OnConVarChanged);
	hDebug.AddChangeHook(OnConVarChanged);
	hDefaultSpeedMultiplier.AddChangeHook(OnConVarChanged);
	hDefaultVerticalMultiplier.AddChangeHook(OnConVarChanged);
	hLightweightSpeedMultiplier.AddChangeHook(OnConVarChanged);
	hLightweightVerticalMultiplier.AddChangeHook(OnConVarChanged);
	hCarSpeedMultiplier.AddChangeHook(OnConVarChanged);
	hCarVerticalMultiplier.AddChangeHook(OnConVarChanged);
	hDumpsterSpeedMultiplier.AddChangeHook(OnConVarChanged);
	hDumpsterVerticalMultiplier.AddChangeHook(OnConVarChanged);
	hTickrateCompensate.AddChangeHook(OnConVarChanged);
	hTickrateRef.AddChangeHook(OnConVarChanged);
	hTickrateCompensatePower.AddChangeHook(OnConVarChanged);
	hPostPunchTime.AddChangeHook(OnConVarChanged);
	hBounceRetain.AddChangeHook(OnConVarChanged);
	hFollowAngularDamp.AddChangeHook(OnConVarChanged);

	GetCvars();

	g_PunchFollows = new ArrayList(sizeof(PunchFollow));

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public void OnMapEnd()
{
	StopFollowTimer();
	g_PunchFollows.Clear();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!g_bStabilizationEnabled)
		return;

	if (entity <= 0 || entity > MAX_EDICTS)
		return;

	g_bOutputHooked[entity] = false;

	if (StrEqual(classname, "prop_physics") || StrEqual(classname, "prop_car_alarm"))
	{
		DataPack pack;
		CreateDataTimer(0.1, Timer_HookNewEntity, pack);
		pack.WriteCell(EntIndexToEntRef(entity));

		if (g_bDebug)
		{
			PrintToServer("[HittableStabilization] Found new entity %d (%s)", entity, classname);
		}
	}
}

public void OnEntityDestroyed(int entity)
{
	if (entity > 0 && entity <= MAX_EDICTS)
		g_bOutputHooked[entity] = false;
}

Action Timer_HookNewEntity(Handle timer, DataPack pack)
{
	pack.Reset();
	int entity = EntRefToEntIndex(pack.ReadCell());

	if (entity != INVALID_ENT_REFERENCE && IsValidEntity(entity) && IsTankHittable(entity))
	{
		HookHittableOutput(entity);
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
	g_fDefaultSpeedMultiplier = hDefaultSpeedMultiplier.FloatValue;
	g_fDefaultVerticalMultiplier = hDefaultVerticalMultiplier.FloatValue;
	g_fLightweightSpeedMultiplier = hLightweightSpeedMultiplier.FloatValue;
	g_fLightweightVerticalMultiplier = hLightweightVerticalMultiplier.FloatValue;
	g_fCarSpeedMultiplier = hCarSpeedMultiplier.FloatValue;
	g_fCarVerticalMultiplier = hCarVerticalMultiplier.FloatValue;
	g_fDumpsterSpeedMultiplier = hDumpsterSpeedMultiplier.FloatValue;
	g_fDumpsterVerticalMultiplier = hDumpsterVerticalMultiplier.FloatValue;
	g_bTickrateCompensate = hTickrateCompensate.BoolValue;
	g_fTickrateRef = hTickrateRef.FloatValue;
	g_fTickrateCompensatePower = hTickrateCompensatePower.FloatValue;
	g_fPostPunchTime = hPostPunchTime.FloatValue;
	g_fBounceRetain = hBounceRetain.FloatValue;
	g_fFollowAngularDamp = hFollowAngularDamp.FloatValue;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 0; i <= MAX_EDICTS; i++)
		g_bOutputHooked[i] = false;

	StopFollowTimer();
	g_PunchFollows.Clear();

	CreateTimer(0.2, HookHittables);
}

Action HookHittables(Handle timer)
{
	if (!g_bStabilizationEnabled)
		return Plugin_Stop;

	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "prop_physics")) != -1)
	{
		if (IsTankHittable(entity))
			HookHittableOutput(entity);
	}

	entity = -1;
	while ((entity = FindEntityByClassname(entity, "prop_car_alarm")) != -1)
	{
		HookHittableOutput(entity);
	}

	return Plugin_Stop;
}

void HookHittableOutput(int entity)
{
	if (entity <= 0 || entity > MAX_EDICTS)
		return;

	if (g_bOutputHooked[entity])
		return;

	HookSingleEntityOutput(entity, "OnHitByTank", OnHittablePunched, false);
	g_bOutputHooked[entity] = true;

	if (g_bDebug)
	{
		PrintToServer("[HittableStabilization] Hooked hittable entity %d", entity);
	}
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

	DataPack pack;
	CreateDataTimer(g_fStabilizationDelay, StabilizeHittable, pack);
	pack.WriteCell(GetClientUserId(activator));
	pack.WriteCell(EntIndexToEntRef(caller));

	if (g_bDebug)
	{
		PrintToServer("[HittableStabilization] Tank %d punched hittable %d", activator, caller);
	}
}

Action StabilizeHittable(Handle timer, DataPack pack)
{
	pack.Reset();
	int tank = GetClientOfUserId(pack.ReadCell());
	int hittable = EntRefToEntIndex(pack.ReadCell());

	if (tank <= 0 || !IsClientInGame(tank) || !IsTank(tank))
		return Plugin_Stop;

	if (hittable == INVALID_ENT_REFERENCE || !IsValidEntity(hittable))
		return Plugin_Stop;

	float tankAngles[3];
	GetClientEyeAngles(tank, tankAngles);

	float direction[3];
	GetAngleVectors(tankAngles, direction, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(direction, direction);

	float currentVelocity[3];
	GetEntPropVector(hittable, Prop_Data, "m_vecAbsVelocity", currentVelocity);

	float speed = GetVectorLength(currentVelocity);
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
		newVelocity[0] = direction[0] * speed;
		newVelocity[1] = direction[1] * speed;
		if (currentVelocity[2] > 0.0)
		{
			float horizontalSpeed = SquareRoot(newVelocity[0] * newVelocity[0] + newVelocity[1] * newVelocity[1]);
			float baseUpward = horizontalSpeed * 0.15 + 50.0;
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
		NormalizeVector(currentVelocity, newVelocity);
		newVelocity[0] *= speed;
		newVelocity[1] *= speed;
		newVelocity[2] = currentVelocity[2] * verticalMultiplier;
	}

	ApplyHittableVelocity(hittable, newVelocity);
	DampenAngularVelocity(hittable, g_fAngularVelocityDamping);
	StartPunchFollow(hittable, newVelocity);

	return Plugin_Stop;
}

void ApplyHittableVelocity(int hittable, const float velocity[3])
{
	SetEntPropVector(hittable, Prop_Data, "m_vecAbsVelocity", velocity);
	TeleportEntity(hittable, NULL_VECTOR, NULL_VECTOR, velocity);
}

void DampenAngularVelocity(int hittable, float factor)
{
	if (factor >= 1.0)
		return;

	float angularVelocity[3];
	GetEntPropVector(hittable, Prop_Data, "m_vecAngVelocity", angularVelocity);
	ScaleVector(angularVelocity, factor);
	SetEntPropVector(hittable, Prop_Data, "m_vecAngVelocity", angularVelocity);
}

void StartPunchFollow(int hittable, const float velocity[3])
{
	if (g_fPostPunchTime <= 0.0)
		return;

	int ref = EntIndexToEntRef(hittable);
	int index = FindFollowIndex(ref);
	if (index == -1)
	{
		index = g_PunchFollows.Length;
		PunchFollow blank;
		g_PunchFollows.PushArray(blank);
	}

	PunchFollow follow;
	follow.ref = ref;
	follow.until = GetGameTime() + g_fPostPunchTime;
	follow.lastVel[0] = velocity[0];
	follow.lastVel[1] = velocity[1];
	follow.lastVel[2] = velocity[2];
	g_PunchFollows.SetArray(index, follow);

	if (g_hFollowTimer == null)
		g_hFollowTimer = CreateTimer(FOLLOW_INTERVAL, Timer_PunchFollow, _, TIMER_REPEAT);
}

int FindFollowIndex(int ref)
{
	PunchFollow follow;
	int length = g_PunchFollows.Length;
	for (int i = 0; i < length; i++)
	{
		g_PunchFollows.GetArray(i, follow);
		if (follow.ref == ref)
			return i;
	}
	return -1;
}

Action Timer_PunchFollow(Handle timer)
{
	if (g_PunchFollows.Length == 0)
	{
		g_hFollowTimer = null;
		return Plugin_Stop;
	}

	float now = GetGameTime();
	PunchFollow follow;
	for (int i = g_PunchFollows.Length - 1; i >= 0; i--)
	{
		g_PunchFollows.GetArray(i, follow);
		int hittable = EntRefToEntIndex(follow.ref);
		if (hittable == INVALID_ENT_REFERENCE || !IsValidEntity(hittable) || now >= follow.until)
		{
			g_PunchFollows.Erase(i);
			continue;
		}

		float velocity[3];
		GetEntPropVector(hittable, Prop_Data, "m_vecAbsVelocity", velocity);

		bool bounced = ScaleBounceVelocity(follow.lastVel, velocity);
		if (bounced)
			ApplyHittableVelocity(hittable, velocity);

		DampenAngularVelocity(hittable, g_fFollowAngularDamp);

		follow.lastVel[0] = velocity[0];
		follow.lastVel[1] = velocity[1];
		follow.lastVel[2] = velocity[2];
		g_PunchFollows.SetArray(i, follow);

		if (g_bDebug && bounced)
		{
			PrintToServer("[HittableStabilization] Bounce damped hittable %d retain=%.2f speed=%.2f",
				hittable, g_fBounceRetain, GetVectorLength(velocity));
		}
	}

	if (g_PunchFollows.Length == 0)
	{
		g_hFollowTimer = null;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

bool ScaleBounceVelocity(const float lastVel[3], float velocity[3])
{
	if (g_fBounceRetain >= 1.0)
		return false;

	float lastSpeed = GetVectorLength(lastVel);
	float curSpeed = GetVectorLength(velocity);
	if (lastSpeed < MIN_BOUNCE_SPEED && curSpeed < MIN_BOUNCE_SPEED)
		return false;

	bool bounced = false;

	float lastHoriz[3], curHoriz[3];
	lastHoriz[0] = lastVel[0];
	lastHoriz[1] = lastVel[1];
	curHoriz[0] = velocity[0];
	curHoriz[1] = velocity[1];
	float lastHorizSpeed = GetVectorLength(lastHoriz);
	float curHorizSpeed = GetVectorLength(curHoriz);
	if (lastHorizSpeed > MIN_BOUNCE_SPEED && curHorizSpeed > MIN_BOUNCE_SPEED)
	{
		NormalizeVector(lastHoriz, lastHoriz);
		NormalizeVector(curHoriz, curHoriz);
		if (GetVectorDotProduct(lastHoriz, curHoriz) < BOUNCE_DOT_THRESHOLD)
		{
			velocity[0] *= g_fBounceRetain;
			velocity[1] *= g_fBounceRetain;
			bounced = true;
		}
	}

	// Floor/ceiling hits often keep XY direction, so catch Z reversals separately.
	if (lastVel[2] < -40.0 && velocity[2] > 80.0)
	{
		velocity[2] *= g_fBounceRetain;
		bounced = true;
	}

	return bounced;
}

void StopFollowTimer()
{
	if (g_hFollowTimer != null)
	{
		delete g_hFollowTimer;
		g_hFollowTimer = null;
	}
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
			speedMultiplier = g_fDefaultSpeedMultiplier;
			verticalMultiplier = g_fDefaultVerticalMultiplier;
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

	if (StrContains(sModelName, "dumpster", false) != -1
	 || StrContains(sModelName, "trashcan", false) != -1)
		return HittableClass_Dumpster;

	if (IsLightweightModel(sModelName))
		return HittableClass_Lightweight;

	if (IsCarModel(sModelName))
		return HittableClass_Car;

	return HittableClass_Default;
}

bool IsCarModel(const char[] sModelName)
{
	if (StrContains(sModelName, "cara_", false) != -1
	 || StrContains(sModelName, "taxi_", false) != -1
	 || StrContains(sModelName, "police_car", false) != -1
	 || StrContains(sModelName, "utility_truck", false) != -1
	 || StrContains(sModelName, "ambulance", false) != -1
	 || StrContains(sModelName, "pickup", false) != -1
	 || StrContains(sModelName, "sedan", false) != -1
	 || StrEqual(sModelName, "models/props_vehicles/van.mdl", false)
	 || StrEqual(sModelName, "models/props_fairgrounds/bumpercar.mdl", false))
		return true;

	// Remaining vehicle props that are not already classified as lightweight.
	if (StrContains(sModelName, "models/props_vehicles/", false) != -1)
		return true;

	return false;
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
