#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <dhooks>
#undef REQUIRE_PLUGIN
#include <l4d2_hittable_control>

#define Z_TANK			8
#define TEAM_INFECTED	3
#define TEAM_SPECTATOR	1
#define TEAM_SURVIVOR	2

#define MAX_EDICTS		2048 //(1 << 11)

ConVar
	g_hTankPropFade = null,
	g_hCvartankPropsGlow = null,
	g_hCvarRange = null,
	g_hCvarRangeMin = null,
	g_hCvarColor = null,
	g_hCvarTankOnly = null,
	g_hCvarTankSpec = null,
	g_hCvarTankPropsBeGone = null,
	g_hCvarSurvivorsGlow = null,
	g_hCvarSurvivorsColor = null,
	g_hCvarSurvivorsRange = null,
	g_hCvarSurvivorsRangeMin = null,
	g_hCvarTankFarRange = null,
	g_hCvarTankFarRangeMin = null,
	g_hCvarTankFarColor = null;

ArrayList
	g_hTankProps = null,
	g_hTankPropsHit = null,
	g_hDeadTankProps = null;

Handle
	g_hTimerSyncFarGlows = null,
	g_hTimerTankDeathCheck = null;

int
	g_iEntityList[MAX_EDICTS] = {-1, ...},
	g_iEntityListSurvivors[MAX_EDICTS] = {-1, ...},
	g_iEntityListFar[MAX_EDICTS] = {-1, ...},
	g_iTankClient = -1,
	g_iCvarRange = 0,
	g_iCvarRangeMin = 0,
	g_iCvarColor = 0,
	g_iCvarSurvivorsColor = 0,
	g_iCvarSurvivorsRange = 0,
	g_iCvarSurvivorsRangeMin = 0,
	g_iCvarTankFarRange = 0,
	g_iCvarTankFarRangeMin = 0,
	g_iCvarTankFarColor = 0;

bool
	g_bCvarTankOnly = false,
	g_bCvarTankSpec = false,
	g_bCvarSurvivorsGlow = false,
	g_bTankSpawned = false,
	g_bHittableControlExists = false;

public Plugin myinfo =
{
	name = "L4D2 Tank Hittable Glow (Kether)",
	author = "Harry Potter, Sir, A1m`, Derpduck",
	version = "2.6.0",
	description = "Stop tank props from fading whilst the tank is alive + add Hittable Glow."
};

public void OnPluginStart()
{
	g_hCvartankPropsGlow = CreateConVar("l4d_tank_props_glow", "1", "Show Hittable Glow for infected team while the tank is alive", FCVAR_NOTIFY);
	g_hCvarColor = CreateConVar("l4d2_tank_prop_glow_color", "255 255 255", "Prop Glow Color, three values between 0-255 separated by spaces. RGB Color255 - Red Green Blue.", FCVAR_NOTIFY);
	g_hCvarRange = CreateConVar("l4d2_tank_prop_glow_range", "4500", "How near to props do players need to be to enable their glow.", FCVAR_NOTIFY);
	g_hCvarRangeMin = CreateConVar("l4d2_tank_prop_glow_range_min", "256", "How near to props do players need to be to disable their glow.", FCVAR_NOTIFY);
	g_hCvarTankOnly = CreateConVar("l4d2_tank_prop_glow_only", "0", "Only Tank can see the glow", FCVAR_NOTIFY);
	g_hCvarTankSpec = CreateConVar("l4d2_tank_prop_glow_spectators", "1", "Spectators can see the glow too", FCVAR_NOTIFY);
	g_hCvarTankPropsBeGone = CreateConVar("l4d2_tank_prop_dissapear_time", "10.0", "Time it takes for hittables that were punched by Tank to dissapear after the Tank dies.", FCVAR_NOTIFY);
	g_hCvarSurvivorsGlow = CreateConVar("l4d2_tank_prop_glow_survivors", "1", "Show weak glow for survivors when tank is alive (does not penetrate walls)", FCVAR_NOTIFY);
	g_hCvarSurvivorsColor = CreateConVar("l4d2_tank_prop_glow_survivors_color", "80 80 80", "Survivor Glow Color (weaker), three values between 0-255 separated by spaces. RGB Color255 - Red Green Blue.", FCVAR_NOTIFY);
	g_hCvarSurvivorsRange = CreateConVar("l4d2_tank_prop_glow_survivors_range", "700", "Max distance for survivors to see hittable glow (weak, nearby only).", FCVAR_NOTIFY);
	g_hCvarSurvivorsRangeMin = CreateConVar("l4d2_tank_prop_glow_survivors_range_min", "0", "Min distance for survivors to see hittable glow (0 = no minimum).", FCVAR_NOTIFY);
	g_hCvarTankFarRange = CreateConVar("l4d2_tank_prop_glow_tank_far_range", "12000", "Max distance for tank to see weak glow on distant hittables.", FCVAR_NOTIFY);
	g_hCvarTankFarRangeMin = CreateConVar("l4d2_tank_prop_glow_tank_far_range_min", "0", "Min distance for tank far glow (0 = weak glow visible from any distance up to far_range).", FCVAR_NOTIFY);
	g_hCvarTankFarColor = CreateConVar("l4d2_tank_prop_glow_tank_far_color", "100 100 100", "Weak glow color for distant hittables (tank only). RGB 0-255.", FCVAR_NOTIFY);

	GetCvars();

	g_hTankPropFade = FindConVar("sv_tankpropfade");
	g_hCvartankPropsGlow.AddChangeHook(TankPropsGlowAllow);
	g_hCvarColor.AddChangeHook(ConVarChanged_Glow);
	g_hCvarRange.AddChangeHook(ConVarChanged_Range);
	g_hCvarRangeMin.AddChangeHook(ConVarChanged_RangeMin);
	g_hCvarTankOnly.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTankSpec.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarSurvivorsGlow.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarSurvivorsColor.AddChangeHook(ConVarChanged_SurvivorsGlow);
	g_hCvarSurvivorsRange.AddChangeHook(ConVarChanged_SurvivorsRange);
	g_hCvarSurvivorsRangeMin.AddChangeHook(ConVarChanged_SurvivorsRangeMin);
	g_hCvarTankFarRange.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTankFarRangeMin.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTankFarColor.AddChangeHook(ConVarChanged_Cvars);

	PluginEnable();
}

