#if defined __ksr_lifecycle_included
	#endinput
#endif
#define __ksr_lifecycle_included

public void OnMapStart()
{
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));
}

public void OnAllPluginsLoaded()
{
	g_bReadyUpAvailable = LibraryExists("readyup");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "readyup"))
	{
		g_bReadyUpAvailable = true;
		// readyup keeps its footer list for the lifetime of the plugin, so the slot
		// is only stale when readyup itself was reloaded.
		g_iReadyFooterIndex = -1;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "readyup"))
	{
		g_bReadyUpAvailable = false;
		g_iReadyFooterIndex = -1;
	}
}

public void OnMapEnd()
{
	FinalizeRoundIfNeeded();
	delete g_hFlowTimer;
	delete g_hMixApplyTimer;
	delete g_hReadyFooterTimer;
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_CvarEnabled.BoolValue)
	{
		return;
	}
	int client = GetClientOfUserId(event.GetInt("userid"));
	StartTankHold(client);
}

public void OnClientPostAdminCheck(int client)
{
	if (!IsValidHuman(client))
	{
		return;
	}

	TryMergeSteamIdVariantsForClient(client);
	ResetRoundStats(client);
	g_fTotalPoints[client] = 0.0;
	g_iRoundsPlayed[client] = 0;
	ResetRatingCache(client);
	g_bWasLive[client] = false;
	LoadPlayerProfile(client);
	RequestReadyFooterUpdate();
}

public void OnClientDisconnect(int client)
{
	if (g_iCurrentTank == client)
	{
		EndTankHoldSegment(client);
	}
	ResetRoundStats(client);
	g_fTotalPoints[client] = 0.0;
	g_iRoundsPlayed[client] = 0;
	ResetRatingCache(client);
	g_bWasLive[client] = false;
	g_sFirstName[client][0] = '\0';
	g_sLastName[client][0] = '\0';
	RequestReadyFooterUpdate();
}

public void OnRatingEnabledChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar.BoolValue)
	{
		return;
	}

	// A partially recorded round cannot be rated after re-enabling the plugin.
	g_bRoundActive = false;
	g_bRoundFinalized = true;
	g_bRoundLive = false;
	g_bPaused = false;
	g_iCurrentTank = 0;
	g_iLastHumanTank = 0;
	g_fTankHoldStart = 0.0;
	delete g_hFlowTimer;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_CvarEnabled.BoolValue)
	{
		return;
	}

	g_bRoundActive = true;
	g_bRoundLive = g_bReadyUpAvailable ? false : true;
	g_bRoundFinalized = false;
	g_bPaused = false;
	g_iRoundNumber++;
	g_iCurrentTank = 0;
	g_iLastHumanTank = 0;
	g_fTankHoldStart = 0.0;
	g_iLiveSurvCount = 0;
	g_iLiveInfCount = 0;
	g_iHalfTankPasses = 0;
	g_iHalfTankKills = 0;
	g_iHalfWitchBonus = 0;
	g_fHalfBonus = 0.0;
	g_iHalfMaxScore = 0;
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));

	for (int i = 1; i <= MaxClients; i++)
	{
		ResetRoundStats(i);
		g_fLifeStart[i] = GetEngineTime();
		g_bAliveAtEnd[i] = true;
		g_bWasLive[i] = false;
	}

	delete g_hFlowTimer;
	g_hFlowTimer = CreateTimer(1.0, Timer_FlowSnapshot, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_FlowSnapshot(Handle timer)
{
	if (!g_bRoundActive || g_bRoundFinalized)
	{
		// Clear the handle first: SourceMod frees a repeating timer that returns
		// Plugin_Stop, and a later delete on the stale handle would throw.
		g_hFlowTimer = null;
		return Plugin_Stop;
	}

	// l4d_tank_rush zeroes the max completion score while a tank is up, so the last
	// real value is kept for the end-of-half snapshot.
	int maxScore = L4D_GetVersusMaxCompletionScore();
	if (maxScore > 0)
	{
		g_iLastMaxScore = maxScore;
	}

	if (!g_bRoundLive || g_bPaused)
	{
		return Plugin_Continue;
	}

	if (IsTankInPlayActive())
	{
		return Plugin_Continue;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidHuman(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i))
		{
			continue;
		}

		float progress = GetFlowPercentSafe(i);
		if (progress > g_fFlowBest[i])
		{
			g_fFlowBest[i] = progress;
		}
	}

	return Plugin_Continue;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	FinalizeRoundIfNeeded();
}

// Everybody readied up and the countdown started: this is the last moment where
// the teams can still be judged before the round runs, so announce the balance.
public void OnRoundLiveCountdown()
{
	if (!g_CvarEnabled.BoolValue || !g_CvarReadyBalanceInfo.BoolValue)
	{
		return;
	}

	AnnounceTeamBalance();
}

public void OnReadyUpInitiate()
{
	RequestReadyFooterUpdate();
}

public void OnPlayerReady(int client)
{
	RequestReadyFooterUpdate();
}

public void OnPlayerUnready(int client)
{
	RequestReadyFooterUpdate();
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	RequestReadyFooterUpdate();
}

