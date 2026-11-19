#if defined __ksr_ranking_included
	#endinput
#endif
#define __ksr_ranking_included

int GetTopMinRounds()
{
	int minRounds = g_CvarTopMinRounds.IntValue;
	if (minRounds < SKILL_TOP_MIN_ROUNDS_FLOOR)
	{
		minRounds = SKILL_TOP_MIN_ROUNDS_FLOOR;
	}
	return minRounds;
}

void RequestTopMenu(int client, int limit, int minRounds, bool showBackButton)
{
	char query[512];
	Format(query, sizeof(query),
		"SELECT last_name, first_name, rating, rating_rounds, steamid "
		... "FROM players WHERE rating_rounds >= %d "
		// Order by the value that is actually shown. Sorting on the bare rating puts
		// thin-history players above their own displayed KSR, because shrinkage pulls
		// the number down after the sort has already happened.
		... "ORDER BY (rating * rating_rounds / (rating_rounds + %.4f)) DESC, rating_rounds DESC "
		... "LIMIT %d;",
		minRounds, g_CvarRatingShrinkRounds.FloatValue, limit);

	DataPack pack = new DataPack();
	pack.WriteCell(client);
	pack.WriteCell(showBackButton ? 1 : 0);
	pack.WriteCell(minRounds);
	pack.WriteCell(limit);
	g_Db.Query(SQL_ShowTop, query, pack);
}

void RequestSimilarityMenu(int client, int target, bool showBackButton)
{
	char targetSteamid[32];
	if (!GetPlayerSteamId(target, targetSteamid, sizeof(targetSteamid)))
	{
		ReplyToCommand(client, "[KSR] Cannot resolve SteamID for target.");
		return;
	}

	char targetName[MAX_NAME_LENGTH * 2];
	if (g_sFirstName[target][0] != '\0' && !StrEqual(g_sFirstName[target], g_sLastName[target], false))
	{
		Format(targetName, sizeof(targetName), "%s (%s)", g_sLastName[target], g_sFirstName[target]);
	}
	else if (g_sLastName[target][0] != '\0')
	{
		strcopy(targetName, sizeof(targetName), g_sLastName[target]);
	}
	else
	{
		GetClientName(target, targetName, sizeof(targetName));
	}

	int minRounds = GetTopMinRounds();
	char query[512];
	Format(query, sizeof(query),
		"SELECT steamid, last_name, first_name, rating, rating_rounds, rating AS score "
		... "FROM players WHERE rating_rounds >= %d "
		... "ORDER BY (rating * rating_rounds / (rating_rounds + %.4f)) DESC, rating_rounds DESC;",
		minRounds, g_CvarRatingShrinkRounds.FloatValue);

	DataPack pack = new DataPack();
	pack.WriteCell(client);
	pack.WriteCell(showBackButton ? 1 : 0);
	pack.WriteString(targetSteamid);
	pack.WriteString(targetName);
	pack.WriteCell(minRounds);
	g_Db.Query(SQL_ShowRankNeighbors, query, pack);
}

public int MenuHandler_InfoBack(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack && IsValidHuman(client))
	{
		ShowSkillMainMenu(client);
	}

	return 0;
}

public void SQL_ShowTop(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	bool showBackButton = view_as<bool>(pack.ReadCell());
	int minRounds = pack.ReadCell();
	int limit = pack.ReadCell();
	delete pack;

	if (!IsValidClient(client))
	{
		return;
	}

	if (results == null)
	{
		ReplyToCommand(client, "[KSR] Top query failed: %s", error);
		return;
	}

	// Rows are selectable, which is what makes SourceMod page through them seven
	// at a time instead of cutting the list off, and lets a name be opened.
	Menu menu = new Menu(MenuHandler_TopList, MENU_ACTIONS_DEFAULT);
	char title[128];
	Format(title, sizeof(title), "KSR leaderboard - min %d rounds", minRounds);
	menu.SetTitle(title);
	menu.ExitBackButton = showBackButton;

	int rank = 0;
	while (results.FetchRow() && rank < limit)
	{
		char lastName[MAX_NAME_LENGTH];
		char firstName[MAX_NAME_LENGTH];
		char steamid[32];
		results.FetchString(0, lastName, sizeof(lastName));
		results.FetchString(1, firstName, sizeof(firstName));
		float rating = results.FetchFloat(2);
		int rounds = results.FetchInt(3);
		results.FetchString(4, steamid, sizeof(steamid));

		char name[MAX_NAME_LENGTH * 2];
		FormatSkillPlayerName(lastName, firstName, name, sizeof(name));

		rank++;

		char line[192];
		Format(line, sizeof(line), "#%d %s | KSR %.0f | %d rounds",
			rank, name, RatingToKSR(rating, rounds), rounds);
		menu.AddItem(steamid, line);
	}

	if (rank == 0)
	{
		menu.AddItem("x", "No players match KSR ranking criteria.", ITEMDRAW_DISABLED);
	}

	menu.Display(client, 60);
}

