/*
*	Neon Beams
*	Copyright (C) 2021 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/



#define PLUGIN_VERSION 		"1.13"

/*=======================================================================================
	Plugin Info:

*	Name	:	[ANY] Neon Beams
*	Author	:	SilverShot
*	Descrp	:	Spawn and save Neon Beams to the map.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=318209
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.13 (30-Jun-2021)
	- Fixed late loading particles counting toward total spawned and blocking them. Thanks to "Tonblader" for reporting.
	- Fixed plugin not waiting for all clients to load before spawning after server start or a new map.
	- Hopefully loading beams and late loading beams to clients still works for all games.

1.12 (10-Apr-2021)
	- L4D2: Fixed a particle from version 1.8 update not working. Thanks to "Marttt" for reporting and fixing.

1.11 (02-Apr-2021)
	- Fixed presets using temporary beams not displaying to other players. Thanks to "Tonblader" for reporting.

1.10 (01-Apr-2021)
	- Added commands "sm_neon_preset_eye" and "sm_neon_preset_eyes" to spawn presets from your eye position.
	- Commands also allow setting how far from the eyes they are placed. Requested by "Tonblader".

1.9 (29-Mar-2021)
	- Added commands "sm_neon_point", "sm_neon_points", "sm_neon_point2", "sm_neon_points2" to place beams from your eye position.
	- Commands also allow setting how far from the eyes they are placed. Requested by "Tonblader".

1.8 (26-Feb-2021)
	- Added 28 new particles in L4D2. Thanks to "Marttt" for adding and scripting.
		@ Notes:
			- Lights Moving particles don't kill the entity. 
			- Resource expensive. Doesn't kill the entity and refreshes the particle very often.

	- Fixed invalid client errors when late loading beams. Thanks to "Tonblader" for reporting.

1.7 (30-Sep-2020)
	- Fixed compile errors on SM 1.11.

1.6 (10-May-2020)
	- Removed Listen server block.
	- Various changes to tidy up code.
	- Various optimizations and fixes.

1.5 (20-Jan-2020)
	- Fixed "sm_neon_delpre" not deleting a preset filename from the menu when it has no presets and the file was deleted.
	- Various changes to warn and prevent using spaces in preset filenames and preset names.
	- Menus will display spaces for ease of readability.
	- Thanks to "Apeboy21" for reporting the issue.

1.4 (17-Jan-2020)
	- Fixed Invalid timer handle errors. Thanks to "AK978" for reporting.

1.3 (10-Jan-2020)
	- Fixed "Spawning Blocked" error not resetting on map change, except on config error. Thanks to "Marttt" for reporting.
	- Added "Silvers.cfg" and "Checkpoint_Arrows.cfg" preset configs to "neon_beams.zip".

1.2 (27-Aug-2019)
	- Fixed "Spawning Blocked" error when beams are time limited and not permanent. They are simply not counted.

1.1 (22-Aug-2019)
	- Added command "sm_neon_wipe" to delete all beams and presets saved to the current maps config.

1.0 (20-Aug-2019)
	- Initial release.
	- Originally created on 02-Jan-2012.

========================================================================================

	This plugin was made using source code from the following plugins.

*	Thanks to "Boikinov" for "[L4D] Left FORT Dead builder" - 3 functions for rotation.
	https://forums.alliedmods.net/showthread.php?t=93716

======================================================================================*/



#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
// #include <neon_beams>



// =======================================================================================
//					PLUGIN DEFINES
// =======================================================================================
#define CVAR_FLAGS			FCVAR_NOTIFY
#define MAX_ENTITIES		2048		// Max ents, for particles.
#define MAX_RESERVED		50			// Maximum reserved particles, for possible future expansions.
#define MAX_PART_L4D2		37			// Max inbuilt L4D2 particles.
#define MAX_PARTICLES		10			// Max custom particles for all games
#define INT_PRE_START		2			// Preset data starting index. 0=Name. 1=File.
#define LEN_VBIG			192			// Max string length to store data etc.
#define LEN_FULL			128			// Max string length to store data etc.
#define LEN_HALF			64			// Max string length for names etc.
#define CHAT_TAG			"\x05[Neon Beams] \x01"
#define PATH_PCF			"particles/neon_beams.pcf"
#define PATH_MAT1			"materials/particle/particle_glow_05.vtf"
#define PATH_MAT2			"materials/particle/particle_glow_05_add_5ob.vmt"
#define PATH_MAT3			"materials/particle/string_light_beam.vmt"
#define PATH_MAT4			"materials/particle/string_light_beam.vtf"
#define CONFIG_FOLDER		"data/neon"
#define CONFIG_PATH_M		"maps"
#define CONFIG_PATH_P		"presets"
#define CONFIG_PRESET		"-Default"
#define CONFIG_MENU			"menu.cfg"


ConVar g_hCvarAllow, g_hCvarCfgLoad, g_hCvarCfgMax, g_hCvarCfgRound, g_hCvarCfgTime, g_hCvarDist, g_hCvarLate, g_hCvarMaxBeam, g_hCvarMaxPart, g_hCvarPaint, g_hCvarOpac, g_hCvarSize, g_hCvarSprite, g_hCvarHalo;
bool g_bCvarAllow;
int g_iCvarCfgRound, g_iCvarCfgMax, g_iCvarLate, g_iCvarOpac, g_iCvarMaxB, g_iCvarMaxP;
float g_fCvarCfgLoad, g_fCvarCfgTime, g_fCvarDist, g_fCvarPaint, g_fCvarSize;
char g_sCvarSprite[64], g_sCvarHalo[64];
Menu g_hMenuMain, g_hMenuPaint, g_hMenuMapSpawn, g_hMenuPreSpawn, g_hMenuPaint2, g_hMenuMapSpawn2, g_hMenuPreSpawn2, g_hMenuPresetList;

Menu g_hClientPreMenu[MAXPLAYERS+1];						// Menu handle for each clients selected preset list
char g_sPresetConfig[MAXPLAYERS+1][LEN_HALF];				// Selected preset for creation/deletion/editing
Handle g_hPaintTimer[MAXPLAYERS+1];							// Painting timer
float g_vPresetStart[MAXPLAYERS+1][3];						// Preset start origin for relative pos
float g_vTargetPos[MAXPLAYERS+1][3];						// Stores first point for spawning beam lines
float g_fDistance[MAXPLAYERS+1];							// Range to spawn from eye position (sm_neon_point commands)
int g_iStretched[MAXPLAYERS+1];								// Stretch message hint
int g_iSaveIndex[MAXPLAYERS+1];								// Color type to paint/save
int g_iSaveOrTemp[MAXPLAYERS+1];							// Current user action: 0=Temp Map. 1=Save Map. 2=Save Preset. 3=Temp Preset (required?). 4=Temp Particle. 5=Save Particle. 6=Save Particle Preset. 7=Temp Particle Preset
bool g_bLateLoaded[MAXPLAYERS+1];							// Has client loaded map data
bool g_bLoadingLate[MAXPLAYERS+1];							// Is the client currently late loading, to avoid displaying particles to others
int g_iLoadCount[MAXPLAYERS+1];								// Keep within g_iCvarCfgMax
int g_iLoadIndex[MAXPLAYERS+1];								// Map index they are loading from
int g_iLoadPreset[MAXPLAYERS+1] = {INT_PRE_START,...};		// Preset index they are loading from
int g_iLoopCount, g_iLateLoad, g_iRoundStart, g_iBlocked, g_iTotalBeam, g_iTotalPart, g_Sprite, g_Halo;
bool g_bLoaded; bool g_bRoundRestart; char g_sPreLoadPath[LEN_HALF];
int g_iAccessParticles;

EngineVersion g_Engine;
Handle g_hTimerLoad;
float g_fLoadTick;
float g_fLoadTime;

ArrayList g_hPresetList;
ArrayList g_hMapList;

enum
{
	ACTION_MAP_TEMP		= 0,		// Temp beam
	ACTION_MAP_SAVE		= 1,		// Save beam to map
	ACTION_PRE_SAVE		= 2,		// Save preset to map
	ACTION_PRE_TEMP		= 3,		// Temp preset
	ACTION_PRE_CONF		= 4,		// Creating preset
	ACTION_PAINTING		= 5,		// Paint beam
	ACTION_MAP_TEMP2	= 6,		// Temp particle
	ACTION_MAP_SAVE2	= 7,		// Save particle to map
	ACTION_PRE_CONF2	= 8,		// Creating preset
	ACTION_PAINTING2	= 9,		// Paint particle
	ACTION_MAP_POINT	= 10,		// Eye position beam
	ACTION_MAP_POINT2	= 11,		// Eye position particle
	ACTION_MAP_POINTS	= 12,		// Eye position beam save
	ACTION_MAP_POINTS2	= 13,		// Eye position particle save
	ACTION_EYE_POINT	= 14,		// Eye position preset temp
	ACTION_EYE_POINTS	= 15		// Eye position preset save
}

static const char g_sParticles_L4D2[MAX_PART_L4D2][] =
{
	"string_lights_01",						// Red
	"string_lights_04",						// Blue
	"string_lights_05",						// Green
	"string_lights_02",						// Purple
	"string_lights_03",						// Multi
	"string_lights_06",						// Gold
	"string_lights_06_cheap",				// Gold (Cheap)
	"string_lights_heart_01",				// Red Curved
	"string_lights_heart_02",				// Pink Curved
	"string_lights_06_droopy",				// Gold Curved 1
	"string_lights_06_droopy_2",			// Gold Curved 2
	"string_lights_01_glow",				// Red (Fading Glow)
	"string_lights_04_glow",				// Blue (Glow)
	"string_lights_05_glow",				// Green (Glow)
	"string_lights_02_glow",				// Purple (Fading Glow)
	"string_lights_03_glow",				// Multi (Glow)
	"string_lights_06_glow",				// Gold (Glow)
	"string_lights_06_glow_cheap",			// Gold (Glow Cheap)
	"string_lights_heart_01_glow",			// Red Curved (Glow)
	"string_lights_heart_02_glow",			// Pink Curved (Glow)
	"string_lights_06_glow_droopy",			// Gold Curved 1 (Glow)
	"string_lights_06_glow_droopy_2",		// Gold Curved 2 (Glow)
	"lights_moving_straight_bounce_4",		// Lights Moving Straight Fast (Bounce)
	"lights_moving_straight_bounce_4_b",	// Lights Moving Straight Slow (Bounce)
	"lights_moving_straight_loop_4",		// Lights Moving Straight Fast (Loop)
	"lights_moving_straight_loop_4_b",		// Lights Moving Straight Slow (Loop)
	"lights_moving_curved_bounce_4",		// Lights Moving Curved Fast (Bounce)
	"lights_moving_curved_bounce_4_b",		// Lights Moving Curved Slow (Bounce)
	"lights_moving_curved_loop_4",			// Lights Moving Curved Fast (Loop)
	"lights_moving_curved_loop_4_b",		// Lights Moving Curved Slow (Loop)
	"string_lights_off",					// String Off
	"smoker_tongue",						// Smoker Tongue
	"flag_banner_01",						// Flag Banner
	"balloon_string",						// Balloon String
	"electrical_arc_01",					// Electrical Arc (expensive)
	"storm_lightning_02_thin",				// Storm Lightning Thin (expensive)
	"weapon_tracers_incendiary_smoke"		// Incendiary Smoke (expensive)
};
static const char g_sPartNames_L4D2[MAX_PART_L4D2][] =
{
	"Red",
	"Blue",
	"Green",
	"Purple",
	"Multi",
	"Gold",
	"Gold (Cheap)",
	"Red Curved",
	"Pink Curved",
	"Gold Curved 1",
	"Gold Curved 2",
	"Red (Fading Glow)",
	"Blue (Glow)",
	"Green (Glow)",
	"Purple (Fading Glow)",
	"Multi (Glow)",
	"Gold (Glow)",
	"Gold (Glow Cheap)",
	"Red Curved (Glow)",
	"Pink Curved (Glow)",
	"Gold Curved 1 (Glow)",
	"Gold Curved 2 (Glow)",
	"Lights Moving Straight Fast (Bounce)",
	"Lights Moving Straight Slow (Bounce)",
	"Lights Moving Straight Fast (Loop)",
	"Lights Moving Straight Slow (Loop)",
	"Lights Moving Curved Fast (Bounce)",
	"Lights Moving Curved Slow (Bounce)",
	"Lights Moving Curved Fast (Loop)",
	"Lights Moving Curved Slow (Loop)",
	"String Off",
	"Smoker Tongue",
	"Flag Banner",
	"Balloon String",
	"Electrical Arc (expensive)",
	"Storm Lightning Thin (expensive)",
	"Incendiary Smoke (expensive)"
};
static const char g_sParticles[MAX_PARTICLES][] =
{
	"silvershot_string_lights_01",
	"silvershot_string_lights_02",
	"silvershot_string_lights_03",
	"silvershot_string_lights_04",
	"silvershot_string_lights_05",
	"silvershot_string_lights_06",
	"silvershot_string_lights_07",
	"silvershot_string_lights_08",
	"silvershot_string_lights_09",
	"silvershot_string_lights_10"
};
static const char g_sPartNames[MAX_PARTICLES][] =
{
	"Red",
	"Orange",
	"Yellow",
	"Green",
	"Blue",
	"Purple",
	"Pink",
	"Gold",
	"White",
	"Multi"
};



// ====================================================================================================
//					PLUGIN INFO / NATIVES
// ====================================================================================================
public Plugin myinfo =
{
	name = "[ANY] Neon Beams",
	author = "SilverShot",
	description = "Spawn and save Neon Beams or presets to the map.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=318209"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// Late Engine
	g_Engine = GetEngineVersion();
	g_iLateLoad = late;
	g_iRoundStart = late;

	// Natives
	RegPluginLibrary("neon_beams");
	CreateNative("NeonBeams_SetupPos",	Native_SetupPos);
	CreateNative("NeonBeams_LoadArray",	Native_LoadFromArray);
	CreateNative("NeonBeams_TempPre",	Native_TempPre);
	CreateNative("NeonBeams_TempMap",	Native_TempMap);
	CreateNative("NeonBeams_SaveMap",	Native_SaveMap);

	return APLRes_Success;
}

public int Native_SetupPos(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !client ) return false;
	client = GetClientOfUserId(client);

	if( client < 1 || !IsClientInGame(client) )
	{
		return false;
	}

	float vPos[3], vAng[3];
	if( SetupBeamPos(client, vPos, vAng) == false )
	{
		return false;
	}

	SetNativeArray(2, vAng, 3);
	SetNativeArray(3, vPos, 3);

	return true;
}

public int Native_LoadFromArray(Handle plugin, int numParams)
{
	if( !g_bCvarAllow ) return false;

	ArrayList aHand = GetNativeCell(1);
	if( aHand == null || g_iLoadPreset[0] != INT_PRE_START ) return false;

	float vAng[3], vPos[3];
	GetNativeArray(2, vAng, 3);
	GetNativeArray(3, vPos, 3);

	g_iLoadPreset[0] = INT_PRE_START;
	LoadPreset(0, vAng, vPos, 0, aHand);

	return true;
}

