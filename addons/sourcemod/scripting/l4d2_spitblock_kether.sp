#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define MAX_ENTITY_NAME_SIZE 64
#define MAX_MAP_NAME_SIZE 64

#define DMG_TYPE_SPIT (DMG_RADIATION|DMG_ENERGYBEAM)
#define PLUGIN_TAG "l4d2_spitblock_kether"
#define L4D2_ZOMBIE_CLASS_SPITTER 4

// Spit block area visualization (shown to infected)
#define SPITBLOCK_BEAM_LIFE     1.2
#define SPITBLOCK_BEAM_WIDTH    8.0

bool
	g_bIsBlockEnable = false;

float
	g_fBlockSquare[4] = {0.0, ...};

StringMap
	g_hSpitBlockSquares = null;

bool
	g_bLateLoad = false;

Handle
	g_hDrawTimer = null;

int
	g_iBeamSprite = 0;

ConVar
	g_cvShowAreas = null,
	g_cvShowToSpecs = null,
	g_cvShowToSurvivors = null,
	g_cvSpitterOnly = null,
	g_cvBoxZMin = null,
	g_cvBoxZMax = null,
	g_cvDrawInterval = null;

public Plugin myinfo =
{
	name = "L4D2 Spit Blocker (Kether)",
	author = "ProdigySim, Estoopi, Jacob, Visor, A1m`, Kether",
	description = "Blocks spit damage on various maps; shows blocked areas to infected players",
	version = "2.30.3",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hSpitBlockSquares = new StringMap();

	RegServerCmd("spit_block_square", AddSpitBlockSquare);
	RegServerCmd("spit_remove_block_square", RemoveSpitBlockSquare);

	g_cvShowAreas = CreateConVar("l4d2_spitblock_kether_show", "1", "Show spit-block areas to infected players (1 = yes, 0 = no).", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvShowToSpecs = CreateConVar("l4d2_spitblock_kether_specs", "1", "Also show spit-block areas to spectators (1 = yes, 0 = no).", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvShowToSurvivors = CreateConVar("l4d2_spitblock_kether_survivors", "0", "Also show spit-block areas to survivor players (1 = yes, 0 = no).", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvSpitterOnly = CreateConVar("l4d2_spitblock_kether_spitter_only", "0", "Show spit-block areas only to Spitter class (1 = spitter only, 0 = all infected).", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvBoxZMin = CreateConVar("l4d2_spitblock_kether_z_min", "-500.0", "Bottom Z of the drawn spit-block box (fixed, so the box does not slide).", FCVAR_NONE, true, -2000.0, true, 2000.0);
	g_cvBoxZMax = CreateConVar("l4d2_spitblock_kether_z_max", "2500.0", "Top Z of the drawn spit-block box (fixed, so the box does not slide).", FCVAR_NONE, true, -1000.0, true, 4000.0);
	g_cvDrawInterval = CreateConVar("l4d2_spitblock_kether_interval", "1.0", "Interval in seconds between redrawing the spit-block area to infected.", FCVAR_NONE, true, 0.2, true, 5.0);

	if (g_bLateLoad) {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i)) {
				OnClientPutInServer(i);
			}
		}
	}
}

Action AddSpitBlockSquare(int iArgs)
{
	float fSquare[4];
	char sMapName[MAX_MAP_NAME_SIZE], sBuffer[32], sGetCmd[128];

	if (iArgs != 5) {
		GetCmdArgString(sGetCmd, sizeof(sGetCmd));
		ErrorAnnounce("[%s] You entered the wrong number of arguments '%f'. Need 5 arguments.", PLUGIN_TAG, sGetCmd);
		ErrorAnnounce("[%s] Usage: spit_block_square <mapname> <x1> <y1> <x2> <y2>.", PLUGIN_TAG);
		return Plugin_Handled;
	}

	GetCmdArg(1, sMapName, sizeof(sMapName));

	for (int i = 0; i < 4; i++) {
		GetCmdArg(2 + i, sBuffer, sizeof(sBuffer));
		fSquare[i] = StringToFloat(sBuffer);
	}

	g_hSpitBlockSquares.SetArray(sMapName, fSquare, sizeof(fSquare), true);

	OnMapStart();

	return Plugin_Handled;
}

Action RemoveSpitBlockSquare(int iArgs)
{
	float fSquare[4];
	char sMapName[MAX_MAP_NAME_SIZE], sGetCmd[128];

	if (iArgs != 1) {
		GetCmdArgString(sGetCmd, sizeof(sGetCmd));
		ErrorAnnounce("[%s] You entered the wrong number of arguments '%f'. Need 1 argument.", PLUGIN_TAG, sGetCmd);
		ErrorAnnounce("[%s] Usage: spit_remove_block_square <mapname>.", PLUGIN_TAG);
		return Plugin_Handled;
	}

	GetCmdArg(1, sMapName, sizeof(sMapName));
	if (g_hSpitBlockSquares.GetArray(sMapName, fSquare, sizeof(fSquare))) {
		g_hSpitBlockSquares.Remove(sMapName);
		PrintToServer("[%s] Spit block square removed on this map '%s'.", PLUGIN_TAG, sMapName);
	} else {
		PrintToServer("[%s] Could not find the specified map '%s'.", PLUGIN_TAG, sMapName);
	}

	OnMapStart();

	return Plugin_Handled;
}

public void OnMapStart()
{
	char sMapName[MAX_MAP_NAME_SIZE];
	GetCurrentMap(sMapName, sizeof(sMapName));

	if (g_hDrawTimer != null) {
		delete g_hDrawTimer;
		g_hDrawTimer = null;
	}

	g_iBeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt", true);
	if (g_iBeamSprite == 0) {
		g_iBeamSprite = PrecacheModel("sprites/laser.vmt", true);
	}

	if (g_hSpitBlockSquares.GetArray(sMapName, g_fBlockSquare, sizeof(g_fBlockSquare))) {
		g_bIsBlockEnable = true;
		if (g_cvShowAreas != null && g_cvShowAreas.BoolValue) {
			float interval = g_cvDrawInterval.FloatValue;
			g_hDrawTimer = CreateTimer(interval, Timer_DrawSpitBlockAreas, _, TIMER_REPEAT);
		}
		return;
	}

	for (int i = 0; i < sizeof(g_fBlockSquare); i++) {
		g_fBlockSquare[i] = 0.0;
	}

	g_bIsBlockEnable = false;
}

public void OnMapEnd()
{
	if (g_hDrawTimer != null) {
		delete g_hDrawTimer;
		g_hDrawTimer = null;
	}
}

Action Timer_DrawSpitBlockAreas(Handle timer)
{
	if (!g_bIsBlockEnable || !g_cvShowAreas.BoolValue || g_iBeamSprite == 0) {
		return Plugin_Continue;
	}

	int recipients[MAXPLAYERS + 1];
	int n = 0;
	bool includeSpecs = (g_cvShowToSpecs != null && g_cvShowToSpecs.BoolValue);
	bool includeSurvivors = (g_cvShowToSurvivors != null && g_cvShowToSurvivors.BoolValue);
	bool spitterOnly = (g_cvSpitterOnly != null && g_cvSpitterOnly.BoolValue);

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i)) {
			continue;
		}
		int team = GetClientTeam(i);
		if (team == 3) {  // L4DTeam_Infected
			if (spitterOnly) {
				if (GetEntProp(i, Prop_Send, "m_zombieClass") == L4D2_ZOMBIE_CLASS_SPITTER) {
					recipients[n++] = i;
				}
			} else {
				recipients[n++] = i;
			}
		} else if (includeSpecs && team == 1) {  // Spectators
			recipients[n++] = i;
		} else if (includeSurvivors && team == 2) {  // Survivors
			recipients[n++] = i;
		}
	}
	if (n == 0) {
		return Plugin_Continue;
	}

	// Fixed Z range so the box is static and covers the whole elevator (no sliding)
	float zMin = g_cvBoxZMin.FloatValue;
	float zMax = g_cvBoxZMax.FloatValue;
	if (zMin > zMax) {
		float t = zMin;
		zMin = zMax;
		zMax = t;
	}

	float x1 = g_fBlockSquare[0], y1 = g_fBlockSquare[1];
	float x2 = g_fBlockSquare[2], y2 = g_fBlockSquare[3];
	float minX = (x1 < x2) ? x1 : x2;
	float maxX = (x1 > x2) ? x1 : x2;
	float minY = (y1 < y2) ? y1 : y2;
	float maxY = (y1 > y2) ? y1 : y2;

	float corners[8][3];
	// Bottom (z = zMin): 0 minX,minY  1 maxX,minY  2 maxX,maxY  3 minX,maxY
	corners[0][0] = minX; corners[0][1] = minY; corners[0][2] = zMin;
	corners[1][0] = maxX; corners[1][1] = minY; corners[1][2] = zMin;
	corners[2][0] = maxX; corners[2][1] = maxY; corners[2][2] = zMin;
	corners[3][0] = minX; corners[3][1] = maxY; corners[3][2] = zMin;
	// Top (z = zMax): 4..7
	corners[4][0] = minX; corners[4][1] = minY; corners[4][2] = zMax;
	corners[5][0] = maxX; corners[5][1] = minY; corners[5][2] = zMax;
	corners[6][0] = maxX; corners[6][1] = maxY; corners[6][2] = zMax;
	corners[7][0] = minX; corners[7][1] = maxY; corners[7][2] = zMax;

	int color[4] = { 255, 100, 0, 200 };  // Orange

	// Bottom rectangle
	for (int i = 0; i < 4; i++) {
		int j = (i == 3) ? 0 : i + 1;
		TE_SetupBeamPoints(corners[i], corners[j], g_iBeamSprite, 0, 0, 0, SPITBLOCK_BEAM_LIFE, SPITBLOCK_BEAM_WIDTH, SPITBLOCK_BEAM_WIDTH, 1, 0.0, color, 0);
		TE_Send(recipients, n, 0.0);
	}
	// Top rectangle
	for (int i = 4; i < 8; i++) {
		int j = (i == 7) ? 4 : i + 1;
		TE_SetupBeamPoints(corners[i], corners[j], g_iBeamSprite, 0, 0, 0, SPITBLOCK_BEAM_LIFE, SPITBLOCK_BEAM_WIDTH, SPITBLOCK_BEAM_WIDTH, 1, 0.0, color, 0);
		TE_Send(recipients, n, 0.0);
	}
	// Vertical edges
	for (int i = 0; i < 4; i++) {
		TE_SetupBeamPoints(corners[i], corners[i + 4], g_iBeamSprite, 0, 0, 0, SPITBLOCK_BEAM_LIFE, SPITBLOCK_BEAM_WIDTH, SPITBLOCK_BEAM_WIDTH, 1, 0.0, color, 0);
		TE_Send(recipients, n, 0.0);
	}

	return Plugin_Continue;
}

