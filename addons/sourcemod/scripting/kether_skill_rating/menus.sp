#if defined __ksr_menus_included
	#endinput
#endif
#define __ksr_menus_included

public Action Command_Skill(int client, int args)
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

	if (args < 1)
	{
		ShowSkillMainMenu(client);
		return Plugin_Handled;
	}

	int target = client;
	if (args >= 1)
	{
		char arg[64];
		GetCmdArg(1, arg, sizeof(arg));
		target = FindTarget(client, arg, true, false);
		if (target <= 0)
		{
			return Plugin_Handled;
		}
	}

	ShowSkillForTarget(client, target, false);

	return Plugin_Handled;
}

void ShowSkillForTarget(int client, int target, bool showBackButton)
{
	if (!IsValidHuman(client) || !IsValidClient(target))
	{
		return;
	}

	char steamid[32];
	if (!GetPlayerSteamId(target, steamid, sizeof(steamid)))
	{
		ReplyToCommand(client, "[KSR] Cannot resolve SteamID for target.");
		return;
	}

	// Recent form is the average z of the last rounds, which lives in round_stats.
	char query[512];
	Format(query, sizeof(query),
		"SELECT AVG(rating_z), COUNT(*) FROM "
		... "(SELECT rating_z FROM round_stats WHERE steamid='%s' AND rating_z != 0.0 "
		... "ORDER BY ts DESC, id DESC LIMIT 30);",
		steamid);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(GetClientUserId(target));
	pack.WriteCell(showBackButton ? 1 : 0);
	g_Db.Query(SQL_ShowProfileCard, query, pack);
}

public void SQL_ShowProfileCard(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	int target = GetClientOfUserId(pack.ReadCell());
	bool showBackButton = view_as<bool>(pack.ReadCell());
	delete pack;

	if (!IsValidHuman(client) || !IsValidClient(target))
	{
		return;
	}

	float formZ = 0.0;
	int formRounds = 0;
	if (results != null && results.FetchRow())
	{
		if (!results.IsFieldNull(0))
		{
			formZ = results.FetchFloat(0);
		}
		formRounds = results.FetchInt(1);
	}

	Menu menu = new Menu(MenuHandler_InfoBack, MENU_ACTIONS_DEFAULT);
	char title[128];
	char displayName[160];
	BuildDisplayName(target, displayName, sizeof(displayName));
	Format(title, sizeof(title), "KSR: %s", displayName);
	menu.SetTitle(title);

	char line[256];
	char ksr[32];

	FormatKSRWithConfidence(g_fRating[target], g_iRatingRounds[target], ksr, sizeof(ksr));
	Format(line, sizeof(line), "KSR: %s   |   %d rated rounds", ksr, g_iRatingRounds[target]);
	menu.AddItem("x", line, ITEMDRAW_DISABLED);

	if (g_iRatingRounds[target] < GetTopMinRounds())
	{
		Format(line, sizeof(line), "Provisional - %d more rounds to qualify",
			GetTopMinRounds() - g_iRatingRounds[target]);
		menu.AddItem("x", line, ITEMDRAW_DISABLED);
	}

	menu.AddItem("x", "--- By side ---", ITEMDRAW_DISABLED);
	Format(line, sizeof(line), "Survivor: %.0f   (%d rounds)",
		GetSideKSR(target, TEAM_SURVIVOR), g_iRatingSideRounds[TEAM_SURVIVOR][target]);
	menu.AddItem("x", line, ITEMDRAW_DISABLED);
	Format(line, sizeof(line), "Infected: %.0f   (%d rounds)",
		GetSideKSR(target, TEAM_INFECTED), g_iRatingSideRounds[TEAM_INFECTED][target]);
	menu.AddItem("x", line, ITEMDRAW_DISABLED);

	if (formRounds >= 5)
	{
		// Same scale as the rating, so form and KSR can be read side by side.
		float formKsr = KSR_BASE + g_CvarRatingScale.FloatValue * formZ;
		float diff = formKsr - RatingToKSR(g_fRating[target], g_iRatingRounds[target]);
		Format(line, sizeof(line), "Form (last %d): %.0f   [%s%.0f vs rating]",
			formRounds, formKsr, (diff >= 0.0) ? "+" : "", diff);
		menu.AddItem("x", line, ITEMDRAW_DISABLED);
	}
	else
	{
		menu.AddItem("x", "Form: not enough rounds on the new model yet", ITEMDRAW_DISABLED);
	}

	menu.ExitBackButton = showBackButton;
	menu.Display(client, 25);
}

public Action Command_SkillTop(int client, int args)
{
	if (!g_CvarEnabled.BoolValue)
	{
		ReplyToCommand(client, "[KSR] Plugin is disabled.");
		return Plugin_Handled;
	}

	int limit = g_CvarTopListMax.IntValue;
	if (args >= 1)
	{
		char arg[16];
		GetCmdArg(1, arg, sizeof(arg));
		limit = StringToInt(arg);
		if (limit < 7)
		{
			limit = 7;
		}
		if (limit > SKILL_RANK_LIST_MAX)
		{
			limit = SKILL_RANK_LIST_MAX;
		}
	}

	RequestTopMenu(client, limit, GetTopMinRounds(), false);

	return Plugin_Handled;
}