public int Native_TempPre(Handle plugin, int numParams)
{
	if( !g_bCvarAllow || g_iLoadPreset[0] != INT_PRE_START ) return false;

	char sTemp[LEN_HALF];
	float vAng[3], vPos[3];
	GetNativeString(1, sTemp, sizeof(sTemp));
	GetNativeArray(2, vAng, 3);
	GetNativeArray(3, vPos, 3);

	int index = GetPresetIndex(sTemp);
	if( index != -1 )
	{
		g_iLoadPreset[0] = INT_PRE_START;
		LoadPreset(index, vAng, vPos);
		return true;
	}

	return false;
}

public int Native_TempMap(Handle plugin, int numParams)
{
	if( !g_bCvarAllow ) return false;

	float vPos[3], vPos2[3];
	int type = GetNativeCell(1);
	GetNativeArray(2, vPos, 3);
	GetNativeArray(3, vPos2, 3);
	float time = GetNativeCell(4);

	SpawnBeam(vPos, vPos2, type, 0, time);

	return true;
}

public int Native_SaveMap(Handle plugin, int numParams)
{
	if( !g_bCvarAllow ) return false;

	float vPos[3], vPos2[3];
	int type = GetNativeCell(1);
	GetNativeArray(2, vPos, 3);
	GetNativeArray(3, vPos2, 3);

	SpawnBeam(vPos, vPos2, type);

	char sTemp[LEN_FULL];
	Format(sTemp, sizeof(sTemp), "%d %f %f %f %f %f %f", type, vPos[0], vPos[1], vPos[2], vPos2[0], vPos2[1], vPos2[2]);
	g_hMapList.PushString(sTemp);

	SaveMapConfig();

	return true;
}



