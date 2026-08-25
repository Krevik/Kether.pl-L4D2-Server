#if defined __ph_hud_included
	#endinput
#endif
#define __ph_hud_included

void PH_Hud_Init()
{
	if (g_hHudSync == null)
		g_hHudSync = CreateHudSynchronizer();
}

void PH_Hud_AnnounceRoundStart()
{
	PrintToChatAll("%t", "PropHunt_RoundStart", g_iRoundNumber, g_iPropsAliveCount);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		if (PH_IsHunter(i))
			PrintToChat(i, "%t", "PropHunt_YouAreHunter", RoundToNearest(g_flCvarHideTime));
		else if (PH_IsProp(i))
			PrintToChat(i, "%t", "PropHunt_YouAreProp", RoundToNearest(g_flCvarHideTime));
	}

	delete g_hTimerHudUpdate;
	g_hTimerHudUpdate = CreateTimer(1.0, PH_Timer_HudUpdate, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

void PH_Hud_AnnounceSeekStart()
{
	PrintToChatAll("%t", "PropHunt_SeekStart");
}

void PH_Hud_AnnouncePropEliminated(int client)
{
	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	PrintToChatAll("%t", "PropHunt_PropEliminated", name, g_iPropsAliveCount, g_iPropsTotalCount);
}

void PH_Hud_AnnounceRoundEnd(bool huntersWon)
{
	PrintToChatAll("%t", huntersWon ? "PropHunt_HuntersWin" : "PropHunt_PropsWin");
	delete g_hTimerHudUpdate;
}

void PH_Hud_WarnCueIncoming()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && PH_IsProp(i) && IsPlayerAlive(i) && !g_bPropEliminated[i])
			PrintHintText(i, "%t", "PropHunt_CueWarning");
	}
}

public Action PH_Timer_HudUpdate(Handle timer)
{
	if (!PH_IsModeActive() || (g_ePhase != PHPhase_Hide && g_ePhase != PHPhase_Seek))
	{
		g_hTimerHudUpdate = null;
		return Plugin_Stop;
	}

	int remaining = RoundToCeil(g_flPhaseEndTime - GetGameTime());
	if (remaining < 0)
		remaining = 0;

	char phaseKey[32];
	strcopy(phaseKey, sizeof(phaseKey), (g_ePhase == PHPhase_Hide) ? "PropHunt_Hud_Hide" : "PropHunt_Hud_Seek");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		SetHudTextParams(-1.0, 0.05, 1.1, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
		ShowSyncHudText(i, g_hHudSync, "%t", phaseKey, remaining, g_iPropsAliveCount, g_iPropsTotalCount);
	}

	return Plugin_Continue;
}
