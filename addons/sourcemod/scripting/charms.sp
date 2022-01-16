/*
*	Weapon Charms
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



#define PLUGIN_VERSION 		"1.16"

/*======================================================================================
	Plugin Info:

*	Name	:	[CS:GO/L4D1/L4D2] Weapon Charms
*	Author	:	SilverShot
*	Descrp	:	Weapon and item charm attachments.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=325652
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.16 (04-Dec-2021)
	- Changes to fix warnings when compiling on SourceMod 1.11.

1.15 (01-Jul-2021)
	- L4D2: Added a warning message to suggest installing the "Use Priority Patch" plugin if missing.

1.14b (15-May-2021)
	- L4D2: Fixed the Rifle weapon positions in 3rd person view.
	- Config file "charms.data.l4d2.cfg" has been updated.

	- Fixed bad translations data. Thanks to "weffer" for reporting.
	- Translation file "translations/es/charms.phrases.txt" has been updated.

1.14a (20-Apr-2021)
	- Added Spanish translations. Thanks to "AlexAlcala" for providing.

1.14 (12-Apr-2021)
	- L4D/L4D2: Fixed not restoring the charm after being revived.

1.13 (04-Mar-2021)
	- Added an extra check in case the database had not connected. Thanks to "Marttt" for reporting.
	- Added Portuguese translations. Thanks to "hoyxen" for providing.

1.12 (15-Feb-2021)
	- Fixed "Array index out-of-bounds" error. Thanks to "Alex101192" for reporting and "Marttt" for fixing.
	- Added Russian translations. Thanks to "Kleiner" for providing.

1.11 (05-Oct-2020)
	- Added cvar "charms_default" to give default charms to new players or none at all.

1.10 (01-Oct-2020)
	- Added support for following weapons "m_nSkin" value. Fixes L4D2 new weapon skins.
	- Added an "IsClientInGame" check to "TimerSpawn" due to rare case of logging an error.
	- L4D2: Added charms to CSS weapons since their viewmodel is now better from The Last Stand update.
	- L4D2: Changed "charms_precache" cvar default value to blank.
	- L4D2: Fixed various weapon positions supporting The Last Stand update changes.
	- L4D2: Fixed displaying the wrong arms model for L4D2 characters on L4D1 maps.
	- L4D/2: Fixed reloading or turning plugin off/on from making the weapon and arms invisible.
	- L4D/2: Fixed not hiding the charm when reviving someone.

1.9 (25-Jul-2020)
	- Any: "Attachments_API" version 1.5 fixes wrong or broken weapon models being shown.
	- Added some code to attempt fixing charms blocking +USE action. Thanks to Lux for providing.
	- Fixed not saving clients selected charms when "charms_bots" cvar was disabled.
	- L4D2: Fixed the "F-18" and "Missile" charms causing lag stutter on first usage.
	- L4D2: Fixed the "prop_minigun_l4d1" minigun from not removing charms when used.
	- L4D2: Fixed thirdperson weapon showing when using a minigun. Thanks to "Alex101192" for reporting.

1.8 (20-Jul-2020)
	- Added cvar "charms_timeout" to prevent equipping a new charm for X seconds.
	- L4D2: Jockey riding someone now deletes the charm and restores on ride end.
	- L4D2: Ladder fix from "Attachments_API" version 1.4 update.

1.7 (15-Jul-2020)
	- Added 4 natives for other plugins (support for L4D/2 "Extinguisher" plugin to create/remove charms).
	- Optimized bots using charms, no longer creating viewmodels or fake arms.
	- CSGO: Removed the charm when aiming down iron sights (Aug).
	- CSGO: Better replicating the players arms based on their current model.
	- CSGO: Blocked some silenced/modified weapons from using charms.

1.6 (11-Jul-2020)
	- Changed command "sm_charm" to allow using an optional arg to select the charm index.
	- Fixed L4D1 crash due to using the wrong dual pistol model.
	- Fixed L4D1 errors about event missing. Now hooks OnUse to hide charms when mounting a minigun.
	- Removes the charm when zooming down a scope. Thanks to "Alex101192" for reporting.
	- CSGO: The charm won't re-attach when shooting during scoped view, only when manually unscoping.
	- CSGO: Updated the C4 charm position in the "charms.data.csgo.cfg" config.
	- CSGO: Blocked plugin from running when "Sm_Skinchooser" plugin is detected.

1.5 (09-Jul-2020)
	- L4D2: Fixed showing a duplicate weapon when using "thirdpersonshoulder". Thanks to "Alex101192" for reporting.

1.4 (06-Jul-2020)
	- Added cvar "charms_precache" to prevent the plugin working and PreCaching models on certain maps.
	- Added a 1 frame delay in creating a charm to hopefully fix weapons or charms getting stuck or invisible.

1.3 (05-Jul-2020)
	- Fixed minor memory leak from bots, forgot to delete a handle I tried to remember.

1.2 (04-Jul-2020)
	- Added support for bots using random charms.
	- Added cvar "charms_bots" to control if bots can use charms.
	- Fixed L4D1 and L4D2 not removing charms when pinned.
	- Plugin "Attachments_API" updated and required.

1.1 (02-Jul-2020)
	- Fixed database creation error. Thanks to "NanoC" for reporting.
	- Fixed default charm settings in "charms.data.csgo.cfg" config.
	- Fixed batch exporting the project to .zip archive duplicating the .sp source code.

1.0 (01-Jul-2020)
	- Initial release.

========================================================================================
	Thanks:

	This plugin was made using source code from the following plugins.
	If I have used your code and not credited you, please let me know.

*	"Lux" for " [L4D/L4D2]Lux's Model Changer" - Using the "IsSurvivorThirdPerson" function.
	https://forums.alliedmods.net/showthread.php?t=286987

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <attachments_api>
#tryinclude <ThirdPersonShoulder_Detect> // L4D2 1st/3rd person view management


#define CVAR_FLAGS				FCVAR_NOTIFY
#define CONFIG_DATA				"data/charms.data"			// Appends ".game.cfg" to the filename.
#define CONFIG_WEPS				"data/charms.weapons"		// Appends ".game.cfg" to the filename.
#define DATABASE_NAME			"charms"

#define SF_PHYSPROP_PREVENT_PICKUP		(1 << 9)
#define EFL_DONTBLOCKLOS		(1 << 25)
#define EF_BONEMERGE			(1 << 0)
#define EF_NOSHADOW				(1 << 4)
#define EF_BONEMERGE_FASTCULL	(1 << 7)
#define EF_PARENT_ANIMATES		(1 << 9)

#define INDEX_VIEWS				0				// Indexes for g_iEntSaved
#define INDEX_WORLD				1
#define INDEX_ARMS				2

#define MAX_LENGTH_CLASS		64				// Maximum weapon classname length
#define MAX_LENGTH_MODEL		128				// Maximum modelname string length
#define MAX_WEAPONS_DB			512				// Maximum length for saving weapons string, increase if total weapons grows or total charms exceed 99.
												// (CSWeaponID (2) + charm ID (2) + comma (1) * total weapons). For CSGO that's: 5 (size) * 71 (weapons) = 355


EngineVersion g_iEngine;
bool g_bLateLoad, g_bCvarAllow, g_bValidMap, g_bAllowSize, g_bAttachments;
char g_sConfigData[PLATFORM_MAX_PATH];
char g_sConfigWeps[PLATFORM_MAX_PATH];
char g_sCHAT_TAG[PLATFORM_MAX_PATH];
char g_szBuffer[512];

// Cvars
ConVar g_hCvarAllow, g_hCvarBots, g_hCvarCheck, g_hCvarDefault, g_hCvarPrecache, g_hCvarTimeout;
float g_fCvarCheck, g_fCvarTimeout;
bool g_bCvarBots, g_bCvarDefault;

// Database
Database g_hDB;
bool g_bSQLite;
int g_iMaxCharmIndex;							// Prevent accessing higher saved indexes if some were deleted

// Views
bool g_bExternalCvar[MAXPLAYERS+1];				// External view status - command
bool g_bExternalProp[MAXPLAYERS+1];				// External view status - netprop
bool g_bExternalView[MAXPLAYERS+1];				// External view status - current
Handle g_hTimerDetectView;						// First/Third person view timer. L4D2

// Entities
int g_iEntDupes[MAXPLAYERS+1];
int g_iEntBones[MAXPLAYERS+1];					// Entity index of replica weapon (used to show/hide model in 1st/3rd person view)
int g_iEntSaved[MAXPLAYERS+1][3];				// Entity indexes (arms/viewmodel/worldmodel), for tracking and deletion
int g_iSelected[MAXPLAYERS+1];					// Charm index selected being worn
int g_iEditing[MAXPLAYERS+1];					// Charm index selected for editing
int g_iLastItem[MAXPLAYERS+1];					// Monitor for weapon change to reset position.
float g_fSpawned[MAXPLAYERS+1];					// Prevent weapon switch creating/deleting charms before player spawn or just after player spawn
bool g_bCreating[MAXPLAYERS+1];					// Prevent creating a charm during the delay of creating one

// Weapons menu
Menu g_hWeaponsMenu;
char g_sDefaultCharms[MAX_WEAPONS_DB];			// Default weapon preferences string from "default" key
StringMap g_smViewModels;						// Viewmodel model names + precache index
StringMap g_smWeaponNames;						// Weapon classname and text names
StringMap g_smWeaponClassID;					// Weapon weapon ID + classnames (for saving preferences)
StringMap g_smWeaponIDClass;					// Weapon classnames + weapon ID (for saving preferences)
StringMap g_smSelected[MAXPLAYERS+1];			// Selected weapon classname + charm index.
int g_iWeaponsMenu[MAXPLAYERS+1];				// Used to determine if we came from the weapons menu
float g_fLastSave[MAXPLAYERS+1];				// Prevent spamming save to database button
float g_fTimeout[MAXPLAYERS+1];					// Prevent spamming to create new charms

// L4D2: block miniguns
bool g_bMountedGun[MAXPLAYERS+1];
Handle g_hTimerGun;

// L4D/2 dual pistol model:
char g_sPistol[64];

// CSGO arms:
// char g_sArms_T[64];
// char g_sArms_CT[64];



// Charms data dynamic array list
ArrayList g_aArrayList;

// Charms main data struct
enum struct CharmData
{
	char sName[64];
	char sModelName[MAX_LENGTH_MODEL];
	StringMap smArrayWeapons;
}

// Weapon attachments data
enum struct WeaponData
{
	char sAttach_1[128]; // 128: Used to store model when bonemerging
	char sAttach_2[32];
	int isDefault;
	int boneMerge;
	float vPos_1[3];
	float vAng_1[3];
	float fSize_1;
	float vPos_2[3];
	float vAng_2[3];
	float fSize_2;
}



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[CS:GO/L4D1/L4D2] Weapon Charms",
	author = "SilverShot",
	description = "Weapon and item charm attachments.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=325652"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("charms_silvers");

	CreateNative("Charms_Create",	Native_CharmCreate);
	CreateNative("Charms_Delete",	Native_CharmDelete);
	CreateNative("Charms_GetIndex",	Native_GetIndex);
	CreateNative("Charms_GetValid",	Native_GetValid);

	g_bLateLoad = late;
	g_iEngine = GetEngineVersion();

	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	// Block running with Sm_Skinchooser:
	if( g_iEngine == Engine_CSGO && FindConVar("sm_skinchooser_version") != null )
	{
		SetFailState("\n==========\nPlugin conflict: \"Weapon Charms\" cannot work with \"Sm_Skinchooser\" plugin.\n\"Weapon Charms\" plugin has been disabled.\n==========");
	}

	// Use Priority Patch
	if( g_iEngine == Engine_Left4Dead || g_iEngine == Engine_Left4Dead2 )
	{
		if( FindConVar("l4d_use_priority_version") == null )
		{
			LogMessage("\n==========\nWarning: You should install \"[L4D & L4D2] Use Priority Patch\" to fix attached models blocking +USE action: https://forums.alliedmods.net/showthread.php?t=327511\n==========\n");
		}
	}
}

public void OnPluginStart()
{
	// Init
	if( g_iEngine == Engine_Left4Dead2 || g_iEngine == Engine_CSGO ) g_bAllowSize = true;
	g_bAttachments = true;

	LoadTranslations("charms.phrases");



	// Parse config
	BuildPath(Path_SM, g_sConfigData, sizeof(g_sConfigData), "%s.", CONFIG_DATA);
	BuildPath(Path_SM, g_sConfigWeps, sizeof(g_sConfigWeps), "%s.", CONFIG_WEPS);

	switch( g_iEngine )
	{
		case Engine_Left4Dead:		{ StrCat(g_sConfigData, sizeof(g_sConfigData), "l4d1.cfg");		StrCat(g_sConfigWeps, sizeof(g_sConfigWeps), "l4d1.cfg");	}
		case Engine_Left4Dead2:		{ StrCat(g_sConfigData, sizeof(g_sConfigData), "l4d2.cfg");		StrCat(g_sConfigWeps, sizeof(g_sConfigWeps), "l4d2.cfg");	}
		case Engine_CSGO:			{ StrCat(g_sConfigData, sizeof(g_sConfigData), "csgo.cfg");		StrCat(g_sConfigWeps, sizeof(g_sConfigWeps), "csgo.cfg");	}
		default:					{ StrCat(g_sConfigData, sizeof(g_sConfigData), "game.cfg");		StrCat(g_sConfigWeps, sizeof(g_sConfigWeps), "game.cfg");	}
	}

	if( FileExists(g_sConfigData) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", g_sConfigData);
	if( FileExists(g_sConfigWeps) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", g_sConfigWeps);

	switch( g_iEngine )
	{
		case Engine_CSGO:			g_sCHAT_TAG = " \x05[Charms]\x01 ";
		default:					g_sCHAT_TAG = "\x05[Charms]\x01 ";
	}

	switch( g_iEngine )
	{
		case Engine_Left4Dead:		g_sPistol = "models/v_models/v_dualpistols.mdl";
		case Engine_Left4Dead2:		g_sPistol = "models/v_models/v_dual_pistolA.mdl";
	}

	LoadConfigCharms();
	LoadConfigWeapons();



	// Cvars
	g_hCvarAllow = CreateConVar(			"charms_allow",			"1",				"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarBots = CreateConVar(				"charms_bots",			"1",				"0=Off, 1=Give bots a random charm on spawn.", CVAR_FLAGS );
	if( g_iEngine == Engine_Left4Dead || g_iEngine == Engine_Left4Dead2 )
		g_hCvarCheck = CreateConVar(		"charms_check",			"0.2",				"L4D/2: 0.0=Off. How often to check if a players in first or thirdperson view to show/hide the correct Charm.", CVAR_FLAGS );
	g_hCvarDefault = CreateConVar(			"charms_default",		"1",				"0=None. 1=Give default charms to new players (search for default in the charms.data config).", CVAR_FLAGS );
	g_hCvarPrecache = CreateConVar(			"charms_precache",		"",					"Prevent pre-caching models on these maps, separate by commas (no spaces). Blocks the plugin working on these maps.", CVAR_FLAGS );
	g_hCvarTimeout = CreateConVar(			"charms_timeout",		"1.0",				"0.0=Off. Block someone from equipping a new charm for this many seconds.", CVAR_FLAGS );
	CreateConVar(							"charms_version",		PLUGIN_VERSION,		"Weapon Charms plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true, "charms");

	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarBots.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDefault.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarPrecache.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTimeout.AddChangeHook(ConVarChanged_Cvars);
	if( g_iEngine == Engine_Left4Dead || g_iEngine == Engine_Left4Dead2 )
		g_hCvarCheck.AddChangeHook(ConVarChanged_Cvars);



	// Commands
	RegConsoleCmd("sm_charm",			CmdCharm,						"Shows the Charms menu. Alternative usage: sm_charm [charm index] or 0 to remove.");
	RegConsoleCmd("sm_charms",			CmdCharms,						"Shows the Charms weapon menu.");
	RegAdminCmd("sm_charm_reload",		CmdReload,		ADMFLAG_ROOT,	"Reload the Charms config.");
	RegAdminCmd("sm_charm_edit",		CmdEdit,		ADMFLAG_ROOT,	"Usage: sm_charm_edit <type>. 1=First person. 2=Third person. Enables editing pos/ang/size.");
	RegAdminCmd("sm_charm_ang",			CmdAng,			ADMFLAG_ROOT,	"Shows a menu allowing you to adjust the charm angles.");
	RegAdminCmd("sm_charm_pos",			CmdPos,			ADMFLAG_ROOT,	"Shows a menu allowing you to adjust the charm position.");
	RegAdminCmd("sm_charm_size",		CmdSize,		ADMFLAG_ROOT,	"Shows a menu allowing you to adjust the charm size.");
	RegAdminCmd("sm_charm_save",		CmdSave,		ADMFLAG_ROOT,	"Saves the data config. Suggest saving after editing each charm, either via menu or command.");
}

public void Attachments_OnLateLoad()
{
	g_bAttachments = true;
	IsAllowed();
	LateLoad();
}

public void Attachments_OnPluginEnd()
{
	g_bAttachments = false;
	OnPluginEnd();
	IsAllowed();
}

public void OnPluginEnd()
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		DeleteCharm(i);

		if( IsClientInGame(i) && !IsFakeClient(i) )
		{
			OnClientDisconnect(i);
		}
	}
}

void DeleteCharm(int client)
{
	if( IsValidEntRef(g_iEntSaved[client][INDEX_VIEWS]) )
	{
		AcceptEntityInput(g_iEntSaved[client][INDEX_VIEWS], "ClearParent");
		RemoveEntity(g_iEntSaved[client][INDEX_VIEWS]);
	}

	if( IsValidEntRef(g_iEntSaved[client][INDEX_WORLD]) )
	{
		AcceptEntityInput(g_iEntSaved[client][INDEX_WORLD], "ClearParent");
		RemoveEntity(g_iEntSaved[client][INDEX_WORLD]);
	}

	if( IsValidEntRef(g_iEntSaved[client][INDEX_ARMS]) )
	{
		AcceptEntityInput(g_iEntSaved[client][INDEX_ARMS], "ClearParent");
		RemoveEntity(g_iEntSaved[client][INDEX_ARMS]);
	}

	if( IsValidEntRef(g_iEntDupes[client]) )
	{
		AcceptEntityInput(g_iEntDupes[client], "ClearParent");
		RemoveEntity(g_iEntDupes[client]);
	}

	if( IsValidEntRef(g_iEntBones[client]) )
	{
		SetEntityRenderMode(g_iEntBones[client], RENDER_NONE); // Hide fake viewmodel weapon, created by Attachments_API - don't want to delete in case other plugins using
	}

	g_iEntSaved[client][INDEX_VIEWS] = 0;
	g_iEntSaved[client][INDEX_WORLD] = 0;
	g_iEntSaved[client][INDEX_ARMS] = 0;

	if( IsClientInGame(client) )
	{
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
	}
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnConfigsExecuted()
{
	IsAllowed();
}

public void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bCvarBots = g_hCvarBots.BoolValue;
	g_bCvarDefault = g_hCvarDefault.BoolValue;
	g_fCvarTimeout = g_hCvarTimeout.FloatValue;

	// Cvars
	if( g_iEngine == Engine_Left4Dead || g_iEngine == Engine_Left4Dead2 )
		g_fCvarCheck = g_hCvarCheck.FloatValue;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	GetCvars();

	// Connect MySQL (only connects once)
	MySQL_Connect();



	// Plugin On
	if( !g_bCvarAllow && g_bAttachments && bCvarAllow && g_bValidMap )
	{
		g_bCvarAllow = true;

		if( g_iEngine == Engine_CSGO )
		{
			HookEvent("round_officially_ended",		Event_RoundEnd);
			HookEvent("weapon_zoom_rifle",			Event_Zoom);
		}
		else
		{
			HookEvent("round_end",					Event_RoundEnd);
		}

		HookEvent("player_team",					Event_PlayerDeath);
		HookEvent("player_death",					Event_PlayerDeath);
		HookEvent("player_spawn",					Event_PlayerSpawn);
		HookEvent("weapon_zoom",					Event_Zoom);

		// View detection
		if( g_iEngine == Engine_Left4Dead || g_iEngine == Engine_Left4Dead2 )
		{
			HookEvent("player_ledge_grab",			Event_Block);
			HookEvent("player_ledge_release",		Event_Unlock);
			HookEvent("player_incapacitated",		Event_Block);
			HookEvent("revive_begin",				Event_Block);
			HookEvent("revive_success",				Event_Unlock2);
			HookEvent("revive_success",				Event_Unlock);
			HookEvent("revive_end",					Event_Unlock);
			HookEvent("gameinstructor_draw",		Event_Instructor);
			HookEvent("player_bot_replace",			Event_BotReplace);
			HookEvent("player_use",					Event_PlayerUse);

			HookEvent("lunge_pounce",				Event_BlockStart);
			HookEvent("pounce_end",					Event_BlockEnd);
			HookEvent("tongue_grab",				Event_BlockStart);
			HookEvent("tongue_release",				Event_BlockEnd);

			if( g_iEngine == Engine_Left4Dead2 )
			{
				HookEvent("mounted_gun_start",		Event_Block2);
				HookEvent("charger_pummel_start",	Event_BlockStart);
				HookEvent("charger_carry_start",	Event_BlockStart);
				HookEvent("charger_carry_end",		Event_BlockEnd);
				HookEvent("charger_pummel_end",		Event_BlockEnd);
				HookEvent("jockey_ride",			Event_BlockStart);
				HookEvent("jockey_ride_end",		Event_BlockEnd);
			}

			delete g_hTimerDetectView;
			if( g_fCvarCheck )
				g_hTimerDetectView = CreateTimer(g_fCvarCheck, TimerDetectView, _, TIMER_REPEAT);
		}

		if( g_hDB )
		{
			// Load clients data if allowed + lateload:
			LateLoad();
		}
	}

	// Plugin Off
	else if( g_bCvarAllow && (!bCvarAllow || !g_bAttachments || !g_bValidMap) )
	{
		g_bCvarAllow = false;
		delete g_hTimerDetectView;

		if( g_iEngine == Engine_CSGO )
		{
			UnhookEvent("round_officially_ended",	Event_RoundEnd);
			UnhookEvent("weapon_zoom_rifle",		Event_Zoom);
		}
		else
		{
			UnhookEvent("round_end",				Event_RoundEnd);
		}

		UnhookEvent("player_team",					Event_PlayerDeath);
		UnhookEvent("player_death",					Event_PlayerDeath);
		UnhookEvent("player_spawn",					Event_PlayerSpawn);
		UnhookEvent("weapon_zoom",					Event_Zoom);

		if( g_iEngine == Engine_Left4Dead || g_iEngine == Engine_Left4Dead2 )
		{
			UnhookEvent("player_ledge_grab",		Event_Block);
			UnhookEvent("player_ledge_release",		Event_Unlock);
			UnhookEvent("player_incapacitated",		Event_Block);
			UnhookEvent("revive_begin",				Event_Block);
			UnhookEvent("revive_success",			Event_Unlock2);
			UnhookEvent("revive_success",			Event_Unlock);
			UnhookEvent("revive_end",				Event_Unlock);
			UnhookEvent("gameinstructor_draw",		Event_Instructor);
			UnhookEvent("player_bot_replace",		Event_BotReplace);
			UnhookEvent("player_use",				Event_PlayerUse);

			UnhookEvent("lunge_pounce",				Event_BlockStart);
			UnhookEvent("pounce_end",				Event_BlockEnd);
			UnhookEvent("tongue_grab",				Event_BlockStart);
			UnhookEvent("tongue_release",			Event_BlockEnd);

			if( g_iEngine == Engine_Left4Dead2 )
			{
				UnhookEvent("mounted_gun_start",	Event_Block2);
				UnhookEvent("charger_pummel_start",	Event_BlockStart);
				UnhookEvent("charger_carry_start",	Event_BlockStart);
				UnhookEvent("charger_carry_end",	Event_BlockEnd);
				UnhookEvent("charger_pummel_end",	Event_BlockEnd);
				UnhookEvent("jockey_ride",			Event_BlockStart);
				UnhookEvent("jockey_ride_end",		Event_BlockEnd);
			}
		}

		g_bLateLoad = true;
		OnMapEnd();
	}
}

void LateLoad()
{
	if( g_bLateLoad && g_bCvarAllow && g_bValidMap )
	{
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsClientConnected(i) )
			{
				g_bCreating[i] = false;
				g_fSpawned[i] = 1.0;
				OnClientConnected(i);
				OnClientAuthorized(i, "");
			}
		}

		// Late load minigun mount detection
		if( g_iEngine == Engine_Left4Dead )
		{
			int entity = -1;
			while( (entity = FindEntityByClassname(entity, "prop_minigun")) != INVALID_ENT_REFERENCE )
				SDKHook(entity, SDKHook_UsePost, OnUseMinigun);

			entity = -1;
			while( (entity = FindEntityByClassname(entity, "prop_mounted_machine_gun")) != INVALID_ENT_REFERENCE )
				SDKHook(entity, SDKHook_UsePost, OnUseMinigun);
		}
		else if( g_iEngine == Engine_Left4Dead2 )
		{
			int entity = -1;
			while( (entity = FindEntityByClassname(entity, "prop_minigun_l4d1")) != INVALID_ENT_REFERENCE )
				SDKHook(entity, SDKHook_UsePost, OnUseMinigun);
		}

		g_bLateLoad = false;
	}
}



// ====================================================================================================
//					CACHE MODELS
// ====================================================================================================
public void OnMapStart()
{
	// Block plugin and precache on certain maps
	g_bValidMap = true;

	g_hCvarPrecache.GetString(g_szBuffer, sizeof(g_szBuffer));

	if( g_szBuffer[0] != '\0' )
	{
		char sMap[64];
		GetCurrentMap(sMap, sizeof(sMap));

		Format(sMap, sizeof(sMap), ",%s,", sMap);
		Format(g_szBuffer, sizeof(g_szBuffer), ",%s,", g_szBuffer);

		if( StrContains(g_szBuffer, sMap, false) != -1 )
			g_bValidMap = false;
	}

	if( g_bValidMap == false ) return;



	// Precache charms models
	int len = g_aArrayList.Length;
	CharmData charmTemp;
	WeaponData wepsData;
	StringMap smWepsData;
	StringMapSnapshot smWepsSnap;
	char sClass[MAX_LENGTH_CLASS];

	// Loop through charms data, precache models
	for( int i = 0; i < len; i++ )
	{
		g_aArrayList.GetArray(i, charmTemp, sizeof(charmTemp));

		if( charmTemp.sModelName[0] != 0 )
		{
			PrecacheModel(charmTemp.sModelName);
		}

		// Loop through each charm + weapons, if boneMerge then PrecacheModel and store modex index.
		smWepsData = charmTemp.smArrayWeapons;
		smWepsSnap = smWepsData.Snapshot();

		for( int x = 0; x < smWepsSnap.Length; x++ )
		{
			smWepsSnap.GetKey(x, sClass, sizeof(sClass));
			smWepsData.GetArray(sClass, wepsData, sizeof(wepsData));

			if( wepsData.boneMerge && wepsData.sAttach_1[0] )
			{
				wepsData.boneMerge = PrecacheModel(wepsData.sAttach_1);
				smWepsData.SetArray(sClass, wepsData, sizeof(wepsData));
			}
		}

		delete smWepsSnap;
	}



	if( g_iEngine == Engine_Left4Dead2 )
	{
		// For some reason creating "f18_agm65maverick" or "f18_placeholder" cause lag stutter like some other model is not cached.
		// This stupid workaround fixes it.

		// Precache incase removed from "charms.data"
		PrecacheModel("models/f18/f18_placeholder.mdl");
		PrecacheModel("models/missiles/f18_agm65maverick.mdl");

		int entity = CreateEntityByName("prop_dynamic_override");
		DispatchKeyValue(entity, "model", "models/f18/f18_placeholder.mdl");
		DispatchSpawn(entity);
		RemoveEntity(entity);

		entity = CreateEntityByName("prop_dynamic_override");
		DispatchKeyValue(entity, "model", "models/missiles/f18_agm65maverick.mdl");
		DispatchSpawn(entity);
		RemoveEntity(entity);
	}
	else if( g_iEngine == Engine_CSGO )
	{
		// We have to duplicate the models so the path is different or the dupe weapon is stuck within the players forehead.
		// Don't know how else to fix, tried changing viewmodel, bone, dupe etc.
		smWepsSnap = g_smViewModels.Snapshot();
		char sPathRead[PLATFORM_MAX_PATH];
		char sPathWrite[PLATFORM_MAX_PATH];
		char sDir[PLATFORM_MAX_PATH];
		File hRead;
		File hWrite;
		int buffer[32];
		int bytes;

		// Create custom dirs
		Format(sDir, sizeof(sDir), "models");
		if( DirExists(sDir) == false )
			CreateDirectory(sDir, 511);

		Format(sDir, sizeof(sDir), "models/weapons");
		if( DirExists(sDir) == false )
			CreateDirectory(sDir, 511);

		Format(sDir, sizeof(sDir), "models/weapons/silvershot");
		if( DirExists(sDir) == false )
			CreateDirectory(sDir, 511);

		Format(sDir, sizeof(sDir), "models/weapons/silvershot/viewmodels");
		if( DirExists(sDir) == false )
			CreateDirectory(sDir, 511);

		// Loop through custom weapon viewmodels, precache models to get index
		len = smWepsSnap.Length;

		for( int i = 0; i < len; i++ )
		{
			smWepsSnap.GetKey(i, sClass, sizeof(sClass));

			// Check its only viewmodel names and not the "models/" path since both are in the StringMap
			if( strncmp(sClass, "models/", 7) )
			{
				// Check model exists
				Format(sPathRead, sizeof(sPathRead), "models/weapons/%s.mdl", sClass);
				if( FileExists(sPathRead, true) )
				{
					// Custom file doesn't exist
					Format(sPathWrite, sizeof(sPathWrite), "models/weapons/silvershot/viewmodels/%s.mdl", sClass);
					if( FileExists(sPathWrite, true) == false )
					{
						// Copy
						hRead = OpenFile(sPathRead, "rb", true, NULL_STRING);
						hWrite = OpenFile(sPathWrite, "wb");

						while( !IsEndOfFile(hRead) )
						{
							bytes = ReadFile(hRead, buffer, sizeof(buffer), 1);
							WriteFile(hWrite, buffer, bytes, 1);
						}

						delete hRead;
						delete hWrite;
					}

					AddFileToDownloadsTable(sPathWrite);
					g_smViewModels.SetValue(sPathRead, PrecacheModel(sPathWrite));
				}
				else
				{
					LogError("Missing file \"%s\"", sPathRead);
				}
			}
		}

		delete smWepsSnap;



		// Get Arms
		// Moved to hard coded method GetArmsModel() to change based on player skin, to support custom maps etc.
		/*
		g_sArms_T[0] = 0;
		g_sArms_CT[0] = 0;

		// Retrieve arm models for current map
		KeyValues kvFile = new KeyValues("GameModes.txt");

		if( kvFile.ImportFromFile("gamemodes.txt") )
		{
			if( kvFile.JumpToKey("maps") )
			{
				GetCurrentMap(g_szBuffer, sizeof(g_szBuffer));
				if( kvFile.JumpToKey(g_szBuffer) )
				{
					kvFile.GetString("t_arms", g_sArms_T, sizeof(g_sArms_T));
					kvFile.GetString("ct_arms", g_sArms_CT, sizeof(g_sArms_CT));
				}
			}
		}

		delete kvFile;

		// Failed to find arms? Default
		if( g_sArms_T[0] == 0 )
			g_sArms_T = "models/weapons/t_arms_professional.mdl";
		if( g_sArms_CT[0] == 0 )
			g_sArms_CT = "models/weapons/t_arms_professional.mdl";
		*/
	}
}