// ====================================================================================================
//					PLUGIN START / END
// ====================================================================================================
public void OnPluginStart()
{
	// Default ConVars
	char sCvarRound[16], sCvarTime[16], sCvarHalo[64], sCvarMatS[64], sCvarSize[16], sCvarMaxB[16], sCvarMaxP[16];

	sCvarRound = "2";
	sCvarTime = "0.2";
	sCvarHalo = "materials/sprites/halo.vmt";
	sCvarMatS = "materials/sprites/laser.vmt";
	sCvarMaxP = "768";
	sCvarMaxB = "768";
	sCvarSize = "2";

	// 65535 is Valves limit for beams/particles: Assert( (iLeaf >= 0) && (iLeaf <= 65535) );
	// Setting 8192 to prevent eating into other entities and brushes on map.
	// Client crashes when games fullscreen and too many in 1 area.

	// Default ConVars per-game
	switch( g_Engine )
	{
		case Engine_Left4Dead:
		{
			sCvarHalo = "materials/sprites/glow.vmt";
		}
		case Engine_Left4Dead2:
		{
			sCvarHalo = "materials/sprites/glow.vmt";
			sCvarMatS = "materials/sprites/laserbeam.vmt";
		}
		case Engine_CSGO:
		{
			sCvarHalo = "materials/sprites/glow.vmt";
			sCvarMatS = "materials/sprites/laserbeam.vmt";
		}
		case Engine_CSS:
		{
			sCvarHalo = "materials/sprites/halo01.vmt";
		}
		case Engine_TF2:
		{
			sCvarSize = "5";
		}
	}

	// ConVars
	g_hCvarAllow =		CreateConVar(	"neon_allow",			"1",				"0=Plugin off. 1=Plugin on.", CVAR_FLAGS);
	g_hCvarCfgLoad =	CreateConVar(	"neon_cfg_load",		"5.0",				"0.0=Off. After round start and all connected players have spawned, wait this long before spawning beams and particles saved to map.", CVAR_FLAGS);
	g_hCvarCfgMax =		CreateConVar(	"neon_cfg_max",			"32",				"Max beams and particles to load in 1 frame. More than 32 cannot be loaded at once due to engine limitations.", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_hCvarCfgRound =	CreateConVar(	"neon_cfg_round",		sCvarRound,			"If beams or particles are deleted on round restart you can enable them to load here. 0=None. 1=Load beams on round_start. 2=Load particles on round_start. 3=Both.", CVAR_FLAGS, true, 0.1);
	g_hCvarCfgTime =	CreateConVar(	"neon_cfg_time",		sCvarTime,			"Interval to wait before loading the next set of beams and particles.", CVAR_FLAGS, true, 0.1);
	g_hCvarDist =		CreateConVar(	"neon_distance",		"1.5",				"Distance from the wall to spawn beams, particles and presets.", CVAR_FLAGS);
	g_hCvarLate =		CreateConVar(	"neon_late_load",		"3",				"0=Off. 1=Send clients the saved beams map data when joining after round start. 2=Send particles (attempts to hide from others). 3=Both.", CVAR_FLAGS);
	g_hCvarHalo =		CreateConVar(	"neon_mat_halo",		sCvarHalo,			"The sprite halo used for beams.", CVAR_FLAGS);
	g_hCvarSprite =		CreateConVar(	"neon_mat_sprite",		sCvarMatS,			"The sprite material used for beams.", CVAR_FLAGS);
	g_hCvarMaxBeam =	CreateConVar(	"neon_max_beams",		sCvarMaxB,			"Maximum number of beams allowed on the map.", CVAR_FLAGS);
	g_hCvarMaxPart =	CreateConVar(	"neon_max_parts",		sCvarMaxP,			"Maximum number of particles allowed on the map.", CVAR_FLAGS);
	g_hCvarPaint =		CreateConVar(	"neon_paints",			"0.5",				"Interval between each paint.", CVAR_FLAGS, true, 0.1, true, 5.0);
	g_hCvarOpac =		CreateConVar(	"neon_opacity",			"128",				"Transparency of beams. 0=Invisible. 255=Solid.", CVAR_FLAGS);
	g_hCvarSize =		CreateConVar(	"neon_size",			sCvarSize,			"Width of beams.", CVAR_FLAGS);
	CreateConVar(						"neon_version",			PLUGIN_VERSION,		"Neon Beams plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,				"neon_beams");

	g_hCvarAllow.AddChangeHook(ConVarChanged_Allowed);
	g_hCvarCfgLoad.AddChangeHook(ConVarChanged_Changed);
	g_hCvarCfgMax.AddChangeHook(ConVarChanged_Changed);
	g_hCvarCfgRound.AddChangeHook(ConVarChanged_Changed);
	g_hCvarCfgTime.AddChangeHook(ConVarChanged_Changed);
	g_hCvarDist.AddChangeHook(ConVarChanged_Changed);
	g_hCvarLate.AddChangeHook(ConVarChanged_Changed);
	g_hCvarPaint.AddChangeHook(ConVarChanged_Changed);
	g_hCvarMaxBeam.AddChangeHook(ConVarChanged_Changed);
	g_hCvarMaxPart.AddChangeHook(ConVarChanged_Changed);
	g_hCvarOpac.AddChangeHook(ConVarChanged_Changed);
	g_hCvarSize.AddChangeHook(ConVarChanged_Changed);
	g_hCvarSprite.AddChangeHook(ConVarChanged_Changed);



	// Commands
	RegAdminCmd("sm_neon_paint2",		CmdNeonPaint2,		ADMFLAG_CUSTOM1,	"Menu to start and stop painting - continuous spawning of Particles with color selection.");
	RegAdminCmd("sm_neon_preset2",		CmdNeonPreset2,		ADMFLAG_ROOT,		"Create or edit a preset with Particles. Usage: sm_neon_preset2 <config file/preset name>.");
	RegAdminCmd("sm_neon_save2",		CmdNeonMenuSave2,	ADMFLAG_ROOT,		"Menu to spawn and save Particles at your crosshair.");
	RegAdminCmd("sm_neon_temp2",		CmdNeonMenuMap2,	ADMFLAG_ROOT,		"Menu to spawn temporary Particles at your crosshair.");
	RegAdminCmd("sm_neon_point",		CmdNeonMenuPoint,	ADMFLAG_ROOT,		"Menu to spawn temporary Beams from your eye location. Usage: sm_neon_point [optional range from eyes]");
	RegAdminCmd("sm_neon_point2",		CmdNeonMenuPoint2,	ADMFLAG_ROOT,		"Menu to spawn temporary Particles from your eye location. Usage: sm_neon_point2 [optional range from eyes]");
	RegAdminCmd("sm_neon_points",		CmdNeonMenuPoints,	ADMFLAG_ROOT,		"Menu to spawn save Beams from your eye location. Usage: sm_neon_points [optional range from eyes]");
	RegAdminCmd("sm_neon_points2",		CmdNeonMenuPoints2,	ADMFLAG_ROOT,		"Menu to spawn save Particles from your eye location. Usage: sm_neon_points2 [optional range from eyes]");
	RegAdminCmd("sm_neon_preset_eye",	CmdNeonPreset3,		ADMFLAG_ROOT,		"Opens the Preset menu list, spawns them from your eye location. Usage: sm_neon_preset_eye [optional range from eyes]");
	RegAdminCmd("sm_neon_preset_eyes",	CmdNeonPresetS,		ADMFLAG_ROOT,		"Opens the Preset menu list, spawns them from your eye location and saves to map. Usage: sm_neon_preset_eyes [optional range from eyes]");

	RegAdminCmd("sm_neon",				CmdNeonMenuMain,	ADMFLAG_ROOT,		"Open the main menu for Neon Beams.");
	RegAdminCmd("sm_neon_temp",			CmdNeonMenuMap,		ADMFLAG_ROOT,		"Menu to spawn temporary Beams at your crosshair.");
	RegAdminCmd("sm_neon_save",			CmdNeonMenuSave,	ADMFLAG_ROOT,		"Menu to spawn and save Beams at your crosshair.");
	RegAdminCmd("sm_neon_paint",		CmdNeonPaint,		ADMFLAG_CUSTOM1,	"Menu to start and stop painting - continuous spawning of Beams with color selection.");
	RegAdminCmd("sm_neon_preset",		CmdNeonPreset,		ADMFLAG_ROOT,		"Create or edit a preset with Beams: sm_neon_preset <config file/preset name>.");
	RegAdminCmd("sm_neon_preset_temp",	CmdNeonTempPre,		ADMFLAG_ROOT,		"Opens the Preset menu list, to spawn temporary presets.");
	RegAdminCmd("sm_neon_preset_save",	CmdNeonSavePre,		ADMFLAG_ROOT,		"Opens the Preset menu list, allowing you to save them to the map.");

	RegAdminCmd("sm_neon_del",			CmdNeonMapDel,		ADMFLAG_ROOT, 		"Remove the last placed preset or beam from the saved map config.");
	RegAdminCmd("sm_neon_delpre",		CmdNeonPreDel,		ADMFLAG_ROOT,		"Remove the last saved beam from the currently selected preset. Or delete a preset config, usage: sm_neon_delpre <preset name>");
	RegAdminCmd("sm_neon_wipe",			CmdNeonWipe,		ADMFLAG_ROOT, 		"Delete all beams and presets saved to the current maps config.");
	RegAdminCmd("sm_neon_load",			CmdNeonLoad,		ADMFLAG_ROOT,		"Reloads the Preset and current Map configs, used to refresh the plugin after manual cfg changes.");
	RegAdminCmd("sm_neon_overload",		CmdNeonOverLoad,	ADMFLAG_ROOT,		"Overrides the duplicate load prevention, and loads the auto spawn data config for the current map.");
	RegAdminCmd("sm_neon_stats",		CmdNeonStats,		ADMFLAG_ROOT, 		"Shows details about how many beams were spawned and how long it took etc.");
	// RegAdminCmd("sm_neon_con",			CmdNeonCon,			ADMFLAG_ROOT, 		"For testing late loading on clients.");



	// Menus
	g_hMenuPaint = new Menu(MenuPaintHandler);
	g_hMenuPaint.SetTitle("Neon Painting");
	g_hMenuPaint.ExitButton = true;

	g_hMenuMapSpawn = new Menu(MapSpawnMenuHandler);
	g_hMenuMapSpawn.SetTitle("Neon Beams");
	g_hMenuMapSpawn.ExitBackButton = true;

	g_hMenuPreSpawn = new Menu(PreSpawnMenuHandler);
	g_hMenuPreSpawn.SetTitle("Neon Beams - Save Preset");
	g_hMenuPreSpawn.ExitBackButton = true;

	g_hMenuPresetList = new Menu(PreListMenuHandler);
	g_hMenuPresetList.SetTitle("Neon Beams - Preset");
	g_hMenuPresetList.ExitBackButton = true;

	g_hMenuMain = new Menu(MainMenuHandler);
	g_hMenuMain.SetTitle("Neon Beams");
	g_hMenuMain.AddItem("1", "Temp Beam");
	g_hMenuMain.AddItem("2", "Save Beam");
	g_hMenuMain.AddItem("3", "Temp Preset");
	g_hMenuMain.AddItem("4", "Save Preset");
	g_hMenuMain.AddItem("5", "Paint");
	g_hMenuMain.Pagination = MENU_NO_PAGINATION;
	g_hMenuMain.ExitButton = true;

	if( g_Engine != Engine_TF2 )
	{
		g_hMenuMain.AddItem("6", "Temp Particle");
		g_hMenuMain.AddItem("7", "Save Particle");
		g_hMenuMain.AddItem("8", "Paint Particle");
	}

	g_hMenuPaint2 = new Menu(MenuPaintHandler);
	g_hMenuPaint2.SetTitle("Neon Painting");
	g_hMenuPaint2.ExitButton = true;

	g_hMenuMapSpawn2 = new Menu(MapSpawnMenuHandler);
	g_hMenuMapSpawn2.SetTitle("Neon Beams");
	g_hMenuMapSpawn2.ExitBackButton = true;

	g_hMenuPreSpawn2 = new Menu(PreSpawnMenuHandler);
	g_hMenuPreSpawn2.SetTitle("Neon - Save Preset");
	g_hMenuPreSpawn2.ExitBackButton = true;



	// Data Arrays
	g_hMapList = new ArrayList(ByteCountToCells(LEN_FULL));
	g_hPresetList = new ArrayList();

	if( g_iLateLoad ) LoadMapConfig();



	// Try hooking events
	HookEventEx("player_death",						Event_PlayerDeath);
	HookEventEx("player_team",						Event_PlayerTeam);
	HookEventEx("player_spawn",						Event_PlayerSpawn,	EventHookMode_PostNoCopy);

	switch( g_Engine )
	{
		case Engine_DODS:
		{
			HookEventEx("dod_round_win",			Event_RoundEnded,	EventHookMode_PostNoCopy);
		}
		case Engine_CSGO:
		{
			HookEventEx("round_start",				Event_RoundStart,	EventHookMode_PostNoCopy);
			HookEventEx("round_end",				Event_RoundEnded,	EventHookMode_PostNoCopy);
			HookEventEx("round_end_upload_stats",	Event_RoundEnded,	EventHookMode_PostNoCopy); // Fires after warmup round.
		}
		case Engine_CSS:
		{
			HookEventEx("round_start",				Event_RoundStart,	EventHookMode_PostNoCopy);
			HookEventEx("cs_win_panel_round",		Event_RoundEnded,	EventHookMode_PostNoCopy);
			HookEventEx("round_officially_ended",	Event_RoundEnded,	EventHookMode_PostNoCopy);
			HookEventEx("cs_pre_start",				Event_RoundEnded,	EventHookMode_PostNoCopy);
			HookEventEx("round_end_message",		Event_RoundEnded,	EventHookMode_PostNoCopy);
			HookEventEx("round_win",				Event_RoundEnded,	EventHookMode_PostNoCopy);
		}
		default:
		{
			HookEventEx("round_start",				Event_RoundStart,	EventHookMode_PostNoCopy);
			HookEventEx("round_end",				Event_RoundEnded,	EventHookMode_PostNoCopy);
		}
	}
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnConfigsExecuted()
{
	GetCvars();
}

public void ConVarChanged_Allowed(Handle convar, const char[] oldValue, const char[] newValue)
{
	int value = g_hCvarAllow.IntValue;

	if( g_bCvarAllow && value == 0 )
	{
		g_bCvarAllow = false;

		for( int client = 1; client <= MaxClients; client++ )
		{
			KillPainting(client);
		}
	}
	else if( g_bCvarAllow == false && value == 1 )
	{
		g_bCvarAllow = true;
	}
}

public void ConVarChanged_Changed(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bCvarAllow = g_hCvarAllow.BoolValue;
	g_fCvarCfgLoad = g_hCvarCfgLoad.FloatValue;
	g_iCvarCfgMax = g_hCvarCfgMax.IntValue;
	g_iCvarCfgRound = g_hCvarCfgRound.IntValue;
	g_fCvarCfgTime = g_hCvarCfgTime.FloatValue;
	g_fCvarDist = g_hCvarDist.FloatValue;
	g_iCvarLate = g_hCvarLate.IntValue;
	g_fCvarPaint = g_hCvarPaint.FloatValue;
	g_iCvarMaxB = g_hCvarMaxBeam.IntValue;
	g_iCvarMaxP = g_hCvarMaxPart.IntValue;
	g_iCvarOpac = g_hCvarOpac.IntValue;
	g_fCvarSize = g_hCvarSize.FloatValue;
	g_hCvarSprite.GetString(g_sCvarSprite, sizeof(g_sCvarSprite));
	g_hCvarHalo.GetString(g_sCvarHalo, sizeof(g_sCvarHalo));
	if( g_sCvarSprite[0] )		g_Sprite	= PrecacheModel(g_sCvarSprite);
	if( g_sCvarHalo[0] )		g_Halo		= PrecacheModel(g_sCvarHalo);
}



// ====================================================================================================
//					LOAD COLOR MENU
// ====================================================================================================
void CreateFolders()
{
	char sPath[PLATFORM_MAX_PATH];

	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_FOLDER);
	if( !DirExists(sPath, false) )
	{
		CreateDirectory(sPath, 511);
	}

	BuildPath(Path_SM, sPath, sizeof(sPath), "%s/%s", CONFIG_FOLDER, CONFIG_PATH_M);
	if( !DirExists(sPath, false) )
	{
		CreateDirectory(sPath, 511);
	}

	BuildPath(Path_SM, sPath, sizeof(sPath), "%s/%s", CONFIG_FOLDER, CONFIG_PATH_P);
	if( !DirExists(sPath, false) )
	{
		CreateDirectory(sPath, 511);
	}
}

void LoadColorConfig()
{
	CreateFolders();

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s/%s", CONFIG_FOLDER, CONFIG_MENU);
	if( !FileExists(sPath) )
	{
		File hCfg = OpenFile(sPath, "w");
		hCfg.WriteLine("\"Neon_Menu\"");
		hCfg.WriteLine("{");
		hCfg.WriteLine("	\"Red\"			\"255 0 0\"");
		hCfg.WriteLine("	\"Orange\"		\"255 100 0\"");
		hCfg.WriteLine("	\"Yellow\"		\"255 255 0\"");
		hCfg.WriteLine("	\"Green\"		\"0 255 0\"");
		hCfg.WriteLine("	\"Blue\"		\"0 0 255\"");
		hCfg.WriteLine("	\"Purple\"		\"75 0 150\"");
		hCfg.WriteLine("	\"Pink\"		\"255 0 255\"");
		hCfg.WriteLine("	\"White\"		\"255 255 255\"");
		hCfg.WriteLine("}");
		delete hCfg;
	}

	ParseColorConfigFile(sPath);
}

bool ParseColorConfigFile(const char[] file)
{
	SMCParser parser = new SMCParser();
	SMC_SetReaders(parser, ColorConfig_NewSection, ColorConfig_KeyValue, ColorConfig_EndSection);
	parser.OnEnd = ColorConfig_End;

	char error[128];
	int line = 0, col = 0;
	SMCError result = parser.ParseFile(file, line, col);

	if( result != SMCError_Okay )
	{
		parser.GetErrorString(result, error, sizeof(error));
		SetFailState("%s on line %d, col %d of %s [%d]", error, line, col, file, result);
	}

	delete parser;
	return (result == SMCError_Okay);
}

public SMCResult ColorConfig_NewSection(Handle parser, const char[] section, bool quotes)
{
	return SMCParse_Continue;
}

public SMCResult ColorConfig_KeyValue(Handle parser, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	int type = GetColor(value);
	char sCols[12];

	IntToString(type, sCols, sizeof(sCols));
	g_hMenuPaint.AddItem(sCols, key);
	g_hMenuMapSpawn.AddItem(sCols, key);
	g_hMenuPreSpawn.AddItem(sCols, key);

	return SMCParse_Continue;
}

public SMCResult ColorConfig_EndSection(Handle parser)
{
	return SMCParse_Continue;
}

public void ColorConfig_End(Handle parser, bool halted, bool failed)
{
	if( failed )
		SetFailState("Error: Cannot load the Neon Beam Color menu.");
}



// ====================================================================================================
//					MAP START / END / CLEAN UP
// ====================================================================================================
public void OnMapStart()
{
	g_bRoundRestart = false;

	GetCvars();
	CleanUp();

	g_iAccessParticles = 0;

	// L4D2 has it's own particles and TF2 doesn't support custom particles
	if( g_Engine != Engine_Left4Dead2 && g_Engine != Engine_TF2 )
	{
		if( FileExists(PATH_PCF) && FileExists(PATH_MAT1) && FileExists(PATH_MAT2) && FileExists(PATH_MAT3) && FileExists(PATH_MAT4) )
		{
			g_iAccessParticles = 1;
			AddFileToDownloadsTable(PATH_MAT1);
			AddFileToDownloadsTable(PATH_MAT2);
			AddFileToDownloadsTable(PATH_MAT3);
			AddFileToDownloadsTable(PATH_MAT4);
			AddFileToDownloadsTable(PATH_PCF);
			PrecacheGeneric(PATH_PCF, true);
		}
	}

	// L4D2 has it's own set. Could allow custom particles but AddFileToDownloadsTable issues with L4D2 I will not support.
	if( g_Engine == Engine_Left4Dead2  )
	{
		g_iAccessParticles = 2;
	}

	// Precache
	if( g_iAccessParticles )
		for( int i = 0; i < GetMaxParticles(); i++ )
			PrecacheParticle(g_iAccessParticles == 1 ? g_sParticles[i] : g_sParticles_L4D2[i]);

	// Only wipe menu and recreate if changes to particles
	static int iAccessParticles;
	if( g_iAccessParticles != iAccessParticles )
	{
		iAccessParticles = g_iAccessParticles;
		char sTemp[4];

		// Map: Spawn particles menu
		g_hMenuMapSpawn2.RemoveAllItems();
		for( int i = 0; i < GetMaxParticles(); i++ )
		{
			IntToString(i+1, sTemp, sizeof(sTemp));
			g_hMenuMapSpawn2.AddItem(sTemp,	(g_iAccessParticles == 1 ? g_sPartNames[i] : g_sPartNames_L4D2[i]));
		}

		// Presets: Spawn particles menu
		g_hMenuPreSpawn2.RemoveAllItems();
		for( int i = 0; i < (g_iAccessParticles == 1 ? MAX_PARTICLES : MAX_PART_L4D2 - 2); i++ ) // L4D2 avoid last 2 particles
		{
			IntToString(i+1, sTemp, sizeof(sTemp));
			g_hMenuPreSpawn2.AddItem(sTemp,	(g_iAccessParticles == 1 ? g_sPartNames[i] : g_sPartNames_L4D2[i]));
		}
		if( g_iAccessParticles == 2 )
			g_hMenuPreSpawn2.Pagination = MENU_NO_PAGINATION;

		// Paint: Spawn particles menu
		g_hMenuPaint2.RemoveAllItems();
		g_hMenuPaint2.AddItem("0", "START/STOP");
		for( int i = 0; i < (g_iAccessParticles == 1 ? MAX_PARTICLES : MAX_PART_L4D2 - 3); i++ ) // L4D2 avoid last 3 particles
		{
			IntToString(i+1, sTemp, sizeof(sTemp));
			g_hMenuPaint2.AddItem(sTemp, g_iAccessParticles == 1 ? g_sPartNames[i] : g_sPartNames_L4D2[i]);
		}
		if( g_iAccessParticles == 2 )
		{
			g_hMenuPaint2.Pagination = MENU_NO_PAGINATION;
			g_hMenuPaint2.ExitButton = true;
		}
	}
}

public void OnMapEnd()
{
	g_bLoaded = false;
	g_iLateLoad	= 0;
	g_iRoundStart = 0;
	g_iTotalBeam = 0;
	g_iTotalPart = 0;
	g_fLoadTime = 0.0;
	if( g_iBlocked != 3 ) g_iBlocked = 0;
	delete g_hTimerLoad;
}

void CleanUp(bool load = true)
{
	// Array Presets
	for( int i = 0; i <= MaxClients; i++ )
	{
		g_bLoadingLate[i] = false;
		g_bLateLoaded[i] = false;
		delete g_hClientPreMenu[i];
	}

	ArrayList aHand;
	int size = g_hPresetList.Length;

	for( int i = 0; i < size; i++ )
	{
		aHand = g_hPresetList.Get(i);
		delete aHand;
	}

	g_hPresetList.Clear();					// Array: Presets data
	g_hMapList.Clear();						// Array: Map saved data
	g_hMenuPresetList.RemoveAllItems();		// Menu: Preset List
	g_hMenuPreSpawn.RemoveAllItems();		// Menu: Preset Create
	g_hMenuMapSpawn.RemoveAllItems();		// Menu: Map Spawn
	g_hMenuPaint.RemoveAllItems();			// Menu: Paint
	g_hMenuPaint.AddItem("0", "START/STOP");

	// Load Configs
	if( load )
	{
		LoadColorConfig();
		LoadPreConfig();
		LoadMapConfig();
	}
}



// ====================================================================================================
//					SAVE MAP CONFIG
// ====================================================================================================
void SaveMapConfig()
{
	File hCfg;
	char sPath[PLATFORM_MAX_PATH];
	GetCurrentMap(sPath, sizeof(sPath));
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s/%s/%s.cfg", CONFIG_FOLDER, CONFIG_PATH_M, sPath);
	hCfg = OpenFile(sPath, "w");

	char sTemp[LEN_FULL];
	int size = g_hMapList.Length;

	if( size == 0 )
	{
		CmdNeonWipe(-1, 0);
		return;
	}

	hCfg.WriteLine("\"Neon_Beams\"");
	hCfg.WriteLine("{");

	for( int i = 0; i < size; i++ )
	{
		g_hMapList.GetString(i, sTemp, sizeof(sTemp));
		hCfg.WriteLine("\t\"\" \"%s\"", sTemp);
	}

	hCfg.WriteLine("}");
	delete hCfg;
}

// ====================================================================================================
//					LOAD MAP CONFIG
// ====================================================================================================
void LoadMapConfig()
{
	char sPath[PLATFORM_MAX_PATH];

	GetCurrentMap(sPath, sizeof(sPath));
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s/%s/%s.cfg", CONFIG_FOLDER, CONFIG_PATH_M, sPath);

	if( FileExists(sPath) )
	{
		ParseMapConfigFile(sPath);
	}
}

bool ParseMapConfigFile(const char[] file)
{
	SMCParser parser = new SMCParser();
	SMC_SetReaders(parser, MapConfig_NewSection, MapConfig_KeyValue, MapConfig_EndSection);
	parser.OnEnd = MapConfig_End;

	char error[128];
	int line = 0, col = 0;
	SMCError result = parser.ParseFile(file, line, col);

	if( result != SMCError_Okay )
	{
		parser.GetErrorString(result, error, sizeof(error));
		SetFailState("%s on line %d, col %d of %s [%d]", error, line, col, file, result);
	}

	delete parser;
	return (result == SMCError_Okay);
}

public SMCResult MapConfig_NewSection(Handle parser, const char[] section, bool quotes)
{
	return SMCParse_Continue;
}

public SMCResult MapConfig_KeyValue(Handle parser, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	g_hMapList.PushString(value);
	return SMCParse_Continue;
}

public SMCResult MapConfig_EndSection(Handle parser)
{
	return SMCParse_Continue;
}

public void MapConfig_End(Handle parser, bool halted, bool failed)
{
	if( failed )
		SetFailState("Error: Cannot load the Neon Beams config.");
}



// ====================================================================================================
//					SAVE PRESET CONFIG
// ====================================================================================================
void SavePreConfig(int index)
{
	char sPath[PLATFORM_MAX_PATH];
	char sName[LEN_HALF];
	char sTemp[LEN_FULL];
	ArrayList aHand;
	File hCfg;

	aHand = g_hPresetList.Get(index);
	aHand.GetString(1, sName, sizeof(sName));

	BuildPath(Path_SM, sPath, sizeof(sPath), "%s/%s/%s.cfg", CONFIG_FOLDER, CONFIG_PATH_P, sName);
	hCfg = OpenFile(sPath, "w");

	int size = g_hPresetList.Length;
	int size2;

	for( int p = 0; p < size; p++ )
	{
		aHand = g_hPresetList.Get(p);
		aHand.GetString(1, sPath, sizeof(sPath));

		if( strcmp(sPath, sName, false) == 0 )
		{
			size2 = aHand.Length;
			aHand.GetString(0, sTemp, sizeof(sTemp));
			hCfg.WriteLine("\"%s\"", sTemp);
			hCfg.WriteLine("{");

			for( int i = INT_PRE_START; i < size2; i++ )
			{
				aHand.GetString(i, sTemp, sizeof(sTemp));
				hCfg.WriteLine("\t\"\" \"%s\"", sTemp);
			}

			hCfg.WriteLine("}");
		}
	}

	delete hCfg;
}

// ====================================================================================================
//					LOAD PRESET CONFIG
// ====================================================================================================
bool IsUniquePresetName(const char[] section)
{
	int size = g_hPresetList.Length;
	ArrayList aHand;
	char sTemp[LEN_HALF];

	for( int i = 0; i < size; i++ )
	{
		aHand = g_hPresetList.Get(i);
		aHand.GetString(0, sTemp, sizeof(sTemp));

		if( strcmp(section, sTemp, false) == 0 )
		{
			return false;
		}
	}
	return true;
}

int GetPresetIndex(const char[] section)
{
	int size = g_hPresetList.Length;
	ArrayList aHand;
	char sTemp[LEN_HALF];

	for( int i = 0; i < size; i++ )
	{
		aHand = g_hPresetList.Get(i);
		aHand.GetString(0, sTemp, sizeof(sTemp));
		if( strcmp(section, sTemp, false) == 0 )
		{
			return i;
		}
	}
	return -1;
}

void LoadPreConfig()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s/%s", CONFIG_FOLDER, CONFIG_PATH_P);

	DirectoryListing hFile;
	hFile = OpenDirectory(sPath);
	if( hFile == null )
	{
		return;
	}

	FileType type;
	char sName[PLATFORM_MAX_PATH];

	while( hFile.GetNext(sPath, sizeof(sPath), type) )
	{
		if( type == FileType_File && strcmp(sPath[strlen(sPath) - 4], ".cfg", false) == 0 )
		{
			if( StrContains(sPath, " ") != -1 )
			{
				LogError("Error: The preset config '%s/%s/%s' contains spaces. Preset config names cannot contain spaces. Please correct the issue and reload the plugin.", CONFIG_FOLDER, CONFIG_PATH_P, sPath);
				CleanUp(false);
				g_iBlocked = 3;
				return;
			}

			ReplaceString(sPath, sizeof(sPath), ".cfg", "");
			strcopy(g_sPreLoadPath, sizeof(g_sPreLoadPath), sPath);
			strcopy(sName, sizeof(sName), sPath);
			ReplaceString(sName, sizeof(sName), "_", " ");
			g_hMenuPresetList.AddItem(sPath, sName);

			SMCParser parser = new SMCParser();
			SMC_SetReaders(parser, PreConfig_NewSection, PreConfig_KeyValue, PreConfig_EndSection);
			parser.OnEnd = PreConfig_End;

			char error[128];
			int line = 0, col = 0;
			BuildPath(Path_SM, sPath, sizeof(sPath), "%s/%s/%s.cfg", CONFIG_FOLDER, CONFIG_PATH_P, sPath);
			SMCError result = parser.ParseFile(sPath, line, col);

			if( result != SMCError_Okay )
			{
				parser.GetErrorString(result, error, sizeof(error));
				SetFailState("%s on line %d, col %d of %s [%d]", error, line, col, sPath, result);
			}

			delete parser;
		}
	}

	delete hFile;
}

public SMCResult PreConfig_NewSection(Handle parser, const char[] section, bool quotes)
{
	if( !IsUniquePresetName(section) )
	{
		LogError("Error: The preset '%s' from '%s.cfg' conflicts with another preset using an identical name. Please correct the issue and reload the plugin.", section, g_sPreLoadPath);
		CleanUp(false);
		g_iBlocked = 3;
		return SMCParse_Halt;
	}

	ArrayList aHand = new ArrayList(ByteCountToCells(LEN_FULL));
	g_hPresetList.Push(aHand);

	if( StrContains(section, " ") != -1 )
	{
		LogError("Error: Preset '%s' from '%s.cfg' contains spaces. Preset names cannot contain spaces. Please correct the issue and reload the plugin.", section, g_sPreLoadPath);
		CleanUp(false);
		g_iBlocked = 3;
		return SMCParse_Halt;
	}

	aHand.PushString(section);
	aHand.PushString(g_sPreLoadPath);
	return SMCParse_Continue;
}

public SMCResult PreConfig_KeyValue(Handle parser, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	ArrayList aHand;
	aHand = g_hPresetList.Get(g_hPresetList.Length - 1);
	aHand.PushString(value);
	return SMCParse_Continue;
}

public SMCResult PreConfig_EndSection(Handle parser)
{
	return SMCParse_Continue;
}

public void PreConfig_End(Handle parser, bool halted, bool failed)
{
	if( failed )
	{
		SetFailState("Error: Cannot load the Neon Beams config.");
	}
}



// ====================================================================================================
//					SPAWN PRESET
// ====================================================================================================
// Creating a timer to load presets so max 32 beams are created per allowed g_fCvarCfgTime time.
// Without a delay they would fail to draw completely
public Action TimerPreset(Handle timer, DataPack dPack)
{
	float vAng[3], vPos[3];
	dPack.Reset();
	int index = dPack.ReadCell();
	vAng[0] = dPack.ReadFloat();
	vAng[1] = dPack.ReadFloat();
	vAng[2] = dPack.ReadFloat();
	vPos[0] = dPack.ReadFloat();
	vPos[1] = dPack.ReadFloat();
	vPos[2] = dPack.ReadFloat();
	int target = dPack.ReadCell();
	ArrayList aHand = dPack.ReadCell();

	g_iLoadCount[target] = 0;
	LoadPreset(index, vAng, vPos, target, aHand);
}

void LoadPreset(int index, float vAngles[3], const float vClient[3], int target = 0, ArrayList aHand = null)
{
	float vPos[3], vPos2[3], vNew[3];
	float angleX, angleY, angleZ;

	int type;
	int client = target;
	if( target == -1 ) target = 0; // -1 = Server loading

	char sTemp[LEN_FULL];
	char sBuff[7][LEN_HALF];

	if( aHand == null ) aHand = g_hPresetList.Get(index);
	int size = aHand.Length;

	// Loop through beams and draw
	for( int i = g_iLoadPreset[target]; i < size; i++ )
	{
		// Prevent overflow of beams, load next frame/allowed time.
		if( HasReachedMax(target) )
		{
			DataPack dPack;
			CreateDataTimer(g_fCvarCfgTime, TimerPreset, dPack, TIMER_FLAG_NO_MAPCHANGE);
			dPack.WriteCell(index);
			dPack.WriteFloat(vAngles[0]);
			dPack.WriteFloat(vAngles[1]);
			dPack.WriteFloat(vAngles[2]);
			dPack.WriteFloat(vClient[0]);
			dPack.WriteFloat(vClient[1]);
			dPack.WriteFloat(vClient[2]);
			dPack.WriteCell(target);
			dPack.WriteCell(aHand);
			return;
		}

		// Counter how many beams loaded from the current preset
		g_iLoadPreset[target]++;

		aHand.GetString(i, sTemp, sizeof(sTemp));
		ExplodeString(sTemp, " ", sBuff, sizeof(sBuff), LEN_HALF);

		type = StringToInt(sBuff[0]);
		vPos[0] = StringToFloat(sBuff[1]);
		vPos[1] = StringToFloat(sBuff[2]);
		vPos[2] = StringToFloat(sBuff[3]);
		vPos2[0] = StringToFloat(sBuff[4]);
		vPos2[1] = StringToFloat(sBuff[5]);
		vPos2[2] = StringToFloat(sBuff[6]);

		angleX = vAngles[0];
		angleY = vAngles[1];
		angleZ = vAngles[2];

		// Thanks to "Don't Fear The Reaper" for the Rotation Matrix:
		vNew[0] = (vPos[0] * Cosine(angleX) * Cosine(angleY)) - (vPos[1] * Cosine(angleZ) * Sine(angleY)) + (vPos[1] * Sine(angleZ) * Sine(angleX) * Cosine(angleY)) + (vPos[2] * Sine(angleZ) * Sine(angleY)) + (vPos[2] * Cosine(angleZ) * Sine(angleX) * Cosine(angleY));
		vNew[1] = (vPos[0] * Cosine(angleX) * Sine(angleY)) + (vPos[1] * Cosine(angleZ) * Cosine(angleY)) + (vPos[1] * Sine(angleZ) * Sine(angleX) * Sine(angleY)) - (vPos[2] * Sine(angleZ) * Cosine(angleY)) + (vPos[2] * Cosine(angleZ) * Sine(angleX) * Sine(angleY));
		vNew[2] = (-1.0 * vPos[0] * Sine(angleX)) + (vPos[1] * Sine(angleZ) * Cosine(angleX)) + (vPos[2] * Cosine(angleZ) * Cosine(angleX));
		vPos = vNew;

		vNew[0] = (vPos2[0] * Cosine(angleX) * Cosine(angleY)) - (vPos2[1] * Cosine(angleZ) * Sine(angleY)) + (vPos2[1] * Sine(angleZ) * Sine(angleX) * Cosine(angleY)) + (vPos2[2] * Sine(angleZ) * Sine(angleY)) + (vPos2[2] * Cosine(angleZ) * Sine(angleX) * Cosine(angleY));
		vNew[1] = (vPos2[0] * Cosine(angleX) * Sine(angleY)) + (vPos2[1] * Cosine(angleZ) * Cosine(angleY)) + (vPos2[1] * Sine(angleZ) * Sine(angleX) * Sine(angleY)) - (vPos2[2] * Sine(angleZ) * Cosine(angleY)) + (vPos2[2] * Cosine(angleZ) * Sine(angleX) * Sine(angleY));
		vNew[2] = (-1.0 * vPos2[0] * Sine(angleX)) + (vPos2[1] * Sine(angleZ) * Cosine(angleX)) + (vPos2[2] * Cosine(angleZ) * Cosine(angleX));
		vPos2 = vNew;

		AddVectors(vClient, vPos, vPos);
		AddVectors(vClient, vPos2, vPos2);
		SpawnBeam(vPos, vPos2, type, client ? client : -1); // -1 indicates server loading preset
	}

	// Only reaches here when all data has spawned
	g_iLoadPreset[target] = INT_PRE_START;
}



// ====================================================================================================
//					EVENTS - SPAWN - LOAD BEAMS
// ====================================================================================================
public void Event_RoundEnded(Event event, const char[] name, bool dontBroadcast)
{
	g_bLoaded = false;
	g_iLateLoad = 0;

	if( g_iRoundStart == 1 ) // Only when the round actually started, CSGO round_end fires after OnMapStart and then round_start actually takes place.
		g_bRoundRestart = true;

	if( g_iCvarCfgRound == 1 || g_iCvarCfgRound == 3 )
		g_iTotalBeam = 0;

	if( g_iCvarCfgRound > 1 )
		g_iTotalPart = 0;

	g_iRoundStart = 0;
}

// Stop auto painting when client dies
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	KillPainting(client);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	AutoLoadBeams();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	// Load beams saved to the map only the round has started for the first time and all connecting players are in-game.
	AutoLoadBeams();

	g_iRoundStart = 1;
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	AutoLoadBeams();
}

