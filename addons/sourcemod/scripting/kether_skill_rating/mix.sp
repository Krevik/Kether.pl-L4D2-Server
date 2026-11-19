#if defined __ksr_mix_included
	#endinput
#endif
#define __ksr_mix_included

void PerformSkillMix()
{
	if (!IsMixAllowedNow())
	{
		PrintToChatAll("\x04[KSR]\x01 Mix aborted: the round already started.");
		return;
	}

	// The roster can change while the vote runs. Re-plan if it did, so the mix is
	// never applied to a lobby it was not computed for.
	if (!IsPlannedSplitStillValid() && !BuildPlannedSplit())
	{
		PrintToChatAll("\x04[KSR]\x01 Mix aborted: teams are no longer valid.");
		return;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidHuman(i) && GetClientTeam(i) != TEAM_SPECTATOR)
		{
			ChangeClientTeam(i, TEAM_SPECTATOR);
		}
	}

	// Moving everyone at once does not work: the survivor slots are taken over
	// from bots, and the game needs a few frames to actually spawn those bots
	// after the humans leave. Firing all four sb_takecontrol calls in the same
	// frame is why a mix could silently end up lopsided. One player per tick.
	g_iMixApplyStep = 0;
	delete g_hMixApplyTimer;
	g_hMixApplyTimer = CreateTimer(0.3, Timer_ApplyMixStep, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ApplyMixStep(Handle timer)
{
	int total = g_iPlannedSurvCount + g_iPlannedInfCount;

	if (g_iMixApplyStep >= total)
	{
		g_hMixApplyTimer = null;
		VerifyMixResult();
		return Plugin_Stop;
	}

	int step = g_iMixApplyStep++;
	if (step < g_iPlannedInfCount)
	{
		// Infected first: a plain team change, no bot needed, and it frees the
		// survivor slots the rest of the lobby is about to take over.
		MoveHumanToTeam(g_iPlannedInf[step], TEAM_INFECTED);
	}
	else
	{
		MoveHumanToTeam(g_iPlannedSurv[step - g_iPlannedInfCount], TEAM_SURVIVOR);
	}

	return Plugin_Continue;
}

// Says so out loud when the move did not take, instead of leaving people to
// wonder why the teams look nothing like the ones they voted for.
void VerifyMixResult()
{
	int wrong = 0;

	for (int i = 0; i < g_iPlannedSurvCount; i++)
	{
		int c = g_iPlannedSurv[i];
		if (IsValidHuman(c) && GetClientTeam(c) != TEAM_SURVIVOR)
		{
			MoveHumanToTeam(c, TEAM_SURVIVOR);
			wrong++;
		}
	}
	for (int i = 0; i < g_iPlannedInfCount; i++)
	{
		int c = g_iPlannedInf[i];
		if (IsValidHuman(c) && GetClientTeam(c) != TEAM_INFECTED)
		{
			MoveHumanToTeam(c, TEAM_INFECTED);
			wrong++;
		}
	}

	if (wrong > 0)
	{
		PrintToChatAll("\x04[KSR]\x01 %d player(s) did not land on the right team - retrying.", wrong);
		CreateTimer(1.0, Timer_MixFinalCheck, _, TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

	PrintToChatAll("\x04[KSR]\x01 Teams mixed by current KSR.");
	PrintTeamKsrSummary(0);
}

public Action Timer_MixFinalCheck(Handle timer)
{
	int wrong = 0;
	for (int i = 0; i < g_iPlannedSurvCount; i++)
	{
		if (IsValidHuman(g_iPlannedSurv[i]) && GetClientTeam(g_iPlannedSurv[i]) != TEAM_SURVIVOR)
		{
			wrong++;
		}
	}
	for (int i = 0; i < g_iPlannedInfCount; i++)
	{
		if (IsValidHuman(g_iPlannedInf[i]) && GetClientTeam(g_iPlannedInf[i]) != TEAM_INFECTED)
		{
			wrong++;
		}
	}

	if (wrong > 0)
	{
		PrintToChatAll("\x04[KSR]\x01 \x03Warning:\x01 %d player(s) are still on the wrong team - fix it manually.", wrong);
	}
	else
	{
		PrintToChatAll("\x04[KSR]\x01 Teams mixed by current KSR.");
	}

	PrintTeamKsrSummary(0);
	return Plugin_Stop;
}

bool IsPlannedSplitStillValid()
{
	if (g_iPlannedSurvCount == 0 || g_iPlannedSurvCount != g_iPlannedInfCount)
	{
		return false;
	}

	int seen = 0;
	for (int i = 0; i < g_iPlannedSurvCount; i++)
	{
		if (!IsValidHuman(g_iPlannedSurv[i]))
		{
			return false;
		}
		seen++;
	}
	for (int i = 0; i < g_iPlannedInfCount; i++)
	{
		if (!IsValidHuman(g_iPlannedInf[i]))
		{
			return false;
		}
		seen++;
	}

	// Nobody may have joined a team in the meantime either.
	int onTeams = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidHuman(i) && (GetClientTeam(i) == TEAM_SURVIVOR || GetClientTeam(i) == TEAM_INFECTED))
		{
			onTeams++;
		}
	}

	return onTeams == seen;
}

bool BuildPlannedSplit()
{
	int players[MAXPLAYERS + 1];
	float rating[MAXPLAYERS + 1];
	int count = 0;
	int survCount = 0;
	int infCount = 0;

	g_iPlannedSurvCount = 0;
	g_iPlannedInfCount = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidHuman(i))
		{
			continue;
		}

		int team = GetClientTeam(i);
		if (team != TEAM_SURVIVOR && team != TEAM_INFECTED)
		{
			continue;
		}

		players[count] = i;
		rating[count] = GetMixRating(i);
		count++;

		if (team == TEAM_SURVIVOR)
		{
			survCount++;
		}
		else
		{
			infCount++;
		}
	}

	if (!IsValidMixSetup(survCount, infCount))
	{
		return false;
	}

	SortByRatingDesc(players, rating, count);

	int teamSize = count / 2;
	if (FindBestSplit(rating, count, teamSize, players, g_iPlannedSurv, g_iPlannedInf,
		g_iPlannedSurvCount, g_iPlannedInfCount))
	{
		return true;
	}

	// Search space too large: fall back to the greedy walk.
	g_iPlannedSurvCount = 0;
	g_iPlannedInfCount = 0;
	float sumSurv = 0.0;
	float sumInf = 0.0;

	for (int i = 0; i < count; i++)
	{
		if (g_iPlannedSurvCount >= teamSize)
		{
			g_iPlannedInf[g_iPlannedInfCount++] = players[i];
			sumInf += rating[i];
			continue;
		}
		if (g_iPlannedInfCount >= teamSize)
		{
			g_iPlannedSurv[g_iPlannedSurvCount++] = players[i];
			sumSurv += rating[i];
			continue;
		}

		if (sumSurv <= sumInf)
		{
			g_iPlannedSurv[g_iPlannedSurvCount++] = players[i];
			sumSurv += rating[i];
		}
		else
		{
			g_iPlannedInf[g_iPlannedInfCount++] = players[i];
			sumInf += rating[i];
		}
	}

	return g_iPlannedSurvCount > 0;
}