// ====================================================================================================
//					DELETE MODELS - UNHOOK
// ====================================================================================================
public void OnMapEnd()
{
	// Event_RoundEnd calls this function, so if deleting g_hTimerDetectView consider round start.
	// delete g_hTimerDetectView; // FIXME: TODO: delete / recreate on map change?
	delete g_hTimerGun;

	for( int i = 1; i <= MaxClients; i++ )
	{
		DeleteCharm(i);
		g_iSelected[i] = 0;
		g_fSpawned[i] = 0.0;
		g_bCreating[i] = false;
		g_bMountedGun[i] = false;
	}
}



// ====================================================================================================
//					DATABASE CONNECT / CREATE TABLES
// ====================================================================================================
void MySQL_Connect()
{
	if( g_hDB != null )
	{
		return;
	}

	if( !SQL_CheckConfig(DATABASE_NAME) )
	{
		SetFailState("Missing database entry \"%s\" from your servers \"sourcemod/configs/databases.cfg\" file.", DATABASE_NAME);
	}

	Database.Connect(OnMySQLConnect, DATABASE_NAME);
}

public void OnMySQLConnect(Database db, const char[] szError, any data)
{
	if( db == null || szError[0] )
	{
		SetFailState("MySQL error: %s", szError);
		return;
	}

	g_hDB = db;



	// Database type (required for update queries, standard MySQL and SQLite are different)
	DBDriver driver = g_hDB.Driver;
	driver.GetIdentifier(g_szBuffer, sizeof(g_szBuffer));
	if( strcmp(g_szBuffer, "sqlite") == 0 )
		g_bSQLite = true;



	// Create table if missing
	db.Format(g_szBuffer, sizeof(g_szBuffer),\
		"CREATE TABLE IF NOT EXISTS `charms` ( \
			`steamid` varchar(18) NOT NULL default '', \
			`weapons` varchar(%d) NOT NULL default '', \
			`created_at` TIMESTAMP NULL, \
			`updated_at` TIMESTAMP NULL, \
			PRIMARY KEY (`steamid`)\
		);"
	, MAX_WEAPONS_DB);

	g_hDB.Query(Database_OnConnect, g_szBuffer);



	// Load clients data if allowed + lateload:
	LateLoad();
}

