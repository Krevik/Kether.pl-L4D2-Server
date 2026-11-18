#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0.0"
#define SAMPLE_INTERVAL 1.0
#define RETRY_INTERVAL 5.0
#define PROGRESS_INTERVAL 5.0
#define MIN_PROGRESS_DISTANCE 64.0
#define MIN_ROUTE_DISPLACEMENT 32.0
#define ROCK_THROW_GRACE 3.0
#define MAX_COMBAT_DEFERRAL 5.0
#define CANDIDATE_DIRECTIONS 16
#define CANDIDATE_RINGS 3
#define GROUND_SEARCH_HEIGHT 64.0
#define GROUND_SEARCH_DEPTH 128.0
#define GROUND_CLEARANCE 2.0
#define SUPPORT_DEPTH 18.0
#define MIN_GROUND_NORMAL 0.9
#define NAV_SEARCH_DISTANCE 64.0
#define MAX_LOCAL_PATH 1200.0
#define FIRE_CLEARANCE 256.0
#define VISIBILITY_HEIGHT 60.0
#define VISIBILITY_LOW_HEIGHT 8.0
#define VISIBILITY_LEVELS 3

ConVar g_cvEnabled;
ConVar g_cvDwellTime;
ConVar g_cvCampRadius;
ConVar g_cvIsolationDistance;
ConVar g_cvMinSeparation;
ConVar g_cvMaxSeparation;
ConVar g_cvCooldown;
ConVar g_cvMaxRecoveries;

bool g_bTracking[MAXPLAYERS + 1];
bool g_bSearchLogged[MAXPLAYERS + 1];
float g_fAnchor[MAXPLAYERS + 1][3];
float g_fDwellStart[MAXPLAYERS + 1];
float g_fNextAttempt[MAXPLAYERS + 1];
float g_fThrowUntil[MAXPLAYERS + 1];
float g_fProgressGoal[MAXPLAYERS + 1][MAXPLAYERS + 1][3];
float g_fProgressReference[MAXPLAYERS + 1][MAXPLAYERS + 1][3];
float g_fBestGoalDistance[MAXPLAYERS + 1][MAXPLAYERS + 1];
float g_fBestRouteDistance[MAXPLAYERS + 1][MAXPLAYERS + 1];
float g_fNextProgressCheck[MAXPLAYERS + 1];
int g_iProgressSurvivorUserId[MAXPLAYERS + 1][MAXPLAYERS + 1];
int g_iRecoveries[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "[L4D2] AI Tank Recovery",
	author = "Kether.pl",
	description = "Recovers isolated AI Tanks confined to a small area without pursuit progress.",
	version = PLUGIN_VERSION
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errorLength)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, errorLength, "This plugin requires Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_cvEnabled = CreateConVar("l4d2_ai_tank_recovery_enable", "1", "Enable isolated AI Tank recovery.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvDwellTime = CreateConVar("l4d2_ai_tank_recovery_dwell", "15", "Seconds confined without nearby survivors or meaningful pursuit progress.", FCVAR_NONE, true, 15.0);
	g_cvCampRadius = CreateConVar("l4d2_ai_tank_recovery_radius", "160", "Maximum distance from the observation anchor, in units.", FCVAR_NONE, true, 32.0, true, 400.0);
	g_cvIsolationDistance = CreateConVar("l4d2_ai_tank_recovery_isolation", "600", "Every living survivor must be at least this far away, in units.", FCVAR_NONE, true, 700.0);
	g_cvMinSeparation = CreateConVar("l4d2_ai_tank_recovery_min_distance", "300", "Minimum destination distance from every living survivor, in units.", FCVAR_NONE, true, 300.0, true, 600.0);
	g_cvMaxSeparation = CreateConVar("l4d2_ai_tank_recovery_max_distance", "600", "Maximum destination distance from the survivor being searched around, in units.", FCVAR_NONE, true, 300.0, true, 700.0);
	g_cvCooldown = CreateConVar("l4d2_ai_tank_recovery_cooldown", "60", "Minimum seconds between successful recoveries for a Tank.", FCVAR_NONE, true, 30.0);
	g_cvMaxRecoveries = CreateConVar("l4d2_ai_tank_recovery_limit", "2", "Maximum successful recoveries per Tank life; zero disables recovery.", FCVAR_NONE, true, 0.0, true, 10.0);
	AutoExecConfig(true, "l4d2_ai_tank_recovery");

	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_bot_replace", Event_TankReplacement);
	HookEvent("bot_player_replace", Event_TankReplacement);
	CreateTimer(SAMPLE_INTERVAL, Timer_CheckTanks, _, TIMER_REPEAT);
}