// Nobody should have to vote blind on what the teams will look like.
void AnnouncePlannedSplit()
{
	char line[256];
	char name[MAX_NAME_LENGTH];
	float sumSurv = 0.0;
	float sumInf = 0.0;

	line[0] = '\0';
	for (int i = 0; i < g_iPlannedSurvCount; i++)
	{
		GetClientName(g_iPlannedSurv[i], name, sizeof(name));
		Format(line, sizeof(line), "%s%s%s %.0f", line, (i > 0) ? ", " : "", name, GetMixRating(g_iPlannedSurv[i]));
		sumSurv += GetMixRating(g_iPlannedSurv[i]);
	}
	PrintToChatAll("\x04[KSR]\x01 \x04Survivors\x01 (\x05%.0f\x01): %s", sumSurv, line);

	line[0] = '\0';
	for (int i = 0; i < g_iPlannedInfCount; i++)
	{
		GetClientName(g_iPlannedInf[i], name, sizeof(name));
		Format(line, sizeof(line), "%s%s%s %.0f", line, (i > 0) ? ", " : "", name, GetMixRating(g_iPlannedInf[i]));
		sumInf += GetMixRating(g_iPlannedInf[i]);
	}
	PrintToChatAll("\x04[KSR]\x01 \x08Infected\x01 (\x05%.0f\x01): %s", sumInf, line);

	if (g_iPlannedSurvCount > 0 && g_iPlannedInfCount > 0)
	{
		char balance[192];
		BuildBalanceLine(sumSurv / float(g_iPlannedSurvCount), sumInf / float(g_iPlannedInfCount), balance, sizeof(balance));
		PrintToChatAll("%s", balance);
		AnnounceShapeWarning();
	}
}