public void Database_OnConnect(Database db, DBResultSet results, const char[] error, any data)
{
	if( results == null )
	{
		SetFailState("[Database_OnConnect] Error: %s", error);
	}
}



// ====================================================================================================
//					DATABASE - CLIENT CONNECT - LOAD PREFS
// ====================================================================================================
public void OnClientConnected(int client)
{
	if( !IsFakeClient(client) )
	{
		delete g_smSelected[client];
		g_smSelected[client] = new StringMap();
		g_fTimeout[client] = 0.0;
	}
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if( !IsFakeClient(client) )
	{
		if( g_hDB == null )
		{
			return;
		}

		if( GetClientAuthId(client, AuthId_SteamID64, g_szBuffer, sizeof(g_szBuffer)) == false ) return;

		static char szBuffer[MAX_WEAPONS_DB];
		g_hDB.Format(szBuffer, sizeof(szBuffer), "SELECT weapons FROM `charms` WHERE steamid = '%s'", g_szBuffer);
		g_hDB.Query(Database_OnClientLoadData, szBuffer, GetClientUserId(client));
	}
	else if( g_bCvarBots )
	{
		int weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		if( weapon != -1 )
		{
			Attachments_OnWeaponSwitch(client, weapon, -1, -1);
		}
	}
}

public void Database_OnClientLoadData(Database db, DBResultSet results, const char[] error, any data)
{
	if( results != null )
	{
		int client = GetClientOfUserId(data);
		if( client )
		{
			static char szBuffer[MAX_WEAPONS_DB];

			if( results.RowCount )
			{
				results.FetchRow();
				results.FetchString(0, szBuffer, sizeof(szBuffer));

				
				if( g_bCvarDefault && szBuffer[0] == 0 )
				{
					strcopy(szBuffer, sizeof(szBuffer), g_sDefaultCharms);
				}
			}
			else
			{
				// Default charms/weapons if no preferences.
				if( g_bCvarDefault )
				{
					strcopy(szBuffer, sizeof(szBuffer), g_sDefaultCharms);
				}
			}

			if( szBuffer[0] )
			{
				StrCat(szBuffer, sizeof(szBuffer), ",");

				// Split data, add to clients StringMap, preferred charms for each weapon
				char sVal[10];
				int pos, last, val;

				while( (pos = SplitString(szBuffer[last], ",", sVal, 32)) != -1 )
				{
					last += pos;
					pos = StrContains(sVal, ":"); // CSWeaponID:CharmID
					if (pos == -1)
						break; //or return;  

					sVal[pos] = 0;

					if( g_smWeaponIDClass.GetString(sVal, g_szBuffer, sizeof(g_szBuffer)) )
					{
						// Prevent exceeding max charms
						val = StringToInt(sVal[pos+1]);
						if( val > g_iMaxCharmIndex ) val = g_iMaxCharmIndex;
						g_smSelected[client].SetValue(g_szBuffer, val);
					}
				}
			}



			if( g_bCvarAllow && g_bValidMap )
			{
				// Default 1st person
				g_bExternalView[client] = false;
				g_bExternalProp[client] = true;

				if( IsClientInGame(client) && IsPlayerAlive(client) )
				{
					int index = GetCharmFromClassname(client);
					if( index )
					{
						// Create
						CreateCharm(client, index - 1);

						// Check first/third person view
						if( (g_iEngine == Engine_Left4Dead2 || g_iEngine == Engine_Left4Dead) )
						{
							if( IsSurvivorThirdPerson(client) )
							{
								g_bExternalView[client] = false; // Flipped, so script toggles
								g_bExternalProp[client] = true;
								SetCharmView(client, true);
							}
							else
							{
								QueryClientConVar(client, "c_thirdpersonshoulder", QueryClientConVarView);
							}
						}
					}
				}
			}
		}

		delete results;
	}
}

public void QueryClientConVarView(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	if( strcmp(cvarValue, "0") )
	{
		g_bExternalView[client] = false;
		// g_bExternalCvar[client] = true; // Reloading plugin with this uncommented makes the weapon/arms invisible. Used to work ok, don't know what happened.
		SetCharmView(client, true);
	}
	else
	{
		g_bExternalView[client] = true;
		g_bExternalCvar[client] = false;
		SetCharmView(client, false);
	}
}



// ====================================================================================================
//					DATABASE - CLIENT DISCONNECT - SAVE PREFS
// ====================================================================================================
public void OnClientDisconnect(int client)
{
	SavePreferences(client);

	delete g_smSelected[client];
}

void SavePreferences(int client)
{
	// DB not loaded
	if( g_hDB == null ) return;

	// No prefs loaded
	if( g_smSelected[client] == null ) return;

	// Get valid SteamID
	if( GetClientAuthId(client, AuthId_SteamID64, g_szBuffer, sizeof(g_szBuffer)) == false ) return;



	// Loop client preferences
	char sVal[4];
	static char sClass[MAX_LENGTH_CLASS];
	static char szBuffer[MAX_WEAPONS_DB * 2];
	StringMapSnapshot hSnapPrefs = g_smSelected[client].Snapshot();
	int len = hSnapPrefs.Length;
	int index;

	// Reset static char
	szBuffer[0] = 0;

	for( int i = 0; i < len; i++ )
	{
		// Get client weapon classname
		hSnapPrefs.GetKey(i, sClass, sizeof(sClass));

		// Get weapon ID from classname
		if( g_smWeaponClassID.GetString(sClass, sVal, sizeof(sVal)) )
		{
			// Get client charm index from weapon classname
			if( g_smSelected[client].GetValue(sClass, index) )
			{
				Format(szBuffer, sizeof(szBuffer), "%s%s:%d,", szBuffer, sVal, index);
			}
		}
	}

	if( szBuffer[0] ) szBuffer[strlen(szBuffer) - 1] = 0; // Remove last ","

	delete hSnapPrefs;



	// Save to DB
	if( g_bSQLite )
	{
		g_hDB.Format(szBuffer, sizeof(szBuffer), "\
		INSERT INTO \
			`charms` (steamid, weapons, created_at, updated_at) \
		VALUES \
			('%s', '%s', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) ON CONFLICT(steamid) \
		DO UPDATE SET \
			weapons = '%s', \
			updated_at = CURRENT_TIMESTAMP", g_szBuffer, szBuffer, szBuffer);
	} else {
		g_hDB.Format(szBuffer, sizeof(szBuffer), "\
		INSERT INTO \
			`charms` (steamid, weapons, created_at, updated_at) \
		VALUES \
			('%s', '%s', NOW(), NOW()) ON DUPLICATE KEY \
		UPDATE \
			weapons = '%s', \
			updated_at = NOW()", g_szBuffer, szBuffer, szBuffer);
	}

	g_hDB.Query(Database_OnClientSaveData, szBuffer, GetClientUserId(client));
}

public void Database_OnClientSaveData(Database db, DBResultSet results, const char[] error, any data)
{
	if( results == null )
	{
		LogError("[OnClientSaveData] Error: %s", error);
	}
	else
	{
		delete results;
	}
}



// ====================================================================================================
//					CONFIG WEAPONS: LOAD
// ====================================================================================================
void LoadConfigWeapons()
{
	// Open
	if( !FileExists(g_sConfigWeps) )
		SetFailState("Cannot find the file %s", g_sConfigWeps);

	KeyValues kvFile = new KeyValues("Weapons");
	if( !kvFile.ImportFromFile(g_sConfigWeps) )
	{
		delete kvFile;
		SetFailState("Cannot load the file '%s'", g_sConfigWeps);
	}

	// Init
	delete g_smWeaponClassID;
	delete g_smWeaponIDClass;
	delete g_hWeaponsMenu;
	g_sDefaultCharms[0] = 0;

	g_smViewModels = new StringMap();
	g_smWeaponNames = new StringMap();
	g_smWeaponClassID = new StringMap();
	g_smWeaponIDClass = new StringMap();
	g_hWeaponsMenu = new Menu(WeaponMenuHandler);

	char sClass[MAX_LENGTH_CLASS];
	char sName[64];

	// Get Charms data to match used classnames:
	WeaponData wepsData;
	CharmData charmTemp;
	StringMap smWepsData;
	int length = g_aArrayList.Length;
	bool done;



	// Iterate through Weapon keyvalue data config.
	kvFile.GotoFirstSubKey(true);

	do
	{
		kvFile.GetSectionName(sClass, sizeof(sClass));
		done = false;

		// Loop charms
		for( int i = 0; i < length; i++ )
		{
			g_aArrayList.GetArray(i, charmTemp, sizeof(charmTemp));
			smWepsData = charmTemp.smArrayWeapons;

			// Verify weapon classname being used by a Charm, otherwise ignore:
			if( smWepsData.GetArray(sClass, wepsData, sizeof(wepsData)) )
			{
				// We need to loop through all Charms to check for default, but we only need to get name/id once.
				if( done == false )
				{
					// Add to menu
					kvFile.GetString("model", sName, sizeof(sName));
					g_smViewModels.SetValue(sName, 0);

					kvFile.GetString("name", sName, sizeof(sName));
					g_hWeaponsMenu.AddItem(sClass, sName);
					g_smWeaponNames.SetString(sClass, sName);

					kvFile.GetString("id", sName, sizeof(sName));
					g_smWeaponIDClass.SetString(sName, sClass);
					g_smWeaponClassID.SetString(sClass, sName);
				}

				// Default weapons
				if( wepsData.isDefault )
				{
					Format(sName, sizeof(sName), "%s:%d,", sName, i + 1);
					StrCat(g_sDefaultCharms, sizeof(g_sDefaultCharms), sName);

					break; // Validated for menu and found default, so exit
				}

				done = true; // Validated for menu
			}
		}
	}
	while( kvFile.GotoNextKey(true) );

	if( g_sDefaultCharms[0] ) g_sDefaultCharms[strlen(g_sDefaultCharms) - 1] = 0; // Remove last ","

	FormatEx(g_szBuffer, sizeof(g_szBuffer), "%t:", "Charm_Menu2");
	g_hWeaponsMenu.SetTitle(g_szBuffer);
	g_hWeaponsMenu.ExitButton = true;
}



// ====================================================================================================
//					CONFIG DATA: LOAD / OPEN / SAVE
// ====================================================================================================
void LoadConfigCharms()
{
	// Load config
	KeyValues kvFile = OpenConfig();
	char sTemp[MAX_LENGTH_MODEL];



	// Delete any existing StringMap and ArrayList handles
	CharmData charmTemp;
	WeaponData wepsData;
	StringMap smWepsData;

	// Loop through each charm
	if( g_aArrayList != null )
	{
		int len = g_aArrayList.Length;
		for( int i = 0; i < len; i++ )
		{
			// Get CharmData
			g_aArrayList.GetArray(i, charmTemp, sizeof(charmTemp));

			// Get StringMap
			smWepsData = charmTemp.smArrayWeapons;
			delete smWepsData;
		}
	}

	delete g_aArrayList;



	// Create
	g_aArrayList = new ArrayList(sizeof(CharmData));
	int index;
	int count;



	// Iterate through "Charms" keyvalue data config.
	for( ;; )
	{
		index++;
		IntToString(index, sTemp, sizeof(sTemp));
		if( kvFile.JumpToKey(sTemp) )
		{
			kvFile.GetString("mod", sTemp, sizeof(sTemp));

			TrimString(sTemp);
			if( sTemp[0] == 0 )
				continue;

			if( FileExists(sTemp, true) )
			{
				// Main CharmData
				kvFile.GetString("Name", charmTemp.sName, sizeof(charmTemp.sName));
				strcopy(charmTemp.sModelName, sizeof(charmTemp.sModelName), sTemp);

				// Loop through keyvalues config weapon classnames and get data
				count = 0;
				do
				{
					// Classname
					kvFile.GotoFirstSubKey(true);
					kvFile.GetSectionName(sTemp, sizeof(sTemp));

					// Data
					kvFile.GetString("attach_1", wepsData.sAttach_1, sizeof(wepsData.sAttach_1));
					kvFile.GetString("attach_2", wepsData.sAttach_2, sizeof(wepsData.sAttach_2), wepsData.sAttach_1);
					kvFile.GetVector("vpos_1", wepsData.vPos_1);
					kvFile.GetVector("vang_1", wepsData.vAng_1);
					kvFile.GetVector("vpos_2", wepsData.vPos_2, wepsData.vPos_1);
					kvFile.GetVector("vang_2", wepsData.vAng_2, wepsData.vAng_1);
					wepsData.fSize_1 = kvFile.GetFloat("size_1", 1.0);
					wepsData.fSize_2 = kvFile.GetFloat("size_2", wepsData.fSize_1);
					wepsData.boneMerge = kvFile.GetNum("boneMerge");
					wepsData.isDefault = kvFile.GetNum("default");

					// Save weapon classname data to StringMap
					if( count++ == 0 ) smWepsData = new StringMap();
					smWepsData.SetArray(sTemp, wepsData, sizeof(wepsData));
				}
				while( kvFile.GotoNextKey(true) );

				// Save to main CharmData struct
				charmTemp.smArrayWeapons = smWepsData;
				g_aArrayList.PushArray(charmTemp);
			}
			else
				LogError("Cannot find the model '%s'", sTemp);

			kvFile.Rewind();
		}
		else
		{
			break;
		}
	}

	delete kvFile;

	g_iMaxCharmIndex = g_aArrayList.Length;
	if( g_iMaxCharmIndex == 0 )
		SetFailState("No models wtf?!");
}