public void OnMapStart()
{
	ResetAllTanks();
}

public void OnClientDisconnect(int client)
{
	ResetTank(client);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ResetAllTanks();
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0)
		ResetTank(client);
}

public void L4D_OnCThrowActivate_Post(int ability)
{
	int owner = GetEntPropEnt(ability, Prop_Send, "m_owner");
	if (IsAITank(owner))
		g_fThrowUntil[owner] = GetGameTime() + ROCK_THROW_GRACE;
}

void Event_TankReplacement(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	int bot = GetClientOfUserId(event.GetInt("bot"));
	if (player == 0 || bot == 0)
		return;
	if (StrEqual(name, "player_bot_replace"))
		TransferRecoveryState(player, bot);
	else
		TransferRecoveryState(bot, player);
}

public void L4D_OnReplaceTank(int oldTank, int newTank)
{
	if (oldTank > 0 && oldTank <= MaxClients && newTank > 0 && newTank <= MaxClients && oldTank != newTank)
		TransferRecoveryState(oldTank, newTank);
}

void TransferRecoveryState(int oldTank, int newTank)
{
	g_bTracking[oldTank] = false;
	g_bTracking[newTank] = false;
	g_iRecoveries[newTank] = g_iRecoveries[oldTank];
	g_fNextAttempt[newTank] = g_fNextAttempt[oldTank];
	g_fThrowUntil[newTank] = g_fThrowUntil[oldTank];
}

Action Timer_CheckTanks(Handle timer)
{
	float currentTime = GetGameTime();
	for (int tank = 1; tank <= MaxClients; tank++)
	{
		if (!g_cvEnabled.BoolValue || !IsAITank(tank))
		{
			g_bTracking[tank] = false;
			continue;
		}
		if (g_iRecoveries[tank] >= g_cvMaxRecoveries.IntValue)
			continue;

		float tankPosition[3], survivorPosition[3];
		GetClientAbsOrigin(tank, tankPosition);
		int survivor = FindNearestSurvivor(tankPosition, survivorPosition);
		if (survivor == 0 || GetVectorDistance(tankPosition, survivorPosition) < g_cvIsolationDistance.FloatValue
			|| GetEntityMoveType(tank) != MOVETYPE_WALK || !(GetEntityFlags(tank) & FL_ONGROUND))
		{
			g_bTracking[tank] = false;
			continue;
		}

		if (!g_bTracking[tank] || GetVectorDistance(tankPosition, g_fAnchor[tank]) > g_cvCampRadius.FloatValue)
		{
			StartObservation(tank, tankPosition, currentTime);
			continue;
		}
		if (currentTime >= g_fNextProgressCheck[tank] && HasPursuitProgress(tank, tankPosition, currentTime))
		{
			// Keep the anchor and best distances; backtracking must not earn the same progress again.
			g_fDwellStart[tank] = currentTime;
			g_bSearchLogged[tank] = false;
			continue;
		}
		if (currentTime - g_fDwellStart[tank] < g_cvDwellTime.FloatValue || currentTime < g_fNextAttempt[tank])
			continue;
		// A stream of throws may delay recovery briefly, but cannot restart or indefinitely extend dwell.
		if (currentTime < g_fThrowUntil[tank]
			&& currentTime < g_fDwellStart[tank] + g_cvDwellTime.FloatValue + MAX_COMBAT_DEFERRAL)
			continue;

		g_fNextAttempt[tank] = currentTime + RETRY_INTERVAL;
		float destination[3];
		survivor = FindRecoverySurvivor(tank, tankPosition, destination);
		if (survivor == 0)
		{
			// Rate limit diagnostics as well as searches when no safe destination exists.
			if (!g_bSearchLogged[tank])
			{
				LogMessage("No valid recovery position for AI Tank %N near any living survivor; leaving Tank in place.", tank);
				g_bSearchLogged[tank] = true;
			}
			continue;
		}

		LogMessage("Recovering AI Tank %N near %N after %.1fs confined; frustration=%d, recovery=%d, from [%.0f %.0f %.0f] to [%.0f %.0f %.0f].",
			tank, survivor, currentTime - g_fDwellStart[tank], GetEntProp(tank, Prop_Send, "m_frustration"), g_iRecoveries[tank] + 1,
			tankPosition[0], tankPosition[1], tankPosition[2], destination[0], destination[1], destination[2]);
		float velocity[3];
		TeleportEntity(tank, destination, NULL_VECTOR, velocity);
		g_iRecoveries[tank]++;
		g_bTracking[tank] = false;
		g_fNextAttempt[tank] = currentTime + g_cvCooldown.FloatValue;
	}
	return Plugin_Continue;
}