bool g_block;
public void OnClientPutInServer(int client)
{
	if( !g_block && IsFakeClient(client) )
	{
		return;
	}

	// Late loading beams on connecting client if allowed
	if( g_bLoaded )
	{
		if( g_fCvarCfgLoad && g_iCvarLate && !g_bLateLoaded[client] )
		{
			g_bLoadingLate[client] = true;
			g_bLateLoaded[client] = true;

			CreateTimer(g_fCvarCfgLoad, TimerMake, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}

		return;
	}

	// Load beams saved to the map only the round has started for the first time and all connecting players are in-game.
	AutoLoadBeams();
}

public void OnClientDisconnect(int client)
{
	g_bLoadingLate[client] = false;
	g_bLateLoaded[client] = false;
	delete g_hClientPreMenu[client];

	// In case someone disconnects while loading and others are waiting
	AutoLoadBeams();
}

// Verify all players in-game before loading beams after map change
void AutoLoadBeams()
{
	if( !g_bCvarAllow || g_bLoaded || g_iRoundStart == 0 || g_fCvarCfgLoad == 0.0 ) return;

	// Wait until all loaded
	for( int i = 1; i <= MaxClients; i++ )
		if( IsClientConnected(i) && !IsClientInGame(i) && !IsFakeClient(i) )
			return;

	// Flag the connected players as having loaded the beams, to avoid late loading on them
	for( int i = 1; i <= MaxClients; i++ )
		if( IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i) )
			g_bLateLoaded[i] = true;

	g_bLoaded = true;

	// Load beams saved to the map?
	if( g_fCvarCfgLoad )
		CreateTimer(g_fCvarCfgLoad, TimerMake, 0, TIMER_FLAG_NO_MAPCHANGE);

}

public Action TimerMake(Handle timer, any client)
{
	if( !g_bCvarAllow ) return;
	if( client == 0 && g_iLateLoad != 0 ) return; // Allow clients to lateload. Don't allow plugin to lateload (g_iLateLoad)

	if( client )
	{
		client = GetClientOfUserId(client);
		if( !client ) return;
	}

	LoadBeams(client);
}