KeyValues OpenConfig()
{
	if( !FileExists(g_sConfigData) )
		SetFailState("Cannot find the file %s", g_sConfigData);

	KeyValues kvFile = new KeyValues("Charms");
	if( !kvFile.ImportFromFile(g_sConfigData) )
	{
		delete kvFile;
		SetFailState("Cannot load the file '%s'", g_sConfigData);
	}

	return kvFile;
}

void SaveConfig(KeyValues kvFile)
{
	kvFile.Rewind();
	kvFile.ExportToFile(g_sConfigData);
}



// ====================================================================================================
//					EVENTS
// ====================================================================================================
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	OnMapEnd();
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( client )
	{
		DeleteCharm(client);
		g_iSelected[client] = 0;
		g_fSpawned[client] = 0.0;
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( client && (g_bCvarBots || !IsFakeClient(client)) )
	{
		DeleteCharm(client);
		g_iSelected[client] = 0;
		g_bMountedGun[client] = false;

		// Delay so we get proper weapon after weapon equips, also needs longer delay otherwise m_bDrawViewmodel reverts to 1... stupid games.
		CreateTimer(g_iEngine == Engine_Left4Dead ? 3.5 : 2.5, TimerSpawn, GetClientUserId(client));

		g_bCreating[client] = false;
		g_fSpawned[client] = GetGameTime() + 2.3;
	}
}

public Action TimerSpawn(Handle timer, any client)
{
	client = GetClientOfUserId(client);
	if( client && IsClientInGame(client) && IsPlayerAlive(client) )
	{
		int weapon;
		int index = GetCharmFromClassname(client, weapon);
		if( index )
		{
			CreateCharm(client, index - 1);

			// Fix weapon being invisible when creating charm on first spawn.. strange game bug.
			if( g_iEngine != Engine_CSGO )
			{
				CreateCharm(client, index - 1);

				g_iLastItem[client] = weapon;
				RemovePlayerItem(client, weapon);
				EquipPlayerWeapon(client, weapon);
			}
		}
	}

	return Plugin_Continue;
}

// Block charms while zooming down the scope
public void Event_Zoom(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( client > 0 )
	{
		bool zoom;
		if( g_iEngine == Engine_CSGO )
		{
			int weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
			zoom = GetEntProp(weapon, Prop_Send, "m_zoomLevel") != 0;
			if( !zoom ) zoom = GetEntProp(weapon, Prop_Send, "m_iIronSightMode") != 0;
		} else {
			zoom = GetEntPropEnt(client, Prop_Send, "m_hZoomOwner") != -1;
		}

		if( zoom )
		{
			DeleteCharm(client);
		}
		else
		{
			int weapon;
			int index = GetCharmFromClassname(client, weapon);
			if( index )
			{
				CreateCharm(client, index - 1);
			}
		}
	}
}

// L4D1/2: Block charms while using miniguns.
public void OnEntityCreated(int entity, const char[] classname)
{
	if( g_iEngine == Engine_Left4Dead )
	{
		if( strcmp(classname, "prop_minigun") == 0 || strcmp(classname, "prop_mounted_machine_gun") == 0 )
		{
			SDKHook(entity, SDKHook_UsePost, OnUseMinigun);
		}
	}
	else if( g_iEngine == Engine_Left4Dead2 )
	{
		if( strcmp(classname, "prop_minigun_l4d1") == 0 )
		{
			SDKHook(entity, SDKHook_UsePost, OnUseMinigun);
		}
	}
}

public Action OnUseMinigun(int weapon, int client, int caller, UseType type, float value)
{
	// Detect actually when mounting, and verify mounted (otherwise they're just pressing E whilst looking at MG but not actually mounting)
	if( client && type == Use_Toggle && GetEntProp(client, Prop_Send, "m_usingMountedWeapon") )
	{
		g_bMountedGun[client] = true;
		g_fSpawned[client] = 99999.9;
		DeleteCharm(client);

		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0); // Hide since delete unhides

		// Have to delete Attachments_API bone to remove thirdperson view of weapon, setting render has no affect
		int entity = g_iEntBones[client];
		if( IsValidEntRef(entity) )
		{
			RemoveEntity(entity);
		}

		// From "Survivor Thirdperson" plugin:
		if( g_hTimerGun == null )
		{
			g_hTimerGun = CreateTimer(0.3, TimerCheck, _, TIMER_REPEAT);
		}
	}

	return Plugin_Continue;
}

// L4D2: Block charms while using miniguns.
public void Event_Block2(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_bMountedGun[client] = true;
	g_fSpawned[client] = 99999.9;
	DeleteCharm(client);

	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0); // Hide since delete unhides

	// Have to delete Attachments_API bone to remove thirdperson view of weapon, setting render has no affect
	int entity = g_iEntBones[client];
	if( IsValidEntRef(entity) )
	{
		RemoveEntity(entity);
	}

	// From "Survivor Thirdperson" plugin:
	if( g_hTimerGun == null )
	{
		g_hTimerGun = CreateTimer(0.3, TimerCheck, _, TIMER_REPEAT);
	}
}

public Action TimerCheck(Handle timer)
{
	// Need to check for dismount after event (L4D2) / OnUse (L4D1) triggers
	int count;
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( g_bMountedGun[i] && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2 )
		{
			if( GetEntProp(i, Prop_Send, "m_usingMountedWeapon") )
			{
				count++;
			}
			else
			{
				g_bMountedGun[i] = false;
				g_fSpawned[i] = 1.0;
				SetEntProp(i, Prop_Send, "m_bDrawViewmodel", 1); // Unhide

				int index = GetCharmFromClassname(i);
				if( index )
				{
					CreateCharm(i, index - 1);
				}
			}
		}
	}

	if( count )
		return Plugin_Continue;

	g_hTimerGun = null;
	return Plugin_Stop;
}

// Block charms while pinned.
public void Event_BlockStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if( client > 0 )
	{
		g_fSpawned[client] = 99999.9;
		DeleteCharm(client);
	}
}

public void Event_BlockEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if( client > 0 )
	{
		g_fSpawned[client] = 1.0;

		int index = GetCharmFromClassname(client);
		if( index )
		{
			CreateCharm(client, index - 1);
		}
	}
}

// Block charms while incapped/ledge hanging.
public void Event_Block(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_fSpawned[client] = 99999.9;
	DeleteCharm(client);
}

public void Event_Unlock(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_fSpawned[client] = 1.0;

	int index = GetCharmFromClassname(client);
	if( index )
	{
		CreateCharm(client, index - 1);
	}
}

public void Event_Unlock2(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	g_fSpawned[client] = 1.0;

	int index = GetCharmFromClassname(client);
	if( index )
	{
		CreateCharm(client, index - 1);
	}
}

// When the intro cut scene finishes the viewmodel is shown again, prevent that if charm equipped
public void Event_Instructor(Event event, const char[] name, bool dontBroadcast)
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		int entity = g_iEntSaved[i][INDEX_VIEWS];
		if( IsValidEntRef(entity) )
		{
			SetEntProp(i, Prop_Send, "m_bDrawViewmodel", 0);
		}
	}
}

// Need to set bots "m_bDrawViewmodel" to 1 when they replace a player with active Charm, otherwise "m_bDrawViewmodel" stays on 0 when players replace the bot and will have no viewmodel showing.
public void Event_BotReplace(Event event, const char[] name, bool dontBroadcast)
{
	int bot = GetClientOfUserId(event.GetInt("bot"));
	if( bot )
	{
		SetEntProp(bot, Prop_Send, "m_bDrawViewmodel", 1);
	}
}

// Fix L4D/2 picking up second pistol, change fake VM to dual pistol model.
public void Event_PlayerUse(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( client )
	{
		int index = g_iSelected[client]; // Has charm
		if( index )
		{
			int entity = event.GetInt("targetid"); // What we're attempting to use/pickup
			if( entity && IsValidEntity(entity) )
			{
				GetEdictClassname(entity, g_szBuffer, sizeof(g_szBuffer)); // Verify it's a pistol
				if( strncmp(g_szBuffer, "weapon_pistol", 13) == 0 )
				{
					entity = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
					if( GetEntProp(entity, Prop_Send, "m_isDualWielding") ) // Are we dual wielding
					{
						GetEdictClassname(entity, g_szBuffer, sizeof(g_szBuffer)); // Is our pistol equipped
						if( strcmp(g_szBuffer, "weapon_pistol") == 0 )
						{
							if( g_iEntBones[client] && EntRefToEntIndex(g_iEntBones[client]) != INVALID_ENT_REFERENCE ) // Do we have fake viewmodel
							{
								// Have to delete to reposition since it changes -_-
								DeleteCharm(client); // FIXME: Should teleport instead of delete.
								CreateCharm(client, index - 1);

								SetEntityModel(g_iEntBones[client], g_sPistol); // Fix wrong model bug
								SetEntityRenderMode(g_iEntBones[client], RENDER_NORMAL);
							}
						}
					}
				}
			}
		}
	}
}



// ====================================================================================================
//					COMMAND VALIDATION
// ====================================================================================================
bool ValidateCommand(int client)
{
	if( client == 0 )
	{
		ReplyToCommand(client, "[Charms] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return false;
	}

	if( g_bCvarAllow == false || g_bValidMap == false )
	{
		CPrintToChat(client, "%s%t", g_sCHAT_TAG, "Charm_Off");
		return false;
	}

	if( IsValidClient(client) == false )
	{
		CPrintToChat(client, "%s%t", g_sCHAT_TAG, "Charm_Invalid");
		return false;
	}

	return true;
}



// ====================================================================================================
//					COMMAND: SAVE DATA
// ====================================================================================================
public Action CmdSave(int client, int args)
{
	KeyValues kvFile = OpenConfig();
	SaveConfig(kvFile);
	delete kvFile;

	return Plugin_Handled;
}

void SaveData(int client)
{
	// Open file
	KeyValues kvFile = OpenConfig();
	int index = g_iSelected[client] - 1;

	// Weapon valid test
	int weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	if( weapon == -1 )
	{
		CPrintToChat(client, "%s%t", g_sCHAT_TAG, "Charm_Empty");
		return;
	}

	// Get CharmData
	WeaponData wepsData;
	CharmData charmTemp;
	g_aArrayList.GetArray(index, charmTemp, sizeof(charmTemp));
	StringMap smWepsData = charmTemp.smArrayWeapons;

	// Classname test
	GetEdictClassname(weapon, g_szBuffer, sizeof(g_szBuffer));

	if( smWepsData.GetArray(g_szBuffer, wepsData, sizeof(wepsData)) == false )
	{
		CPrintToChat(client, "%s%t", g_sCHAT_TAG, "Charm_Weapon");
		return;
	}

	// Retrieve main data
	g_aArrayList.GetArray(index, charmTemp, sizeof(charmTemp));

	char sTemp[4];
	IntToString(index+1, sTemp, sizeof(sTemp));

	// Jump to Charm and classname sections
	if( kvFile.JumpToKey(sTemp, true) && kvFile.JumpToKey(g_szBuffer, true) )
	{
		// Get values
		float fSize;
		float vAng[3], vPos[3];

		// ViewModel
		int entity = g_iEntSaved[client][INDEX_VIEWS];
		if( IsValidEntRef(entity) )
		{
			GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
			kvFile.SetVector("vpos_1", vPos);
			kvFile.SetVector("vang_1", vAng);
			wepsData.vAng_1 = vAng;
			wepsData.vPos_1 = vPos;

			if( g_bAllowSize )
			{
				fSize = GetEntPropFloat(entity, Prop_Send, "m_flModelScale");
				if( fSize != 1.0 )
					kvFile.SetFloat("size_1", fSize);
				wepsData.fSize_1 = fSize;
			}
		}

		// WorldModel
		entity = g_iEntSaved[client][INDEX_WORLD];
		if( IsValidEntRef(entity) )
		{
			GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);

			if( g_bAllowSize )
				fSize = GetEntPropFloat(entity, Prop_Send, "m_flModelScale");

			kvFile.SetVector("vpos_2", vPos);
			kvFile.SetVector("vang_2", vAng);

			if( g_bAllowSize )
			{
				if( fSize != 1.0 )
					kvFile.SetFloat("size_2", fSize);
				wepsData.fSize_2 = fSize;
			}

			wepsData.vAng_2 = vAng;
			wepsData.vPos_2 = vPos;
		}

		smWepsData.SetArray(g_szBuffer, wepsData, sizeof(wepsData));
		g_aArrayList.SetArray(index, charmTemp, sizeof(charmTemp));

		SaveConfig(kvFile);
		PrintToChat(client, "%sSaved \x04all \x01charms pos/ang/size.", g_sCHAT_TAG);
	}
	else
	{
		PrintToChat(client, "%s\x04Error: \x01Could not save pos/ang/size.", g_sCHAT_TAG);
	}

	delete kvFile;
}



// ====================================================================================================
//					COMMAND: RELOAD
// ====================================================================================================
public Action CmdReload(int client, int args)
{
	float fTime = GetEngineTime();

	LoadConfigCharms();
	LoadConfigWeapons();

	if( !client )
		ReplyToCommand(client, "[Charms] Reloaded configs in %f seconds.", GetEngineTime() - fTime);
	else
		PrintToChat(client, "%sReloaded config in %f seconds.", g_sCHAT_TAG, GetEngineTime() - fTime);

	return Plugin_Handled;
}



// ====================================================================================================
//					MENU: WEAPONS
// ====================================================================================================
public Action CmdCharms(int client, int args)
{
	ShowWeaponMenu(client);
	return Plugin_Handled;
}

void ShowWeaponMenu(int client, int menupos = 0)
{
	if( ValidateCommand(client) == false )
		return;

	FormatEx(g_szBuffer, sizeof(g_szBuffer), "%T:", "Charm_Menu2", client);
	g_hWeaponsMenu.SetTitle(g_szBuffer);
	g_hWeaponsMenu.DisplayAt(client, menupos, MENU_TIME_FOREVER);
}

public int WeaponMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_Select )
	{
		if( IsValidClient(client) )
		{
			// g_iWeaponsMenu[client] = menu.Selection + 1; // Changed so we can use selected menu index instead of page
			g_iWeaponsMenu[client] = index + 1;
			ShowCharmMenu(client);
		}
	}

	return 0;
}



// ====================================================================================================
//					MENU: CHARM
// ====================================================================================================
public Action CmdCharm(int client, int args)
{
	g_iWeaponsMenu[client] = 0;
	g_iEditing[client] = 0;

	if( args )
	{
		GetCmdArg(1, g_szBuffer, sizeof(g_szBuffer));
		int index = StringToInt(g_szBuffer);
		DeleteCharm(client);

		if( index > 0 && index <= g_aArrayList.Length )
		{
			CreateCharm(client, index - 1, true);
		}
	}
	else
	{
		ShowCharmMenu(client);
	}
	return Plugin_Handled;
}