void StartObservation(int tank, const float tankPosition[3], float currentTime)
{
	g_bTracking[tank] = true;
	g_bSearchLogged[tank] = false;
	g_fAnchor[tank] = tankPosition;
	g_fDwellStart[tank] = currentTime;
	for (int survivor = 1; survivor <= MaxClients; survivor++)
	{
		g_iProgressSurvivorUserId[tank][survivor] = 0;
		if (IsLivingSurvivor(survivor))
			StartSurvivorProgress(tank, survivor, tankPosition);
	}
	g_fNextProgressCheck[tank] = currentTime + PROGRESS_INTERVAL;
}

void StartSurvivorProgress(int tank, int survivor, const float tankPosition[3])
{
	float goal[3], routeStart[3];
	GetClientAbsOrigin(survivor, goal);
	routeStart = tankPosition;
	g_iProgressSurvivorUserId[tank][survivor] = GetClientUserId(survivor);
	// Each survivor has a fixed goal so their movement alone cannot earn progress.
	g_fProgressGoal[tank][survivor] = goal;
	g_fProgressReference[tank][survivor] = tankPosition;
	g_fBestGoalDistance[tank][survivor] = GetVectorDistance(tankPosition, goal);
	g_fBestRouteDistance[tank][survivor] = L4D2_NavAreaTravelDistance(routeStart, goal, false);
}

bool HasPursuitProgress(int tank, const float tankPosition[3], float currentTime)
{
	g_fNextProgressCheck[tank] = currentTime + PROGRESS_INTERVAL;
	bool progressed = false;
	for (int survivor = 1; survivor <= MaxClients; survivor++)
	{
		if (!IsLivingSurvivor(survivor))
		{
			g_iProgressSurvivorUserId[tank][survivor] = 0;
			continue;
		}
		if (g_iProgressSurvivorUserId[tank][survivor] != GetClientUserId(survivor))
		{
			StartSurvivorProgress(tank, survivor, tankPosition);
			continue;
		}

		float routeStart[3], goal[3], reference[3];
		routeStart = tankPosition;
		goal = g_fProgressGoal[tank][survivor];
		reference = g_fProgressReference[tank][survivor];
		float goalDistance = GetVectorDistance(tankPosition, goal);
		float routeDistance = L4D2_NavAreaTravelDistance(routeStart, goal, false);
		bool goalProgress = g_fBestGoalDistance[tank][survivor] - goalDistance >= MIN_PROGRESS_DISTANCE;
		bool routeProgress = false;
		if (routeDistance >= 0.0)
		{
			if (g_fBestRouteDistance[tank][survivor] < 0.0)
			{
				// First valid route establishes a baseline without changing dwell.
				g_fBestRouteDistance[tank][survivor] = routeDistance;
				g_fProgressReference[tank][survivor] = tankPosition;
			}
			else if (g_fBestRouteDistance[tank][survivor] - routeDistance >= MIN_PROGRESS_DISTANCE
				&& GetVectorDistance(tankPosition, reference) >= MIN_ROUTE_DISPLACEMENT)
			{
				// Re-query the reference under the same blockers: topology changes alone are not movement.
				float referenceRouteDistance = L4D2_NavAreaTravelDistance(reference, goal, false);
				routeProgress = referenceRouteDistance >= 0.0 && referenceRouteDistance - routeDistance >= MIN_PROGRESS_DISTANCE;
			}
		}
		if (!goalProgress && !routeProgress)
			continue;

		progressed = true;
		if (goalDistance < g_fBestGoalDistance[tank][survivor])
			g_fBestGoalDistance[tank][survivor] = goalDistance;
		if (routeDistance >= 0.0 && (g_fBestRouteDistance[tank][survivor] < 0.0 || routeDistance < g_fBestRouteDistance[tank][survivor]))
			g_fBestRouteDistance[tank][survivor] = routeDistance;
		g_fProgressReference[tank][survivor] = tankPosition;
	}
	return progressed;
}