// Load map saved beams/presets.
void LoadBeams(int client = 0)
{
	delete g_hTimerLoad;
	if( g_hMapList.Length == 0 ) return;

	g_iLoadIndex[client] = 0;
	g_iLoadPreset[client] = INT_PRE_START;
	g_iLoadCount[client] = 0;
	g_iLoopCount = 0;
	g_fLoadTick = GetTickedTime();

	LogAction(-1, -1, "[Neon Beams]: (%d)%N Got %d. Max %d/%d & %d/%d. Started at %0.1f", client, client, g_hMapList.Length, g_iCvarCfgMax, MAX_ENTITIES, g_iCvarMaxB, g_iCvarMaxP, g_fLoadTick);

	Handle tmr = CreateTimer(g_fCvarCfgTime, TimerLoadBeams, client ? GetClientUserId(client) : 0, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	if( !client )
		g_hTimerLoad = tmr;
}

public Action TimerLoadBeams(Handle timer, any client)
{
	if( client )
	{
		client = GetClientOfUserId(client);
		if( !client || IsClientInGame(client) == false ) return Plugin_Stop;
	}

	g_iLoopCount++;

	bool bContLoad = true;
	int p, index;
	int max = g_hMapList.Length;
	float vPos[3], vPos2[3];

	while( bContLoad )
	{
		if( g_iLoadPreset[client] != INT_PRE_START )
		{
			bContLoad = false;
			return Plugin_Continue;
		}

		// Stop - max loading at once
		if( HasReachedMax(client) )
		{
			bContLoad = false;
			g_iLoadCount[client] = 0;
			return Plugin_Continue;
		}

		p = g_iLoadIndex[client];
		g_iLoadIndex[client]++;

		// Stop - all ents spawned
		if( p >= max )
		{
			g_bLoadingLate[client] = false;
			g_iLoadCount[client] = 0;
			g_hTimerLoad = null;
			g_fLoadTime = GetTickedTime() - g_fLoadTick;
			LogAction(-1, -1, "[Neon Beams]: (%d)%N Entries %d. Loops %d. Total %d/%d. Max %d/%d & %d/%d. Finished at %0.1f. Took %f seconds.", client, client, max, g_iLoopCount, g_iTotalBeam, g_iTotalPart, g_iCvarCfgMax, MAX_ENTITIES, g_iCvarMaxB, g_iCvarMaxP, GetTickedTime(), g_fLoadTime);
			return Plugin_Stop;
		}

		// Load data
		char sTemp[LEN_VBIG];
		char sBuff[7][LEN_HALF];

		g_hMapList.GetString(p, sTemp, sizeof(sTemp));
		ExplodeString(sTemp, " ", sBuff, 7, LEN_HALF);

		vPos[0] = StringToFloat(sBuff[1]);
		vPos[1] = StringToFloat(sBuff[2]);
		vPos[2] = StringToFloat(sBuff[3]);
		vPos2[0] = StringToFloat(sBuff[4]);
		vPos2[1] = StringToFloat(sBuff[5]);
		vPos2[2] = StringToFloat(sBuff[6]);

		if( IsNumericString(sBuff[0]) )
		{
			SpawnBeam(vPos, vPos2, StringToInt(sBuff[0]), client ? client : -1 ); // -1 indicates server loading, else late loading client
		} else {
			index = GetPresetIndex(sBuff[0]);

			if( index == -1 )
			{
				LogError("Failed loading preset '%s'. Add the missing preset or remove entry from this maps config. Possible spaces in preset name?", sBuff[0]);
			} else {
				g_iLoadPreset[0] = INT_PRE_START;
				LoadPreset(index, vPos, vPos2, client ? client : -1);
			}
		}
	}

	return Plugin_Continue;
}



// ====================================================================================================
//					COMMAND - sm_neon_overload - sm_neon_load - sm_neon_stats
// ====================================================================================================
public Action CmdNeonOverLoad(int client, int args)
{
	if( client )
	{
		if( IsBlocked(client) ) return Plugin_Handled;
	}

	if( g_hTimerLoad != null )
	{
		ReplyToCommand(client, "[Neon Beams] Already loading data configs. Please wait.");
		return Plugin_Handled;
	}

	ReplyToCommand(client, "[Neon Beams] Overloading beams...");

	g_iLateLoad = 0;
	g_bLoaded = false;
	LoadBeams();
	return Plugin_Handled;
}

public Action CmdNeonLoad(int client, int args)
{
	if( IsBlocked(client) ) return Plugin_Handled;

	CleanUp();

	if( client )	PrintToChat(client, "%sConfigs reloaded.", CHAT_TAG);
	else			PrintToServer("[Neon] Configs reloaded.");
	return Plugin_Handled;
}

public Action CmdNeonStats(int client, int args)
{
	// [Neon Stats 1/2] Presets 13. Map saved 15. Loop Count 8. Load time 1.59. Total 0/898. Max load 30. Max ents 2048. Max total 8192/8192. Time load/spawn 4.0/0.2.
	// [Neon Stats 2/2] Allow 1. Late 0/3. Round/spawn 1/1. Blocked 0. Loaded 0. Restart 1. Particles: 2

	ReplyToCommand(client, "[Neon Stats 1/2] Presets %d. Map saved %d. Loop Count %d. Load time %0.2f. Total %d/%d. Max load %d. Max ents %d. Max total %d/%d. Time load/spawn %0.1f/%0.1f.", g_hPresetList.Length, g_hMapList.Length, g_iLoopCount, g_fLoadTime, g_iTotalBeam, g_iTotalPart, g_iCvarCfgMax, MAX_ENTITIES, g_iCvarMaxB, g_iCvarMaxP, g_fCvarCfgLoad, g_fCvarCfgTime);
	ReplyToCommand(client, "[Neon Stats 2/2] Allow %d. Late %d/%d. Round %d. Blocked %d. Loaded %d. Restart %d. Particles: %d", g_bCvarAllow, g_iLateLoad, g_iCvarLate, g_iRoundStart, g_iBlocked, g_bLoaded, g_bRoundRestart, g_iAccessParticles);
	return Plugin_Handled;
}

/* For testing late loading
public Action CmdNeonCon(int client, int args)
{
	char temp[53];
	GetCmdArg(1, temp,51);
	g_block = true;
	OnClientPutInServer(StringToInt(temp));
	g_block = false;
	return Plugin_Handled;
}
*/



// ====================================================================================================
//					COMMAND - sm_neon
// ====================================================================================================
public Action CmdNeonMenuMain(int client, int args)
{
	ShowMainMenu(client);
	return Plugin_Handled;
}

void ShowMainMenu(int client)
{
	if( !IsBlocked(client) )
		g_hMenuMain.Display(client, MENU_TIME_FOREVER);
}

public int MainMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_Select )
	{
		if( IsBlocked(client) ) return;
		g_iStretched[client] = 0;

		switch( index )
		{
			case 0:		CmdNeonMenuMap(client, 0);		// Temp Beam
			case 1:		CmdNeonMenuSave(client, 0);		// Save Beam
			case 2:		CmdNeonTempPre(client, 0);		// Temp Preset
			case 3:		CmdNeonSavePre(client, 0);		// Save Preset
			case 4:		CmdNeonPaint(client, 0);		// Paint
			case 5:		CmdNeonMenuMap2(client, 0);		// Temp Particle
			case 6:		CmdNeonMenuSave2(client, 0);	// Save Particle
			case 7:		CmdNeonPaint2(client, 0);		// Paint Particle
		}
	}
}



// ====================================================================================================
//					COMMAND - sm_neon_temp / sm_neon_temp2 - sm_neon_save / sm_neon_save2
// ====================================================================================================
public Action CmdNeonMenuMap(int client, int args)
{
	g_iSaveOrTemp[client] = ACTION_MAP_TEMP;
	FncNeonMenuMap(client);
	return Plugin_Handled;
}

public Action CmdNeonMenuMap2(int client, int args)
{
	if( !CheckParticles(client) ) return Plugin_Handled;

	g_iSaveOrTemp[client] = ACTION_MAP_TEMP2;
	FncNeonMenuMap(client);
	return Plugin_Handled;
}

public Action CmdNeonMenuPoint(int client, int args)
{
	if( !CheckParticles(client) ) return Plugin_Handled;

	if( args )
	{
		char temp[8];
		GetCmdArg(1, temp, sizeof(temp));
		g_fDistance[client] = StringToFloat(temp);
	} else {
		g_fDistance[client] = 0.0;
	}

	g_iSaveOrTemp[client] = ACTION_MAP_POINT;
	FncNeonMenuMap(client);
	return Plugin_Handled;
}

public Action CmdNeonMenuPoint2(int client, int args)
{
	if( !CheckParticles(client) ) return Plugin_Handled;

	if( args )
	{
		char temp[8];
		GetCmdArg(1, temp, sizeof(temp));
		g_fDistance[client] = StringToFloat(temp);
	} else {
		g_fDistance[client] = 0.0;
	}

	g_iSaveOrTemp[client] = ACTION_MAP_POINT2;
	FncNeonMenuMap(client);
	return Plugin_Handled;
}

public Action CmdNeonMenuPoints(int client, int args)
{
	if( args )
	{
		char temp[8];
		GetCmdArg(1, temp, sizeof(temp));
		g_fDistance[client] = StringToFloat(temp);
	} else {
		g_fDistance[client] = 0.0;
	}

	g_iSaveOrTemp[client] = ACTION_MAP_POINTS;
	FncNeonMenuMap(client);
	return Plugin_Handled;
}

public Action CmdNeonMenuPoints2(int client, int args)
{
	if( !CheckParticles(client) ) return Plugin_Handled;

	if( args )
	{
		char temp[8];
		GetCmdArg(1, temp, sizeof(temp));
		g_fDistance[client] = StringToFloat(temp);
	} else {
		g_fDistance[client] = 0.0;
	}

	g_iSaveOrTemp[client] = ACTION_MAP_POINTS2;
	FncNeonMenuMap(client);
	return Plugin_Handled;
}

public Action CmdNeonPresetS(int client, int args)
{
	if( args )
	{
		char temp[8];
		GetCmdArg(1, temp, sizeof(temp));
		g_fDistance[client] = StringToFloat(temp);
	} else {
		g_fDistance[client] = 0.0;
	}

	g_iSaveOrTemp[client] = ACTION_EYE_POINTS;
	FncNeonPreset(client);
	return Plugin_Handled;
}

public Action CmdNeonPreset3(int client, int args)
{
	if( args )
	{
		char temp[8];
		GetCmdArg(1, temp, sizeof(temp));
		g_fDistance[client] = StringToFloat(temp);
	} else {
		g_fDistance[client] = 0.0;
	}

	g_iSaveOrTemp[client] = ACTION_EYE_POINT;
	FncNeonPreset(client);
	return Plugin_Handled;
}

public Action CmdNeonMenuSave(int client, int args)
{
	g_iSaveOrTemp[client] = ACTION_MAP_SAVE;
	FncNeonMenuMap(client);
	return Plugin_Handled;
}

public Action CmdNeonMenuSave2(int client, int args)
{
	if( !CheckParticles(client) ) return Plugin_Handled;

	g_iSaveOrTemp[client] = ACTION_MAP_SAVE2;
	FncNeonMenuMap(client);
	return Plugin_Handled;
}

void FncNeonMenuMap(int client)
{
	if( !client )
	{
		ReplyToCommand(client, "[Neon Beams] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return;
	}

	if( IsBlocked(client) ) return;

	g_vTargetPos[client] = view_as<float>({ 0.0, 0.0, 0.0 });
	g_iSaveIndex[client] = 0;


	switch( g_iSaveOrTemp[client] )
	{
		case ACTION_MAP_TEMP, ACTION_MAP_POINT:
		{
			g_hMenuMapSpawn.SetTitle("Neon - Temp Beam");
			g_hMenuMapSpawn.Display(client, MENU_TIME_FOREVER);
		}
		case ACTION_MAP_TEMP2, ACTION_MAP_POINT2:
		{
			g_hMenuMapSpawn2.SetTitle("Neon - Temp Particle");
			g_hMenuMapSpawn2.Display(client, MENU_TIME_FOREVER);
		}
		case ACTION_MAP_SAVE, ACTION_MAP_POINTS:
		{
			g_hMenuMapSpawn.SetTitle("Neon - Save Beam");
			g_hMenuMapSpawn.Display(client, MENU_TIME_FOREVER);
		}
		case ACTION_MAP_SAVE2, ACTION_MAP_POINTS2:
		{
			g_hMenuMapSpawn2.SetTitle("Neon - Save Particle");
			g_hMenuMapSpawn2.Display(client, MENU_TIME_FOREVER);
		}
	}
}

public int MapSpawnMenuHandler(Menu menu, MenuAction action, int client, int type)
{
	if( action == MenuAction_Cancel )
	{
		if( type == MenuCancel_ExitBack )
			ShowMainMenu(client);
	}
	else if( action == MenuAction_Select )
	{
		if( IsBlocked(client) ) return;

		char sTemp[12];
		menu.GetItem(type, sTemp, sizeof(sTemp));
		type = StringToInt(sTemp);
		SaveBeam(client, type);

		switch( g_iSaveOrTemp[client] )
		{
			case ACTION_MAP_TEMP, ACTION_MAP_POINT:			menu.SetTitle("Neon - Temp Beam");
			case ACTION_MAP_SAVE, ACTION_MAP_POINTS:		menu.SetTitle("Neon - Save Beam");
			case ACTION_MAP_TEMP2, ACTION_MAP_POINT2:		menu.SetTitle("Neon - Temp Particle");
			case ACTION_MAP_SAVE2, ACTION_MAP_POINTS2:		menu.SetTitle("Neon - Save Particle");
		}

		menu.DisplayAt(client, menu.Selection, MENU_TIME_FOREVER);
	}
}

void SaveBeam(int client, int type)
{
	// Setup
	float vPos[3];
	switch( g_iSaveOrTemp[client] )
	{
		case ACTION_MAP_POINT, ACTION_MAP_POINT2, ACTION_MAP_POINTS, ACTION_MAP_POINTS2:
		{
			GetClientEyePosition(client, vPos);

			if( g_fDistance[client] )
			{
				float vAng[3], vDir[3];
				GetClientEyeAngles(client, vDir);
				GetAngleVectors(vDir, vAng, NULL_VECTOR, NULL_VECTOR);
				NormalizeVector(vAng, vAng);
				vPos[0] += (vAng[0] * g_fDistance[client]);
				vPos[1] += (vAng[1] * g_fDistance[client]);
				vPos[2] += (vAng[2] * g_fDistance[client]);
			}
		}
		default:
		{
			if( SetupBeamPos(client, vPos) == false )
			{
				PrintToChat(client, "%sInvalid location. Try again.", CHAT_TAG);
				return;
			}
		}
	}

	if( g_iSaveIndex[client] == 0 )
	{
		if( g_iStretched[client] == 0 )
		{
			g_iStretched[client] = 1;
			PrintToChat(client, "%sChoose next location to stretch between.", CHAT_TAG);
		}
		g_iSaveIndex[client] = type;
		g_vTargetPos[client] = vPos;

		return;
	}

	// Spawn
	float vPos2[3];
	vPos2 = g_vTargetPos[client];
	g_iSaveIndex[client] = 0;
	g_vTargetPos[client] = view_as<float>({ 0.0, 0.0, 0.0 });

	SpawnBeam(vPos, vPos2, type);

	// Exit if only temp beam
	switch( g_iSaveOrTemp[client] )
	{
		case ACTION_MAP_TEMP, ACTION_MAP_TEMP2, ACTION_MAP_POINT, ACTION_MAP_POINT2:
		{
			return;
		}
	}

	// Save to map for auto spawning
	CreateMapConfig();

	char sTemp[LEN_FULL];
	Format(sTemp, sizeof(sTemp), "%d %f %f %f %f %f %f", type, vPos[0], vPos[1], vPos[2], vPos2[0], vPos2[1], vPos2[2]);
	g_hMapList.PushString(sTemp);

	SaveMapConfig();
}

void CreateMapConfig()
{
	if( g_hMapList.Length == 0 )
	{
		CreateFolders();

		char sPath[PLATFORM_MAX_PATH];
		GetCurrentMap(sPath, sizeof(sPath));
		BuildPath(Path_SM, sPath, sizeof(sPath), "%s/%s/%s.cfg", CONFIG_FOLDER, CONFIG_PATH_M, sPath);

		if( !FileExists(sPath) )
		{
			File hCfg = OpenFile(sPath, "w");
			hCfg.WriteLine("");
			delete hCfg;
		}
	}
}



// ====================================================================================================
//					COMMAND - sm_neon_preset / sm_neon_preset2 - Create or Edit Preset
// ====================================================================================================
public Action CmdNeonPreset(int client, int args)
{
	g_iSaveOrTemp[client] = ACTION_PRE_CONF;
	FncNeonPreConfig(client, args);
	return Plugin_Handled;
}

public Action CmdNeonPreset2(int client, int args)
{
	if( !CheckParticles(client) ) return Plugin_Handled;

	g_iSaveOrTemp[client] = ACTION_PRE_CONF2;
	FncNeonPreConfig(client, args);
	return Plugin_Handled;
}

// Create a new preset config to save beams to
void FncNeonPreConfig(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Neon Beams] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return;
	}

	if( IsBlocked(client) ) return;

	g_vTargetPos[client] = view_as<float>({ 0.0, 0.0, 0.0 });
	g_iSaveIndex[client] = 0;

	if( args == 0 )
	{
		char sTemp[4];
		Format(sTemp, sizeof(sTemp), g_iSaveOrTemp[client] == ACTION_PRE_CONF2 ? "2" : "");
		PrintToChat(client, "%sUsage: sm_neon_preset%s <optional file name/unique name> to create a new config. Or sm_neon_preset%s <preset name> to edit.", CHAT_TAG, sTemp, sTemp);
	}
	else
	{
		if( g_iLoadPreset[client] != INT_PRE_START )
		{
			PrintToChat(client, "%sA preset is already loading, please wait.", CHAT_TAG);
			return;
		}

		// validate file name
		char sName[LEN_FULL];
		GetCmdArgString(sName, sizeof(sName));
		ReplaceString(sName, sizeof(sName), " ", "_");

		if( IsCharNumeric(sName[0]) )
		{
			g_iSaveOrTemp[client] = 0;
			PrintToChat(client, "%sPreset name cannot start with a number.", CHAT_TAG);
			return;
		}

		if( strlen(sName) < 2 )
		{
			g_iSaveOrTemp[client] = 0;
			PrintToChat(client, "%sPreset name must be longer than 1 character.", CHAT_TAG);
			return;
		}

		char sFile[LEN_HALF];
		char sPath[PLATFORM_MAX_PATH];
		int pos = FindCharInString(sName, '/');
		if( pos == -1 )
		{
			strcopy(sFile, sizeof(sFile), CONFIG_PRESET);
		} else {
			strcopy(sFile, sizeof(sFile), sName);
			strcopy(sName, sizeof(sName), sName[pos+1]);
			sFile[pos] = '\x0';
		}

		char sTemp[LEN_HALF];
		strcopy(sTemp, sizeof(sTemp), sName);
		ReplaceString(sTemp, sizeof(sTemp), " ", "_");
		g_iLoadCount[client] = 0;

		// Save
		int index = GetPresetIndex(sTemp);
		if( index == -1 )
		{
			// Save to a new preset file
			CreateFolders();

			BuildPath(Path_SM, sPath, sizeof(sPath), "%s/%s/%s.cfg", CONFIG_FOLDER, CONFIG_PATH_P, sFile);

			if( !FileExists(sPath) )
			{
				File hCfg = OpenFile(sPath, "w");
				hCfg.WriteLine("");
				delete hCfg;

				char sName2[PLATFORM_MAX_PATH];
				strcopy(sName2, sizeof(sName2), sFile);
				ReplaceString(sName2, sizeof(sName2), "_", " ");
				g_hMenuPresetList.AddItem(sFile, sName2);
			}

			// Save
			ArrayList aHand;
			aHand = new ArrayList(ByteCountToCells(LEN_FULL));
			g_hPresetList.Push(aHand);
			aHand.PushString(sTemp);
			aHand.PushString(sFile);

			PrintToChat(client, "%sStarted saving a new preset named '\x05%s\x01'", CHAT_TAG, sName);

			g_iStretched[client] = 0;
			g_vPresetStart[client] = view_as<float>({ 0.0, 0.0, 0.0 });
		} else {
			// Edit a preset file
			if( pos != -1 ) // Specific file
			{
				ArrayList aHand = g_hPresetList.Get(index);
				aHand.GetString(1, sPath, sizeof(sPath));

				if( strcmp(sFile, sPath, false) ) // File doesn't match selected name
				{
					PrintToChat(client, "%sChoose a unique name. A preset using the file/name of '\x05%s/%s\x01' already exists.", CHAT_TAG, sPath, sTemp);
					return;
				}
			}

			float vPos[3];
			float vAng[3];

			if( SetupBeamPos(client, vPos, vAng) == false )
			{
				PrintToChat(client, "%sInvalid position, please try again.", CHAT_TAG, sName);
			} else {
				if( AngleCheck(client, vAng) == false ) return;

				g_vPresetStart[client] = vPos;
				g_iLoadPreset[client] = INT_PRE_START;
				LoadPreset(index, vAng, vPos);
				PrintToChat(client, "%sSelected preset '\x05%s\x01' for editing.", CHAT_TAG, sName);
			}
		}

		strcopy(g_sPresetConfig[client], LEN_HALF, sTemp);

		if( g_iSaveOrTemp[client] == ACTION_PRE_CONF )
			g_hMenuPreSpawn.Display(client, MENU_TIME_FOREVER);
		else
			g_hMenuPreSpawn2.Display(client, MENU_TIME_FOREVER);
	}
}