public void OnClientPutInServer(int iClient)
{
	SDKHook(iClient, SDKHook_OnTakeDamage, stop_spit_dmg);
}

Action stop_spit_dmg(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamageType)
{
	if (!g_bIsBlockEnable || !(iDamageType & DMG_TYPE_SPIT)) {
		return Plugin_Continue;
	}

	if (!IsInsectSwarm(iInflictor) || !IsValidClient(iVictim)) {
		return Plugin_Continue;
	}

	float fOrigin[3];
	GetClientAbsOrigin(iVictim, fOrigin);
	if (isPointIn2DBox(fOrigin[0], fOrigin[1], g_fBlockSquare[0], g_fBlockSquare[1], g_fBlockSquare[2], g_fBlockSquare[3])) {
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

bool isPointIn2DBox(float x0, float y0, float x1, float y1, float x2, float y2)
{
	if (x1 > x2) {
		if (y1 > y2) {
			return (x0 <= x1 && x0 >= x2 && y0 <= y1 && y0 >= y2);
		} else {
			return (x0 <= x1 && x0 >= x2 && y0 >= y1 && y0 <= y2);
		}
	} else {
		if (y1 > y2) {
			return (x0 >= x1 && x0 <= x2 && y0 <= y1 && y0 >= y2);
		} else {
			return (x0 >= x1 && x0 <= x2 && y0 >= y1 && y0 <= y2);
		}
	}
}

bool IsInsectSwarm(int iEntity)
{
	if (iEntity <= MaxClients || !IsValidEdict(iEntity)) {
		return false;
	}

	char sClassName[MAX_ENTITY_NAME_SIZE];
	GetEdictClassname(iEntity, sClassName, sizeof(sClassName));
	return (strcmp(sClassName, "insect_swarm") == 0);
}

bool IsValidClient(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients);
}

void ErrorAnnounce(const char[] szFormat, any ...)
{
	int iLen = strlen(szFormat) + 255;
	char[] szBuffer = new char[iLen];
	VFormat(szBuffer, iLen, szFormat, 2);

	LogError(szBuffer);
	PrintToServer(szBuffer);
}
