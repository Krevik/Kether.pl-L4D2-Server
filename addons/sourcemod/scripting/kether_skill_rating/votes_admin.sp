#if defined __ksr_votes_admin_included
	#endinput
#endif
#define __ksr_votes_admin_included

public Action Command_SkillMixVote(int client, int args)
{
	if (!g_CvarEnabled.BoolValue)
	{
		ReplyToCommand(client, "[KSR] Plugin is disabled.");
		return Plugin_Handled;
	}

	if (!IsValidHuman(client))
	{
		ReplyToCommand(client, "[KSR] This command is in-game only.");
		return Plugin_Handled;
	}

	if (GetClientTeam(client) == TEAM_SPECTATOR)
	{
		ReplyToCommand(client, "[KSR] Spectators cannot call this vote.");
		return Plugin_Handled;
	}

	if (g_bMixVoteInProgress || IsBuiltinVoteInProgress())
	{
		ReplyToCommand(client, "[KSR] A vote is already in progress.");
		return Plugin_Handled;
	}

	if (!IsMixAllowedNow())
	{
		ReplyToCommand(client, "[KSR] Teams can only be mixed during ready-up.");
		return Plugin_Handled;
	}

	int survCount = 0;
	int infCount = 0;
	int voters[MAXPLAYERS + 1];
	int voterCount = CollectEligibleVoters(voters, survCount, infCount);

	if (!IsValidMixSetup(survCount, infCount))
	{
		ReplyToCommand(client, "[KSR] Mix requires equal teams, from 1v1 up to %dv%d.", MIX_MAX_TEAM_SIZE, MIX_MAX_TEAM_SIZE);
		return Plugin_Handled;
	}

	if (!BuildPlannedSplit())
	{
		ReplyToCommand(client, "[KSR] Could not work out a split for the current teams.");
		return Plugin_Handled;
	}

	AnnouncePlannedSplit();

	g_hMixVote = CreateBuiltinVote(Handle_MixVoteAction, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
	SetBuiltinVoteArgument(g_hMixVote, "Mix teams by KSR?");
	SetBuiltinVoteInitiator(g_hMixVote, client);
	SetBuiltinVoteResultCallback(g_hMixVote, Handle_MixVoteResult);
	DisplayBuiltinVote(g_hMixVote, voters, voterCount, 15);
	FakeClientCommand(client, "Vote Yes");

	g_bMixVoteInProgress = true;

	return Plugin_Handled;
}

void ShowSkillMainMenu(int client)
{
	Menu menu = new Menu(MenuHandler_SkillMain, MENU_ACTIONS_DEFAULT);
	menu.SetTitle("=== Kether Skill Rating (KSR) ===");
	menu.AddItem("my", "My KSR profile");
	menu.AddItem("break", "Where my points come from");
	menu.AddItem("top", "Leaderboard - browse all players");
	menu.AddItem("sim", "My place in the ranking");
	menu.AddItem("teams", "Current team balance");
	menu.AddItem("mix", "Call KSR mix vote");
	if (CheckCommandAccess(client, "sm_skill_admin_reset", ADMFLAG_ROOT, true))
	{
		menu.AddItem("reset", "Admin: Reset selected player stats");
	}
	menu.ExitButton = true;
	menu.Display(client, 20);
}

public int MenuHandler_SkillMain(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action != MenuAction_Select || !IsValidHuman(client))
	{
		return 0;
	}

	char info[32];
	menu.GetItem(item, info, sizeof(info));

	if (StrEqual(info, "my"))
	{
		ShowSkillForTarget(client, client, true);
	}
	else if (StrEqual(info, "break"))
	{
		char mySteamid[32];
		char myName[160];
		if (GetPlayerSteamId(client, mySteamid, sizeof(mySteamid)))
		{
			BuildDisplayName(client, myName, sizeof(myName));
			RequestBreakdown(client, mySteamid, myName, true);
		}
	}
	else if (StrEqual(info, "top"))
	{
		RequestTopMenu(client, g_CvarTopListMax.IntValue, GetTopMinRounds(), true);
	}
	else if (StrEqual(info, "sim"))
	{
		RequestSimilarityMenu(client, client, true);
	}
	else if (StrEqual(info, "teams"))
	{
		PrintTeamKsrSummary(client);
	}
	else if (StrEqual(info, "mix"))
	{
		Command_SkillMixVote(client, 0);
	}
	else if (StrEqual(info, "reset"))
	{
		ShowAdminResetPlayerMenu(client);
	}

	return 0;
}

