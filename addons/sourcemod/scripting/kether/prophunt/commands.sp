#if defined __ph_commands_included
	#endinput
#endif
#define __ph_commands_included

// sm_X commands are automatically reachable as "!x" and "/x" via SourceMod's built-in chat
// trigger handling, so !hunt / !prop / !lock / !taunt all work without any extra wiring.
void PH_Commands_Init()
{
	RegConsoleCmd("sm_hunt", PH_Cmd_Hunt, "Prop Hunt: volunteer to be picked as a Hunter next round.");
	RegConsoleCmd("sm_prop", PH_Cmd_PropMenu, "Prop Hunt: open the disguise menu (fallback for aim + use).");
	RegConsoleCmd("sm_lock", PH_Cmd_Lock, "Prop Hunt: toggle your rotation/position lock.");
	RegConsoleCmd("sm_taunt", PH_Cmd_Taunt, "Prop Hunt: play a voluntary special-infected sound.");
	RegConsoleCmd("sm_ph", PH_Cmd_Status, "Prop Hunt: show the current round status.");
	RegAdminCmd("sm_ph_forceround", PH_Cmd_ForceRound, ADMFLAG_CHANGEMAP, "Prop Hunt: force-end the current round.");
	RegAdminCmd("sm_ph_forcehunter", PH_Cmd_ForceHunter, ADMFLAG_ROOT, "Prop Hunt: debug - force yourself onto the Hunter team mid-round.");
	RegAdminCmd("sm_ph_forceprop", PH_Cmd_ForceProp, ADMFLAG_ROOT, "Prop Hunt: debug - force yourself onto the Props team mid-round.");
}

public Action PH_Cmd_Hunt(int client, int args)
{
	if (client == 0 || !PH_IsModeActive())
		return Plugin_Handled;

	PH_Teams_ToggleVolunteer(client);
	return Plugin_Handled;
}

public Action PH_Cmd_PropMenu(int client, int args)
{
	if (client == 0 || !PH_IsModeActive())
		return Plugin_Handled;

	PH_OpenPropMenu(client);
	return Plugin_Handled;
}

public Action PH_Cmd_Lock(int client, int args)
{
	if (client == 0 || !PH_IsModeActive())
		return Plugin_Handled;

	if (!g_bCvarProplockEnabled)
		return Plugin_Handled;

	PH_ToggleLock(client);
	return Plugin_Handled;
}

public Action PH_Cmd_Taunt(int client, int args)
{
	if (client == 0 || !PH_IsModeActive() || !g_bCvarTauntEnabled || !PH_IsProp(client))
		return Plugin_Handled;

	PH_DoTaunt(client);
	return Plugin_Handled;
}

public Action PH_Cmd_Status(int client, int args)
{
	if (!PH_IsModeActive())
	{
		ReplyToCommand(client, "[PropHunt] Mode not active.");
		return Plugin_Handled;
	}

	char phaseName[16];
	PH_GetPhaseName(g_ePhase, phaseName, sizeof(phaseName));
	ReplyToCommand(client, "[PropHunt] Round %d - Phase: %s - Props alive: %d/%d",
		g_iRoundNumber, phaseName, g_iPropsAliveCount, g_iPropsTotalCount);
	return Plugin_Handled;
}

public Action PH_Cmd_ForceRound(int client, int args)
{
	if (!PH_IsModeActive())
	{
		ReplyToCommand(client, "[PropHunt] Mode not active.");
		return Plugin_Handled;
	}

	if (g_ePhase == PHPhase_Hide || g_ePhase == PHPhase_Seek)
		PH_EndRound(false);

	ReplyToCommand(client, "[PropHunt] Round force-ended.");
	return Plugin_Handled;
}

public Action PH_Cmd_ForceHunter(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "[PropHunt] Run this from in-game, not the server console.");
		return Plugin_Handled;
	}

	PH_Debug_ForceTeam(client, PH_TEAM_HUNTER);
	return Plugin_Handled;
}

public Action PH_Cmd_ForceProp(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "[PropHunt] Run this from in-game, not the server console.");
		return Plugin_Handled;
	}

	PH_Debug_ForceTeam(client, PH_TEAM_PROP);
	return Plugin_Handled;
}