public void OnAllPluginsLoaded()
{
	g_bHittableControlExists = LibraryExists("l4d2_hittable_control");
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "l4d2_hittable_control", true)) {
		g_bHittableControlExists = false;
	}
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "l4d2_hittable_control", true)) {
		g_bHittableControlExists = true;
	}
}

void ConVarChanged_Cvars(ConVar hConvar, const char[] sOldValue, const char[] sNewValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bCvarTankOnly = g_hCvarTankOnly.BoolValue;
	g_bCvarTankSpec = g_hCvarTankSpec.BoolValue;
	g_bCvarSurvivorsGlow = g_hCvarSurvivorsGlow.BoolValue;
	g_iCvarRange = g_hCvarRange.IntValue;
	g_iCvarRangeMin = g_hCvarRangeMin.IntValue;
	g_iCvarSurvivorsRange = g_hCvarSurvivorsRange.IntValue;
	g_iCvarSurvivorsRangeMin = g_hCvarSurvivorsRangeMin.IntValue;
	g_iCvarTankFarRange = g_hCvarTankFarRange.IntValue;
	g_iCvarTankFarRangeMin = g_hCvarTankFarRangeMin.IntValue;

	char sColor[16];
	g_hCvarColor.GetString(sColor, sizeof(sColor));
	g_iCvarColor = GetColor(sColor);

	char sSurvivorsColor[16];
	g_hCvarSurvivorsColor.GetString(sSurvivorsColor, sizeof(sSurvivorsColor));
	g_iCvarSurvivorsColor = GetColor(sSurvivorsColor);

	char sTankFarColor[16];
	g_hCvarTankFarColor.GetString(sTankFarColor, sizeof(sTankFarColor));
	g_iCvarTankFarColor = GetColor(sTankFarColor);
}

void TankPropsGlowAllow(Handle hConVar, const char[] sOldValue, const char[] sNewValue)
{
	if (!g_hCvartankPropsGlow.BoolValue) {
		PluginDisable();
	} else {
		PluginEnable();
	}
}

void ConVarChanged_Glow(Handle hConVar, const char[] sOldValue, const char[] sNewValue)
{
	GetCvars();

	if (!g_bTankSpawned) {
		return;
	}

	int iRef = INVALID_ENT_REFERENCE, iValue = 0, iSize = g_hTankPropsHit.Length;
	for (int i = 0; i < iSize; i++) {
		iValue = g_hTankPropsHit.Get(i);

		if (iValue > 0 && IsValidEdict(iValue)) {
			iRef = g_iEntityList[iValue];

			if (IsValidEntRef(iRef)) {
				SetEntProp(iRef, Prop_Send, "m_iGlowType", 3);
				SetEntProp(iRef, Prop_Send, "m_glowColorOverride", g_iCvarColor);
			}
		}
	}
}

void ConVarChanged_Range(ConVar hConVar, const char[] sOldValue, const char[] sNewValue)
{
	GetCvars();

	if (!g_bTankSpawned) {
		return;
	}

	int iRef = INVALID_ENT_REFERENCE, iValue = -1, iSize = g_hTankPropsHit.Length;
	for (int i = 0; i < iSize; i++) {
		iValue = g_hTankPropsHit.Get(i);

		if (iValue > 0 && IsValidEdict(iValue)) {
			iRef = g_iEntityList[iValue];

			if (IsValidEntRef(iRef)) {
				SetEntProp(iRef, Prop_Send, "m_nGlowRange", g_iCvarRange);
			}
		}
	}
}

