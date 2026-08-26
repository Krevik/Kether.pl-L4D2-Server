#if defined __ph_rounds_included
	#endinput
#endif
#define __ph_rounds_included

// L4D2 versus only ever gives two rounds per map before transitioning maps - unsuitable for a
// rotation gamemode that wants many short rounds on one map. So this never touches the native
// round-end flow at all: it just keeps reassigning teams and respawning/re-materializing
// players in place ("soft reset"), while stripper removes the checkpoint/changelevel triggers
// that would otherwise let the native mode end the map underneath us (see cfg/stripper/prophunt).
void PH_Rounds_Init()
{
	g_ePhase = PHPhase_Warmup;
}

void PH_Rounds_OnMatchLoaded()
{
	PH_Rounds_KillTimers();
	g_ePhase = PHPhase_Warmup;
	g_iRoundNumber = 0;
	PH_Stealth_StartAnticheatScan();
	CreateTimer(5.0, PH_Timer_KickoffFirstRound, _, TIMER_FLAG_NO_MAPCHANGE);
}

void PH_Rounds_OnMatchUnloaded()
{
	PH_Rounds_KillTimers();
	PH_Stealth_StopAnticheatScan();
	g_ePhase = PHPhase_Warmup;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			PH_ClearDisguise(i);
	}
}

public Action PH_Timer_KickoffFirstRound(Handle timer)
{
	if (PH_IsModeActive())
		PH_StartRound();
	return Plugin_Stop;
}

void PH_Rounds_KillTimers()
{
	delete g_hTimerHidePhaseEnd;
	delete g_hTimerRoundTimeUp;
	delete g_hTimerRoundEndDelay;
	delete g_hTimerPeriodicCue;
}

void PH_StartRound()
{
	if (!PH_IsModeActive())
		return;

	PH_Rounds_KillTimers();
	g_iRoundNumber++;
	g_ePhase = PHPhase_Hide;

	PH_Teams_ComputeRoster();

	int propsAlive = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		PH_ResetClientRoundState(i);

		if (PH_IsHunter(i))
		{
			PH_Hunters_FreezeForHide(i);
		}
		else if (PH_IsProp(i))
		{
			PH_Props_SpawnForRound(i);
			propsAlive++;
		}
	}

	g_iPropsAliveCount = propsAlive;
	g_iPropsTotalCount = propsAlive;

	g_flPhaseEndTime = GetGameTime() + g_flCvarHideTime;
	PH_Hud_AnnounceRoundStart();

	g_hTimerHidePhaseEnd = CreateTimer(g_flCvarHideTime, PH_Timer_HidePhaseEnd, _, TIMER_FLAG_NO_MAPCHANGE);
}

