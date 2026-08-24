/*  
*    Fixes for gamebreaking bugs and stupid gameplay aspects
*    Copyright (C) 2019  LuxLuma		acceliacat@gmail.com
*
*    This program is free software: you can redistribute it and/or modify
*    it under the terms of the GNU General Public License as published by
*    the Free Software Foundation, either version 3 of the License, or
*    (at your option) any later version.
*
*    This program is distributed in the hope that it will be useful,
*    but WITHOUT ANY WARRANTY; without even the implied warranty of
*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*    GNU General Public License for more details.
*
*    You should have received a copy of the GNU General Public License
*    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>

#pragma newdecls required

#define GAMEDATA "witch_update_nbm"
#define PLUGIN_VERSION "2.0"

#define MAX_EDICTS 2049

// L4D2 witch.mdl sequences used by the original Lux prototype.
#define WITCH_SEQ_STARTLE_SKIP 30
#define WITCH_SEQ_ATTACK_A 32
#define WITCH_SEQ_ATTACK_B 54
#define WITCH_SEQ_ATTACK_C 55
#define WITCH_SEQ_STARTLE_FAST 56
#define WITCH_SEQ_CLIMB 60

ConVar g_cvEnabled;
ConVar g_cvInterval;
ConVar g_cvClimbInterval;
ConVar g_cvAttackRealtime;
ConVar g_cvAnimFix;

int g_iWitchRef[MAX_EDICTS] = {INVALID_ENT_REFERENCE, ...};
float g_fWitchNextUpdate[MAX_EDICTS];

bool g_bLateLoad;
bool g_bInWitchDoThink;
bool g_bAllowThisUpdate;
bool g_bForceThisUpdate;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}

	g_bLateLoad = late;
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "[L4D2] Witch NextBot 30-tick throttle",
	author = "Lux, Kether",
	description = "Caps witch pathfinding/AI updates to ~30 Hz so she behaves like on 30-tick, independent of nb_update_frequency.",
	version = PLUGIN_VERSION,
	url = "-"
};

public void OnPluginStart()
{
	g_cvEnabled = CreateConVar("witch_nbm_enabled", "1", "Throttle witch NextBot updates independently of nb_update_frequency.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvInterval = CreateConVar("witch_nbm_interval", "0.033", "Seconds between witch AI/path updates (0.033 = ~30 Hz, official 30-tick feel). 0 = no throttle.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvClimbInterval = CreateConVar("witch_nbm_climb_interval", "0.067", "Seconds between updates while climbing (seq 60). Lower can stick her on ledges.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvAttackRealtime = CreateConVar("witch_nbm_attack_realtime", "1", "Do not throttle swipes / kill-hit animations so she can still land attacks.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvAnimFix = CreateConVar("witch_nbm_anim_fix", "1", "Keep high-tick animation patches (startle skip / faster sit-up).", FCVAR_NONE, true, 0.0, true, 1.0);

	Handle hGamedata = LoadGameConfigFile(GAMEDATA);
	if (hGamedata == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	Handle hDetour = DHookCreateFromConf(hGamedata, "NextBotManager::ShouldUpdate");
	if (!hDetour)
		SetFailState("Failed to find \"NextBotManager::ShouldUpdate\" signature.");

	if (!DHookEnableDetour(hDetour, false, NextBotShouldUpdatePre))
		SetFailState("Failed to detour pre \"NextBotManager::ShouldUpdate\".");
	if (!DHookEnableDetour(hDetour, true, NextBotShouldUpdatePost))
		SetFailState("Failed to detour post \"NextBotManager::ShouldUpdate\".");

	hDetour = DHookCreateFromConf(hGamedata, "NextBotCombatCharacter::DoThink");
	if (!hDetour)
		SetFailState("Failed to find \"NextBotCombatCharacter::DoThink\" signature.");

	if (!DHookEnableDetour(hDetour, false, NextBotDoThinkPre))
		SetFailState("Failed to detour pre \"NextBotCombatCharacter::DoThink\".");
	if (!DHookEnableDetour(hDetour, true, NextBotDoThinkPost))
		SetFailState("Failed to detour post \"NextBotCombatCharacter::DoThink\".");

	delete hGamedata;

	if (g_bLateLoad)
		TrackExistingWitches();
}

public void OnMapStart()
{
	g_bInWitchDoThink = false;
	g_bAllowThisUpdate = true;
	g_bForceThisUpdate = false;
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	if (!IsWitchClass(sClassname))
		return;

	TrackWitch(iEntity);
}

public void OnEntityDestroyed(int iEntity)
{
	UntrackWitch(iEntity);
}

public void OnThink(int iWitch)
{
	if (!g_cvAnimFix.BoolValue)
		return;

	switch (GetEntProp(iWitch, Prop_Send, "m_nSequence"))
	{
		case WITCH_SEQ_STARTLE_FAST:
		{
			SetEntPropFloat(iWitch, Prop_Send, "m_flPlaybackRate", 2.0);
			g_fWitchNextUpdate[iWitch] = 0.0;
		}
		case WITCH_SEQ_STARTLE_SKIP:
		{
			SetEntPropFloat(iWitch, Prop_Send, "m_flCycle", 1.0);
			g_fWitchNextUpdate[iWitch] = 0.0;
		}
		case WITCH_SEQ_ATTACK_A, WITCH_SEQ_ATTACK_B, WITCH_SEQ_ATTACK_C:
		{
			g_fWitchNextUpdate[iWitch] = 0.0;
		}
	}
}

public MRESReturn NextBotDoThinkPre(int pThis)
{
	g_bInWitchDoThink = false;
	g_bAllowThisUpdate = true;
	g_bForceThisUpdate = false;

	if (!g_cvEnabled.BoolValue || !IsTrackedWitch(pThis))
		return MRES_Ignored;

	g_bInWitchDoThink = true;

	int iSeq = GetEntProp(pThis, Prop_Send, "m_nSequence");
	if (g_cvAttackRealtime.BoolValue && IsAttackSequence(iSeq))
	{
		g_bAllowThisUpdate = true;
		g_bForceThisUpdate = true;
		g_fWitchNextUpdate[pThis] = 0.0;
		return MRES_Ignored;
	}

	float fInterval = (iSeq == WITCH_SEQ_CLIMB) ? g_cvClimbInterval.FloatValue : g_cvInterval.FloatValue;
	if (fInterval <= 0.0)
	{
		g_bAllowThisUpdate = true;
		return MRES_Ignored;
	}

	float fNow = GetGameTime();
	if (g_fWitchNextUpdate[pThis] > fNow)
	{
		g_bAllowThisUpdate = false;
		g_bForceThisUpdate = false;
		return MRES_Ignored;
	}

	g_bAllowThisUpdate = true;
	g_bForceThisUpdate = true;
	g_fWitchNextUpdate[pThis] = fNow + fInterval;
	return MRES_Ignored;
}

public MRESReturn NextBotDoThinkPost(int pThis)
{
	g_bInWitchDoThink = false;
	g_bAllowThisUpdate = true;
	g_bForceThisUpdate = false;
	return MRES_Ignored;
}

public MRESReturn NextBotShouldUpdatePre(Handle hReturn)
{
	if (!g_bInWitchDoThink)
		return MRES_Ignored;

	if (!g_bAllowThisUpdate)
	{
		DHookSetReturn(hReturn, false);
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

public MRESReturn NextBotShouldUpdatePost(Handle hReturn)
{
	if (!g_bInWitchDoThink || !g_bForceThisUpdate)
		return MRES_Ignored;

	g_bForceThisUpdate = false;
	DHookSetReturn(hReturn, true);
	return MRES_Override;
}

void TrackExistingWitches()
{
	int iEntity = -1;
	while ((iEntity = FindEntityByClassname(iEntity, "witch")) != -1)
		TrackWitch(iEntity);

	iEntity = -1;
	while ((iEntity = FindEntityByClassname(iEntity, "witch_bride")) != -1)
		TrackWitch(iEntity);
}

void TrackWitch(int iEntity)
{
	if (iEntity <= 0 || iEntity >= MAX_EDICTS)
		return;

	if (IsValidEntRef(g_iWitchRef[iEntity]))
	{
		g_fWitchNextUpdate[iEntity] = 0.0;
		return;
	}

	g_iWitchRef[iEntity] = EntIndexToEntRef(iEntity);
	g_fWitchNextUpdate[iEntity] = 0.0;
	SDKHook(iEntity, SDKHook_Think, OnThink);
}

void UntrackWitch(int iEntity)
{
	if (iEntity <= 0 || iEntity >= MAX_EDICTS)
		return;

	g_iWitchRef[iEntity] = INVALID_ENT_REFERENCE;
	g_fWitchNextUpdate[iEntity] = 0.0;
}

bool IsTrackedWitch(int iEntity)
{
	return (iEntity > 0 && iEntity < MAX_EDICTS && IsValidEntRef(g_iWitchRef[iEntity]));
}

bool IsWitchClass(const char[] sClassname)
{
	return (sClassname[0] == 'w' && (StrEqual(sClassname, "witch") || StrEqual(sClassname, "witch_bride")));
}

bool IsAttackSequence(int iSeq)
{
	return (iSeq == WITCH_SEQ_ATTACK_A || iSeq == WITCH_SEQ_ATTACK_B || iSeq == WITCH_SEQ_ATTACK_C || iSeq == WITCH_SEQ_STARTLE_FAST);
}

bool IsValidEntRef(int iEntRef)
{
	return (iEntRef != INVALID_ENT_REFERENCE && iEntRef != 0 && EntRefToEntIndex(iEntRef) != INVALID_ENT_REFERENCE);
}