// Debug/testing helper - moves the caller to the requested team *through* the same helpers
// PH_StartRound() itself uses, instead of a raw ChangeClientTeam() (e.g. an external !swapto),
// so a lone tester can reach the Props team without getting stuck in the native versus
// "Entering spawn mode..." ghost wait - see the plan doc for why that happens otherwise.
void PH_Debug_ForceTeam(int client, int wantedTeam)
{
	if (!PH_IsModeActive())
	{
		ReplyToCommand(client, "[PropHunt] Mode not active.");
		return;
	}

	if (g_ePhase == PHPhase_Warmup || g_ePhase == PHPhase_End)
		PH_StartRound();

	if (!PH_IsModeActive() || (g_ePhase != PHPhase_Hide && g_ePhase != PHPhase_Seek))
	{
		ReplyToCommand(client, "[PropHunt] Could not start a round to join.");
		return;
	}

	if (GetClientTeam(client) == wantedTeam)
	{
		ReplyToCommand(client, "[PropHunt] Already on that team.");
		return;
	}

	if (PH_IsProp(client) && !g_bPropEliminated[client])
	{
		PH_ClearDisguise(client);
		g_iPropsAliveCount--;
		g_iPropsTotalCount--;
	}

	ChangeClientTeam(client, wantedTeam);
	PH_ResetClientRoundState(client);

	if (wantedTeam == PH_TEAM_PROP)
	{
		PH_Props_SpawnForRound(client);
		g_iPropsAliveCount++;
		g_iPropsTotalCount++;
		ReplyToCommand(client, "[PropHunt] Debug: forced onto the Props team.");
	}
	else if (wantedTeam == PH_TEAM_HUNTER)
	{
		PH_Hunters_FreezeForHide(client);
		if (g_ePhase == PHPhase_Seek)
			PH_Hunters_ReleaseForSeek(client);
		ReplyToCommand(client, "[PropHunt] Debug: forced onto the Hunter team.");
	}
}

stock void PH_GetPhaseName(PHRoundPhase phase, char[] buffer, int maxlen)
{
	switch (phase)
	{
		case PHPhase_Warmup: strcopy(buffer, maxlen, "Warmup");
		case PHPhase_Hide: strcopy(buffer, maxlen, "Hide");
		case PHPhase_Seek: strcopy(buffer, maxlen, "Seek");
		case PHPhase_End: strcopy(buffer, maxlen, "End");
		default: strcopy(buffer, maxlen, "Unknown");
	}
}

// Fallback path for +use: lists nearby prop models (from the per-map static-prop dump plus
// whatever's already validated by props.cfg/the size limits) so a Prop can pick a disguise by
// name instead of having to aim precisely - this is the "menu is the fallback and admin/debug
// path" from the plan.
void PH_OpenPropMenu(int client)
{
	if (!PH_IsProp(client) || !IsPlayerAlive(client) || g_bPropEliminated[client])
		return;

	if (g_iCvarPropChangeLimit > 0 && g_iPropChanges[client] >= g_iCvarPropChangeLimit)
	{
		PrintHintText(client, "%t", "PropHunt_ChangeLimitReached");
		return;
	}

	int count = PH_PropData_Count();
	if (count == 0)
	{
		PrintHintText(client, "%t", "PropHunt_NoPropFound");
		return;
	}

	float origin[3];
	GetClientAbsOrigin(client, origin);
	float radius = g_flCvarPropSelectDistance * 3.0;

	Menu menu = new Menu(PH_PropMenuHandler);
	menu.SetTitle("%T", "PropHunt_MenuTitle", client);

	char seen[24][PLATFORM_MAX_PATH];
	int seenCount = 0;
	int added = 0;

	float candOrigin[3], candAngles[3];
	char candModel[PLATFORM_MAX_PATH];
	PHPropType candType;

	for (int i = 0; i < count && added < 24; i++)
	{
		PH_PropData_Get(i, candModel, candOrigin, candAngles, candType);
		if (GetVectorDistance(origin, candOrigin) > radius)
			continue;

		bool dup = false;
		for (int s = 0; s < seenCount; s++)
		{
			if (StrEqual(seen[s], candModel))
			{
				dup = true;
				break;
			}
		}
		if (dup)
			continue;

		float offset[3];
		if (!PH_IsModelAllowed(candModel, offset))
			continue;

		float diagonal;
		if (!PH_GetModelBoundsDiagonal(candModel, diagonal) || !PH_IsSizeAllowed(diagonal))
			continue;

		char pretty[PLATFORM_MAX_PATH];
		PH_GetPrettyModelName(candModel, pretty, sizeof(pretty));
		menu.AddItem(candModel, pretty);
		added++;

		if (seenCount < sizeof(seen))
			strcopy(seen[seenCount++], sizeof(seen[]), candModel);
	}

	if (added == 0)
	{
		delete menu;
		PrintHintText(client, "%t", "PropHunt_NoPropFound");
		return;
	}

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int PH_PropMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char model[PLATFORM_MAX_PATH];
		menu.GetItem(param2, model, sizeof(model));

		float offset[3];
		PH_IsModelAllowed(model, offset);

		if (PH_ApplyDisguise(param1, model, PHProp_Static, offset))
		{
			g_iPropChanges[param1]++;
			char pretty[PLATFORM_MAX_PATH];
			PH_GetPrettyModelName(model, pretty, sizeof(pretty));
			PrintHintText(param1, "%t", "PropHunt_Disguised", pretty);
		}
		else
		{
			PrintHintText(param1, "%t", "PropHunt_DisguiseFailed");
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}