void ConVarChanged_RangeMin(ConVar hConVar, const char[] sOldValue, const char[] sNewValue)
{
	GetCvars();

	if (!g_bTankSpawned) {
		return;
	}

	int iRef = INVALID_ENT_REFERENCE, iValue = -1, iSize = g_hTankPropsHit.Length;
	for (int i = 0; i < iSize; i++) {
		iValue = g_hTankPropsHit.Get(i);

		if (iValue > 0 && IsValidEdict(iValue)) {
			iRef = g_iEntityList[iValue];

			if (IsValidEntRef(iRef)) {
				SetEntProp(iRef, Prop_Send, "m_nGlowRangeMin", g_iCvarRangeMin);
			}
		}
	}
}

void ConVarChanged_SurvivorsGlow(Handle hConVar, const char[] sOldValue, const char[] sNewValue)
{
	GetCvars();

	if (!g_bTankSpawned) {
		return;
	}

	int iRef = INVALID_ENT_REFERENCE, iValue = 0, iSize = g_hTankPropsHit.Length;
	for (int i = 0; i < iSize; i++) {
		iValue = g_hTankPropsHit.Get(i);

		if (iValue > 0 && IsValidEdict(iValue)) {
			iRef = g_iEntityListSurvivors[iValue];

			if (IsValidEntRef(iRef)) {
				SetEntProp(iRef, Prop_Send, "m_iGlowType", 2);
				SetEntProp(iRef, Prop_Send, "m_glowColorOverride", g_iCvarSurvivorsColor);
			}
		}
	}
}

void ConVarChanged_SurvivorsRange(ConVar hConVar, const char[] sOldValue, const char[] sNewValue)
{
	GetCvars();

	if (!g_bTankSpawned) {
		return;
	}

	int iRef = INVALID_ENT_REFERENCE, iValue = -1, iSize = g_hTankPropsHit.Length;
	for (int i = 0; i < iSize; i++) {
		iValue = g_hTankPropsHit.Get(i);

		if (iValue > 0 && IsValidEdict(iValue)) {
			iRef = g_iEntityListSurvivors[iValue];

			if (IsValidEntRef(iRef)) {
				SetEntProp(iRef, Prop_Send, "m_nGlowRange", g_iCvarSurvivorsRange);
			}
		}
	}
}

void ConVarChanged_SurvivorsRangeMin(ConVar hConVar, const char[] sOldValue, const char[] sNewValue)
{
	GetCvars();

	if (!g_bTankSpawned) {
		return;
	}

	int iRef = INVALID_ENT_REFERENCE, iValue = -1, iSize = g_hTankPropsHit.Length;
	for (int i = 0; i < iSize; i++) {
		iValue = g_hTankPropsHit.Get(i);

		if (iValue > 0 && IsValidEdict(iValue)) {
			iRef = g_iEntityListSurvivors[iValue];

			if (IsValidEntRef(iRef)) {
				SetEntProp(iRef, Prop_Send, "m_nGlowRangeMin", g_iCvarSurvivorsRangeMin);
			}
		}
	}
}

void PluginEnable()
{
	g_hTankPropFade.SetBool(false);

	g_hTankProps = new ArrayList();
	g_hTankPropsHit = new ArrayList();
	g_hDeadTankProps = new ArrayList();

	HookEvent("round_start", TankPropRoundReset, EventHookMode_PostNoCopy);
	HookEvent("round_end", TankPropRoundReset, EventHookMode_PostNoCopy);
	HookEvent("tank_spawn", TankPropTankSpawn, EventHookMode_PostNoCopy);
	HookEvent("tank_killed", TankPropTankKilledEvent, EventHookMode_PostNoCopy);
	HookEvent("player_death", TankPropTankKilled, EventHookMode_Post);

	char sColor[16];
	g_hCvarColor.GetString(sColor, sizeof(sColor));
	g_iCvarColor = GetColor(sColor);
	g_iCvarRange = g_hCvarRange.IntValue;
	g_iCvarRangeMin = g_hCvarRangeMin.IntValue;
	g_bCvarTankOnly = g_hCvarTankOnly.BoolValue;
	g_bCvarSurvivorsGlow = g_hCvarSurvivorsGlow.BoolValue;
	g_iCvarSurvivorsRange = g_hCvarSurvivorsRange.IntValue;
	g_iCvarSurvivorsRangeMin = g_hCvarSurvivorsRangeMin.IntValue;
	g_iCvarTankFarRange = g_hCvarTankFarRange.IntValue;
	g_iCvarTankFarRangeMin = g_hCvarTankFarRangeMin.IntValue;

	char sSurvivorsColor[16];
	g_hCvarSurvivorsColor.GetString(sSurvivorsColor, sizeof(sSurvivorsColor));
	g_iCvarSurvivorsColor = GetColor(sSurvivorsColor);

	char sTankFarColor[16];
	g_hCvarTankFarColor.GetString(sTankFarColor, sizeof(sTankFarColor));
	g_iCvarTankFarColor = GetColor(sTankFarColor);
}