int FindRecoverySurvivor(int tank, const float tankPosition[3], float destination[3])
{
	int survivors[MAXPLAYERS + 1];
	float distances[MAXPLAYERS + 1];
	int survivorCount = 0;
	for (int survivor = 1; survivor <= MaxClients; survivor++)
	{
		if (!IsLivingSurvivor(survivor))
			continue;
		float survivorPosition[3];
		GetClientAbsOrigin(survivor, survivorPosition);
		float distance = GetVectorDistance(tankPosition, survivorPosition, true);
		int insertIndex = survivorCount;
		while (insertIndex > 0 && distances[insertIndex - 1] > distance)
		{
			survivors[insertIndex] = survivors[insertIndex - 1];
			distances[insertIndex] = distances[insertIndex - 1];
			insertIndex--;
		}
		survivors[insertIndex] = survivor;
		distances[insertIndex] = distance;
		survivorCount++;
	}
	for (int index = 0; index < survivorCount; index++)
	{
		float survivorPosition[3];
		GetClientAbsOrigin(survivors[index], survivorPosition);
		if (FindRecoveryPosition(tank, survivorPosition, destination))
			return survivors[index];
	}
	return 0;
}

bool FindRecoveryPosition(int tank, const float survivorPosition[3], float destination[3])
{
	float minimumDistance = g_cvMinSeparation.FloatValue;
	float maximumDistance = g_cvMaxSeparation.FloatValue;
	if (maximumDistance < minimumDistance)
		return false;

	float hullMins[3], hullMaxs[3];
	GetEntPropVector(tank, Prop_Send, "m_vecMins", hullMins);
	GetEntPropVector(tank, Prop_Send, "m_vecMaxs", hullMaxs);
	float angleOffset = GetRandomFloat(0.0, 360.0);
	for (int ring = 0; ring < CANDIDATE_RINGS; ring++)
	{
		float distance = maximumDistance - (maximumDistance - minimumDistance) * float(ring) / float(CANDIDATE_RINGS - 1);
		for (int direction = 0; direction < CANDIDATE_DIRECTIONS; direction++)
		{
			float angle = DegToRad(angleOffset + float(direction) * 360.0 / float(CANDIDATE_DIRECTIONS));
			destination[0] = survivorPosition[0] + Cosine(angle) * distance;
			destination[1] = survivorPosition[1] + Sine(angle) * distance;
			destination[2] = survivorPosition[2];
			if (FindGround(destination, tank) && GetVectorDistance(destination, survivorPosition) <= maximumDistance
				&& IsDestinationClear(tank, destination, hullMins, hullMaxs)
				&& IsSeparatedAndHidden(destination) && HasLocalRoute(destination, survivorPosition)
				&& !IsNearHazard(destination))
				return true;
		}
	}
	return false;
}

bool FindGround(float position[3], int tank)
{
	float start[3], end[3];
	start = position;
	end = position;
	start[2] += GROUND_SEARCH_HEIGHT;
	end[2] -= GROUND_SEARCH_DEPTH;
	Handle trace = TR_TraceRayFilterEx(start, end, MASK_PLAYERSOLID, RayType_EndPoint, Trace_IgnoreTank, tank);
	float normal[3];
	TR_GetPlaneNormal(trace, normal);
	bool valid = TR_DidHit(trace) && !TR_StartSolid(trace) && TR_GetEntityIndex(trace) == 0 && normal[2] >= MIN_GROUND_NORMAL;
	if (valid)
	{
		TR_GetEndPosition(position, trace);
		position[2] += GROUND_CLEARANCE;
	}
	delete trace;
	return valid;
}