bool AngleCheck(int client, float vAng[3])
{
	bool rtn = true;
	float deg = RadToDeg(vAng[1]);

	if( deg != 0.0 && deg != 90.0 && deg != 180.0 && deg != 270.0 )
	{
		rtn = false;
		PrintToChat(client, "%s\x05Error: \x01Surface does not align with 0, 90, 180 or 270 degrees to the map (%f).", CHAT_TAG, deg);
	}

	if( vAng[0] != 0.0 && vAng[2] != 0.0 )
	{
		rtn = false;
		PrintToChat(client, "%s\x05Error: \x01Surface must be perfectly vertical and not angled (%0.1f/%0.1f).", CHAT_TAG, vAng[0], vAng[2]);
	}

	return rtn;
}



// ====================================================================================================
//					COMMANDS -	sm_neon_preset_temp		/	sm_neon_preset_save
//									Temp Preset			/	Save Preset to Map
// ====================================================================================================
public Action CmdNeonTempPre(int client, int args)
{
	g_iSaveOrTemp[client] = ACTION_PRE_TEMP;
	FncNeonPreset(client);
	return Plugin_Handled;
}

public Action CmdNeonSavePre(int client, int args)
{
	g_iSaveOrTemp[client] = ACTION_PRE_SAVE;
	FncNeonPreset(client);
	return Plugin_Handled;
}

void FncNeonPreset(int client)
{
	if( !client )
	{
		ReplyToCommand(client, "[Neon Beams] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return;
	}

	if( IsBlocked(client) ) return;

	g_vTargetPos[client] = view_as<float>({ 0.0, 0.0, 0.0 });
	g_iSaveIndex[client] = 0;

	if( g_hPresetList.Length == 0 )
	{
		PrintToChat(client, "%sNo preset list. Usage: sm_neon_preset%s <optional file name/unique name> to create a new config.", CHAT_TAG, g_iSaveOrTemp[client] == ACTION_PRE_CONF2 ? "2" : "");
	} else {
		if( g_hMenuPresetList.ItemCount == 1 )
		{
			ShowPresetList(client, 0);
		} else {
			if( g_iSaveOrTemp[client] == ACTION_PRE_TEMP || g_iSaveOrTemp[client] == ACTION_EYE_POINT )
				g_hMenuPresetList.SetTitle("Neon - Temp Preset");
			else
				g_hMenuPresetList.SetTitle("Neon - Save Preset");

			g_hMenuPresetList.Display(client, MENU_TIME_FOREVER);
		}
	}
}

void ShowPresetList(int client, int index)
{
	delete g_hClientPreMenu[client];

	Menu menu;
	menu = new Menu(MenuPreListHandler);
	g_hClientPreMenu[client] = menu;

	int size = g_hPresetList.Length;
	ArrayList aHand;
	char sPath[LEN_HALF];
	char sName[LEN_HALF];
	char sTest[LEN_HALF];

	g_hMenuPresetList.GetItem(index, sTest, sizeof(sTest));

	for( int i = 0; i < size; i++ )
	{
		aHand = g_hPresetList.Get(i);
		aHand.GetString(0, sName, sizeof(sName));
		aHand.GetString(1, sPath, sizeof(sPath));

		if( strcmp(sPath, sTest, false) == 0 )
		{
			IntToString(i, sPath, sizeof(sPath));
			ReplaceString(sName, sizeof(sName), "_", " ");
			menu.AddItem(sPath, sName);
		}
	}

	menu.ExitBackButton = true;

	if( g_iSaveOrTemp[client] == ACTION_PRE_TEMP || g_iSaveOrTemp[client] == ACTION_EYE_POINT )
		menu.SetTitle("Neon - Temp Preset");
	else
		menu.SetTitle("Neon - Save Preset");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuPreListHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
		{
			if( g_hMenuPresetList.ItemCount == 1 )
				ShowMainMenu(client);
			else
				FncNeonPreset(client);
		}
	}
	else if( action == MenuAction_Select )
	{
		if( IsBlocked(client) ) return;

		if( g_iSaveOrTemp[client] == ACTION_PRE_TEMP || g_iSaveOrTemp[client] == ACTION_EYE_POINT )
			menu.SetTitle("Neon - Temp Preset");
		else
			menu.SetTitle("Neon - Save Preset");
		menu.DisplayAt(client, menu.Selection, MENU_TIME_FOREVER);

		if( g_iLoadPreset[client] != INT_PRE_START )
		{
			PrintToChat(client, "%sA preset is already loading, please wait.", CHAT_TAG);
			return;
		}

		float vPos[3], vAng[3];
		if( g_iSaveOrTemp[client] == ACTION_EYE_POINT || g_iSaveOrTemp[client] == ACTION_EYE_POINTS )
		{
			GetClientEyePosition(client, vPos);
			GetClientEyeAngles(client, vAng);

			if( g_fDistance[client] )
			{
				float vDir[3];
				GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);
				NormalizeVector(vDir, vDir);
				vPos[0] += (vDir[0] * g_fDistance[client]);
				vPos[1] += (vDir[1] * g_fDistance[client]);
				vPos[2] += (vDir[2] * g_fDistance[client]);

				vAng[0] = DegToRad(vAng[0]);
				vAng[1] = DegToRad(vAng[1]);
				vAng[2] = DegToRad(vAng[2]);
			} else {
				vAng[0] = DegToRad(vAng[0]);
				vAng[1] = DegToRad(vAng[1]);
				vAng[2] = DegToRad(vAng[2]);
			}
		} else {
			if( SetupBeamPos(client, vPos, vAng) == false )
			{
				PrintToChat(client, "%sError: You're not pointing at a valid location.", CHAT_TAG);
				return;
			}
		}

		g_iLoadPreset[client] = INT_PRE_START;
		g_iLoadCount[client] = 0;
		char sIndex[8];
		menu.GetItem(index, sIndex, sizeof(sIndex));
		index = StringToInt(sIndex);
		LoadPreset(index, vAng, vPos);

		// Save preset to map for auto-spawn
		if( g_iSaveOrTemp[client] == ACTION_PRE_SAVE || g_iSaveOrTemp[client] == ACTION_EYE_POINTS )
		{
			CreateMapConfig();

			char sTemp[LEN_VBIG];
			ArrayList aHand = g_hPresetList.Get(index);
			aHand.GetString(0, sTemp, sizeof(sTemp));

			Format(sTemp, sizeof(sTemp), "%s %f %f %f %f %f %f", sTemp, vAng[0], vAng[1], vAng[2], vPos[0], vPos[1], vPos[2]);
			g_hMapList.PushString(sTemp);

			SaveMapConfig();
		}
	}
}

public int PreListMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMainMenu(client);
	}
	else if( action == MenuAction_Select )
	{
		ShowPresetList(client, index);
	}
}

public int PreSpawnMenuHandler(Menu menu, MenuAction action, int client, int type)
{
	if( action == MenuAction_Cancel )
	{
		if( type == MenuCancel_ExitBack )
			ShowMainMenu(client);
	}
	else if( action == MenuAction_Select )
	{
		if( IsBlocked(client) ) return;

		char sTemp[12];
		menu.GetItem(type, sTemp, sizeof(sTemp));
		type = StringToInt(sTemp);
		SavePreset(client, type);

		menu.DisplayAt(client, menu.Selection, MENU_TIME_FOREVER);
	}
}

void SavePreset(int client, int type)
{
	// Setup
	float vPos[3], vAng[3];
	if( SetupBeamPos(client, vPos, vAng) == false )
	{
		PrintToChat(client, "%sInvalid location. Try again.", CHAT_TAG);
		return;
	}

	if( g_iSaveIndex[client] == 0 )
	{
		if( g_iStretched[client] == 0 )
		{
			if( AngleCheck(client, vAng) == false ) return;

			g_iStretched[client] = 1;
			PrintToChat(client, "%sChoose next location to stretch between.", CHAT_TAG);
		}
		g_iSaveIndex[client] = type;
		g_vTargetPos[client] = vPos;

		if( g_vPresetStart[client][0] == 0.0 && g_vPresetStart[client][1] == 0.0 && g_vPresetStart[client][2] == 0.0 )
		{
			g_vPresetStart[client] = vPos;
		}
		return;
	}

	// Spawn
	float vPos2[3];
	vPos2 = g_vTargetPos[client];
	g_iSaveIndex[client] = 0;
	g_vTargetPos[client] = view_as<float>({ 0.0, 0.0, 0.0 });

	SpawnBeam(vPos, vPos2, type);

	// Normalize angles for config
	float angleX;
	float angleY;
	float angleZ;

	if( vAng[1] != 0.0 )
		vAng[1] *= -1.0;

	angleX = vAng[0];
	angleY = vAng[1];
	angleZ = vAng[2];

	// Normalize origin for config
	vPos[0] -= g_vPresetStart[client][0];
	vPos[1] -= g_vPresetStart[client][1];
	vPos[2] -= g_vPresetStart[client][2];
	vPos2[0] -= g_vPresetStart[client][0];
	vPos2[1] -= g_vPresetStart[client][1];
	vPos2[2] -= g_vPresetStart[client][2];

	// Thanks to "Don't Fear The Reaper" for the Rotation Matrix:
	vAng[0] = (vPos[0] * Cosine(angleX) * Cosine(angleY)) - (vPos[1] * Cosine(angleZ) * Sine(angleY)) + (vPos[1] * Sine(angleZ) * Sine(angleX) * Cosine(angleY)) + (vPos[2] * Sine(angleZ) * Sine(angleY)) + (vPos[2] * Cosine(angleZ) * Sine(angleX) * Cosine(angleY));
	vAng[1] = (vPos[0] * Cosine(angleX) * Sine(angleY)) + (vPos[1] * Cosine(angleZ) * Cosine(angleY)) + (vPos[1] * Sine(angleZ) * Sine(angleX) * Sine(angleY)) - (vPos[2] * Sine(angleZ) * Cosine(angleY)) + (vPos[2] * Cosine(angleZ) * Sine(angleX) * Sine(angleY));
	vAng[2] = (-1.0 * vPos[0] * Sine(angleX)) + (vPos[1] * Sine(angleZ) * Cosine(angleX)) + (vPos[2] * Cosine(angleZ) * Cosine(angleX));
	vPos = vAng;

	vAng[0] = (vPos2[0] * Cosine(angleX) * Cosine(angleY)) - (vPos2[1] * Cosine(angleZ) * Sine(angleY)) + (vPos2[1] * Sine(angleZ) * Sine(angleX) * Cosine(angleY)) + (vPos2[2] * Sine(angleZ) * Sine(angleY)) + (vPos2[2] * Cosine(angleZ) * Sine(angleX) * Cosine(angleY));
	vAng[1] = (vPos2[0] * Cosine(angleX) * Sine(angleY)) + (vPos2[1] * Cosine(angleZ) * Cosine(angleY)) + (vPos2[1] * Sine(angleZ) * Sine(angleX) * Sine(angleY)) - (vPos2[2] * Sine(angleZ) * Cosine(angleY)) + (vPos2[2] * Cosine(angleZ) * Sine(angleX) * Sine(angleY));
	vAng[2] = (-1.0 * vPos2[0] * Sine(angleX)) + (vPos2[1] * Sine(angleZ) * Cosine(angleX)) + (vPos2[2] * Cosine(angleZ) * Cosine(angleX));
	vPos2 = vAng;

	// Save to array
	ArrayList aHand;
	int index = GetPresetIndex(g_sPresetConfig[client]);
	if( index == -1 )
	{
		PrintToChat(client, "%sSomething bad happened. Please report.", CHAT_TAG);
		LogError("Something bad happened. Please report.");
		return;
	} else {
		aHand = g_hPresetList.Get(index);
	}

	char sTemp[LEN_FULL];
	Format(sTemp, sizeof(sTemp), "%d %f %f %f %f %f %f", type, vPos[0], vPos[1], vPos[2], vPos2[0], vPos2[1], vPos2[2]);
	aHand.PushString(sTemp);

	SavePreConfig(index);
}