// Equal sums are not the whole story. Head to head over 445 map pairs, the single
// best player predicts how many survivors reach the saferoom about as well as the
// whole team's sum does - so a team built as star-plus-passenger is not really the
// same as four even players, even when the totals match. The search already avoids
// the worst case, but where a gap in shape remains it is called out so people can
// re-roll instead of finding out the hard way.
void AnnounceShapeWarning()
{
	float topSurv = 0.0, lowSurv = 0.0, topInf = 0.0, lowInf = 0.0;

	for (int i = 0; i < g_iPlannedSurvCount; i++)
	{
		float r = GetMixRating(g_iPlannedSurv[i]);
		if (i == 0 || r > topSurv) { topSurv = r; }
		if (i == 0 || r < lowSurv) { lowSurv = r; }
	}
	for (int i = 0; i < g_iPlannedInfCount; i++)
	{
		float r = GetMixRating(g_iPlannedInf[i]);
		if (i == 0 || r > topInf) { topInf = r; }
		if (i == 0 || r < lowInf) { lowInf = r; }
	}

	float spreadSurv = topSurv - lowSurv;
	float spreadInf = topInf - lowInf;
	float shapeGap = spreadSurv - spreadInf;
	if (shapeGap < 0.0)
	{
		shapeGap = -shapeGap;
	}

	PrintToChatAll("\x04[KSR]\x01 Shape: \x04S\x01 %.0f-%.0f  |  \x08I\x01 %.0f-%.0f",
		lowSurv, topSurv, lowInf, topInf);

	if (shapeGap >= g_CvarMixShapeWarn.FloatValue)
	{
		PrintToChatAll("\x04[KSR]\x01 \x03Heads up:\x01 sums match but one side is far more top-heavy (%.0f KSR apart).",
			shapeGap);
	}
}

// Exhaustive search over every way to cut the lobby in half. For 8 players that
// is 35 distinct splits, so this is free and always returns the true optimum -
// a greedy walk only approximates it.
//
// Balance means equal total strength, so the difference in sums is the objective,
// plus the StackPenalty surcharge on splits that put both stars or both weakest
// players on one side. The secondary criteria - matching the top player, the
// internal spread, and matching the two teams on each half of the map - pick
// between the splits whose sums are within sm_skill_mix_tolerance of the best one
// available. With a tolerance of 0 they only decided exact ties, and two float sums
// are never exactly tied, so they never ran at all. 40 KSR of team sum is 10 a
// head, about one and a half points of win chance, and buys a third off the
// imbalance on each half of the map.
bool FindBestSplit(const float rating[MAXPLAYERS + 1], int count, int teamSize,
	const int players[MAXPLAYERS + 1], int teamSurv[MAXPLAYERS + 1], int teamInf[MAXPLAYERS + 1],
	int &survIdx, int &infIdx)
{
	if (count > 16 || teamSize <= 0)
	{
		return false;
	}

	int combos = 1 << count;
	float bestDiff = -1.0;
	int weakMask = BuildWeakMask(rating, count);

	// Pass one: how close can the sums possibly get?
	for (int mask = 0; mask < combos; mask++)
	{
		if (!(mask & 1) || !HasExactBits(mask, count, teamSize))
		{
			continue;
		}

		float diff = SplitSumDiff(mask, rating, count) + StackPenalty(mask, count, weakMask);
		if (bestDiff < 0.0 || diff < bestDiff)
		{
			bestDiff = diff;
		}
	}

	if (bestDiff < 0.0)
	{
		return false;
	}

	// Pass two: among the splits that match that, pick the best shaped one.
	float limit = bestDiff + g_CvarMixTolerance.FloatValue;
	int bestMask = -1;
	float bestSecondary = 0.0;

	for (int mask = 0; mask < combos; mask++)
	{
		if (!(mask & 1) || !HasExactBits(mask, count, teamSize))
		{
			continue;
		}

		if (SplitSumDiff(mask, rating, count) + StackPenalty(mask, count, weakMask) > limit)
		{
			continue;
		}

		float secondary = SplitSecondaryCost(mask, rating, players, count);
		if (bestMask == -1 || secondary < bestSecondary)
		{
			bestMask = mask;
			bestSecondary = secondary;
		}
	}

	if (bestMask == -1)
	{
		return false;
	}

	// Player 0 was pinned to one side to skip mirrored splits, which would always
	// park the highest rated player on survivors. Flip a coin instead.
	if (GetRandomInt(0, 1) == 1)
	{
		bestMask = (~bestMask) & (combos - 1);
	}

	survIdx = 0;
	infIdx = 0;
	for (int i = 0; i < count; i++)
	{
		if (bestMask & (1 << i))
		{
			teamSurv[survIdx++] = players[i];
		}
		else
		{
			teamInf[infIdx++] = players[i];
		}
	}

	return true;
}