void ShowCharmMenu(int client, int menupos = 0)
{
	if( ValidateCommand(client) == false )
		return;



	Menu menu = new Menu(CharmMenuHandler);

	// CSGO: Bugged when ITEMDRAW_DISABLED used?
	// menu.AddItem("", "<None>", g_iSelected[client] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	if( g_iSelected[client] || g_iWeaponsMenu[client] )
		menu.AddItem("", "<None>");
	else
		menu.AddItem("", "* <None>");
	menu.AddItem("", "<Save Preferences>\n ");



	char sVal[4];
	char classname[MAX_LENGTH_CLASS];
	CharmData charmTemp;
	WeaponData wepsData;
	int len = g_aArrayList.Length;



	// Get the weapon classname to filter and display in menu title.
	// Either selected weapon from sm_charms menu or from players held weapon from sm_charm
	if( g_iWeaponsMenu[client] )
	{
		g_hWeaponsMenu.GetItem(g_iWeaponsMenu[client] - 1, classname, sizeof(classname));
		g_smWeaponNames.GetString(classname, g_szBuffer, sizeof(g_szBuffer));
	} else {
		int weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		if( weapon != -1 )
		{
			GetEdictClassname(weapon, classname, sizeof(classname));
		}
	}

	// List charms - add to menu
	for( int i = 0; i < len; i++ )
	{
		g_aArrayList.GetArray(i, charmTemp, sizeof(charmTemp));
		StringMap smWepsData = charmTemp.smArrayWeapons;

		if( smWepsData.GetArray(classname, wepsData, sizeof(wepsData)) ) // Check charm exists for weapon
		{
			IntToString(i, sVal, sizeof(sVal));

			if( g_iSelected[client] == i + 1 && g_iWeaponsMenu[client] == 0 )
			{
				FormatEx(g_szBuffer, sizeof(g_szBuffer), "* %s", charmTemp.sName);
				menu.AddItem(sVal, g_szBuffer);
			}
			else
				menu.AddItem(sVal, charmTemp.sName);
		}
	}

	if( g_iWeaponsMenu[client] )
		menu.ExitBackButton = true;
	else
		menu.ExitButton = true;

	// Title
	// Only display weapon name in title when selecting from sm_charms (weapons menu).
	// When using sm_cham and changing weapon the title will no longer be related to current held weapon.
	// Maybe future update to support re-displaying menu on weapon change, have to track when menus open/closed so we can decide to redisplay or not.
	// TODO: Something like store menu handle and check against menu close to match client index, to determine if closed by user.
	// if( classname[0] )
	if( g_iWeaponsMenu[client] )
	{
		g_smWeaponNames.GetString(classname, g_szBuffer, sizeof(g_szBuffer));
		Format(g_szBuffer, sizeof(g_szBuffer), "%T | %s:", "Charm_Menu2", client, g_szBuffer);
	} else {
		FormatEx(g_szBuffer, sizeof(g_szBuffer), "%T:", "Charm_Menu2", client);
	}

	menu.SetTitle(g_szBuffer);
	menu.DisplayAt(client, menupos, MENU_TIME_FOREVER);
}

public int CharmMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_End )
	{
		delete menu;
	}
	else if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
		{
			// Instead of using menu.Selection, we store the index for other usage. This returns us to the correct last menu.
			ShowWeaponMenu(client, 7 * (RoundToCeil(g_iWeaponsMenu[client] / 7.0) - 1));
		}
	}
	else if( action == MenuAction_Select )
	{
		if( IsValidClient(client) )
		{
			// Remove charm
			if( index == 0 )
			{
				// Save clients pref
				if( g_iWeaponsMenu[client] == 0 )
				{
					// Remove charm from held weapon
					index = GetCharmFromClassname(client); // Populates g_szBuffer
					if( index )
					{
						g_smSelected[client].SetValue(g_szBuffer, 0);
					}

					DeleteCharm(client);
					g_iSelected[client] = 0;

					CPrintToChat(client, "%s%t", g_sCHAT_TAG, "Charm_Remove");
				} else {
					g_hWeaponsMenu.GetItem(g_iWeaponsMenu[client] - 1, g_szBuffer, sizeof(g_szBuffer)); // Get classname from index
					g_smSelected[client].SetValue(g_szBuffer, 0); // Update pref
					g_smWeaponNames.GetString(g_szBuffer, g_szBuffer, sizeof(g_szBuffer)); // Get weapon name from classname
					CPrintToChat(client, "%s%t", g_sCHAT_TAG, "Charm_Removed", g_szBuffer);
				}
			}
			// Save prefs
			else if( index == 1 )
			{
				if( g_fLastSave[client] < GetGameTime() )
				{
					CPrintToChat(client, "%s%t", g_sCHAT_TAG, "Charm_Saved");
					g_fLastSave[client] = GetGameTime() + 60;
					SavePreferences(client);
				} else {
					CPrintToChat(client, "%s%t", g_sCHAT_TAG, "Charm_Wait", RoundFloat(g_fLastSave[client] - GetGameTime()));
				}
			}
			else
			{
				if( g_fCvarTimeout && GetGameTime() < g_fTimeout[client] )
				{
					int time = RoundFloat(g_fTimeout[client] - GetGameTime());
					if( time == 0 ) time = 1;
					CPrintToChat(client, "%s%t", g_sCHAT_TAG, "Charm_Wait", time);
				} else {
					if( g_fCvarTimeout )
						g_fTimeout[client] = GetGameTime() + g_fCvarTimeout;

					char sVal[4];

					// Create
					if( g_iWeaponsMenu[client] == 0 )
					{
						GetMenuItem(menu, index, sVal, sizeof(sVal));
						index = StringToInt(sVal);

						CreateCharm(client, index, true);
						SetCharmView(client, false);

						g_iSelected[client] = index + 1; // Adding this here since delay creating.
					} else {
						// Update selected weapon with specific charm
						int na;
						char classname[MAX_LENGTH_CLASS];
						GetMenuItem(menu, index, sVal, sizeof(sVal));

						// Messy, but works lol.
						g_hWeaponsMenu.GetItem(g_iWeaponsMenu[client] - 1, classname, sizeof(classname)); // Get classname from index
						g_smSelected[client].SetValue(classname, StringToInt(sVal) + 1); // Update pref
						g_smWeaponNames.GetString(classname, classname, sizeof(classname)); // Get weapon name from classname
						menu.GetItem(index, sVal, sizeof(sVal), na, g_szBuffer, sizeof(g_szBuffer)); // Get selected charm name from current menu
						CPrintToChat(client, "%s%t", g_sCHAT_TAG, "Charm_Set", g_szBuffer, classname);
					}
				}
			}

			if( g_iEditing[client] )
				ShowEditMenu(client);
			else
				ShowCharmMenu(client, menu.Selection);
		}
	}

	return 0;
}



// ====================================================================================================
//					MENU: EDIT
// ====================================================================================================
public Action CmdEdit(int client, int args)
{
	if( ValidateCommand(client) == false )
		return Plugin_Handled;

	int index = 1;
	char sVal[4];
	if( args == 1 )
	{
		GetCmdArg(1, sVal, sizeof(sVal));
		index = StringToInt(sVal);
		if( index < 1 ) index = 1;
		else if( index > 2 ) index = 2;
	}

	PrintToChat(client, "%sSelected '\x04%s\x01' to edit.", g_sCHAT_TAG, index == 1 ? "ViewModel" : "WorldModel");

	g_iEditing[client] = index;
	ShowEditMenu(client);

	return Plugin_Handled;
}

void ShowEditMenu(int client)
{
	if( ValidateCommand(client) == false )
		return;

	Menu menu = new Menu(EditMenuHandler);

	menu.AddItem("", "Select Charm");
	menu.AddItem("", "Edit Pos");
	menu.AddItem("", "Edit Ang");
	if( g_bAllowSize )
		menu.AddItem("", "Edit Size");

	menu.SetTitle("Editing:");
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int EditMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_End )
	{
		delete menu;
	}
	else if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_Exit )
			g_iEditing[client] = 0;
	}
	else if( action == MenuAction_Select )
	{
		switch( index )
		{
			case 0: ShowCharmMenu(client);
			case 1: ShowPosMenu(client);
			case 2: ShowAngMenu(client);
			case 3: ShowSizeMenu(client);
		}
	}

	return 0;
}



// ====================================================================================================
//					MENU: ANG
// ====================================================================================================
public Action CmdAng(int client, int args)
{
	if( ValidateCommand(client) == false )
		return Plugin_Handled;

	if( g_iEditing[client] == 0 )
	{
		PrintToChat(client, "%sUse sm_charm_edit <1|2> to select editing ViewModel or WorldModel before setting pos/ang/size.", g_sCHAT_TAG);
		return Plugin_Handled;
	}

	int entity = g_iEntSaved[client][g_iEditing[client] - 1];
	if( IsValidEntRef(entity) )
	{
		ShowAngMenu(client);
	} else {
		PrintToChat(client, "%sNo charm selected.", g_sCHAT_TAG);
	}

	return Plugin_Handled;
}

void ShowAngMenu(int client)
{
	if( ValidateCommand(client) == false )
		return;

	Menu menu = new Menu(AngMenuHandler);

	menu.AddItem("", "X + 10.0");
	menu.AddItem("", "Y + 10.0");
	menu.AddItem("", "Z + 10.0");
	menu.AddItem("", "X - 10.0");
	menu.AddItem("", "Y - 10.0");
	menu.AddItem("", "Z - 10.0");
	menu.AddItem("", "Save");
	menu.AddItem("", "Reset");

	menu.SetTitle("Set charm angles:");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int AngMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_End )
	{
		delete menu;
	}
	else if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowEditMenu(client);
		else if( index == MenuCancel_Exit )
			g_iEditing[client] = 0;
	}
	else if( action == MenuAction_Select )
	{
		if( ValidateCommand(client) == false )
			return 0;

		ShowAngMenu(client);

		int entity = g_iEntSaved[client][g_iEditing[client] - 1];
		if( IsValidEntRef(entity) )
		{
			float vAng[3];
			GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);

			switch( index )
			{
				case 0: vAng[0] += 10.0;
				case 1: vAng[1] += 10.0;
				case 2: vAng[2] += 10.0;
				case 3: vAng[0] -= 10.0;
				case 4: vAng[1] -= 10.0;
				case 5: vAng[2] -= 10.0;
				case 7: vAng = view_as<float>({0.0,0.0,0.0});
				case 6:
				{
					SaveData(client);
				}
			}

			if( index != 6 )
			{
				TeleportEntity(entity, NULL_VECTOR, vAng, NULL_VECTOR);

				PrintToChat(client, "%sNew \x04angles\x01 (%s): %f %f %f", g_sCHAT_TAG, g_iEditing[client] == 1 ? "ViewModel" : "WorldModel", vAng[0], vAng[1], vAng[2]);
			}
		}
	}

	return 0;
}

// ====================================================================================================
//					MENU: POS
// ====================================================================================================
public Action CmdPos(int client, int args)
{
	if( ValidateCommand(client) == false )
		return Plugin_Handled;

	if( g_iEditing[client] == 0 )
	{
		PrintToChat(client, "%sUse sm_charm_edit <1|2> to select editing ViewModel or WorldModel before setting pos/ang/size.", g_sCHAT_TAG);
		return Plugin_Handled;
	}

	int entity = g_iEntSaved[client][g_iEditing[client] - 1];
	if( IsValidEntRef(entity) )
	{
		ShowPosMenu(client);
	} else {
		PrintToChat(client, "%sNo charm selected.", g_sCHAT_TAG);
	}

	return Plugin_Handled;
}

void ShowPosMenu(int client)
{
	if( ValidateCommand(client) == false )
		return;

	Menu menu = new Menu(PosMenuHandler);

	menu.AddItem("", "Z - 0.2 (Left)");
	menu.AddItem("", "Z + 0.2 (Right");
	menu.AddItem("", "X + 0.2 (Fwd)");
	menu.AddItem("", "X - 0.2 (Back)");
	menu.AddItem("", "Y + 0.2 (Up)");
	menu.AddItem("", "Y - 0.2 (Down)");

	menu.AddItem("", "Save");
	menu.AddItem("", "Reset");

	menu.SetTitle("Set charm position:");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int PosMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_End )
	{
		delete menu;
	}
	else if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowEditMenu(client);
		else if( index == MenuCancel_Exit )
			g_iEditing[client] = 0;
	}
	else if( action == MenuAction_Select )
	{
		if( ValidateCommand(client) == false )
			return 0;

		ShowPosMenu(client);

		int entity = g_iEntSaved[client][g_iEditing[client] - 1];
		if( IsValidEntRef(entity) )
		{
			float vPos[3];
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);

			if( g_iEngine == Engine_CSGO )
			{
				switch( index )
				{
					case 0: vPos[1] += 0.2;
					case 1: vPos[1] -= 0.2;
					case 2: vPos[0] += 0.2;
					case 3: vPos[0] -= 0.2;
					case 4: vPos[2] += 0.2;
					case 5: vPos[2] -= 0.2;
					case 7: vPos = view_as<float>({0.0,0.0,0.0});
				}
			} else {
				switch( index )
				{
					case 0: vPos[2] -= 0.2;
					case 1: vPos[2] += 0.2;
					case 2: vPos[0] += 0.2;
					case 3: vPos[0] -= 0.2;
					case 4: vPos[1] += 0.2;
					case 5: vPos[1] -= 0.2;
					case 7: vPos = view_as<float>({0.0,0.0,0.0});
				}
			}

			if( index == 6 )
			{
				SaveData(client);
			}
			else
			{
				TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);

				PrintToChat(client, "%sNew \x04origin\x01 (%s): %f %f %f", g_sCHAT_TAG, g_iEditing[client] == 1 ? "ViewModel" : "WorldModel", vPos[0], vPos[1], vPos[2]);
			}
		}
	}

	return 0;
}

// ====================================================================================================
//					MENU: SIZE
// ====================================================================================================
public Action CmdSize(int client, int args)
{
	if( ValidateCommand(client) == false )
		return Plugin_Handled;

	if( g_iEditing[client] == 0 )
	{
		PrintToChat(client, "%sUse sm_charm_edit <1|2> to select editing ViewModel or WorldModel before setting pos/ang/size.", g_sCHAT_TAG);
		return Plugin_Handled;
	}

	int entity = g_iEntSaved[client][g_iEditing[client] - 1];
	if( IsValidEntRef(entity) )
	{
		ShowSizeMenu(client);
	} else {
		PrintToChat(client, "%sNo charm selected.", g_sCHAT_TAG);
	}

	return Plugin_Handled;
}

void ShowSizeMenu(int client)
{
	if( ValidateCommand(client) == false )
		return;

	if( !g_bAllowSize )
	{
		PrintToChat(client, "%sCannot resize charms in this game.", g_sCHAT_TAG);
		return;
	}

	Menu menu = new Menu(SizeMenuHandler);

	menu.AddItem("", "+ 0.001");
	menu.AddItem("", "- 0.001");
	menu.AddItem("", "+ 0.01");
	menu.AddItem("", "- 0.01");
	menu.AddItem("", "+ 0.1");
	menu.AddItem("", "- 0.1");
	menu.AddItem("", "Save");
	menu.AddItem("", "Reset");

	menu.SetTitle("Set charm size:");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int SizeMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_End )
	{
		delete menu;
	}
	else if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowEditMenu(client);
		else if( index == MenuCancel_Exit )
			g_iEditing[client] = 0;
	}
	else if( action == MenuAction_Select )
	{
		if( ValidateCommand(client) == false )
			return 0;

		ShowSizeMenu(client);

		int entity = g_iEntSaved[client][g_iEditing[client] - 1];
		if( IsValidEntRef(entity) )
		{
			float fSize = GetEntPropFloat(entity, Prop_Send, "m_flModelScale");

			switch( index )
			{
				case 0: fSize += 0.001;
				case 1: fSize -= 0.001;
				case 2: fSize += 0.01;
				case 3: fSize -= 0.01;
				case 4: fSize += 0.1;
				case 5: fSize -= 0.1;
				case 7: fSize = 1.0;
				case 6:
				{
					SaveData(client);
				}
			}

			if( fSize < 0.0 ) fSize = 0.00001;

			if( index != 6 )
			{
				SetEntPropFloat(entity, Prop_Send, "m_flModelScale", fSize);

				PrintToChat(client, "%sNew \x04scale\x01 (%s): %f", g_sCHAT_TAG, g_iEditing[client] == 1 ? "ViewModel" : "WorldModel", fSize);
			}
		}
	}

	return 0;
}