public int MenuHandler_TopList(Menu menu, MenuAction action, int client, int item)
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
	char display[192];
	menu.GetItem(item, steamid, sizeof(steamid), _, display, sizeof(display));
	if (StrEqual(steamid, "x"))
	{
		return 0;
	}

	// The label already reads "#4 name | KSR ...", so trim it back to the name for
	// the card's title.
	char name[192];
	strcopy(name, sizeof(name), display);
	int bar = FindCharInString(name, '|');
	if (bar > 1)
	{
		name[bar - 1] = '\0';
	}
	int space = FindCharInString(name, ' ');
	if (space >= 0)
	{
		strcopy(name, sizeof(name), name[space + 1]);
	}

	RequestBreakdown(client, steamid, name, true);
	return 0;
}

void FormatSkillPlayerName(const char[] lastName, const char[] firstName, char[] buffer, int size)
{
	if (lastName[0] == '\0' && firstName[0] != '\0')
	{
		strcopy(buffer, size, firstName);
		return;
	}

	if (firstName[0] != '\0' && !StrEqual(firstName, lastName, false))
	{
		Format(buffer, size, "%s (%s)", lastName, firstName);
	}
	else
	{
		strcopy(buffer, size, lastName);
	}
}

public void SQL_ShowRankNeighbors(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	bool showBackButton = view_as<bool>(pack.ReadCell());
	char targetSteamid[32];
	pack.ReadString(targetSteamid, sizeof(targetSteamid));
	char targetName[MAX_NAME_LENGTH * 2];
	pack.ReadString(targetName, sizeof(targetName));
	int minRounds = pack.ReadCell();
	delete pack;

	if (!IsValidClient(client))
	{
		return;
	}

	Menu menu = new Menu(MenuHandler_TopList, MENU_ACTIONS_DEFAULT);
	menu.ExitBackButton = showBackButton;

	if (results == null)
	{
		ReplyToCommand(client, "[KSR] Ranking query failed: %s", error);
		delete menu;
		return;
	}

	char rankSteamid[SKILL_RANK_LIST_MAX][32];
	char rankName[SKILL_RANK_LIST_MAX][MAX_NAME_LENGTH * 2];
	float rankAvg[SKILL_RANK_LIST_MAX];
	int rankRounds[SKILL_RANK_LIST_MAX];
	int rankCount = 0;

	while (results.FetchRow() && rankCount < SKILL_RANK_LIST_MAX)
	{
		char lastName[MAX_NAME_LENGTH];
		char firstName[MAX_NAME_LENGTH];
		results.FetchString(0, rankSteamid[rankCount], sizeof(rankSteamid[]));
		results.FetchString(1, lastName, sizeof(lastName));
		results.FetchString(2, firstName, sizeof(firstName));
		results.FetchFloat(3); // total_points (unused here)
		rankRounds[rankCount] = results.FetchInt(4);
		rankAvg[rankCount] = results.FetchFloat(5);

		if (rankRounds[rankCount] < minRounds)
		{
			continue;
		}

		FormatSkillPlayerName(lastName, firstName, rankName[rankCount], sizeof(rankName[]));
		rankCount++;
	}

	int targetIdx = -1;
	for (int i = 0; i < rankCount; i++)
	{
		if (StrEqual(rankSteamid[i], targetSteamid, false))
		{
			targetIdx = i;
			break;
		}
	}

	if (targetIdx == -1)
	{
		menu.SetTitle("KSR Similar Rank");
		char line[128];
		Format(line, sizeof(line), "%s needs at least %d rounds for KSR ranking.", targetName, minRounds);
		menu.AddItem("x", line, ITEMDRAW_DISABLED);
		menu.Display(client, 20);
		return;
	}

	int targetRank = targetIdx + 1;
	char title[160];
	Format(title, sizeof(title), "KSR around %s (#%d of %d)", targetName, targetRank, rankCount);
	menu.SetTitle(title);

	// A window centred on the player: SKILL_SIMILAR_SIDE ranks above, the player,
	// and the same number below. Near either end of the ladder the window slides
	// instead of shrinking, so it always shows the same number of names.
	int span = SKILL_SIMILAR_SIDE * 2 + 1;
	int first = targetIdx - SKILL_SIMILAR_SIDE;
	if (first < 0)
	{
		first = 0;
	}
	if (first + span > rankCount)
	{
		first = rankCount - span;
		if (first < 0)
		{
			first = 0;
		}
	}

	int last = first + span;
	if (last > rankCount)
	{
		last = rankCount;
	}

	if (first > 0)
	{
		char above[64];
		Format(above, sizeof(above), "... %d higher", first);
		menu.AddItem("x", above, ITEMDRAW_DISABLED);
	}

	for (int i = first; i < last; i++)
	{
		bool self = (i == targetIdx);
		char ksr[32];
		if (self)
		{
			FormatKSRWithConfidence(rankAvg[i], rankRounds[i], ksr, sizeof(ksr));
		}
		else
		{
			FormatKSRValue(rankAvg[i], rankRounds[i], ksr, sizeof(ksr));
		}

		char line[192];
		Format(line, sizeof(line), "%s#%d %s | KSR %s | %d rounds",
			self ? ">> " : "", i + 1, rankName[i], ksr, rankRounds[i]);

		if (self)
		{
			menu.AddItem("x", line, ITEMDRAW_DISABLED);
		}
		else
		{
			menu.AddItem(rankSteamid[i], line);
		}
	}

	if (last < rankCount)
	{
		char below[64];
		Format(below, sizeof(below), "... %d lower", rankCount - last);
		menu.AddItem("x", below, ITEMDRAW_DISABLED);
	}

	menu.Display(client, 60);
}