bool IsDestinationClear(int tank, const float position[3], const float hullMins[3], const float hullMaxs[3])
{
	float contentsPosition[3];
	contentsPosition = position;
	if (TR_PointOutsideWorld(contentsPosition) || (TR_GetPointContents(contentsPosition) & (CONTENTS_SOLID | CONTENTS_WATER | CONTENTS_SLIME)))
		return false;
	Handle trace = TR_TraceHullFilterEx(position, position, hullMins, hullMaxs, MASK_PLAYERSOLID, Trace_IgnoreTank, tank);
	bool clear = !TR_DidHit(trace) && !TR_StartSolid(trace) && !TR_AllSolid(trace);
	delete trace;
	if (!clear)
		return false;

	// Require world support under all four corners, rejecting ledges and movable platforms.
	for (int corner = 0; corner < 4; corner++)
	{
		float start[3], end[3], normal[3];
		start = position;
		start[0] += (corner & 1) ? hullMaxs[0] : hullMins[0];
		start[1] += (corner & 2) ? hullMaxs[1] : hullMins[1];
		end = start;
		end[2] -= SUPPORT_DEPTH;
		trace = TR_TraceRayFilterEx(start, end, MASK_PLAYERSOLID, RayType_EndPoint, Trace_IgnoreTank, tank);
		TR_GetPlaneNormal(trace, normal);
		clear = TR_DidHit(trace) && !TR_StartSolid(trace) && TR_GetEntityIndex(trace) == 0 && normal[2] >= MIN_GROUND_NORMAL;
		delete trace;
		if (!clear)
			return false;
	}
	return true;
}

bool IsSeparatedAndHidden(const float position[3])
{
	for (int survivor = 1; survivor <= MaxClients; survivor++)
	{
		if (!IsLivingSurvivor(survivor))
			continue;
		float survivorPosition[3], survivorEye[3];
		GetClientAbsOrigin(survivor, survivorPosition);
		if (GetVectorDistance(position, survivorPosition) < g_cvMinSeparation.FloatValue)
			return false;
		GetClientEyePosition(survivor, survivorEye);
		for (int level = 0; level < VISIBILITY_LEVELS; level++)
		{
			float sample[3];
			sample = position;
			sample[2] += VISIBILITY_LOW_HEIGHT + (VISIBILITY_HEIGHT - VISIBILITY_LOW_HEIGHT) * float(level) / float(VISIBILITY_LEVELS - 1);
			Handle trace = TR_TraceRayFilterEx(survivorEye, sample, MASK_VISIBLE, RayType_EndPoint, Trace_IgnorePlayers);
			bool visible = !TR_DidHit(trace);
			delete trace;
			if (visible)
				return false;
		}
	}
	return true;
}

bool HasLocalRoute(float position[3], const float survivorPosition[3])
{
	Address area = L4D_GetNearestNavArea(position, NAV_SEARCH_DISTANCE, false, true, true, L4D_TEAM_INFECTED);
	if (area == Address_Null || L4D_NavArea_IsBlocked(area, L4D_TEAM_INFECTED, false))
		return false;
	int unsafeFlags = NAV_BASE_CROUCH | NAV_BASE_JUMP | NAV_BASE_CLIFF | NAV_BASE_PLAYERCLIP | NAV_BASE_OUTSIDE_WORLD;
	int unsafeSpawnFlags = NAV_SPAWN_PLAYER_START | NAV_SPAWN_CHECKPOINT | NAV_SPAWN_RESCUE_VEHICLE | NAV_SPAWN_RESCUE_CLOSET;
	if ((L4D_GetNavArea_AttributeFlags(area) & unsafeFlags) || (L4D_GetNavArea_SpawnAttributes(area) & unsafeSpawnFlags))
		return false;
	float target[3];
	target = survivorPosition;
	float travelDistance = L4D2_NavAreaTravelDistance(position, target, false);
	return travelDistance >= 0.0 && travelDistance <= MAX_LOCAL_PATH;
}