public Action Command_SkillSim(int client, int args)
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

	int target = client;
	if (args >= 1)
	{
		char arg[64];
		GetCmdArg(1, arg, sizeof(arg));
		target = FindTarget(client, arg, true, false);
		if (target <= 0)
		{
			return Plugin_Handled;
		}
	}

	RequestSimilarityMenu(client, target, false);

	return Plugin_Handled;
}

public Action Command_SkillBreakdown(int client, int args)
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

	int target = client;
	if (args >= 1)
	{
		char arg[64];
		GetCmdArg(1, arg, sizeof(arg));
		target = FindTarget(client, arg, true, false);
		if (target <= 0)
		{
			return Plugin_Handled;
		}
	}

	char steamid[32];
	if (!GetPlayerSteamId(target, steamid, sizeof(steamid)))
	{
		ReplyToCommand(client, "[KSR] Cannot resolve SteamID for target.");
		return Plugin_Handled;
	}

	char displayName[160];
	BuildDisplayName(target, displayName, sizeof(displayName));
	RequestBreakdown(client, steamid, displayName, false);
	return Plugin_Handled;
}

// Player averages next to the server averages for every scored component, shown
// as the points each one actually contributes per round. This is the screen that
// answers "why is my rating what it is" without anyone having to guess.
// Takes a steamid rather than a client, so the leaderboard can open the card of
// somebody who is not on the server right now.
void RequestBreakdown(int client, const char[] steamid, const char[] displayName, bool showBackButton)
{
	// Roughly 21 bytes per stat, repeated four times in the UNION below. At 60 stats
	// that is about 5 KB, so the buffers carry room for a good deal more.
	char cols[4096];
	cols[0] = '\0';
	for (int i = 0; i < g_iStatCount; i++)
	{
		Format(cols, sizeof(cols), "%s, AVG(%s)", cols, g_Stats[i].column);
	}

	char query[12288];
	Format(query, sizeof(query),
		"SELECT 0%s, COUNT(*) FROM round_stats WHERE steamid='%s' AND team=%d"
		... " UNION ALL SELECT 1%s, COUNT(*) FROM round_stats WHERE team=%d"
		... " UNION ALL SELECT 2%s, COUNT(*) FROM round_stats WHERE steamid='%s' AND team=%d"
		... " UNION ALL SELECT 3%s, COUNT(*) FROM round_stats WHERE team=%d;",
		cols, steamid, TEAM_SURVIVOR,
		cols, TEAM_SURVIVOR,
		cols, steamid, TEAM_INFECTED,
		cols, TEAM_INFECTED);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(showBackButton ? 1 : 0);
	pack.WriteString(displayName);
	g_Db.Query(SQL_ShowBreakdown, query, pack);
}

public void SQL_ShowBreakdown(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	bool showBackButton = view_as<bool>(pack.ReadCell());
	char displayName[160];
	pack.ReadString(displayName, sizeof(displayName));
	delete pack;

	if (!IsValidHuman(client))
	{
		return;
	}

	if (results == null)
	{
		ReplyToCommand(client, "[KSR] Breakdown query failed: %s", error);
		return;
	}

	for (int i = 0; i < g_iStatCount; i++)
	{
		g_fBdMine[client][i] = 0.0;
		g_fBdAvg[client][i] = 0.0;
	}
	g_iBdRounds[client][TEAM_SURVIVOR] = 0;
	g_iBdRounds[client][TEAM_INFECTED] = 0;

	while (results.FetchRow())
	{
		int row = results.FetchInt(0);
		int side = (row < 2) ? TEAM_SURVIVOR : TEAM_INFECTED;
		bool mine = (row == 0 || row == 2);

		for (int i = 0; i < g_iStatCount; i++)
		{
			if (g_Stats[i].side != side)
			{
				continue;
			}

			float v = results.IsFieldNull(i + 1) ? 0.0 : results.FetchFloat(i + 1);
			if (mine)
			{
				g_fBdMine[client][i] = v;
			}
			else
			{
				g_fBdAvg[client][i] = v;
			}
		}

		if (mine)
		{
			g_iBdRounds[client][side] = results.FetchInt(g_iStatCount + 1);
		}
	}

	strcopy(g_sBdName[client], sizeof(g_sBdName[]), displayName);
	g_bBdReady[client] = true;

	ShowBreakdownCategories(client, showBackButton);
}