// players[] arrives sorted by rating descending and index 0 is pinned to one side,
// so the two best players share a team exactly when bit 1 is set as well, and the
// two weakest share one when the last two bits are equal.
//
// Equal sums do not mean equal teams. A real lobby split 1518/1190/1017/674 against
// four flat 1090s came to within 39 points on paper and was still one-sided: an
// elite player has no ceiling, while a weak one can only cost you so much. Keeping
// the top two apart costs about 4 KSR of sum balance in an average lobby, which is
// nearly free, and this penalty is what pays for it in the lopsided ones.
//
// The bottom pair gets the same treatment: two passengers on one side means that
// side has two players to carry instead of one, whatever the sums say. Both are
// soft penalties rather than hard rules. Forcing both pairs apart and balancing
// only the middle leaves a 4v4 lobby a single way to split, and on 494 historical
// lobbies that pushed the worst average gap from 53 to 92 KSR; a 150 penalty still
// keeps the weakest two apart in 98% of them for 4 KSR at the 90th percentile.
//
// A lobby with more than two weak players gets one more rule: the weak group is
// split as evenly as it can be, four of them two and two, three of them two and
// one. "Weak" is relative to the lobby - sm_skill_mix_weak_margin below its average
// - so a lobby of four regulars and four newcomers splits the newcomers, while a
// flat lobby has no weak group at all. Both rules are needed: balancing the group
// on its own let the two weakest pair up on the side that got two of them in
// almost one lobby in five. Each player that would have to move to even the
// group out costs one sm_skill_mix_weak_group_penalty.
float StackPenalty(int mask, int count, int weakMask)
{
	float penalty = (mask & 2) ? g_CvarMixStackPenalty.FloatValue : 0.0;

	// Below four players the two pairs overlap, and a 1v1 cannot stack anyone.
	if (count >= 4)
	{
		bool lastOnA = (mask & (1 << (count - 1))) != 0;
		bool secondLastOnA = (mask & (1 << (count - 2))) != 0;
		if (lastOnA == secondLastOnA)
		{
			penalty += g_CvarMixLowStackPenalty.FloatValue;
		}
	}

	if (weakMask != 0)
	{
		int weak = CountBits(weakMask);
		int weakOnA = CountBits(mask & weakMask);
		int imbalance = 2 * weakOnA - weak;
		if (imbalance < 0)
		{
			imbalance = -imbalance;
		}
		int toMove = (imbalance - (weak % 2)) / 2;
		if (toMove > 0)
		{
			penalty += float(toMove) * g_CvarMixWeakGroupPenalty.FloatValue;
		}
	}

	return penalty;
}

// Bit i set = player i is at least sm_skill_mix_weak_margin below the lobby average.
int BuildWeakMask(const float rating[MAXPLAYERS + 1], int count)
{
	if (count < 4 || g_CvarMixWeakGroupPenalty.FloatValue <= 0.0)
	{
		return 0;
	}

	float sum = 0.0;
	for (int i = 0; i < count; i++)
	{
		sum += rating[i];
	}
	float threshold = (sum / float(count)) - g_CvarMixWeakMargin.FloatValue;

	int weakMask = 0;
	for (int i = 0; i < count; i++)
	{
		if (rating[i] <= threshold)
		{
			weakMask |= (1 << i);
		}
	}
	return weakMask;
}