// ====================================================================================================
//					COMMAND - sm_neon_wipe - sm_neon_del - sm_neon_delpre
// ====================================================================================================
public Action CmdNeonWipe(int client, int args)
{
	char sPath[PLATFORM_MAX_PATH];
	GetCurrentMap(sPath, sizeof(sPath));
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s/%s/%s.cfg", CONFIG_FOLDER, CONFIG_PATH_M, sPath);

	if( FileExists(sPath) )
	{
		DeleteFile(sPath);

		if( client != -1 ) // Used from SaveMapConfig
		{
			if( client )
				PrintToChat(client, "%sDeleted config: \"%s\".", CHAT_TAG, sPath);
			else
				PrintToServer("[Neon Beams] Deleted config: \"%s\".", sPath);
		}
	} else {
		if( client != -1 )
		{
			if( client )
				PrintToChat(client, "%sNo config to delete: \"%s\".", CHAT_TAG, sPath);
			else
				PrintToServer("[Neon Beams] No config to delete: \"%s\".", sPath);
		}
	}

	return Plugin_Handled;
}

public Action CmdNeonMapDel(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Neon Beams] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}

	if( !g_bCvarAllow )
	{
		if( client )
			PrintToChat(client, "%sPlugin has been turned off.", CHAT_TAG);
		else
			PrintToServer("[Neon Beams] Plugin has been turned off.");
		return Plugin_Handled;
	}

	if( g_iBlocked == 3 )
	{
		PrintToChat(client, "%sDeleting blocked. There is a problem with the maps config, please see error log.", CHAT_TAG);
		return Plugin_Handled;
	}

	int size = g_hMapList.Length;
	if( size )
	{
		g_hMapList.Erase(size - 1);
		SaveMapConfig();
		PrintToChat(client, "%sDeleted the last Beam or Preset saved to this maps config.", CHAT_TAG);
	} else {
		PrintToChat(client, "%sThere are no Beams or Presets saved to this map.", CHAT_TAG);
	}

	return Plugin_Handled;
}

public Action CmdNeonPreDel(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Neon Beams] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}

	if( !g_bCvarAllow )
	{
		if( client )
			PrintToChat(client, "%sPlugin has been turned off.", CHAT_TAG);
		else
			PrintToServer("[Neon Beams] Plugin has been turned off.");
		return Plugin_Handled;
	}

	if( g_iBlocked == 3 )
	{
		PrintToChat(client, "%sDeleting blocked. There is a problem with the maps config, please see error log.", CHAT_TAG);
		return Plugin_Handled;
	}

	// Delete last placed beams from preset
	if( args == 0 )
	{
		if(
			g_iSaveOrTemp[client] == ACTION_PRE_SAVE ||
			g_iSaveOrTemp[client] == ACTION_PRE_TEMP ||
			g_iSaveOrTemp[client] == ACTION_EYE_POINT ||
			g_iSaveOrTemp[client] == ACTION_EYE_POINTS ||
			g_iSaveOrTemp[client] == ACTION_PRE_CONF ||
			g_iSaveOrTemp[client] == ACTION_PRE_CONF2
		)
		{
			int index = GetPresetIndex(g_sPresetConfig[client]);
			if( index == -1 )
			{
				PrintToChat(client, "%sCannot find the preset '\x05%s\x01' to delete.", CHAT_TAG, g_sPresetConfig[client]);
				return Plugin_Handled;
			} else {
				ArrayList aHand = g_hPresetList.Get(index);
				int size = aHand.Length;
				if( size )
				{
					aHand.Erase(size - 1);
					SavePreConfig(index);
					PrintToChat(client, "%sDeleted the last placed Beam from '\x05%s\x01' preset.", CHAT_TAG, g_sPresetConfig[client]);
				} else {
					PrintToChat(client, "%sThere is nothing to delete from '\x05%s\x01' preset.", CHAT_TAG, g_sPresetConfig[client]);
				}
			}
		}
		return Plugin_Handled;
	}

	// Delete specified preset or config file
	char sName[LEN_HALF];
	GetCmdArgString(sName, sizeof(sName));
	ReplaceString(sName, sizeof(sName), " ", "_");
	int index = GetPresetIndex(sName);

	if( index == -1 )
	{
		PrintToChat(client, "%sCannot find the preset '\x05%s\x01' to delete.", CHAT_TAG, sName);
	} else {
		char sPath[PLATFORM_MAX_PATH];
		char sTemp[LEN_HALF];

		ArrayList aHand = g_hPresetList.Get(index);
		aHand.GetString(1, sTemp, sizeof(sTemp));
		g_hPresetList.Erase(index);

		// Erase file if required
		int count;
		int size = g_hPresetList.Length;
		if( size != 0 )
		{
			for( int p = 0; p < size; p++ )
			{
				aHand = g_hPresetList.Get(p);
				aHand.GetString(1, sPath, sizeof(sPath));

				if( strcmp(sTemp, sPath, false) == 0 )
				{
					count++;
					index = p;
				}
			}
		}

		if( count > 0 )
		{
			PrintToChat(client, "%sDeleted preset '\x05%s\x01'", CHAT_TAG, sName);
			SavePreConfig(index);
		} else {
			// Erase from preset list if deleting last entry in file
			for( int i = 0; i < g_hMenuPresetList.ItemCount; i++ )
			{
				g_hMenuPresetList.GetItem(i, sPath, sizeof(sPath));
				if( strcmp(sPath, sTemp) == 0 )
				{
					g_hMenuPresetList.RemoveItem(i);
					break;
				}
			}

			BuildPath(Path_SM, sPath, sizeof(sPath), "%s/%s/%s.cfg", CONFIG_FOLDER, CONFIG_PATH_P, sTemp);
			if( !FileExists(sPath) || !DeleteFile(sPath) )
			{
				LogError("Failed to delete preset config file '%s'.", sPath);
				PrintToChat(client, "%sUnable to find preset config file '\x05%s\x01'", CHAT_TAG, sName);
			} else {
				PrintToChat(client, "%sDeleted preset file '\x05%s\x01'", CHAT_TAG, sName);
			}
		}
	}

	return Plugin_Handled;
}



// ====================================================================================================
//					COMMAND - sm_neon_paint
// ====================================================================================================
public Action CmdNeonPaint(int client, int args)
{
	g_iSaveOrTemp[client] = ACTION_PAINTING;
	FncNeonPaint(client);
	return Plugin_Handled;
}

public Action CmdNeonPaint2(int client, int args)
{
	if( !CheckParticles(client) ) return Plugin_Handled;

	g_iSaveOrTemp[client] = ACTION_PAINTING2;
	FncNeonPaint(client);
	return Plugin_Handled;
}

void FncNeonPaint(int client)
{
	if( !client )
	{
		ReplyToCommand(client, "[Neon Beams] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
	} else {
		if( IsBlocked(client) ) return;

		g_vTargetPos[client] = view_as<float>({ 0.0, 0.0, 0.0 });
		g_iSaveIndex[client] = 0;

		char sTemp[12];
		if( g_iSaveOrTemp[client] == ACTION_PAINTING )
		{
			g_hMenuPaint.GetItem(1, sTemp, sizeof(sTemp));
			g_iSaveIndex[client] = StringToInt(sTemp);
			g_hMenuPaint.Display(client, MENU_TIME_FOREVER);
		}
		else
		{
			g_hMenuPaint2.GetItem(1, sTemp, sizeof(sTemp));
			g_iSaveIndex[client] = StringToInt(sTemp);
			g_hMenuPaint2.Display(client, MENU_TIME_FOREVER);
		}
	}
}

public int MenuPaintHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_Cancel || action == MenuAction_End )
	{
		if( action == MenuAction_Cancel )
			KillPainting(client);
	}
	else if( action == MenuAction_Select )
	{
		if( IsBlocked(client) )
		{
			KillPainting(client);
			return;
		}

		menu.DisplayAt(client, menu.Selection, MENU_TIME_FOREVER);

		if( index == 0 )
		{
			if( !KillPainting(client) )
			{
				g_hPaintTimer[client] = CreateTimer(g_fCvarPaint, TimerPaint, GetClientUserId(client), TIMER_REPEAT);
				TimerPaint(null, GetClientUserId(client));
			}
		}
		else
		{
			char sTemp[12];
			if( g_iSaveOrTemp[client] == ACTION_PAINTING )
				g_hMenuPaint.GetItem(index, sTemp, sizeof(sTemp));
			else
				g_hMenuPaint2.GetItem(index, sTemp, sizeof(sTemp));
			index = StringToInt(sTemp);
			g_iSaveIndex[client] = index;
		}
	}
}

bool KillPainting(int client)
{
	if( g_hPaintTimer[client] != null )
	{
		delete g_hPaintTimer[client];
		g_vTargetPos[client] = view_as<float>({ 0.0, 0.0, 0.0 });
		return true;
	}
	return  false;
}

public Action TimerPaint(Handle timer, any client)
{
	client = GetClientOfUserId(client);
	if( client && IsClientInGame(client) )
	{
		if( IsBlocked(client) )
		{
			g_hPaintTimer[client] = null;
			g_vTargetPos[client] = view_as<float>({ 0.0, 0.0, 0.0 });
			return Plugin_Stop;
		}

		float vPos[3];

		if( SetupBeamPos(client, vPos) == true )
		{
			if( g_vTargetPos[client][0] == 0.0 && g_vTargetPos[client][1] == 0.0 && g_vTargetPos[client][2] == 0.0 )
			{
				g_vTargetPos[client] = vPos;
				return Plugin_Continue;
			}

			SpawnBeam(vPos, g_vTargetPos[client], g_iSaveIndex[client]);

			/* For Testing: Uncomment to save painting data to map config
			char sTemp[LEN_FULL];
			Format(sTemp, sizeof(sTemp), "%d %f %f %f %f %f %f", g_iSaveIndex[client], vPos[0], vPos[1], vPos[2], g_vTargetPos[client][0], g_vTargetPos[client][1], g_vTargetPos[client][2]);
			g_hMapList.PushString(sTemp);
			SaveMapConfig();
			// */

			g_vTargetPos[client] = vPos;
		}
	} else {
		return Plugin_Stop;
	}
	return Plugin_Continue;
}



// =======================================================================================
// FORTSPAWNER
// =======================================================================================
//---------------------------------------------------------
// the filter function for TR_TraceRayFilterEx
//---------------------------------------------------------
public bool TraceEntityFilterPlayers( int entity, int contentsMask, any data )
{
	return entity > MaxClients && entity != data;
}

//---------------------------------------------------------
// do a specific rotation on the given angles
//---------------------------------------------------------
void RotateYaw(float angles[3], float degree)
{
	float direction[3], normal[3];
	GetAngleVectors( angles, direction, NULL_VECTOR, normal );

	float sin = Sine( degree * 0.01745329251 );	 // Pi/180
	float cos = Cosine( degree * 0.01745329251 );
	float a = normal[0] * sin;
	float b = normal[1] * sin;
	float c = normal[2] * sin;
	float x = direction[2] * b + direction[0] * cos - direction[1] * c;
	float y = direction[0] * c + direction[1] * cos - direction[2] * a;
	float z = direction[1] * a + direction[2] * cos - direction[0] * b;
	direction[0] = x;
	direction[1] = y;
	direction[2] = z;

	GetVectorAngles( direction, angles );

	float up[3];
	GetVectorVectors( direction, NULL_VECTOR, up );

	float roll = GetAngleBetweenVectors( up, normal, direction );
	angles[2] += roll;
}

//---------------------------------------------------------
// calculate the angle between 2 vectors
// the direction will be used to determine the sign of angle (right hand rule)
// all of the 3 vectors have to be normalized
//---------------------------------------------------------
float GetAngleBetweenVectors(const float vector1[3], const float vector2[3], const float direction[3])
{
	float vector1_n[3], vector2_n[3], direction_n[3], cross[3];
	NormalizeVector( direction, direction_n );
	NormalizeVector( vector1, vector1_n );
	NormalizeVector( vector2, vector2_n );
	float degree = ArcCosine( GetVectorDotProduct( vector1_n, vector2_n ) ) * 57.2957795131;   // 180/Pi
	GetVectorCrossProduct( vector1_n, vector2_n, cross );

	if( GetVectorDotProduct( cross, direction_n ) < 0.0 )
		degree *= -1.0;

	return degree;
}

//---------------------------------------------------------
// get position, angles and normal of aimed location if the parameters are not NULL_VECTOR
// return the index of entity you aimed
//---------------------------------------------------------
int GetClientAimedLocationData( int player, float position[3], float angles[3], float normal[3] )
{
	int index = -1;

	float _origin[3], _angles[3];
	GetClientEyePosition( player, _origin );
	GetClientEyeAngles( player, _angles );

	Handle trace = TR_TraceRayFilterEx( _origin, _angles, MASK_SOLID_BRUSHONLY, RayType_Infinite, TraceEntityFilterPlayers );
	if( !TR_DidHit( trace ) )
	{
		ReplyToCommand( player, "[Neon Beams] Failed to pick the aimed location" );
		index = -1;
	}
	else
	{
		TR_GetEndPosition( position, trace );
		TR_GetPlaneNormal( trace, normal );
		angles[0] = _angles[0];
		angles[1] = _angles[1];
		angles[2] = _angles[2];

		index = TR_GetEntityIndex( trace );
	}

	delete trace;
	return index;
}
// ======================================