void ShowBreakdownCategories(int client, bool showBackButton)
{
	Menu menu = new Menu(MenuHandler_BreakdownCategory, MENU_ACTIONS_DEFAULT);
	char title[192];
	Format(title, sizeof(title), "Points per round: %s", g_sBdName[client]);
	menu.SetTitle(title);
	menu.ExitBackButton = showBackButton;

	if (g_iBdRounds[client][TEAM_SURVIVOR] < 5 && g_iBdRounds[client][TEAM_INFECTED] < 5)
	{
		menu.AddItem("x", "Not enough rounds recorded yet.", ITEMDRAW_DISABLED);
		menu.Display(client, 30);
		return;
	}

	char line[192];
	char info[8];
	int lastSide = 0;

	for (int cat = 0; cat < KSR_CATEGORIES; cat++)
	{
		int side = CategorySide(cat);
		if (g_iBdRounds[client][side] < 5)
		{
			continue;
		}

		if (side != lastSide)
		{
			Format(line, sizeof(line), "--- %s (%d rounds) ---",
				(side == TEAM_SURVIVOR) ? "Survivor" : "Infected", g_iBdRounds[client][side]);
			menu.AddItem("x", line, ITEMDRAW_DISABLED);
			lastSide = side;
		}

		float mine = 0.0;
		float avg = 0.0;
		CategoryPoints(client, cat, mine, avg);

		Format(info, sizeof(info), "%d", cat);
		Format(line, sizeof(line), "%s: %.1f pts (avg %.1f) %s",
			g_sCategoryName[cat], mine, avg, DeltaLabel(mine, avg, false));
		menu.AddItem(info, line);
	}

	menu.Display(client, 30);
}

int CategorySide(int category)
{
	return (category < 6) ? TEAM_SURVIVOR : TEAM_INFECTED;
}

void CategoryPoints(int client, int category, float &mine, float &avg)
{
	mine = 0.0;
	avg = 0.0;

	for (int i = 0; i < g_iStatCount; i++)
	{
		if (g_Stats[i].category != category)
		{
			continue;
		}

		float w = g_Stats[i].weight.FloatValue;
		mine += g_fBdMine[client][i] * w;
		avg += g_fBdAvg[client][i] * w;
	}
}

public int MenuHandler_BreakdownCategory(Menu menu, MenuAction action, int client, int item)
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

	if (action != MenuAction_Select || !IsValidHuman(client) || !g_bBdReady[client])
	{
		return 0;
	}

	char info[8];
	menu.GetItem(item, info, sizeof(info));
	ShowBreakdownDetail(client, StringToInt(info));
	return 0;
}

void ShowBreakdownDetail(int client, int category)
{
	if (category < 0 || category >= KSR_CATEGORIES)
	{
		return;
	}

	Menu menu = new Menu(MenuHandler_BreakdownDetail, MENU_ACTIONS_DEFAULT);
	char title[192];
	Format(title, sizeof(title), "%s: %s", g_sCategoryName[category], g_sBdName[client]);
	menu.SetTitle(title);
	menu.ExitBackButton = true;

	char line[192];
	for (int i = 0; i < g_iStatCount; i++)
	{
		if (g_Stats[i].category != category)
		{
			continue;
		}

		float w = g_Stats[i].weight.FloatValue;
		float minePts = g_fBdMine[client][i] * w;
		float avgPts = g_fBdAvg[client][i] * w;

		// Counts as well as points: a raw average of 3200 damage says more about
		// what you actually do than the 23 points it turns into.
		if (g_fBdMine[client][i] >= 100.0 || g_fBdAvg[client][i] >= 100.0)
		{
			Format(line, sizeof(line), "%s: %.0f -> %.1f pts (avg %.1f) %s",
				g_Stats[i].label, g_fBdMine[client][i], minePts, avgPts,
				DeltaLabel(g_fBdMine[client][i], g_fBdAvg[client][i], g_Stats[i].lowerIsBetter));
		}
		else
		{
			Format(line, sizeof(line), "%s: %.2f -> %.1f pts (avg %.1f) %s",
				g_Stats[i].label, g_fBdMine[client][i], minePts, avgPts,
				DeltaLabel(g_fBdMine[client][i], g_fBdAvg[client][i], g_Stats[i].lowerIsBetter));
		}

		menu.AddItem("x", line, ITEMDRAW_DISABLED);
	}

	menu.Display(client, 30);
}

public int MenuHandler_BreakdownDetail(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack && IsValidHuman(client))
	{
		ShowBreakdownCategories(client, true);
	}

	return 0;
}

// lowerIsBetter flips the sign, so "friendly fire -40%" reads as a good thing.
char[] DeltaLabel(float mine, float avg, bool lowerIsBetter)
{
	char out[24];

	if (avg > 0.0001 || avg < -0.0001)
	{
		float pct = ((mine / avg) - 1.0) * 100.0;
		if (lowerIsBetter)
		{
			pct = -pct;
		}
		Format(out, sizeof(out), "%s%.0f%%", (pct >= 0.0) ? "+" : "", pct);
	}
	else
	{
		strcopy(out, sizeof(out), "");
	}

	return out;
}