// Forces an immediate class + materialize instead of letting the normal versus ghost pool
// throttle it in over time - Prop Hunt wants every Prop able to move and hide at once, not one
// every few seconds like a regular versus wave. This is the part most likely to need live-server
// tuning: if L4D_MaterializeFromGhost silently no-ops for a given client state, the 1s retry
// below is the fallback net.
//
// The client can reach here either already dead (fresh round/match start, before anyone has
// spawned) or still alive (a Hunter being rotated onto Props for the next round, or the debug
// !ph_forceprop command mid-round) - left4dhooks.inc exposes two different natives for those two
// cases (L4D_BecomeGhost for an alive client vs L4D_State_Transition(STATE_GHOST) for a dead
// one), so branch on IsPlayerAlive() rather than only handling the dead case.
void PH_Props_SpawnForRound(int client)
{
	L4D_SetClass(client, PH_ZOMBIECLASS_HUNTER);

	g_bPropMaterializing[client] = true;

	if (IsPlayerAlive(client))
		L4D_BecomeGhost(client);
	else
		L4D_State_Transition(client, STATE_GHOST);

	L4D_MaterializeFromGhost(client);

	if (IsPlayerAlive(client))
	{
		g_bPropMaterializing[client] = false;
		SetEntityHealth(client, 100);
		PH_Stealth_ClearGlow(client);

		if (g_bCvarThirdperson)
			PH_UpdateThirdperson(client, true);
	}
	else
	{
		CreateTimer(1.0, PH_Timer_RetryPropSpawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action PH_Timer_RetryPropSpawn(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client <= 0 || !IsClientInGame(client) || !PH_IsModeActive() || g_ePhase == PHPhase_End)
	{
		if (client > 0)
			g_bPropMaterializing[client] = false;
		return Plugin_Stop;
	}

	if (!IsPlayerAlive(client))
	{
		L4D_SetClass(client, PH_ZOMBIECLASS_HUNTER);

		if (IsPlayerAlive(client))
			L4D_BecomeGhost(client);
		else
			L4D_State_Transition(client, STATE_GHOST);

		L4D_MaterializeFromGhost(client);
	}

	g_bPropMaterializing[client] = false;

	if (IsPlayerAlive(client))
	{
		SetEntityHealth(client, 100);
		PH_Stealth_ClearGlow(client);

		if (g_bCvarThirdperson)
			PH_UpdateThirdperson(client, true);
	}
	else
	{
		LogError("[PropHunt] Client %N still not alive one second after being assigned to Props - check L4D_MaterializeFromGhost behaviour on this server.", client);

		// This client is stuck as a permanent ghost - it can never be seen/damaged/killed, so
		// leaving it counted as "alive" would make the "all Props eliminated" win condition
		// uncatchable for the rest of the round. Treat it as removed from play instead, the
		// same way a normal Prop kill does.
		if (!g_bPropEliminated[client])
		{
			g_bPropEliminated[client] = true;
			g_iPropsAliveCount--;
			g_iPropsTotalCount--;

			if (g_iPropsAliveCount <= 0)
				PH_EndRound(true); // All Props eliminated (or stuck) - Hunters win.
		}
	}

	return Plugin_Stop;
}

public Action PH_Timer_HidePhaseEnd(Handle timer)
{
	g_hTimerHidePhaseEnd = null;

	if (!PH_IsModeActive())
		return Plugin_Stop;

	g_ePhase = PHPhase_Seek;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && PH_IsHunter(i))
			PH_Hunters_ReleaseForSeek(i);
	}

	g_flPhaseEndTime = GetGameTime() + g_flCvarRoundTime;
	PH_Hud_AnnounceSeekStart();

	g_hTimerRoundTimeUp = CreateTimer(g_flCvarRoundTime, PH_Timer_RoundTimeUp, _, TIMER_FLAG_NO_MAPCHANGE);

	if (g_flCvarCueInterval > 0.0)
	{
		float firstDelay = g_flCvarCueInterval * (1.0 - g_flCvarCueWarnFraction);
		if (firstDelay < 0.5)
			firstDelay = 0.5;
		g_hTimerPeriodicCue = CreateTimer(firstDelay, PH_Timer_PeriodicCue, false, TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Stop;
}

public Action PH_Timer_RoundTimeUp(Handle timer)
{
	g_hTimerRoundTimeUp = null;

	if (!PH_IsModeActive())
		return Plugin_Stop;

	PH_EndRound(false); // Time ran out with Props still alive - Props win.
	return Plugin_Stop;
}

void PH_Rounds_OnPropDeath(int client)
{
	if (g_ePhase != PHPhase_Hide && g_ePhase != PHPhase_Seek)
		return;

	if (g_bPropEliminated[client])
		return;

	g_bPropEliminated[client] = true;
	PH_ClearDisguise(client);
	g_iPropsAliveCount--;

	PH_Hud_AnnouncePropEliminated(client);

	if (g_iPropsAliveCount <= 0)
		PH_EndRound(true); // All Props eliminated - Hunters win.
}

void PH_EndRound(bool huntersWon)
{
	delete g_hTimerHidePhaseEnd;
	delete g_hTimerRoundTimeUp;
	delete g_hTimerPeriodicCue;

	g_ePhase = PHPhase_End;

	PH_Hud_AnnounceRoundEnd(huntersWon);

	// When Props win by round timeout (or an admin force-ends the round), any Prop still alive
	// and disguised never otherwise gets cleaned up here - PH_ClearDisguise() is only called
	// individually as each Prop dies (PH_Rounds_OnPropDeath), so a *surviving* Prop would
	// carry their invisible body/parented visual prop/thirdperson view into next round, even
	// if fairness rotation makes them a Hunter. PH_ClearDisguise() already resets the freeze/
	// manual-lock flags too, and is a safe no-op for Hunters or already-cleared Props (same
	// pattern already used in PH_Rounds_OnMatchUnloaded()).
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			PH_ClearDisguise(i);
	}

	g_hTimerRoundEndDelay = CreateTimer(g_flCvarRoundEndDelay, PH_Timer_StartNextRound, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action PH_Timer_StartNextRound(Handle timer)
{
	g_hTimerRoundEndDelay = null;

	if (PH_IsModeActive())
		PH_StartRound();

	return Plugin_Stop;
}