// ====================================================================================================
//					CREATE CHARM
// ====================================================================================================
void CreateCharm(int client, int index, bool manual = false)
{
	if( g_fSpawned[client] == 0.0 || g_fSpawned[client] > GetGameTime() ) return; // Prevent weapon switch deleting/creating charms before player spawn or just after player spawn

	if( g_bCreating[client] ) return; // Prevent trying to spawn again during the delay.



	// =========================
	// Verified previous deleted
	// FIXME: Multiple charms?
	// =========================
	DeleteCharm(client);



	// =========================
	// Delay creation
	// =========================
	g_bCreating[client] = true;
	DataPack hPack = new DataPack();

	// CreateTimer(0.1, DelayCreate, hPack);
	RequestFrame(DelayCreate, hPack);
	hPack.WriteCell(GetClientUserId(client));
	hPack.WriteCell(index);
	hPack.WriteCell(manual);
}

void DelayCreate(DataPack hPack)
// public Action DelayCreate(Handle timer, DataPack hPack)
{
	hPack.Reset();
	int client = hPack.ReadCell();
	int index = hPack.ReadCell();
	bool manual = hPack.ReadCell();
	delete hPack;

	if( (client = GetClientOfUserId(client)) == 0 ) return;
	g_bCreating[client] = false;

	// Since delaying and not manually selected, get index here in case weapon changed within delay.
	if( !manual )
	{
		index = GetCharmFromClassname(client);
		if( index == 0 ) return;
		index -= 1;
	}



	// =========================
	// Weapon valid test
	// =========================
	int weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	if( weapon == -1 )
	{
		if( manual )
			CPrintToChat(client, "%s%t", g_sCHAT_TAG, "Charm_Empty");
		return;
	}

	if( manual && g_iEngine == Engine_CSGO )
	{
		if( CheckDefSupport(weapon) == false )
		{
			CPrintToChat(client, "%s%t", g_sCHAT_TAG, "Charm_Weapon");
			return;
		}
	}



	// =========================
	// Validate index
	// =========================
	if( g_aArrayList.Length < index )
	{
		LogError("Tried to select index %d but only %d entries in your charms.game.cfg", index, g_aArrayList.Length);
		CPrintToChat(client, "%s%t", g_sCHAT_TAG, "Charm_Index", index);
		g_iSelected[client] = 0;
		return;
	}



	// =========================
	// Get CharmData
	// =========================
	WeaponData wepsData;
	CharmData charmTemp;
	g_aArrayList.GetArray(index, charmTemp, sizeof(charmTemp));
	StringMap smWepsData = charmTemp.smArrayWeapons;



	// =========================
	// Classname test
	// =========================
	static char classname[MAX_LENGTH_CLASS];
	static char modelname[MAX_LENGTH_MODEL];
	GetEdictClassname(weapon, classname, sizeof(classname));

	if( smWepsData.GetArray(classname, wepsData, sizeof(wepsData)) == false )
	{
		if( manual )
			CPrintToChat(client, "%s%t", g_sCHAT_TAG, "Charm_Weapon");
		return;
	}



	// =========================
	// Save clients pref
	// =========================
	int bone;
	bool isBot;

	if( g_bCvarBots )
	{
		isBot = IsFakeClient(client);

	}

	if( !isBot )
		g_smSelected[client].SetValue(classname, index + 1);



	// Get clients viewmodel
	int viewmodel = GetEntPropEnt(client, Prop_Data, "m_hViewModel");



	// =========================
	// Create Fake Arms
	// =========================
	if( !isBot )
	{
		int m_nSkin;

		switch( g_iEngine )
		{
			case Engine_Left4Dead:
			{
				switch( GetEntProp(client, Prop_Send, "m_survivorCharacter") )
				{
					case 0: modelname = "models/v_models/v_arm_namvet.mdl";
					case 1: modelname = "models/v_models/v_arm_teengirl.mdl";
					case 2: modelname = "models/v_models/v_arm_biker.mdl";
					case 3: modelname = "models/v_models/v_arm_manager.mdl";
				}
			}
			case Engine_Left4Dead2:
			{
				GetClientModel(client, modelname, sizeof(modelname));

				switch( modelname[29] )
				{
					case 'b': // Nick
					{
						modelname = "models/weapons/arms/v_arms_gambler_new.mdl";
					}
					case 'd', 'w': // Rochelle, Adawong
					{
						modelname = "models/weapons/arms/v_arms_producer_new.mdl";
					}
					case 'c': // Coach
					{
						modelname = "models/weapons/arms/v_arms_coach_new.mdl";
					}
					case 'h': // Ellis
					{
						modelname = "models/weapons/arms/v_arms_mechanic_new.mdl";
					}
					case 'v': // Bill
					{
						modelname = "models/weapons/arms/v_arms_bill.mdl";
					}
					case 'n': // Zoey
					{
						modelname = "models/weapons/arms/v_arms_zoey.mdl";
					}
					case 'e': // Francis
					{
						modelname = "models/weapons/arms/v_arms_francis.mdl";
					}
					case 'a': // Louis
					{
						modelname = "models/weapons/arms/v_arms_louis.mdl";
					}
				}

				/*
				switch( GetEntProp(client, Prop_Send, "m_survivorCharacter") )
				{
					case 0: modelname = "models/weapons/arms/v_arms_gambler_new.mdl";
					case 1: modelname = "models/weapons/arms/v_arms_producer_new.mdl";
					case 2: modelname = "models/weapons/arms/v_arms_coach_new.mdl";
					case 3: modelname = "models/weapons/arms/v_arms_mechanic_new.mdl";
					case 4: modelname = "models/weapons/arms/v_arms_bill.mdl";
					case 5: modelname = "models/weapons/arms/v_arms_zoey.mdl";
					case 6: modelname = "models/weapons/arms/v_arms_francis.mdl";
					case 7: modelname = "models/weapons/arms/v_arms_louis.mdl";
				}
				// */
			}
			case Engine_CSGO:
			{
				GetArmsModel(client, modelname, sizeof(modelname), m_nSkin);
			}
		}



		int ent_arms = CreateEntityByName("prop_dynamic_override");
		DispatchKeyValue(ent_arms, "model", modelname);
		DispatchKeyValue(ent_arms, "solid", "0");
		DispatchKeyValue(ent_arms, "spawnflags", "256");
		DispatchKeyValue(ent_arms, "disablereceiveshadows", "1");
		DispatchKeyValue(ent_arms, "disableshadows", "1");
		DispatchSpawn(ent_arms);
		SetEntProp(ent_arms, Prop_Send, "m_nSkin", m_nSkin);

		g_iEntSaved[client][INDEX_ARMS] = EntIndexToEntRef(ent_arms);

		// Attach to real viewmodel
		SetAttached(ent_arms, viewmodel);

		SDKHook(ent_arms, SDKHook_SetTransmit, Hook_SetTransmitViews);

		// Hide real viewmodel
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);

		// Prevent blocking +USE LoS. Thanks to "Lux".
		SetEntProp(ent_arms, Prop_Data, "m_iEFlags", GetEntProp(ent_arms, Prop_Data, "m_iEFlags") | EFL_DONTBLOCKLOS | SF_PHYSPROP_PREVENT_PICKUP);
		SetEntProp(ent_arms, Prop_Send, "m_nSolidType", 6, 1);



		// =========================
		// Create charm - ViewModel version
		// =========================
		int charm_view = CreateEntityByName("prop_dynamic_override");
		DispatchKeyValue(charm_view, "model", charmTemp.sModelName);
		DispatchKeyValue(charm_view, "solid", "0");
		DispatchKeyValue(charm_view, "spawnflags", "256");
		DispatchKeyValue(charm_view, "disablereceiveshadows", "1");
		DispatchKeyValue(charm_view, "disableshadows", "1");
		DispatchSpawn(charm_view);

		// Prevent blocking +USE LoS. Thanks to "Lux".
		SetEntProp(charm_view, Prop_Data, "m_iEFlags", GetEntProp(charm_view, Prop_Data, "m_iEFlags") | EFL_DONTBLOCKLOS | SF_PHYSPROP_PREVENT_PICKUP);
		SetEntProp(charm_view, Prop_Send, "m_nSolidType", 6, 1);

		// Scale
		if( g_bAllowSize )
			SetEntPropFloat(charm_view, Prop_Send, "m_flModelScale", wepsData.fSize_1);

		g_iEntSaved[client][INDEX_VIEWS] = EntIndexToEntRef(charm_view);



		// =========================
		// Replica weapon - ViewModel version
		// =========================
		bone = Attachments_GetViewModel(client, viewmodel); // Attach to viewmodel
		if( bone == 0 )
		{
			PrintToChat(client, "%sViewModel failed.", g_sCHAT_TAG);
			DeleteCharm(client);
			return;
		}

		g_iEntBones[client] = EntIndexToEntRef(bone);



		if( g_iEngine == Engine_CSGO )
		{
			GetEdictClassname(weapon, g_szBuffer, sizeof(g_szBuffer));

			int dupe = CreateEntityByName(g_szBuffer);

			// Not sure if required here. Attachments_API has this issue with "prop_dynamic_override" for fake weapon viewmodel.
			// SDKHook(dupe, SDKHook_Use, OnUse); // Prevent bug where +USE attempts to pickup or something which deletes the weapon.

			GetEntPropString(weapon, Prop_Data, "m_ModelName", g_szBuffer, sizeof(g_szBuffer));
			DispatchKeyValue(dupe, "model", g_szBuffer); // Placeholder to prevent error on spawn, weapon model is changed whenever the weapon switches
			DispatchKeyValue(dupe, "solid", "0");
			DispatchSpawn(dupe);
			AcceptEntityInput(dupe, "DisableShadow");

			DispatchSpawn(dupe);
			g_iEntDupes[client] = EntIndexToEntRef(dupe);

			// Change viewmodel model path -_- otherwise weapon doesn't attach
			int modelindex;
			if( g_smViewModels.GetValue(g_szBuffer, modelindex) )
			{
				SetEntProp(dupe, Prop_Send, "m_nModelIndex", modelindex);
			}

			// Replicate weapon skin
			SetEntProp(dupe, Prop_Send, "m_iItemIDLow",					GetEntProp(weapon, Prop_Send, "m_iItemIDLow"));
			SetEntProp(dupe, Prop_Send, "m_iItemIDHigh",				GetEntProp(weapon, Prop_Send, "m_iItemIDHigh"));
			SetEntProp(dupe, Prop_Send, "m_nFallbackPaintKit",			GetEntProp(weapon, Prop_Send, "m_nFallbackPaintKit"));
			SetEntProp(dupe, Prop_Send, "m_nFallbackSeed",				GetEntProp(weapon, Prop_Send, "m_nFallbackSeed"));
			SetEntProp(dupe, Prop_Send, "m_nFallbackStatTrak",			GetEntProp(weapon, Prop_Send, "m_nFallbackStatTrak"));
			SetEntProp(dupe, Prop_Send, "m_iEntityQuality",				GetEntProp(weapon, Prop_Send, "m_iEntityQuality"));
			SetEntProp(dupe, Prop_Send, "m_iAccountID",					GetEntProp(weapon, Prop_Send, "m_iAccountID"));
			SetEntPropEnt(dupe, Prop_Send, "m_hOwnerEntity",			client);
			SetEntPropEnt(dupe, Prop_Send, "m_hPrevOwner",				GetEntPropEnt(weapon, Prop_Send, "m_hPrevOwner"));
			SetEntPropFloat(dupe, Prop_Send, "m_flFallbackWear",		GetEntPropFloat(weapon, Prop_Send, "m_flFallbackWear"));
			GetEntDataString(weapon, FindSendPropInfo("CBaseAttributableItem", "m_szCustomName"), g_szBuffer, sizeof(g_szBuffer));
			SetEntDataString(dupe, FindSendPropInfo("CBaseAttributableItem", "m_szCustomName"), g_szBuffer, sizeof(g_szBuffer));

			SetEntityRenderMode(dupe, RENDER_NORMAL); // This makes the replica visible
			SetAttached(dupe, bone);

			// Prevent blocking +USE LoS. Thanks to "Lux".
			SetEntProp(dupe, Prop_Data, "m_iEFlags", GetEntProp(ent_arms, Prop_Data, "m_iEFlags") | EFL_DONTBLOCKLOS | SF_PHYSPROP_PREVENT_PICKUP);
			SetEntProp(dupe, Prop_Send, "m_nSolidType", 6, 1);
		}
		else
		{
			SetEntityRenderMode(bone, RENDER_NORMAL);
			SetAttached(bone, viewmodel);
		}

		if( wepsData.boneMerge )
		{
			if( wepsData.sAttach_1[0] )
			{
				SetEntProp(bone, Prop_Send, "m_nModelIndex", wepsData.boneMerge); // Custom viewmodel with bone attachment
				SetAttached(charm_view, bone);
			}
		}
		else
		{
			SetVariantString("!activator");
			AcceptEntityInput(charm_view, "SetParent", bone);
			SetVariantString(wepsData.sAttach_1);
			AcceptEntityInput(charm_view, "SetParentAttachment", bone);

			TeleportEntity(charm_view, wepsData.vPos_1, wepsData.vAng_1, NULL_VECTOR);
		}

		SetEntProp(bone, Prop_Data, "m_nSkin", GetEntProp(weapon, Prop_Data, "m_nSkin"));

		// Transmit
		SetEntityRenderMode(charm_view, RENDER_NORMAL);
		SDKHook(bone, SDKHook_SetTransmit, Hook_SetTransmitViews);
		SDKHook(charm_view, SDKHook_SetTransmit, Hook_SetTransmitViews);
	}



	// =========================
	// Create charm - WorldModel version
	// =========================
	int charm_world = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(charm_world, "solid", "0");
	DispatchKeyValue(charm_world, "spawnflags", "256");
	DispatchKeyValue(charm_world, "model", charmTemp.sModelName);
	if( g_bAllowSize )
		SetEntPropFloat(charm_world, Prop_Send, "m_flModelScale", wepsData.fSize_2);
	DispatchKeyValue(charm_world, "disableshadows", "1");
	DispatchSpawn(charm_world);

	// Prevent blocking +USE LoS. Thanks to "Lux".
	SetEntProp(charm_world, Prop_Data, "m_iEFlags", GetEntProp(charm_world, Prop_Data, "m_iEFlags") | EFL_DONTBLOCKLOS | SF_PHYSPROP_PREVENT_PICKUP);
	SetEntProp(charm_world, Prop_Send, "m_nSolidType", 6, 1);

	g_iEntSaved[client][INDEX_WORLD] = EntIndexToEntRef(charm_world);

	// Transmit
	SDKHook(charm_world, SDKHook_SetTransmit, Hook_SetTransmitWorld);



	// =========================
	// Replica weapon - WorldModel version
	// =========================
	bone = Attachments_GetWorldModel(client, weapon);
	if( bone == 0 )
	{
		if( manual )
			PrintToChat(client, "%sWorldModel failed.", g_sCHAT_TAG);

		RemoveEntity(charm_world);
		DeleteCharm(client);
		return;
	}

	// Prevent blocking +USE LoS. Thanks to "Lux".
	SetEntProp(bone, Prop_Data, "m_iEFlags", GetEntProp(bone, Prop_Data, "m_iEFlags") | EFL_DONTBLOCKLOS | SF_PHYSPROP_PREVENT_PICKUP);
	SetEntProp(bone, Prop_Send, "m_nSolidType", 6, 1);

	SetEntProp(bone, Prop_Data, "m_nSkin", GetEntProp(weapon, Prop_Data, "m_nSkin"));

	// if( wepsData.boneMerge )
	// {
	SetVariantString("!activator");
	AcceptEntityInput(bone, "SetParent", client);

	SetVariantString("!activator");
	AcceptEntityInput(charm_world, "SetParent", bone);

	SetVariantString(wepsData.sAttach_2);
	AcceptEntityInput(charm_world, "SetParentAttachment", bone, bone);
	TeleportEntity(charm_world, wepsData.vPos_2, wepsData.vAng_2, NULL_VECTOR);
	// }



	// =========================
	// FINISH
	// =========================
	// Fix invisible weapon bug. FIXME: TODO: Investigate, Attachments_API related?
	if( g_iSelected[client] == 0 && g_iEngine != Engine_CSGO )
	{
		RemovePlayerItem(client, weapon);
		EquipPlayerWeapon(client, weapon);
	}

	g_iSelected[client] = index + 1;



	// Done
	if( manual )
		CPrintToChat(client, "%s%t", g_sCHAT_TAG, "Charm_Equipped", charmTemp.sName);



	// Re-display menu changing selected charm
	// if( GetClientMenu(client) )
	// {
	//	ShowCharmMenu(client); // FIXME, TEMP
	// }

	/*
	if( !IsFakeClient(client) )
	{
		PrintToServer("");
		PrintToServer("VM %d", viewmodel);
		PrintToServer("Dupe %d", EntRefToEntIndex(g_iEntDupes[client]));
		PrintToServer("Bone %d", EntRefToEntIndex(g_iEntBones[client]));
		PrintToServer("View %d", EntRefToEntIndex(g_iEntSaved[client][INDEX_VIEWS]));
		PrintToServer("Wrld %d", EntRefToEntIndex(g_iEntSaved[client][INDEX_WORLD]));
		PrintToServer("Arms %d", EntRefToEntIndex(g_iEntSaved[client][INDEX_ARMS]));
	}
	// */
}