int CountBits(int value)
{
	int bits = 0;
	while (value != 0)
	{
		value &= value - 1;
		bits++;
	}
	return bits;
}

bool HasExactBits(int mask, int count, int wanted)
{
	int bits = 0;
	for (int i = 0; i < count; i++)
	{
		if (mask & (1 << i))
		{
			bits++;
			if (bits > wanted)
			{
				return false;
			}
		}
	}
	return bits == wanted;
}

float SplitSumDiff(int mask, const float rating[MAXPLAYERS + 1], int count)
{
	float sumA = 0.0;
	float sumB = 0.0;

	for (int i = 0; i < count; i++)
	{
		if (mask & (1 << i))
		{
			sumA += rating[i];
		}
		else
		{
			sumB += rating[i];
		}
	}

	return FloatAbs(sumA - sumB);
}

float SplitSecondaryCost(int mask, const float rating[MAXPLAYERS + 1],
	const int players[MAXPLAYERS + 1], int count)
{
	float topA = 0.0, topB = 0.0, lowA = 0.0, lowB = 0.0;
	float survA = 0.0, survB = 0.0, infA = 0.0, infB = 0.0;
	bool firstA = true, firstB = true;

	for (int i = 0; i < count; i++)
	{
		float r = rating[i];
		int c = players[i];

		if (mask & (1 << i))
		{
			if (firstA || r > topA) { topA = r; }
			if (firstA || r < lowA) { lowA = r; }
			firstA = false;
			survA += GetSideMixRating(c, TEAM_SURVIVOR);
			infA += GetSideMixRating(c, TEAM_INFECTED);
		}
		else
		{
			if (firstB || r > topB) { topB = r; }
			if (firstB || r < lowB) { lowB = r; }
			firstB = false;
			survB += GetSideMixRating(c, TEAM_SURVIVOR);
			infB += GetSideMixRating(c, TEAM_INFECTED);
		}
	}

	return FloatAbs(topA - topB)
		+ 0.6 * FloatAbs((topA - lowA) - (topB - lowB))
		+ 0.6 * FloatAbs(survA - survB)
		+ 0.6 * FloatAbs(infA - infB);
}

// Mixing mid-round dumps everyone to spectator and ruins the round, so it is
// only offered while the server is sitting in ready-up.
bool IsMixAllowedNow()
{
	if (!g_bReadyUpAvailable)
	{
		return true;
	}

	return IsInReady();
}

void PrintTeamKsrSummary(int client)
{
	float sumSurv = 0.0;
	float sumInf = 0.0;
	int survCount = 0;
	int infCount = 0;

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

	if (survCount == 0 && infCount == 0)
	{
		if (client > 0)
		{
			PrintToChat(client, "\x04[KSR]\x01 No players on Survivor/Infected teams.");
		}
		else
		{
			PrintToChatAll("\x04[KSR]\x01 No players on Survivor/Infected teams.");
		}
		return;
	}

	float avgSurv = (survCount > 0) ? sumSurv / float(survCount) : 0.0;
	float avgInf = (infCount > 0) ? sumInf / float(infCount) : 0.0;

	char survLine[192];
	char infLine[192];
	Format(survLine, sizeof(survLine),
		"\x04[KSR]\x01 \x04Survivors\x01 (\x05%dx\x01): sum \x05%.0f\x01 | avg \x05%.0f\x01",
		survCount, sumSurv, avgSurv);
	Format(infLine, sizeof(infLine),
		"\x04[KSR]\x01 \x08Infected\x01 (\x05%dx\x01): sum \x05%.0f\x01 | avg \x05%.0f\x01",
		infCount, sumInf, avgInf);

	if (client > 0)
	{
		PrintToChat(client, "%s", survLine);
		PrintToChat(client, "%s", infLine);
	}
	else
	{
		PrintToChatAll("%s", survLine);
		PrintToChatAll("%s", infLine);
	}

	if (survCount > 0 && infCount > 0)
	{
		char balanceLine[192];
		BuildBalanceLine(avgSurv, avgInf, balanceLine, sizeof(balanceLine));
		if (client > 0)
		{
			PrintToChat(client, "%s", balanceLine);
		}
		else
		{
			PrintToChatAll("%s", balanceLine);
		}
	}
}