void PluginDisable()
{
	g_hTankPropFade.SetBool(true);

	UnhookEvent("round_start", TankPropRoundReset, EventHookMode_PostNoCopy);
	UnhookEvent("round_end", TankPropRoundReset, EventHookMode_PostNoCopy);
	UnhookEvent("tank_spawn", TankPropTankSpawn, EventHookMode_PostNoCopy);
	UnhookEvent("tank_killed", TankPropTankKilledEvent, EventHookMode_PostNoCopy);
	UnhookEvent("player_death", TankPropTankKilled, EventHookMode_Post);

	if (!g_bTankSpawned) {
		return;
	}

	// Remove survivor glow and tank far glow for all props
	int iValue = 0, iSize = g_hTankProps.Length;
	for (int i = 0; i < iSize; i++) {
		iValue = g_hTankProps.Get(i);
		if (iValue > 0 && IsValidEdict(iValue)) {
			int iRef = g_iEntityListSurvivors[iValue];
			if (IsValidEntRef(iRef)) {
				RemoveEntity(EntRefToEntIndex(iRef));
				g_iEntityListSurvivors[iValue] = -1;
			}
			iRef = g_iEntityListFar[iValue];
			if (IsValidEntRef(iRef)) {
				RemoveEntity(EntRefToEntIndex(iRef));
				g_iEntityListFar[iValue] = -1;
			}
		}
	}

	// Remove infected glow for hit props
	iValue = 0;
	iSize = g_hTankPropsHit.Length;
	for (int i = 0; i < iSize; i++) {
		iValue = g_hTankPropsHit.Get(i);

		if (iValue > 0 && IsValidEdict(iValue)) {
			int iRef = g_iEntityList[iValue];

			if (IsValidEntRef(iRef)) {
				RemoveEntity(EntRefToEntIndex(iRef));
			}
		}
	}

	g_bTankSpawned = false;

	delete g_hTankProps;
	g_hTankProps = null;

	delete g_hTankPropsHit;
	g_hTankPropsHit = null;

	delete g_hDeadTankProps;
	g_hDeadTankProps = null;
}

public void OnMapEnd()
{
	DHookRemoveEntityListener(ListenType_Created, PossibleTankPropCreated);
	if (g_hTimerTankDeathCheck != null) {
		delete g_hTimerTankDeathCheck;
		g_hTimerTankDeathCheck = null;
	}

	g_hTankProps.Clear();
	g_hTankPropsHit.Clear();
	g_hDeadTankProps.Clear();
}

void TankPropRoundReset(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	DHookRemoveEntityListener(ListenType_Created, PossibleTankPropCreated);
	if (g_hTimerTankDeathCheck != null) {
		delete g_hTimerTankDeathCheck;
		g_hTimerTankDeathCheck = null;
	}

	g_bTankSpawned = false;

	UnhookTankProps();
	g_hTankPropsHit.Clear();
	g_hDeadTankProps.Clear();
	g_iTankClient = -1;
}

void TankPropTankSpawn(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (g_bTankSpawned) {
		return;
	}

	UnhookTankProps();
	g_hTankPropsHit.Clear();
	g_hDeadTankProps.Clear();
	if (g_hTimerTankDeathCheck != null) {
		delete g_hTimerTankDeathCheck;
		g_hTimerTankDeathCheck = null;
	}

	HookTankProps();

	DHookAddEntityListener(ListenType_Created, PossibleTankPropCreated);

	g_iTankClient = GetTankClient();
	g_bTankSpawned = true;
	if (g_hTimerSyncFarGlows != null) delete g_hTimerSyncFarGlows;
	g_hTimerSyncFarGlows = CreateTimer(0.1, Timer_SyncFarGlows, _, TIMER_REPEAT);
}

/* // error 203: symbol is never used: "PD_ev_EntityKilled"
void PD_ev_EntityKilled(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_bTankSpawned) {
		return;
	}

	int iClient = hEvent.GetInt("entindex_killed");

	if (IsValidAliveTank(iClient)) {
		CreateTimer(1.5, TankDeadCheck, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}
*/

void TankPropTankKilledEvent(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_bTankSpawned) {
		return;
	}

	RequestTankDeathCheck(0.1);
}

void TankPropTankKilled(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_bTankSpawned) {
		return;
	}

	int iVictim = GetClientOfUserId(hEvent.GetInt("userid"));
	// player_death fires when the victim is already dead, so IsTank() is unreliable here.
	if (iVictim > 0 && IsTankClass(iVictim)) {
		RequestTankDeathCheck(0.1);
		return;
	}

	RequestTankDeathCheck(0.5);
}