// Coalesces a burst of triggers into one redraw, and - the reason the delay is
// needed rather than nice to have - it runs after the event that caused it has
// finished. A disconnecting client is still on his team inside
// OnClientDisconnect, and a player_team event fires before the new team is in
// place, so reading the rosters immediately would count the wrong line-up.
void RequestReadyFooterUpdate()
{
	if (!g_CvarEnabled.BoolValue || !g_bReadyUpAvailable || !g_CvarReadyBalanceInfo.BoolValue)
	{
		return;
	}

	if (g_hReadyFooterTimer != null)
	{
		return;
	}

	g_hReadyFooterTimer = CreateTimer(0.3, Timer_ReadyFooterUpdate, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ReadyFooterUpdate(Handle timer)
{
	g_hReadyFooterTimer = null;
	UpdateReadyFooter();
	return Plugin_Stop;
}

void AnnounceTeamBalance()
{
	float sumSurv = 0.0;
	float sumInf = 0.0;
	int survCount = 0;
	int infCount = 0;

	if (!CollectTeamRatings(sumSurv, sumInf, survCount, infCount))
	{
		return;
	}

	float avgSurv = sumSurv / float(survCount);
	float avgInf = sumInf / float(infCount);

	PrintToChatAll("\x04[KSR]\x01 \x04Survivors\x01 \x05%.0f\x01 (avg \x05%.0f\x01)  |  \x08Infected\x01 \x05%.0f\x01 (avg \x05%.0f\x01)",
		sumSurv, avgSurv, sumInf, avgInf);

	char balanceLine[192];
	BuildBalanceLine(avgSurv, avgInf, balanceLine, sizeof(balanceLine));
	PrintToChatAll("%s", balanceLine);

	float gap = avgSurv - avgInf;
	if (gap < 0.0)
	{
		gap = -gap;
	}

	if (gap >= g_CvarMixWarnDelta.FloatValue && IsValidMixSetup(survCount, infCount))
	{
		PrintToChatAll("\x04[KSR]\x01 Teams look lopsided. Type \x05!skillmix\x01 to re-draw them.");
	}
}

bool CollectTeamRatings(float &sumSurv, float &sumInf, int &survCount, int &infCount)
{
	sumSurv = 0.0;
	sumInf = 0.0;
	survCount = 0;
	infCount = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidHuman(i))
		{
			continue;
		}

		int team = GetClientTeam(i);
		if (team == TEAM_SURVIVOR)
		{
			sumSurv += GetMixRating(i);
			survCount++;
		}
		else if (team == TEAM_INFECTED)
		{
			sumInf += GetMixRating(i);
			infCount++;
		}
	}

	return (survCount > 0 && infCount > 0);
}

// Keeps a live balance line in the ready panel, so the teams can be judged while
// people are still picking sides instead of only once the countdown fires.
void UpdateReadyFooter()
{
	if (!g_CvarEnabled.BoolValue || !g_bReadyUpAvailable || !g_CvarReadyBalanceInfo.BoolValue)
	{
		return;
	}

	float sumSurv = 0.0;
	float sumInf = 0.0;
	int survCount = 0;
	int infCount = 0;

	char footer[128];
	if (!CollectTeamRatings(sumSurv, sumInf, survCount, infCount))
	{
		Format(footer, sizeof(footer), "KSR: teams not set");
	}
	else
	{
		float avgSurv = sumSurv / float(survCount);
		float avgInf = sumInf / float(infCount);
		float gap = avgSurv - avgInf;
		Format(footer, sizeof(footer), "KSR  S %.0f  vs  I %.0f   (gap %s%.0f)",
			avgSurv, avgInf, (gap >= 0.0) ? "+" : "-", (gap >= 0.0) ? gap : -gap);
	}

	if (g_iReadyFooterIndex < 0)
	{
		g_iReadyFooterIndex = AddStringToReadyFooter(footer);
		return;
	}

	if (!EditFooterStringAtIndex(g_iReadyFooterIndex, footer))
	{
		g_iReadyFooterIndex = AddStringToReadyFooter(footer);
	}
}

public void OnRoundIsLive()
{
	if (!g_CvarEnabled.BoolValue || !g_bRoundActive || g_bRoundFinalized)
	{
		return;
	}

	g_bRoundLive = true;
	g_bPaused = false;

	float now = GetEngineTime();
	g_iLiveSurvCount = 0;
	g_iLiveInfCount = 0;

	// Snapshot the roster the moment the round goes live. Eligibility is judged on
	// this snapshot, so one player dropping at the end no longer voids the round
	// for everybody, and a late joiner cannot bank a round he barely played.
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidHuman(i))
		{
			continue;
		}

		int team = GetClientTeam(i);
		if (team == TEAM_SURVIVOR)
		{
			g_bWasLive[i] = true;
			g_iLiveSurvCount++;
			if (IsPlayerAlive(i))
			{
				g_fLifeStart[i] = now;
			}
		}
		else if (team == TEAM_INFECTED)
		{
			g_bWasLive[i] = true;
			g_iLiveInfCount++;
		}
	}
}

public void OnPause()
{
	if (!g_bRoundActive || g_bRoundFinalized || g_bPaused)
	{
		return;
	}

	g_bPaused = true;
	float now = GetEngineTime();
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidHuman(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i) || !g_bAliveAtEnd[i])
		{
			continue;
		}
		if (g_bRoundLive)
		{
			g_fSurvivalTime[i] += now - g_fLifeStart[i];
		}
		g_fLifeStart[i] = now;
	}
}

public void OnUnpause()
{
	if (!g_bRoundActive || g_bRoundFinalized)
	{
		return;
	}

	g_bPaused = false;

	if (!g_bRoundLive)
	{
		return;
	}

	float now = GetEngineTime();
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidHuman(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i) || !g_bAliveAtEnd[i])
		{
			continue;
		}
		g_fLifeStart[i] = now;
	}
}

public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	FinalizeRoundIfNeeded();
	return Plugin_Continue;
}