public void Attachments_OnModelChanged(int client)
{
	if( g_bCvarAllow == false || g_bValidMap == false ) return;

	DeleteCharm(client);

	int index = GetCharmFromClassname(client);
	if( index )
	{
		CreateCharm(client, index - 1);
	}
}

public void Attachments_OnWeaponSwitch(int client, int weapon, int ent_views, int ent_world)
{
	// PrintToServer("######## Attachments_OnWeaponSwitch %d (%N) %d (%d) %d", client, client, IsPlayerAlive(client), weapon, g_bCvarAllow);

	// Turned off?
	if( g_bCvarAllow == false || g_bValidMap == false ) return;

	// Weapon changed?
	if( g_iLastItem[client] != weapon )
	{
		g_iLastItem[client] = weapon;

		// Prevent weapon switch creating/deleting charms before player spawn or just after player spawn
		if( g_fSpawned[client] == 0.0 || g_fSpawned[client] > GetGameTime() ) return;

		// FIXME: Should really teleport to new position instead of re-create. Needs classname validation etc, so lazy way to just delete/create. If really a performance issue then report it.
		DeleteCharm(client);

		if( weapon != -1 )
		{
			int index = GetCharmFromClassname(client);
			if( index )
			{
				// Delay so skin generates
				if( g_iEngine == Engine_CSGO )
				{
					DataPack dPack;
					CreateDataTimer(0.1, Timer_DelayCreate, dPack);
					dPack.WriteCell(GetClientUserId(client));
					dPack.WriteCell(index);
				}
				else
				{
					CreateCharm(client, index - 1);
				}
			}
			else
			{
				g_iSelected[client] = 0;

				// Re-display menu changing selected charm to none
				// if( GetClientMenu(client) )
				// {
				// 	ShowCharmMenu(client); // FIXME, TEMP
				// }
			}
		}
	}
}

public Action Timer_DelayCreate(Handle timer, DataPack dPack)
{
	dPack.Reset();

	int client = dPack.ReadCell();
	if( (client = GetClientOfUserId(client)) )
	{
		int index = dPack.ReadCell();
		CreateCharm(client, index - 1);
	}

	return Plugin_Continue;
}

void GetArmsModel(int client, char[] modelname, int maxlen, int &m_nSkin)
{
	GetClientModel(client, modelname, maxlen);

	// TODO: MOVE TO CONFIG.
	// TODO: Precache used arms.
	// Most tested, some maybe using wrong arms for the models.

	static const char sPlayerModels[][] =
	{
		"models/player/custom_player/legacy/ctm_fbi.mdl",
		"models/player/custom_player/legacy/ctm_fbi_varianta.mdl",
		"models/player/custom_player/legacy/ctm_fbi_variantb.mdl",
		"models/player/custom_player/legacy/ctm_fbi_variantc.mdl",
		"models/player/custom_player/legacy/ctm_fbi_variantd.mdl",
		"models/player/custom_player/legacy/ctm_fbi_variante.mdl",
		"models/player/custom_player/legacy/ctm_fbi_variantf.mdl",
		"models/player/custom_player/legacy/ctm_fbi_variantg.mdl",
		"models/player/custom_player/legacy/ctm_fbi_varianth.mdl",
		"models/player/custom_player/legacy/ctm_gign.mdl",
		"models/player/custom_player/legacy/ctm_gign_varianta.mdl",
		"models/player/custom_player/legacy/ctm_gign_variantb.mdl",
		"models/player/custom_player/legacy/ctm_gign_variantc.mdl",
		"models/player/custom_player/legacy/ctm_gign_variantd.mdl",
		"models/player/custom_player/legacy/ctm_gsg9.mdl",
		"models/player/custom_player/legacy/ctm_gsg9_varianta.mdl",
		"models/player/custom_player/legacy/ctm_gsg9_variantb.mdl",
		"models/player/custom_player/legacy/ctm_gsg9_variantc.mdl",
		"models/player/custom_player/legacy/ctm_gsg9_variantd.mdl",
		"models/player/custom_player/legacy/ctm_heavy.mdl",
		"models/player/custom_player/legacy/ctm_idf.mdl",
		"models/player/custom_player/legacy/ctm_idf_variantb.mdl",
		"models/player/custom_player/legacy/ctm_idf_variantc.mdl",
		"models/player/custom_player/legacy/ctm_idf_variantd.mdl",
		"models/player/custom_player/legacy/ctm_idf_variante.mdl",
		"models/player/custom_player/legacy/ctm_idf_variantf.mdl",
		"models/player/custom_player/legacy/ctm_sas.mdl",
		"models/player/custom_player/legacy/ctm_sas_varianta.mdl",
		"models/player/custom_player/legacy/ctm_sas_variantb.mdl",
		"models/player/custom_player/legacy/ctm_sas_variantc.mdl",
		"models/player/custom_player/legacy/ctm_sas_variantd.mdl",
		"models/player/custom_player/legacy/ctm_sas_variante.mdl",
		"models/player/custom_player/legacy/ctm_sas_variantf.mdl",
		"models/player/custom_player/legacy/ctm_st6.mdl",
		"models/player/custom_player/legacy/ctm_st6_varianta.mdl",
		"models/player/custom_player/legacy/ctm_st6_variantb.mdl",
		"models/player/custom_player/legacy/ctm_st6_variantc.mdl",
		"models/player/custom_player/legacy/ctm_st6_variantd.mdl",
		"models/player/custom_player/legacy/ctm_st6_variante.mdl",
		"models/player/custom_player/legacy/ctm_st6_variantg.mdl",
		"models/player/custom_player/legacy/ctm_st6_varianti.mdl",
		"models/player/custom_player/legacy/ctm_st6_variantk.mdl",
		"models/player/custom_player/legacy/ctm_st6_variantm.mdl",
		"models/player/custom_player/legacy/ctm_swat.mdl",
		"models/player/custom_player/legacy/ctm_swat_varianta.mdl",
		"models/player/custom_player/legacy/ctm_swat_variantb.mdl",
		"models/player/custom_player/legacy/ctm_swat_variantc.mdl",
		"models/player/custom_player/legacy/ctm_swat_variantd.mdl",
		"models/player/custom_player/legacy/tm_anarchist.mdl",
		"models/player/custom_player/legacy/tm_anarchist_varianta.mdl",
		"models/player/custom_player/legacy/tm_anarchist_variantb.mdl",
		"models/player/custom_player/legacy/tm_anarchist_variantc.mdl",
		"models/player/custom_player/legacy/tm_anarchist_variantd.mdl",
		"models/player/custom_player/legacy/tm_balkan_varianta.mdl",
		"models/player/custom_player/legacy/tm_balkan_variantb.mdl",
		"models/player/custom_player/legacy/tm_balkan_variantc.mdl",
		"models/player/custom_player/legacy/tm_balkan_variantd.mdl",
		"models/player/custom_player/legacy/tm_balkan_variante.mdl",
		"models/player/custom_player/legacy/tm_balkan_variantf.mdl",
		"models/player/custom_player/legacy/tm_balkan_variantg.mdl",
		"models/player/custom_player/legacy/tm_balkan_varianth.mdl",
		"models/player/custom_player/legacy/tm_balkan_varianti.mdl",
		"models/player/custom_player/legacy/tm_balkan_variantj.mdl",
		"models/player/custom_player/legacy/tm_jumpsuit_varianta.mdl",
		"models/player/custom_player/legacy/tm_jumpsuit_variantb.mdl",
		"models/player/custom_player/legacy/tm_jumpsuit_variantc.mdl",
		"models/player/custom_player/legacy/tm_leet_varianta.mdl",
		"models/player/custom_player/legacy/tm_leet_variantb.mdl",
		"models/player/custom_player/legacy/tm_leet_variantc.mdl",
		"models/player/custom_player/legacy/tm_leet_variantd.mdl",
		"models/player/custom_player/legacy/tm_leet_variante.mdl",
		"models/player/custom_player/legacy/tm_leet_variantf.mdl",
		"models/player/custom_player/legacy/tm_leet_variantg.mdl",
		"models/player/custom_player/legacy/tm_leet_varianth.mdl",
		"models/player/custom_player/legacy/tm_leet_varianti.mdl",
		"models/player/custom_player/legacy/tm_phoenix.mdl",
		"models/player/custom_player/legacy/tm_phoenix_heavy.mdl",
		"models/player/custom_player/legacy/tm_phoenix_varianta.mdl",
		"models/player/custom_player/legacy/tm_phoenix_variantb.mdl",
		"models/player/custom_player/legacy/tm_phoenix_variantc.mdl",
		"models/player/custom_player/legacy/tm_phoenix_variantd.mdl",
		"models/player/custom_player/legacy/tm_phoenix_variantf.mdl",
		"models/player/custom_player/legacy/tm_phoenix_variantg.mdl",
		"models/player/custom_player/legacy/tm_phoenix_varianth.mdl",
		"models/player/custom_player/legacy/tm_pirate.mdl",
		"models/player/custom_player/legacy/tm_pirate_varianta.mdl",
		"models/player/custom_player/legacy/tm_pirate_variantb.mdl",
		"models/player/custom_player/legacy/tm_pirate_variantc.mdl",
		"models/player/custom_player/legacy/tm_pirate_variantd.mdl",
		"models/player/custom_player/legacy/tm_professional.mdl",
		"models/player/custom_player/legacy/tm_professional_var1.mdl",
		"models/player/custom_player/legacy/tm_professional_var2.mdl",
		"models/player/custom_player/legacy/tm_professional_var3.mdl",
		"models/player/custom_player/legacy/tm_professional_var4.mdl",
		"models/player/custom_player/legacy/tm_separatist.mdl",
		"models/player/custom_player/legacy/tm_separatist_varianta.mdl",
		"models/player/custom_player/legacy/tm_separatist_variantb.mdl",
		"models/player/custom_player/legacy/tm_separatist_variantc.mdl",
		"models/player/custom_player/legacy/tm_separatist_variantd.mdl"
	};

	static const char sArmModels[][] =
	{
		"models/weapons/ct_arms_sas.mdl",
		"models/weapons/ct_arms_sas.mdl",
		"models/weapons/ct_arms_sas.mdl",
		"models/weapons/ct_arms_sas.mdl",
		"models/weapons/ct_arms_sas.mdl",
		"models/weapons/ct_arms_sas.mdl",
		"models/weapons/ct_arms_fbi.mdl",
		"models/weapons/ct_arms_swat.mdl",
		"models/weapons/ct_arms_swat.mdl",
		"models/weapons/ct_arms_gsg9.mdl",
		"models/weapons/ct_arms_gsg9.mdl",
		"models/weapons/ct_arms_gsg9.mdl",
		"models/weapons/ct_arms_gsg9.mdl",
		"models/weapons/ct_arms_gsg9.mdl",
		"models/weapons/ct_arms_gsg9.mdl",
		"models/weapons/ct_arms_gsg9.mdl",
		"models/weapons/ct_arms_gsg9.mdl",
		"models/weapons/ct_arms_gsg9.mdl",
		"models/weapons/ct_arms_gsg9.mdl",
		"models/weapons/v_models/arms/glove_hardknuckle/v_glove_hardknuckle_black.mdl",
		"models/weapons/ct_arms_idf.mdl",
		"models/weapons/ct_arms_idf.mdl",
		"models/weapons/ct_arms_idf.mdl",
		"models/weapons/ct_arms_idf.mdl",
		"models/weapons/ct_arms_idf.mdl",
		"models/weapons/ct_arms_idf.mdl",
		"models/weapons/ct_arms_sas.mdl",
		"models/weapons/ct_arms_sas.mdl",
		"models/weapons/ct_arms_sas.mdl",
		"models/weapons/ct_arms_sas.mdl",
		"models/weapons/ct_arms_sas.mdl",
		"models/weapons/ct_arms_sas.mdl",
		"models/weapons/ct_arms_fbi.mdl",
		"models/weapons/ct_arms_st6.mdl",
		"models/weapons/ct_arms_st6.mdl",
		"models/weapons/ct_arms_st6.mdl",
		"models/weapons/ct_arms_st6.mdl",
		"models/weapons/ct_arms_st6.mdl",
		"models/weapons/ct_arms_idf.mdl",
		"models/weapons/ct_arms_idf.mdl",
		"models/weapons/v_models/arms/glove_hardknuckle/v_glove_hardknuckle.mdl",
		"models/weapons/ct_arms_idf.mdl",
		"models/weapons/ct_arms_idf.mdl",
		"models/weapons/ct_arms_swat.mdl",
		"models/weapons/ct_arms_swat.mdl",
		"models/weapons/ct_arms_swat.mdl",
		"models/weapons/ct_arms_swat.mdl",
		"models/weapons/ct_arms_swat.mdl",
		"models/weapons/t_arms_anarchist.mdl",
		"models/weapons/t_arms_anarchist.mdl",
		"models/weapons/t_arms_anarchist.mdl",
		"models/weapons/t_arms_anarchist.mdl",
		"models/weapons/t_arms_anarchist.mdl",
		"models/weapons/t_arms_balkan.mdl",
		"models/weapons/t_arms_balkan.mdl",
		"models/weapons/t_arms_balkan.mdl",
		"models/weapons/t_arms_balkan.mdl",
		"models/weapons/t_arms_balkan.mdl",
		"models/weapons/t_arms_balkan.mdl",
		"models/weapons/t_arms_balkan.mdl",
		"models/weapons/t_arms_balkan.mdl",
		"models/weapons/t_arms_balkan.mdl",
		"models/weapons/t_arms_balkan.mdl",
		"models/weapons/t_arms_anarchist.mdl",
		"models/weapons/t_arms_anarchist.mdl",
		"models/weapons/t_arms_anarchist.mdl",
		"models/weapons/v_models/arms/glove_fingerless/v_glove_fingerless.mdl",
		"models/weapons/v_models/arms/glove_fingerless/v_glove_fingerless.mdl",
		"models/weapons/v_models/arms/glove_fingerless/v_glove_fingerless.mdl",
		"models/weapons/v_models/arms/glove_fingerless/v_glove_fingerless.mdl",
		"models/weapons/v_models/arms/glove_fingerless/v_glove_fingerless.mdl",
		"models/weapons/v_models/arms/glove_fingerless/v_glove_fingerless.mdl",
		"models/weapons/v_models/arms/glove_fingerless/v_glove_fingerless.mdl",
		"models/weapons/v_models/arms/glove_fingerless/v_glove_fingerless.mdl",
		"models/weapons/v_models/arms/glove_fingerless/v_glove_fingerless.mdl",
		"models/weapons/t_arms_phoenix.mdl",
		"models/weapons/v_models/arms/glove_hardknuckle/v_glove_hardknuckle_black.mdl",
		"models/weapons/t_arms_phoenix.mdl",
		"models/weapons/v_models/arms/glove_fingerless/v_glove_fingerless.mdl",
		"models/weapons/t_arms_phoenix.mdl",
		"models/weapons/t_arms_phoenix.mdl",
		"models/weapons/t_arms_phoenix.mdl",
		"models/weapons/t_arms_phoenix.mdl",
		"models/weapons/t_arms_phoenix.mdl",
		"models/weapons/t_arms_pirate.mdl",
		"models/weapons/t_arms_pirate.mdl",
		"models/weapons/t_arms_pirate.mdl",
		"models/weapons/t_arms_pirate.mdl",
		"models/weapons/t_arms_pirate.mdl",
		"models/weapons/t_arms_professional.mdl",
		"models/weapons/t_arms_professional.mdl",
		"models/weapons/t_arms_professional.mdl",
		"models/weapons/t_arms_professional.mdl",
		"models/weapons/t_arms_professional.mdl",
		"models/weapons/ct_arms_sas.mdl",
		"models/weapons/ct_arms_sas.mdl",
		"models/weapons/ct_arms_sas.mdl",
		"models/weapons/ct_arms_sas.mdl",
		"models/weapons/ct_arms_sas.mdl"
	};

	bool found;
	for( int i = 0; i < sizeof(sPlayerModels); i++ )
	{
		if( strcmp(modelname, sPlayerModels[i], false) == 0 )
		{
			switch( i )
			{
				case 4, 45, 63, 66, 74: m_nSkin = 1;
				case 78: m_nSkin = 2;
			}
			strcopy(modelname, maxlen, sArmModels[i]);

			found = true;
			break;
		}
	}

	if( !found )
	{
		strcopy(modelname, maxlen, "models/weapons/t_arms_professional.mdl");
	}
}