void RequestTankDeathCheck(float fDelay)
{
	if (g_hTimerTankDeathCheck != null) {
		return;
	}

	g_hTimerTankDeathCheck = CreateTimer(fDelay, TankDeadCheck, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action TankDeadCheck(Handle hTimer)
{
	g_hTimerTankDeathCheck = null;

	if (GetTankClient() == -1) {
		RemoveAllSurvivorGlows();
		RemoveAllFarGlows();
		QueueHitPropsForRemoval();
		UnhookTankProps(false);
		if (g_hTimerSyncFarGlows != null) { delete g_hTimerSyncFarGlows; g_hTimerSyncFarGlows = null; }
		CreateTimer(g_hCvarTankPropsBeGone.FloatValue, TankPropsBeGone, _, TIMER_FLAG_NO_MAPCHANGE);
		DHookRemoveEntityListener(ListenType_Created, PossibleTankPropCreated);
		g_bTankSpawned = false;
	}
	return Plugin_Stop;
}

Action TankPropsBeGone(Handle hTimer)
{
	RemoveQueuedDeadTankProps();

	return Plugin_Stop;
}

void QueueHitPropsForRemoval()
{
	int iValue = 0, iSize = g_hTankPropsHit.Length;
	for (int i = 0; i < iSize; i++) {
		iValue = g_hTankPropsHit.Get(i);
		if (iValue > 0 && IsValidEdict(iValue)) {
			int iRef = EntIndexToEntRef(iValue);
			if (g_hDeadTankProps.FindValue(iRef) == -1) {
				g_hDeadTankProps.Push(iRef);
			}
		}
	}
}

void RemoveQueuedDeadTankProps()
{
	int iRef = INVALID_ENT_REFERENCE, iEntity = -1, iSize = g_hDeadTankProps.Length;
	for (int i = 0; i < iSize; i++) {
		iRef = g_hDeadTankProps.Get(i);
		iEntity = EntRefToEntIndex(iRef);
		if (iEntity > MaxClients && iEntity != INVALID_ENT_REFERENCE && IsValidEdict(iEntity)) {
			RemoveEntity(iEntity);
		}
	}

	g_hDeadTankProps.Clear();
}

void PropDamaged(int iVictim, int iAttacker, int iInflictor, float fDamage, int iDamageType)
{
	if (IsValidAliveTank(iAttacker) || g_hTankPropsHit.FindValue(iInflictor) != -1) {
		//PrintToChatAll("tank hit %d", iVictim);

		if (g_hTankPropsHit.FindValue(iVictim) == -1) {
			g_hTankPropsHit.Push(iVictim);
			CreateTankPropGlow(iVictim);
		}
	}
}

void CreateTankPropGlow(int iTarget)
{
	// Spawn dynamic prop entity
	int iEntity = CreateEntityByName("prop_dynamic_override");
	if (iEntity == -1) {
		return;
	}

	// Get position of hittable
	float vOrigin[3];
	float vAngles[3];
	GetEntPropVector(iTarget, Prop_Send, "m_vecOrigin", vOrigin);
	GetEntPropVector(iTarget, Prop_Data, "m_angRotation", vAngles);

	// Get Client Model
	char sModelName[PLATFORM_MAX_PATH];
	GetEntPropString(iTarget, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

	// Set new fake model
	SetEntityModel(iEntity, sModelName);
	DispatchSpawn(iEntity);

	// Set outline glow color
	SetEntProp(iEntity, Prop_Send, "m_CollisionGroup", 0);
	SetEntProp(iEntity, Prop_Send, "m_nSolidType", 0);
	SetEntProp(iEntity, Prop_Send, "m_nGlowRange", g_iCvarRange);
	SetEntProp(iEntity, Prop_Send, "m_nGlowRangeMin", g_iCvarRangeMin);
	SetEntProp(iEntity, Prop_Send, "m_iGlowType", 2);
	SetEntProp(iEntity, Prop_Send, "m_glowColorOverride", g_iCvarColor);
	AcceptEntityInput(iEntity, "StartGlowing");

	// Set model invisible
	SetEntityRenderMode(iEntity, RENDER_NONE);
	SetEntityRenderColor(iEntity, 0, 0, 0, 0);

	// Set model to hittable position
	TeleportEntity(iEntity, vOrigin, vAngles, NULL_VECTOR);

	// Set model attach to client, and always synchronize
	SetVariantString("!activator");
	AcceptEntityInput(iEntity, "SetParent", iTarget);

	SDKHook(iEntity, SDKHook_SetTransmit, OnTransmit);
	g_iEntityList[iTarget] = EntIndexToEntRef(iEntity);

	// Create separate glow entity for survivors if enabled
	if (g_bCvarSurvivorsGlow) {
		CreateSurvivorPropGlow(iTarget);
	}
}

void CreateSurvivorPropGlow(int iTarget)
{
	// Check if glow already exists for this prop
	if (g_iEntityListSurvivors[iTarget] != -1 && IsValidEntRef(g_iEntityListSurvivors[iTarget])) {
		return;
	}

	// Spawn dynamic prop entity for survivors
	int iEntity = CreateEntityByName("prop_dynamic_override");
	if (iEntity == -1) {
		return;
	}

	// Get position of hittable
	float vOrigin[3];
	float vAngles[3];
	GetEntPropVector(iTarget, Prop_Send, "m_vecOrigin", vOrigin);
	GetEntPropVector(iTarget, Prop_Data, "m_angRotation", vAngles);

	// Get Client Model
	char sModelName[PLATFORM_MAX_PATH];
	GetEntPropString(iTarget, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

	// Set new fake model
	SetEntityModel(iEntity, sModelName);
	DispatchSpawn(iEntity);

	// Set outline glow color (weaker, same type as infected but with weaker color and range)
	SetEntProp(iEntity, Prop_Send, "m_CollisionGroup", 0);
	SetEntProp(iEntity, Prop_Send, "m_nSolidType", 0);
	SetEntProp(iEntity, Prop_Send, "m_nGlowRange", g_iCvarSurvivorsRange);
	SetEntProp(iEntity, Prop_Send, "m_nGlowRangeMin", g_iCvarSurvivorsRangeMin);
	SetEntProp(iEntity, Prop_Send, "m_iGlowType", 2); // Same type as infected
	SetEntProp(iEntity, Prop_Send, "m_glowColorOverride", g_iCvarSurvivorsColor);
	AcceptEntityInput(iEntity, "StartGlowing");

	// Set model invisible
	SetEntityRenderMode(iEntity, RENDER_NONE);
	SetEntityRenderColor(iEntity, 0, 0, 0, 0);

	// Set model to hittable position
	TeleportEntity(iEntity, vOrigin, vAngles, NULL_VECTOR);

	// Set model attach to client, and always synchronize
	SetVariantString("!activator");
	AcceptEntityInput(iEntity, "SetParent", iTarget);

	SDKHook(iEntity, SDKHook_SetTransmit, OnTransmitSurvivors);
	g_iEntityListSurvivors[iTarget] = EntIndexToEntRef(iEntity);
}

void CreateTankPropGlowFar(int iTarget)
{
	if (g_iEntityListFar[iTarget] != -1 && IsValidEntRef(g_iEntityListFar[iTarget])) {
		return;
	}

	int iEntity = CreateEntityByName("prop_dynamic_override");
	if (iEntity == -1) {
		return;
	}

	float vOrigin[3];
	float vAngles[3];
	GetEntPropVector(iTarget, Prop_Send, "m_vecOrigin", vOrigin);
	GetEntPropVector(iTarget, Prop_Data, "m_angRotation", vAngles);

	char sModelName[PLATFORM_MAX_PATH];
	GetEntPropString(iTarget, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

	SetEntityModel(iEntity, sModelName);
	DispatchSpawn(iEntity);

	// Weak glow for tank at distance – type 3 (Constant) so it can show from far / through walls
	SetEntProp(iEntity, Prop_Send, "m_CollisionGroup", 0);
	SetEntProp(iEntity, Prop_Send, "m_nSolidType", 0);
	SetEntProp(iEntity, Prop_Send, "m_nGlowRange", g_iCvarTankFarRange);
	SetEntProp(iEntity, Prop_Send, "m_nGlowRangeMin", g_iCvarTankFarRangeMin);
	SetEntProp(iEntity, Prop_Send, "m_iGlowType", 3);
	SetEntProp(iEntity, Prop_Send, "m_glowColorOverride", g_iCvarTankFarColor);
	AcceptEntityInput(iEntity, "StartGlowing");

	SetEntityRenderMode(iEntity, RENDER_NONE);
	SetEntityRenderColor(iEntity, 0, 0, 0, 0);

	TeleportEntity(iEntity, vOrigin, vAngles, NULL_VECTOR);

	SetVariantString("!activator");
	AcceptEntityInput(iEntity, "SetParent", iTarget);

	SDKHook(iEntity, SDKHook_SetTransmit, OnTransmitFar);
	g_iEntityListFar[iTarget] = EntIndexToEntRef(iEntity);
}

Action Timer_SyncFarGlows(Handle hTimer)
{
	if (!g_bTankSpawned || g_hTankProps == null) {
		g_hTimerSyncFarGlows = null;
		return Plugin_Stop;
	}
	int iValue, iRef, iSize = g_hTankProps.Length;
	float vOrigin[3], vAngles[3];
	for (int i = 0; i < iSize; i++) {
		iValue = g_hTankProps.Get(i);
		if (iValue <= 0 || !IsValidEntity(iValue)) continue;
		iRef = g_iEntityListFar[iValue];
		if (!IsValidEntRef(iRef)) continue;
		GetEntPropVector(iValue, Prop_Send, "m_vecOrigin", vOrigin);
		GetEntPropVector(iValue, Prop_Data, "m_angRotation", vAngles);
		TeleportEntity(EntRefToEntIndex(iRef), vOrigin, vAngles, NULL_VECTOR);
	}
	return Plugin_Continue;
}

Action OnTransmit(int iEntity, int iClient)
{
	if (!HasAliveTank()) {
		return Plugin_Handled;
	}

	switch (GetClientTeam(iClient)) {
		case TEAM_INFECTED: {
			if (IsTank(iClient)) {
				return Plugin_Continue;
			}

			return Plugin_Handled;
		}
		case TEAM_SPECTATOR: {
			return (g_bCvarTankSpec) ? Plugin_Continue : Plugin_Handled;
		}
	}

	return Plugin_Handled;
}

Action OnTransmitFar(int iEntity, int iClient)
{
	if (!HasAliveTank()) {
		return Plugin_Handled;
	}

	// Same visibility as main tank glow - tank only on infected, spectators optional
	switch (GetClientTeam(iClient)) {
		case TEAM_INFECTED: {
			if (IsTank(iClient)) {
				return Plugin_Continue;
			}
			return Plugin_Handled;
		}
		case TEAM_SPECTATOR: {
			return (g_bCvarTankSpec) ? Plugin_Continue : Plugin_Handled;
		}
	}
	return Plugin_Handled;
}

Action OnTransmitSurvivors(int iEntity, int iClient)
{
	if (!g_bCvarSurvivorsGlow || !HasAliveTank()) {
		return Plugin_Handled;
	}

	switch (GetClientTeam(iClient)) {
		case TEAM_SURVIVOR: {
			return Plugin_Continue;
		}
		case TEAM_SPECTATOR: {
			return (g_bCvarTankSpec) ? Plugin_Continue : Plugin_Handled;
		}
	}

	return Plugin_Handled;
}

bool IsTankProp(int iEntity)
{
	if (!IsValidEdict(iEntity)) {
		return false;
	}

	// CPhysicsProp only
	if (!HasEntProp(iEntity, Prop_Send, "m_hasTankGlow")) {
		return false;
	}

	bool bHasTankGlow = (GetEntProp(iEntity, Prop_Send, "m_hasTankGlow", 1) == 1);
	if (!bHasTankGlow) {
		return false;
	}

	// Exception
	bool bAreForkliftsUnbreakable;
	if (g_bHittableControlExists)
	{
		bAreForkliftsUnbreakable = AreForkliftsUnbreakable();
	}
	else
	{
		bAreForkliftsUnbreakable = false;
	}

	char sModel[PLATFORM_MAX_PATH];
	GetEntPropString(iEntity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	if (strcmp("models/props/cs_assault/forklift.mdl", sModel) == 0 && bAreForkliftsUnbreakable == false) {
		return false;
	}

	return true;
}

void HookTankProps()
{
	int iEntCount = GetMaxEntities();

	for (int i = MaxClients+1; i <= iEntCount; i++) {
		if (IsTankProp(i)) {
			SDKHook(i, SDKHook_OnTakeDamagePost, PropDamaged);
			g_hTankProps.Push(i);
			
			// Create glow for survivors for all hittable props when tank spawns
			if (g_bCvarSurvivorsGlow) {
				CreateSurvivorPropGlow(i);
			}
			// Create weak far glow for tank so he can see distant hittables
			CreateTankPropGlowFar(i);
		}
	}
}

void RemoveAllSurvivorGlows()
{
	int iValue = 0, iSize = g_hTankProps.Length;
	for (int i = 0; i < iSize; i++) {
		iValue = g_hTankProps.Get(i);
		if (iValue > 0 && IsValidEdict(iValue)) {
			int iRef = g_iEntityListSurvivors[iValue];
			if (IsValidEntRef(iRef)) {
				RemoveEntity(EntRefToEntIndex(iRef));
				g_iEntityListSurvivors[iValue] = -1;
			}
		}
	}
}

void RemoveAllFarGlows()
{
	int iValue = 0, iSize = g_hTankProps.Length;
	for (int i = 0; i < iSize; i++) {
		iValue = g_hTankProps.Get(i);
		if (iValue > 0 && IsValidEdict(iValue)) {
			int iRef = g_iEntityListFar[iValue];
			if (IsValidEntRef(iRef)) {
				RemoveEntity(EntRefToEntIndex(iRef));
				g_iEntityListFar[iValue] = -1;
			}
		}
	}
}

void UnhookTankProps(bool removeHitProps = true)
{
	if (g_hTimerSyncFarGlows != null) {
		delete g_hTimerSyncFarGlows;
		g_hTimerSyncFarGlows = null;
	}

	int iValue = 0, iSize = g_hTankProps.Length;

	for (int i = 0; i < iSize; i++) {
		iValue = g_hTankProps.Get(i);
		SDKUnhook(iValue, SDKHook_OnTakeDamagePost, PropDamaged);
		
		// Remove survivor glow for all props
		if (iValue > 0 && IsValidEdict(iValue)) {
			int iRef = g_iEntityListSurvivors[iValue];
			if (IsValidEntRef(iRef)) {
				RemoveEntity(EntRefToEntIndex(iRef));
				g_iEntityListSurvivors[iValue] = -1;
			}
			// Remove tank far glow
			iRef = g_iEntityListFar[iValue];
			if (IsValidEntRef(iRef)) {
				RemoveEntity(EntRefToEntIndex(iRef));
				g_iEntityListFar[iValue] = -1;
			}
		}
	}

	iValue = 0;
	iSize = g_hTankPropsHit.Length;

	if (removeHitProps) {
		for (int i = 0; i < iSize; i++) {
			iValue = g_hTankPropsHit.Get(i);

			if (iValue > 0 && IsValidEdict(iValue)) {
				int iRef = g_iEntityList[iValue];
				if (IsValidEntRef(iRef)) {
					RemoveEntity(EntRefToEntIndex(iRef));
				}
				// Keep original plugin behavior: remove the hittable itself after tank death.
				RemoveEntity(iValue);
				//PrintToChatAll("remove %d", iValue);
			}
		}
	}

	g_hTankProps.Clear();
	g_hTankPropsHit.Clear();
}

//analogue public void OnEntityCreated(int iEntity, const char[] sClassName)
void PossibleTankPropCreated(int iEntity, const char[] sClassName)
{
	if (sClassName[0] != 'p') {
		return;
	}

	if (strcmp(sClassName, "prop_physics") != 0) { // Hooks c11m4_terminal World Sphere
		return;
	}

	// Use SpawnPost to just push it into the Array right away.
	// These entities get spawned after the Tank has punched them, so doing anything here will not work smoothly.
	SDKHook(iEntity, SDKHook_SpawnPost, Hook_PropSpawned);
}

void Hook_PropSpawned(int iEntity)
{
	if (iEntity <= MaxClients || !IsValidEntity(iEntity)) {
		return;
	}

	if (g_hTankProps.FindValue(iEntity) == -1) {
		char sModelName[PLATFORM_MAX_PATH];
		GetEntPropString(iEntity, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

		if (StrContains(sModelName, "atlas_break_ball") != -1 || StrContains(sModelName, "forklift_brokenlift.mdl") != -1) {
			g_hTankProps.Push(iEntity);
			g_hTankPropsHit.Push(iEntity);
			CreateTankPropGlow(iEntity);
			CreateTankPropGlowFar(iEntity);
		} else if (StrContains(sModelName, "forklift_brokenfork.mdl") != -1) {
			RemoveEntity(iEntity);
		}
	}
}

bool IsValidEntRef(int iRef)
{
	return (iRef > 0 && EntRefToEntIndex(iRef) != INVALID_ENT_REFERENCE);
}

int GetColor(char[] sTemp)
{
	if (strcmp(sTemp, "") == 0) {
		return 0;
	}

	char sColors[3][4];
	int iColor = ExplodeString(sTemp, " ", sColors, 3, 4);

	if (iColor != 3) {
		return 0;
	}

	iColor = StringToInt(sColors[0]);
	iColor += 256 * StringToInt(sColors[1]);
	iColor += 65536 * StringToInt(sColors[2]);

	return iColor;
}

int GetTankClient()
{
	if (g_iTankClient == -1 || !IsValidAliveTank(g_iTankClient)) {
		g_iTankClient = FindTank();
	}

	return g_iTankClient;
}

int FindTank()
{
	for (int i = 1; i <= MaxClients; i++) {
		if (IsAliveTank(i)) {
			return i;
		}
	}

	return -1;
}

bool IsValidAliveTank(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients && IsAliveTank(iClient));
}

bool IsAliveTank(int iClient)
{
	return (IsClientInGame(iClient) && GetClientTeam(iClient) == TEAM_INFECTED && IsTank(iClient));
}

bool IsTank(int iClient)
{
	return (GetEntProp(iClient, Prop_Send, "m_zombieClass") == Z_TANK && IsPlayerAlive(iClient));
}

bool IsTankClass(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient) && GetClientTeam(iClient) == TEAM_INFECTED && GetEntProp(iClient, Prop_Send, "m_zombieClass") == Z_TANK);
}

bool HasAliveTank()
{
	return (GetTankClient() != -1);
}

