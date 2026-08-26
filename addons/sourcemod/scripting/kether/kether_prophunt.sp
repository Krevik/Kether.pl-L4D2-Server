#pragma semicolon 1
#pragma newdecls required

// L4D2 Prop Hunt - versus-based hide-and-seek gamemode.
//
// Survivors ("Hunters") seek. Infected ("Props") spawn as attack-disabled Hunters, then
// disguise as world props with +use and try to survive the round without being found.
// Gated on the "prophunt" cfgogl matchmode (cfg/cfgogl/prophunt/) via confogl - this plugin
// is completely inert outside of it. See the plan document for the full design rationale.
//
// Split into fragment includes under kether/prophunt/, mirroring the confoglcompmod/ and
// readyup/ layout already used in this repo:
//   globals.sp    - shared enums/state used by every other fragment
//   convars.sp    - the ph_* convar set
//   propdata.sp   - props.cfg rules + per-map static prop data (tools/prophunt_propscan.py)
//   disguise.sp   - the model-swap + parented visual prop + freeze/thirdperson mechanism
//   selection.sp  - +use handling, live-entity and static-prop aim search, menu fallback
//   teams.sp      - Hunter rotation, fairness counter, volunteer queue
//   rounds.sp     - the plugin-managed soft-reset round loop
//   hunters.sp    - HP economy, damage blocking, hide-phase freeze/blind
//   cues.sp       - periodic forced special-infected sound cue, voluntary taunt
//   stealth.sp    - sound/glow/location leak suppression, r_staticpropinfo anticheat kick
//   hud.sp        - chat announcements + HUD countdown
//   commands.sp   - sm_hunt/sm_prop/sm_lock/sm_taunt/sm_ph and the fallback prop menu

#define PLUGIN_VERSION "1.0.0"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <regex>
#include <smlib>
#include <left4dhooks>
#include <confogl>

// Optional - only used to exclude registered casters from the Hunter/Prop pool (teams.sp),
// guarded at every call site with GetFeatureStatus. <sourcemod> defines REQUIRE_PLUGIN by
// default, so this has to be explicitly un/redefined around the include or SourceMod refuses
// to load kether_prophunt.smx at all when caster_system.smx isn't installed/loaded.
#undef REQUIRE_PLUGIN
#include <caster_system>
#define REQUIRE_PLUGIN

#include "prophunt/globals.sp"
#include "prophunt/convars.sp"
#include "prophunt/propdata.sp"
#include "prophunt/disguise.sp"
#include "prophunt/selection.sp"
#include "prophunt/teams.sp"
#include "prophunt/rounds.sp"
#include "prophunt/hunters.sp"
#include "prophunt/cues.sp"
#include "prophunt/stealth.sp"
#include "prophunt/hud.sp"
#include "prophunt/commands.sp"

public Plugin myinfo =
{
	name = "[L4D2] Kether Prop Hunt",
	author = "Kether.pl",
	description = "Versus-based Prop Hunt gamemode - Props disguise as world props, Hunters seek them out.",
	version = PLUGIN_VERSION,
	url = "https://kether.pl"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("prophunt.phrases");

	PH_Convars_Init();
	PH_PropData_Init();
	PH_Hud_Init();
	PH_Commands_Init();
	PH_Rounds_Init();

	HookEvent("weapon_fire", PH_Event_WeaponFire);
	HookEvent("player_death", PH_Event_PlayerDeath);

	AddNormalSoundHook(PH_NormalSoundHook);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			OnClientPutInServer(i);
	}

	if (PH_IsModeActive())
		PH_Rounds_OnMatchLoaded();
}

public void OnMapStart()
{
	PH_PropData_OnMapStart();
	PH_Cues_Precache();
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_TraceAttack, PH_OnTraceAttack);
	SDKHook(client, SDKHook_OnTakeDamage, PH_OnTakeDamage);
	SDKHook(client, SDKHook_PostThinkPost, PH_Stealth_PostThinkPost);
}

public void OnClientDisconnect(int client)
{
	PH_ClearDisguise(client);
	PH_Teams_OnClientDisconnect(client);

	if (g_ePhase == PHPhase_Hide || g_ePhase == PHPhase_Seek)
	{
		if (PH_IsProp(client) && !g_bPropEliminated[client])
			PH_Rounds_OnPropDeath(client);
	}
}

// Called by confogl (see addons/sourcemod/scripting/include/confogl.inc) - auto-hooked simply
// by matching the forward's name, same convention the include's forwards always use.
public void LGO_OnMatchModeLoaded()
{
	if (PH_IsModeActive())
		PH_Rounds_OnMatchLoaded();
}

public void LGO_OnMatchModeUnloaded()
{
	PH_Rounds_OnMatchUnloaded();
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!PH_IsModeActive() || !IsClientInGame(client))
		return Plugin_Continue;

	if (PH_IsProp(client))
	{
		PH_Selection_OnPlayerRunCmd(client, buttons);
		PH_Stealth_BlockPropButtons(buttons);
	}

	return Plugin_Continue;
}