// ====================================================================================================
//					FIRST / THIRD PERSON VIEWS - HIDE PROPS
// ====================================================================================================
// Toggle charms displayed to owner
// Taken from "LMCL4DSetTransmit" and "LMCL4D2SetTransmit" - "LMC" plugin by "Lux"
bool IsSurvivorThirdPerson(int iClient)
{
	if( GetEntProp(iClient, Prop_Send, "m_iObserverMode") == 1 )					return true;
	if( GetEntPropEnt(iClient, Prop_Send, "m_hViewEntity") > 0 )					return true;
	if( GetEntPropEnt(iClient, Prop_Send, "m_pounceAttacker") > 0 )					return true;
	if( GetEntProp(iClient, Prop_Send, "m_isHangingFromLedge", 1) > 0 )				return true;
	if( GetEntPropEnt(iClient, Prop_Send, "m_reviveTarget") > 0 )					return true;
	if( GetEntPropFloat(iClient, Prop_Send, "m_staggerTimer", 1) > -1.0 )			return true;

	if( g_iEngine == Engine_Left4Dead2 )
	{
		if( GetEntPropFloat(iClient, Prop_Send, "m_TimeForceExternalView") > GetGameTime() )	return true;
		if( GetEntPropEnt(iClient, Prop_Send, "m_pummelAttacker") > 0 )				return true;
		if( GetEntPropEnt(iClient, Prop_Send, "m_carryAttacker") > 0 )				return true;
		if( GetEntPropEnt(iClient, Prop_Send, "m_jockeyAttacker") > 0 )				return true;

		switch( GetEntProp(iClient, Prop_Send, "m_iCurrentUseAction") )
		{
			case 1:
			{
				int iTarget;
				iTarget = GetEntPropEnt(iClient, Prop_Send, "m_useActionTarget");

				if( iTarget == GetEntPropEnt(iClient, Prop_Send, "m_useActionOwner") )
					return true;
				else if( iTarget != iClient )
					return true;
			}
			case 4, 5, 6, 7, 8, 9, 10:
			return true;
		}
	} else {
		if( GetEntPropEnt(iClient, Prop_Send, "m_healTarget") > 0 )					return true;
	}

	GetEntPropString(iClient, Prop_Data, "m_ModelName", g_szBuffer, sizeof(g_szBuffer));

	if( g_iEngine == Engine_Left4Dead2 )
	{
		switch( g_szBuffer[29] )
		{
			case 'b'://nick
			{
				switch( GetEntProp(iClient, Prop_Send, "m_nSequence") )
				{
					case 626, 625, 624, 623, 622, 621, 661, 662, 664, 665, 666, 667, 668, 670, 671, 672, 673, 674, 620, 680, 616:
					return true;
				}
			}
			case 'd', 'w'://rochelle, adawong
			{
				switch( GetEntProp(iClient, Prop_Send, "m_nSequence") )
				{
					case 674, 678, 679, 630, 631, 632, 633, 634, 668, 677, 681, 680, 676, 675, 673, 672, 671, 670, 687, 629, 625, 616:
					return true;
				}
			}
			case 'c'://coach
			{
				switch( GetEntProp(iClient, Prop_Send, "m_nSequence") )
				{
					case 656, 622, 623, 624, 625, 626, 663, 662, 661, 660, 659, 658, 657, 654, 653, 652, 651, 621, 620, 669, 615:
					return true;
				}
			}
			case 'h'://ellis
			{
				switch( GetEntProp(iClient, Prop_Send, "m_nSequence") )
				{
					case 625, 675, 626, 627, 628, 629, 630, 631, 678, 677, 676, 575, 674, 673, 672, 671, 670, 669, 668, 667, 666, 665, 684, 621:
					return true;
				}
			}
			case 'v'://bill
			{
				switch( GetEntProp(iClient, Prop_Send, "m_nSequence") )
				{
					case 528, 759, 763, 764, 529, 530, 531, 532, 533, 534, 753, 676, 675, 761, 758, 757, 756, 755, 754, 527, 772, 762, 522:
					return true;
				}
			}
			case 'n'://zoey
			{
				switch( GetEntProp(iClient, Prop_Send, "m_nSequence") )
				{
					case 537, 819, 823, 824, 538, 539, 540, 541, 542, 543, 813, 828, 825, 822, 821, 820, 818, 817, 816, 815, 814, 536, 809, 572:
					return true;
				}
			}
			case 'e'://francis
			{
				switch( GetEntProp(iClient, Prop_Send, "m_nSequence") )
				{
					case 532, 533, 534, 535, 536, 537, 769, 768, 767, 766, 765, 764, 763, 762, 761, 760, 759, 758, 757, 756, 531, 530, 775, 525:
					return true;
				}
			}
			case 'a'://louis
			{
				switch( GetEntProp(iClient, Prop_Send, "m_nSequence") )
				{
					case 529, 530, 531, 532, 533, 534, 766, 765, 764, 763, 762, 761, 760, 759, 758, 757, 756, 755, 754, 753, 527, 772, 528, 522:
					return true;
				}
			}
		}
	}
	else
	{
		switch( g_szBuffer[29] )
		{
			case 'v'://bill
			{
				switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
				{
					case 535, 537, 539, 540, 541:
					return true;
				}
			}
			case 'n'://zoey
			{
				switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
				{
					case 517, 519, 521, 522, 523:
					return true;
				}
			}
			case 'e'://francis
			{
				switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
				{
					case 536, 538, 540, 541, 542:
					return true;
				}
			}
			case 'a'://louis
			{
				switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
				{
					case 535, 537, 539, 540, 541:
					return true;
				}
			}
		}
	}

	return false;
}

public Action TimerDetectView(Handle timer)
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( (g_iEntSaved[i][INDEX_VIEWS] || g_iEntSaved[i][INDEX_WORLD]) && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) )
		{
			if( IsSurvivorThirdPerson(i) )
			{
				g_bExternalProp[i] = true;
				SetCharmView(i, true);
			}
			else
			{
				g_bExternalProp[i] = false;
				SetCharmView(i, false);
			}
		}
	}

	return Plugin_Continue;
}

// Forward provided by "ThirdPersonShoulder_Detect" plugin by "Lux".
public void TP_OnThirdPersonChanged(int client, bool bIsThirdPerson)
{
	if( g_bCvarAllow && g_bValidMap )
	{
		g_bExternalCvar[client] = bIsThirdPerson;
		SetCharmView(client, bIsThirdPerson);
	}
}

void SetCharmView(int client, bool bIsThirdPerson)
{
	int entity;

	if( bIsThirdPerson && g_bExternalView[client] == false && (g_bExternalCvar[client] || g_bExternalProp[client]) )
	{
		g_bExternalView[client] = true;

		// Bone - hide
		entity = g_iEntBones[client];
		if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		{
			SetEntityRenderMode(entity, RENDER_NONE);
		}
	}
	else if( bIsThirdPerson == false && g_bExternalView[client] == true && g_bExternalCvar[client] == false && g_bExternalProp[client] == false )
	{
		g_bExternalView[client] = false;

		// Bone - show
		if( IsValidEntRef(g_iEntSaved[client][INDEX_ARMS]) )
		{
			entity = g_iEntBones[client];
			if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
			{
				SetEntityRenderMode(entity, RENDER_NORMAL);
			}
		}
	}
}

public Action Block(int entity, int client)
{
	return Plugin_Handled;
}

public Action Hook_SetTransmitViews(int entity, int client)
{
	// Block view OR entity does not belong to client
	entity = EntIndexToEntRef(entity);
	if( g_bExternalView[client] || (
		entity != g_iEntSaved[client][INDEX_VIEWS] &&
		entity != g_iEntSaved[client][INDEX_ARMS] &&
		entity != g_iEntBones[client] )
	)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action Hook_SetTransmitWorld(int entity, int client)
{
	if( !g_bExternalView[client] && EntIndexToEntRef(entity) == g_iEntSaved[client][INDEX_WORLD] )
		return Plugin_Handled;
	return Plugin_Continue;
}



// ====================================================================================================
//					HELPERS
// ====================================================================================================
// Lux: As a note this should only be used for dummy entity other entities need to remove EF_BONEMERGE_FASTCULL flag.
/*
*	Recreated "SetAttached" entity input from "prop_dynamic_ornament"
*/
stock void SetAttached(int iEntToAttach, int iEntToAttachTo)
{
	SetVariantString("!activator");
	AcceptEntityInput(iEntToAttach, "SetParent", iEntToAttachTo);

	SetEntityMoveType(iEntToAttach, MOVETYPE_NONE);
	// SetEntityRenderMode(iEntToAttach, RENDER_NORMAL); // Make visible, for testing.

	SetEntProp(iEntToAttach, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_NOSHADOW|EF_BONEMERGE_FASTCULL|EF_PARENT_ANIMATES);

	// Thanks smlib for flag understanding
	int iFlags = GetEntProp(iEntToAttach, Prop_Data, "m_usSolidFlags", 2);
	iFlags = iFlags |= 0x0004;
	SetEntProp(iEntToAttach, Prop_Data, "m_usSolidFlags", iFlags, 2);

	TeleportEntity(iEntToAttach, view_as<float>({0.0, 0.0, 0.0}), view_as<float>({0.0, 0.0, 0.0}), NULL_VECTOR);
}

// No support for silenced/modified weapons (the fake weapon model appears stuck in the clients forehead)
bool CheckDefSupport(int weapon)
{
	int def = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	switch( def )
	{
		case 23, 60, 61, 62, 63, 64:	return false;
	}
	return true;
}

int GetCharmFromClassname(int client, int &weapon = 0)
{
	if( g_smSelected[client] != null ) // Sometimes triggered before player setup
	{
		weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		if( weapon != -1 )
		{
			int index;
			GetEdictClassname(weapon, g_szBuffer, sizeof(g_szBuffer));
			if( g_smSelected[client].GetValue(g_szBuffer, index) )
			{
				if( g_iEngine == Engine_CSGO )
				{
					if( CheckDefSupport(weapon) == false )
						return 0;
				}
				return index;
			}
		}
	}
	else if( g_bCvarBots && IsFakeClient(client) )
	{
		// Loop through charms, get index for weapon classname, randomly select.
		weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		if( weapon != -1 )
		{
			GetEdictClassname(weapon, g_szBuffer, sizeof(g_szBuffer));

			int len = g_aArrayList.Length;
			ArrayList alRandom = new ArrayList();
			StringMap smWepsData;
			CharmData charmTemp;
			WeaponData wepsData;

			for( int i = 0; i < len; i++ )
			{
				g_aArrayList.GetArray(i, charmTemp, sizeof(charmTemp));
				smWepsData = charmTemp.smArrayWeapons;
				if( smWepsData.GetArray(g_szBuffer, wepsData, sizeof(wepsData)) )
					alRandom.Push(i);
			}

			len = alRandom.Length;
			if( len > 0 )
			{
				len = alRandom.Get(GetRandomInt(0, len - 1)) + 1;
				delete alRandom;
				return len;
			}

			delete alRandom;
		}
	}
	return 0;
}

bool IsValidClient(int client)
{
	if( client && IsClientInGame(client) && IsPlayerAlive(client) )
		return true;
	return false;
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}



// ====================================================================================================
//					NATIVES
// ====================================================================================================
public int Native_CharmCreate(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int index = GetNativeCell(2);

	if( index )
		CreateCharm(client, index - 1);
	else if( g_iSelected[client] )
		CreateCharm(client, g_iSelected[client] - 1);

	return 0;
}

public int Native_CharmDelete(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	DeleteCharm(client);

	return 0;
}

public int Native_GetIndex(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return g_iSelected[client];
}

public int Native_GetValid(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return IsValidEntRef(g_iEntSaved[client][INDEX_VIEWS]);
}



// ====================================================================================================
//					COLORS.INC REPLACEMENT
// ====================================================================================================
void CPrintToChat(int client, char[] message, any ...)
{
	static char buffer[256];
	VFormat(buffer, sizeof(buffer), message, 3);

	ReplaceString(buffer, sizeof(buffer), "{default}",		"\x01");
	ReplaceString(buffer, sizeof(buffer), "{white}",		"\x01");
	ReplaceString(buffer, sizeof(buffer), "{cyan}",			"\x03");
	ReplaceString(buffer, sizeof(buffer), "{lightgreen}",	"\x03");
	ReplaceString(buffer, sizeof(buffer), "{orange}",		"\x04");
	ReplaceString(buffer, sizeof(buffer), "{green}",		"\x04"); // Actually orange in L4D2, but replicating colors.inc behaviour
	ReplaceString(buffer, sizeof(buffer), "{olive}",		"\x05");
	PrintToChat(client, buffer);
}