void ShowAdminResetPlayerMenu(int client)
{
	if (!CheckCommandAccess(client, "sm_skill_admin_reset", ADMFLAG_ROOT, true))
	{
		ReplyToCommand(client, "[KSR] No access.");
		return;
	}

	char query[512];
	Format(query, sizeof(query),
		"SELECT steamid, last_name, first_name, rating, rating_rounds "
		... "FROM players ORDER BY rating_rounds DESC, rating DESC LIMIT 200;");

	DataPack pack = new DataPack();
	pack.WriteCell(client);
	g_Db.Query(SQL_ShowAdminResetPlayersMenu, query, pack);
}

public int MenuHandler_AdminResetPlayer(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack && IsValidHuman(client))
	{
		ShowSkillMainMenu(client);
		return 0;
	}

	if (action != MenuAction_Select || !IsValidHuman(client))
	{
		return 0;
	}

	char steamid[32];
	menu.GetItem(item, steamid, sizeof(steamid));
	ResetPlayerStatsBySteamId(steamid, client);
	ShowAdminResetPlayerMenu(client);
	return 0;
}

public void SQL_ShowAdminResetPlayersMenu(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	delete pack;

	if (!IsValidHuman(client))
	{
		return;
	}

	if (results == null)
	{
		ReplyToCommand(client, "[KSR] Failed to load admin reset list: %s", error);
		return;
	}

	Menu menu = new Menu(MenuHandler_AdminResetPlayer, MENU_ACTIONS_DEFAULT);
	menu.SetTitle("Admin: Reset Player Stats");
	menu.AddItem("x", "Select player from database:", ITEMDRAW_DISABLED);

	int added = 0;
	while (results.FetchRow())
	{
		char steamid[32];
		char lastName[MAX_NAME_LENGTH];
		char firstName[MAX_NAME_LENGTH];
		float rating = results.FetchFloat(3);
		int rounds = results.FetchInt(4);
		float ksr = RatingToKSR(rating, rounds);
		results.FetchString(0, steamid, sizeof(steamid));
		results.FetchString(1, lastName, sizeof(lastName));
		results.FetchString(2, firstName, sizeof(firstName));

		if (lastName[0] == '\0' && firstName[0] != '\0')
		{
			strcopy(lastName, sizeof(lastName), firstName);
		}

		char label[192];
		if (firstName[0] != '\0' && !StrEqual(firstName, lastName, false))
		{
			Format(label, sizeof(label), "%s (%s) | rounds %d | KSR %.0f", lastName, firstName, rounds, ksr);
		}
		else
		{
			Format(label, sizeof(label), "%s | rounds %d | KSR %.0f", lastName, rounds, ksr);
		}
		menu.AddItem(steamid, label);
		added++;
	}

	if (added == 0)
	{
		menu.AddItem("x", "No players found in database.", ITEMDRAW_DISABLED);
	}

	menu.ExitBackButton = true;
	menu.Display(client, 30);
}

void ResetPlayerStatsBySteamId(const char[] steamid, int adminClient)
{
	if (steamid[0] == '\0')
	{
		return;
	}

	char q1[256];
	Format(q1, sizeof(q1), "DELETE FROM round_stats WHERE steamid='%s';", steamid);
	g_Db.Query(SQL_ErrorOnly, q1);

	char q2[256];
	Format(q2, sizeof(q2), "UPDATE players SET total_points=0.0, rounds_played=0, rating=0.0, rating_rounds=0, "
		... "rating_surv=0.0, rating_surv_rounds=0, rating_inf=0.0, rating_inf_rounds=0 WHERE steamid='%s';", steamid);
	g_Db.Query(SQL_ErrorOnly, q2);

	int target = FindOnlineClientBySteamId(steamid);
	if (target > 0)
	{
		g_fTotalPoints[target] = 0.0;
		g_iRoundsPlayed[target] = 0;
		ResetRatingCache(target);
		g_bProfileLoaded[target] = true;
		ResetRoundStats(target);
		PrintToChat(target, "[KSR] Your KSR stats were reset by admin.");
	}

	ReplyToCommand(adminClient, "[KSR] Stats reset for steamid %s", steamid);
}

public void Handle_MixVoteAction(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			g_hMixVote = INVALID_HANDLE;
			g_bMixVoteInProgress = false;
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
			g_bMixVoteInProgress = false;
		}
	}
}

public void Handle_MixVoteResult(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	int yesVotes = 0;
	for (int i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			yesVotes = item_info[i][BUILTINVOTEINFO_ITEM_VOTES];
			break;
		}
	}

	// Against the eligible players, not against however few people bothered to
	// vote - the initiator auto-votes yes, so the old maths passed a 1/1 vote.
	int denominator = (num_clients > 0) ? num_clients : num_votes;

	float yesPct = 0.0;
	if (denominator > 0)
	{
		yesPct = (float(yesVotes) / float(denominator)) * 100.0;
	}

	if (yesPct < g_CvarMixVotePct.FloatValue)
	{
		DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
		return;
	}

	DisplayBuiltinVotePass(vote, "Applying KSR mix...");
	PerformSkillMix();
}