bool SetupBeamPos(int client, float vPos[3] = NULL_VECTOR, float vAng[3] = NULL_VECTOR)
{
	float vNorm[3];
	float vNew[3];
	float angleX;
	float angleY;
	float angleZ;

	GetClientEyePosition(client, vNew);
	GetClientEyeAngles(client, vAng);

	Handle trace = TR_TraceRayFilterEx(vNew, vAng, MASK_SHOT, RayType_Infinite, TraceFilter, client);

	if( TR_DidHit(trace) == false )
	{
		delete trace;
		return false;
	}

	TR_GetPlaneNormal(trace, vNorm);
	TR_GetEndPosition(vPos, trace);
	delete trace;
	GetVectorAngles(vNorm, vNew);

	// Surface is 45 degrees to vertical, align to wall only.
	if( vNorm[2] < 0.5 && vNorm[2] > -0.5 )
	{
		angleX = DegToRad(vNew[0]);
		angleY = DegToRad(vNew[1]);
		angleZ = DegToRad(vNew[2]);
	} else {
		// ======================================
		// FORTSPAWNER
		// ======================================
		float position[3], ang_eye[3], ang_ent[3], normal[3];
		GetClientAimedLocationData( client, position, ang_eye, normal );

		NegateVector( normal );
		GetVectorAngles( normal, ang_ent );
		ang_ent[0] += 90.0;

		// the created entity will face a default direction based on ground normal
		// here we will rotate the entity to let it face or back to you
		float cross[3], vec_eye[3], vec_ent[3];
		GetAngleVectors( ang_eye, vec_eye, NULL_VECTOR, NULL_VECTOR );
		GetAngleVectors( ang_ent, vec_ent, NULL_VECTOR, NULL_VECTOR );
		GetVectorCrossProduct( vec_eye, normal, cross );
		float yaw = GetAngleBetweenVectors( vec_ent, cross, normal );

		RotateYaw( ang_ent, yaw + 90.0 );

		position[0] += normal[0] * -3;
		position[1] += normal[1] * -3;
		position[2] += normal[2] * -3;

		vPos[0] = position[0];
		vPos[1] = position[1];
		vPos[2] = position[2];

		// Play with order to test if this fixes the 180 degree upside down problem.
		vNew[0] = ang_ent[2] + 90;
		vNew[1] = ang_ent[1] - 90;
		vNew[2] = ang_ent[0] - 90;

		// Flip 180 on ceilings
		if( RadToDeg(normal[2]) > 0.0 )
			vNew[2] += 180.0;

		angleX = DegToRad(vNew[0]);
		angleY = DegToRad(vNew[1]);
		angleZ = DegToRad(vNew[2]);
	}

	vAng[0] = angleX;
	vAng[1] = angleY;
	vAng[2] = angleZ;

	// Move away from wall
	GetAngleVectors(vNew, vNew, NULL_VECTOR, NULL_VECTOR);
	vPos[0] += vNew[0] * g_fCvarDist;
	vPos[1] += vNew[1] * g_fCvarDist;
	vPos[2] += vNew[2] * g_fCvarDist;
	return true;
}

public bool TraceFilter(int entity, int contentsMask, any client)
{
	return entity != client;
}



// ====================================================================================================
//					CREATE NEON BEAMS
// ====================================================================================================
void SpawnBeam(float vPos[3], float vPos2[3], int type, int client = 0, float time = 0.0)
{
	// L4D2: green, pink curved and red curved particles disappear on round restart, so only re-spawn these. All other Beams and Particles are permanent.
	if( g_bRoundRestart && client == -1 && g_Engine == Engine_Left4Dead2 && type != 3 && type != 8 && type != 9 )
	{
		return;
	}

	// Prevent spawning beams on round restart
	if( client == -1 && g_bRoundRestart && g_iCvarCfgRound != 1 && g_iCvarCfgRound != 3 && type > MAX_RESERVED )
	{
		return;
	}

	// Prevent spawning particles on round restart
	if( client == -1 && g_bRoundRestart && g_iCvarCfgRound < 2 && type <= MAX_RESERVED )
	{
		return;
	}

	// Server is -1 when called from some functions
	if( client == -1 ) client = 0;

	// Only lateload if cvar allows
	bool late;
	if( client && g_bLoadingLate[client] ) // 1 = Beams, 2 = Particles, 3 = Both
	{
		if( !g_iCvarLate || (g_iCvarLate == 1 && type <= MAX_RESERVED) || g_iCvarLate == 2 && type > MAX_RESERVED )
		{
			return;
		} else {
			late = true;
		}
	}

	// Spawn limits - particles
	if( type != 0 && type <= MAX_RESERVED )
	{
		if( g_iTotalPart >= g_iCvarMaxP )
		{
			if( g_iBlocked == 0 )
			{
				LogAction(client, -1, "Spawning blocked, too many Particles. (%d/%d/%d/%d/%d/%d/%d/%d)", g_hMapList.Length, g_iLoopCount, g_iTotalBeam, g_iTotalPart, g_iCvarCfgMax, MAX_ENTITIES, g_iCvarMaxB, g_iCvarMaxP);
				g_iBlocked = 2;
			}
			return;
		}

		if( !late )
			g_iTotalPart++;
	}

	// Spawn limits - beams
	if( type == 0 || type > MAX_RESERVED )
	{
		if( g_iTotalBeam >= g_iCvarMaxB )
		{
			if( g_iBlocked == 0 )
			{
				LogAction(client, -1, "Spawning blocked, too many Beams. (%d/%d/%d/%d/%d/%d/%d/%d)", g_hMapList.Length, g_iLoopCount, g_iTotalBeam, g_iTotalPart, g_iCvarCfgMax, MAX_ENTITIES, g_iCvarMaxB, g_iCvarMaxP);
				g_iBlocked = 1;
			}
			return;
		}

		if( !late && time == 0.0 )
			g_iTotalBeam++;
	}

	if( time == 0.0 )
		g_iLoadCount[client]++;

	// -1 or 1 to MAX_RESERVED = load particles (-1 = any random particle).
	if( type != 0 && type <= MAX_RESERVED )
	{
		// Particles allowed, and not auto loading data so loaded by client, or loaded by server
		if( g_iAccessParticles && (g_hTimerLoad == null || !client) )
		{
			if( type > GetMaxParticles() )
			{
				LogError("Invalid particle value %d > %d. Change value or remove entry from this maps config/presets.", type, GetMaxParticles());

				g_iLoadCount[client]--;
				if( !late )
					g_iTotalPart--;

				return;
			}

			char sTemp[LEN_HALF];
			int target;

			if( type == -1 ) type = GetRandomInt(1, GetMaxParticles());

			// CREATE: The actual function of creating particles/beams
			if( g_Engine == Engine_Left4Dead2 )
			{
				target = CreateEntityByName("info_particle_target");
			}
			else
			{
				target = CreateEntityByName("info_particle_system");
				DispatchKeyValue(target, "effect_name", g_sParticles[type - 1]);
			}

			Format(sTemp, sizeof(sTemp), "neon%d%d", target, type);
			DispatchKeyValue(target, "targetname", sTemp);
			TeleportEntity(target, vPos2, NULL_VECTOR, NULL_VECTOR);
			DispatchSpawn(target);
			ActivateEntity(target);

			int entity = CreateEntityByName("info_particle_system");
			DispatchKeyValue(entity, "start_active", "1");
			DispatchKeyValue(entity, "effect_name", (g_Engine != Engine_Left4Dead2 ? g_sParticles[type - 1] : g_sParticles_L4D2[type - 1]));
			DispatchKeyValue(entity, "cpoint1", sTemp);

			if (g_Engine == Engine_Left4Dead2)
			{
				switch (type)
				{
					case 23, 24, 25, 26, 27, 28, 29, 30: // Lights Moving
					{
						DispatchKeyValue(entity, "cpoint2", sTemp);
						DispatchKeyValue(entity, "cpoint3", sTemp);
						DispatchKeyValue(entity, "cpoint4", sTemp);
					}
				}
			}

			TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
			DispatchSpawn(entity);
			ActivateEntity(entity);

			if( client && g_bLoadingLate[client] )
			{
				SetEntProp(entity, Prop_Data, "m_iHammerID", GetClientUserId(client));
				SetEntProp(target, Prop_Data, "m_iHammerID", GetClientUserId(client));
				SDKHook(entity, SDKHook_SetTransmit, OnSetTransmit);
				SDKHook(target, SDKHook_SetTransmit, OnSetTransmit);
			}

			if (g_Engine != Engine_Left4Dead2)
			{
				Format(sTemp, sizeof(sTemp), "OnUser1 !self:Kill::%f:-1", g_fCvarCfgTime < 0.4 ? 0.4 : g_fCvarCfgTime);
				SetVariantString(sTemp);
				AcceptEntityInput(entity, "AddOutput");
				AcceptEntityInput(entity, "FireUser1");
				SetVariantString(sTemp);
				AcceptEntityInput(target, "AddOutput");
				AcceptEntityInput(target, "FireUser1");
			}
			else
			{
				switch (type)
				{
					case 23, 24, 25, 26, 27, 28, 29, 30: // Lights Moving
					{
					}
					case 35:
					{
						SetVariantString("OnUser1 !self:Stop::0.36:-1");
						AcceptEntityInput(entity, "AddOutput");
						SetVariantString("OnUser1 !self:FireUser2::0.40:-1");
						AcceptEntityInput(entity, "AddOutput");
						AcceptEntityInput(entity, "FireUser1");
						SetVariantString("OnUser2 !self:Start::0:-1");
						AcceptEntityInput(entity, "AddOutput");
						SetVariantString("OnUser2 !self:FireUser1::0:-1");
						AcceptEntityInput(entity, "AddOutput");
					}
					case 36:
					{
						SetVariantString("OnUser1 !self:Stop::0.01:-1");
						AcceptEntityInput(entity, "AddOutput");
						SetVariantString("OnUser1 !self:FireUser2::0.04:-1");
						AcceptEntityInput(entity, "AddOutput");
						AcceptEntityInput(entity, "FireUser1");
						SetVariantString("OnUser2 !self:Start::0:-1");
						AcceptEntityInput(entity, "AddOutput");
						SetVariantString("OnUser2 !self:FireUser1::0:-1");
						AcceptEntityInput(entity, "AddOutput");
					}
					case 37:
					{
						SetVariantString("OnUser1 !self:Stop::0.15:-1");
						AcceptEntityInput(entity, "AddOutput");
						SetVariantString("OnUser1 !self:FireUser2::0.20:-1");
						AcceptEntityInput(entity, "AddOutput");
						AcceptEntityInput(entity, "FireUser1");
						SetVariantString("OnUser2 !self:Start::0:-1");
						AcceptEntityInput(entity, "AddOutput");
						SetVariantString("OnUser2 !self:FireUser1::0:-1");
						AcceptEntityInput(entity, "AddOutput");
					}
					default:
					{
						Format(sTemp, sizeof(sTemp), "OnUser1 !self:Kill::%f:-1", g_fCvarCfgTime < 0.4 ? 0.4 : g_fCvarCfgTime);
						SetVariantString(sTemp);
						AcceptEntityInput(entity, "AddOutput");
						AcceptEntityInput(entity, "FireUser1");
						SetVariantString(sTemp);
						AcceptEntityInput(target, "AddOutput");
						AcceptEntityInput(target, "FireUser1");
					}
				}
			}
		} else {
			// Subtract so we don't hit limits in timers when not spawning anything
			g_iLoadCount[client]--;
			if( !late )
				g_iTotalPart--;
		}
	} else {
		// 0 or > MAX_RESERVED particles = load beams (0 = any random color).
		if( type == 0 ) type = GetRandomInt(MAX_RESERVED + 1, 16777215); // 255 + (256 * 255) + (65536 * 255)

		int color[4];
		GetColors(type, color);
		color[3] = g_iCvarOpac;

		TE_SetupBeamPoints(vPos, vPos2, g_Sprite, g_Halo, 0, 0, time, g_fCvarSize, g_fCvarSize, 0, 0.0, color, 0);
		if( client )
		{
			TE_SendToClient(client);
		} else {
			TE_SendToAll();
		}
	}
}

// Block late loading particles from being visible to all players except the target
public Action OnSetTransmit(int entity, int client)
{
	if( GetEdictFlags(entity) & FL_EDICT_ALWAYS )
		SetEdictFlags(entity, GetEdictFlags(entity) ^ FL_EDICT_ALWAYS);

	if( GetEntProp(entity, Prop_Data, "m_iHammerID") == GetClientUserId(client) )
		return Plugin_Continue;
	return Plugin_Handled;
}



// ====================================================================================================
//					OTHER
// ====================================================================================================
bool IsBlocked(int client)
{
	if( !g_bCvarAllow )
	{
		g_iSaveOrTemp[client] = 0;
		if( client )
			PrintToChat(client, "%sPlugin has been turned off.", CHAT_TAG);
		else
			PrintToServer("[Neon Beams] Plugin has been turned off.");
		return true;
	}

	if( g_iBlocked == 3 )
	{
		g_iSaveOrTemp[client] = 0;
		PrintToChat(client, "%sSpawning blocked. There is a problem with the maps config, please see error log.", CHAT_TAG);
		return true;
	} else if( g_iBlocked ) {
		g_iSaveOrTemp[client] = 0;
		PrintToChat(client, "%sSpawning blocked, too many %s.", CHAT_TAG, g_iBlocked == 1 ? "Beams" : "Particles");
		return true;
	}

	return false;
}

void PrecacheParticle(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;
	if( table == INVALID_STRING_TABLE )
	{
		table = FindStringTable("ParticleEffectNames");
	}

	if( FindStringIndex(table, sEffectName) == INVALID_STRING_INDEX )
	{
		bool save = LockStringTables(false);
		AddToStringTable(table, sEffectName);
		LockStringTables(save);
	}
}

bool CheckParticles(int client)
{
	if( !g_iAccessParticles )
	{
		if( client )
			PrintToChat(client, "%sParticles not installed.", CHAT_TAG);
		else
			PrintToServer("[Neon Beams] Particles not installed.");
		return false;
	}
	return true;
}

int GetMaxParticles()
{
	return (g_iAccessParticles == 1 ? MAX_PARTICLES : MAX_PART_L4D2);
}

bool HasReachedMax(int client = 0)
{
	// Because TF2 does not support custom particles, slight optimization
	if( g_Engine != Engine_TF2 )
	{
		if( g_iLoadCount[client] == 0 )
		{
			int count;

			for( int i = 0; i <= MAX_ENTITIES; i++ )
			{
				if( IsValidEdict(i) )
					count++;
			}

			if( count + g_iCvarCfgMax > MAX_ENTITIES - 50 ) // Below 2048 limit to be safe
				return true;
		}
	}

	return g_iLoadCount[client] >= g_iCvarCfgMax; // Above g_iCvarCfgMax
}

int GetColor(const char[] sTemp)
{
	if( sTemp[0] == 0 )
		return 0;

	char sColors[3][4];
	int color = ExplodeString(sTemp, " ", sColors, sizeof(sColors), sizeof(sColors[]));

	if( color != 3 )
		return 0;

	color = StringToInt(sColors[0]);
	color += 256 * StringToInt(sColors[1]);
	color += 65536 * StringToInt(sColors[2]);

	if( color <= MAX_RESERVED ) color = MAX_RESERVED + 1;
	return color;
}

void GetColors(int color, int colors[4])
{
    colors[2] = (color >> 16) & 0xFF;
    colors[1] = (color >> 8) & 0xFF;
    colors[0] = (color >> 0) & 0xFF;
}

bool IsNumericString(const char[] str)
{
    for( int i = 0; i < strlen(str); i++ )
        if( !IsCharNumeric(str[i]) )
            return false;
    return true;
}