// Elo-style expectation off the team averages, so the gap is expressed as
// something people can argue about rather than an abstract point difference.
void BuildBalanceLine(float avgSurv, float avgInf, char[] buffer, int size)
{
	float delta = avgSurv - avgInf;
	float expSurv = 100.0 / (1.0 + Pow(10.0, -delta / 400.0));

	char gap[16];
	FloatToStringAbs(delta, gap, sizeof(gap));

	Format(buffer, size,
		"\x04[KSR]\x01 Gap \x05%s\x01 | expected \x04%.0f%%\x01 / \x08%.0f%%\x01",
		gap, expSurv, 100.0 - expSurv);
}

void FloatToStringAbs(float value, char[] buffer, int size)
{
	float v = (value < 0.0) ? -value : value;
	Format(buffer, size, "%.0f", v);
}

void SortByRatingDesc(int players[MAXPLAYERS + 1], float rating[MAXPLAYERS + 1], int count)
{
	for (int i = 0; i < count; i++)
	{
		for (int j = i + 1; j < count; j++)
		{
			if (rating[j] > rating[i])
			{
				int tmpPlayer = players[i];
				players[i] = players[j];
				players[j] = tmpPlayer;

				float tmpRating = rating[i];
				rating[i] = rating[j];
				rating[j] = tmpRating;
			}
		}
	}
}

int FindOnlineClientBySteamId(const char[] steamid)
{
	char current[32];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidHuman(i))
		{
			continue;
		}
		if (!GetPlayerSteamId(i, current, sizeof(current)))
		{
			continue;
		}
		if (StrEqual(current, steamid, false))
		{
			return i;
		}
	}
	return 0;
}

int CollectEligibleVoters(int voters[MAXPLAYERS + 1], int &survCount, int &infCount)
{
	int count = 0;
	survCount = 0;
	infCount = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidHuman(i))
		{
			continue;
		}

		int team = GetClientTeam(i);
		if (team == TEAM_SURVIVOR || team == TEAM_INFECTED)
		{
			voters[count++] = i;
			if (team == TEAM_SURVIVOR)
			{
				survCount++;
			}
			else
			{
				infCount++;
			}
		}
	}

	return count;
}

bool IsValidMixSetup(int survCount, int infCount)
{
	if (survCount != infCount)
	{
		return false;
	}

	if (survCount < MIX_MIN_TEAM_SIZE || survCount > MIX_MAX_TEAM_SIZE)
	{
		return false;
	}

	return true;
}

bool MoveHumanToTeam(int client, int team)
{
	if (!IsValidHuman(client))
	{
		return false;
	}

	if (GetClientTeam(client) == team)
	{
		return true;
	}

	if (team != TEAM_SURVIVOR)
	{
		ChangeClientTeam(client, team);
		return true;
	}

	int bot = FindSurvivorBot();
	if (bot > 0)
	{
		TakeSurvivorBot(client);
		return true;
	}

	// No free bot yet - the game may still be spawning them. Retry shortly instead
	// of dropping the player on spectator.
	ChangeClientTeam(client, TEAM_SURVIVOR);
	CreateTimer(0.5, Timer_RetrySurvivorTakeover, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	return true;
}

void TakeSurvivorBot(int client)
{
	int flags = GetCommandFlags("sb_takecontrol");
	SetCommandFlags("sb_takecontrol", flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "sb_takecontrol");
	SetCommandFlags("sb_takecontrol", flags);
}

public Action Timer_RetrySurvivorTakeover(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsValidHuman(client) || GetClientTeam(client) == TEAM_SURVIVOR)
	{
		return Plugin_Stop;
	}

	if (FindSurvivorBot() > 0)
	{
		TakeSurvivorBot(client);
	}

	return Plugin_Stop;
}

int FindSurvivorBot()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR)
		{
			return i;
		}
	}
	return -1;
}