bool IsNearHazard(const float position[3])
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "trigger_hurt")) != -1)
	{
		// Reject the expanded trigger bounds even when disabled; fail conservatively.
		float origin[3], mins[3], maxs[3], angles[3], forwardVector[3], rightVector[3], upVector[3], offset[3], localPosition[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", origin);
		GetEntPropVector(entity, Prop_Send, "m_vecMins", mins);
		GetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxs);
		GetEntPropVector(entity, Prop_Data, "m_angRotation", angles);
		GetAngleVectors(angles, forwardVector, rightVector, upVector);
		SubtractVectors(position, origin, offset);
		localPosition[0] = GetVectorDotProduct(offset, forwardVector);
		localPosition[1] = -GetVectorDotProduct(offset, rightVector);
		localPosition[2] = GetVectorDotProduct(offset, upVector);
		if (localPosition[0] >= mins[0] - FIRE_CLEARANCE && localPosition[0] <= maxs[0] + FIRE_CLEARANCE
			&& localPosition[1] >= mins[1] - FIRE_CLEARANCE && localPosition[1] <= maxs[1] + FIRE_CLEARANCE
			&& localPosition[2] >= mins[2] - FIRE_CLEARANCE && localPosition[2] <= maxs[2] + FIRE_CLEARANCE)
			return true;
	}
	entity = -1;
	while ((entity = FindEntityByClassname(entity, "inferno")) != -1)
	{
		float origin[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", origin);
		if (GetVectorDistance(position, origin) < FIRE_CLEARANCE)
			return true;
		int fireCount = GetEntProp(entity, Prop_Send, "m_fireCount");
		for (int fire = 0; fire < fireCount; fire++)
		{
			float flamePosition[3];
			flamePosition[0] = origin[0] + float(GetEntProp(entity, Prop_Send, "m_fireXDelta", _, fire));
			flamePosition[1] = origin[1] + float(GetEntProp(entity, Prop_Send, "m_fireYDelta", _, fire));
			flamePosition[2] = origin[2] + float(GetEntProp(entity, Prop_Send, "m_fireZDelta", _, fire));
			if (GetVectorDistance(position, flamePosition) < FIRE_CLEARANCE)
				return true;
		}
	}
	return false;
}

int FindNearestSurvivor(const float position[3], float nearestPosition[3])
{
	int nearest = 0;
	float nearestDistance = 0.0;
	for (int survivor = 1; survivor <= MaxClients; survivor++)
	{
		if (!IsLivingSurvivor(survivor))
			continue;
		float survivorPosition[3];
		GetClientAbsOrigin(survivor, survivorPosition);
		float distance = GetVectorDistance(position, survivorPosition, true);
		if (nearest == 0 || distance < nearestDistance)
		{
			nearest = survivor;
			nearestDistance = distance;
			nearestPosition = survivorPosition;
		}
	}
	return nearest;
}

bool IsLivingSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client)
		&& GetClientTeam(client) == L4D_TEAM_SURVIVOR && IsPlayerAlive(client);
}

bool IsAITank(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && IsFakeClient(client)
		&& GetClientTeam(client) == L4D_TEAM_INFECTED && IsPlayerAlive(client)
		&& GetEntProp(client, Prop_Send, "m_zombieClass") == L4D2_ZOMBIE_CLASS_TANK
		&& !GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isGhost");
}

bool Trace_IgnoreTank(int entity, int contentsMask, any tank)
{
	return entity != tank;
}

bool Trace_IgnorePlayers(int entity, int contentsMask)
{
	return entity == 0 || entity > MaxClients;
}

void ResetTank(int client)
{
	g_bTracking[client] = false;
	g_fNextAttempt[client] = 0.0;
	g_fThrowUntil[client] = 0.0;
	g_iRecoveries[client] = 0;
	// A survivor respawn or reused slot needs fresh records even between progress samples.
	for (int tank = 1; tank <= MaxClients; tank++)
		g_iProgressSurvivorUserId[tank][client] = 0;
}

void ResetAllTanks()
{
	for (int client = 1; client <= MaxClients; client++)
		ResetTank(client);
}
