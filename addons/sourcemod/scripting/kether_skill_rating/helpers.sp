#if defined __ksr_helpers_included
	#endinput
#endif
#define __ksr_helpers_included

// Pulls a thin history towards the middle of the pool. A player with one lucky
// round sits next to the average instead of at the top of the ladder, which is
// what used to wreck mixes.
float ShrinkRating(float rating, int rounds)
{
	float k = g_CvarRatingShrinkRounds.FloatValue;
	if (k <= 0.0 || rounds <= 0)
	{
		return (rounds <= 0) ? 0.0 : rating;
	}

	return rating * (float(rounds) / (float(rounds) + k));
}

float RatingToKSR(float rating, int rounds)
{
	return KSR_BASE + g_CvarRatingScale.FloatValue * ShrinkRating(rating, rounds);
}

// Rough one-sigma uncertainty of the displayed number, so a 30 round player is
// not presented with the same authority as a 900 round one.
float GetKSRConfidence(int rounds)
{
	if (rounds <= 0)
	{
		return g_CvarRatingScale.FloatValue;
	}

	float kMin = g_CvarRatingEmaMin.FloatValue;
	float effective = float(rounds);
	float cap = (2.0 / kMin) - 1.0;
	if (effective > cap)
	{
		effective = cap;
	}

	return g_CvarRatingScale.FloatValue / SquareRoot(effective);
}

void FormatKSRValue(float rating, int rounds, char[] buffer, int size)
{
	Format(buffer, size, "%.0f", RatingToKSR(rating, rounds));
}

void FormatKSRWithConfidence(float rating, int rounds, char[] buffer, int size)
{
	Format(buffer, size, "%.0f (+/-%.0f)", RatingToKSR(rating, rounds), GetKSRConfidence(rounds));
}

// The number the mix balances on. Shrunk, so an unknown player is treated as an
// average one rather than as whatever his first round happened to look like - but
// shrunk far less than the ladder number. The ladder guards against a short lucky
// run; the mix only has to guess the next map, and pulling a 30 round player most
// of the way back to 1000 throws away what is already known about him.
float MixRatingToKSR(float rating, int rounds)
{
	if (rounds <= 0)
	{
		return KSR_BASE;
	}

	float k = g_CvarMixShrink.FloatValue;
	float shrunk = (k <= 0.0) ? rating : rating * (float(rounds) / (float(rounds) + k));
	float ksr = KSR_BASE + g_CvarRatingScale.FloatValue * shrunk;

	// Below the average the scale overstates how much a player costs his team: on
	// 634 maps a KSR point under 1000 was worth only about 55% of one above it in
	// the actual result, so mixes handed the weakest players too strong a team and
	// those teams kept winning more than predicted. Only the mix number is
	// compressed; the ladder keeps the full distance.
	if (ksr < KSR_BASE)
	{
		ksr = KSR_BASE - g_CvarMixLowCompress.FloatValue * (KSR_BASE - ksr);
	}
	return ksr;
}

float GetMixRating(int client)
{
	return MixRatingToKSR(g_fRating[client], g_iRatingRounds[client]);
}

float GetSideMixRating(int client, int team)
{
	return MixRatingToKSR(g_fRatingSide[team][client], g_iRatingSideRounds[team][client]);
}

bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client));
}

bool IsValidHuman(int client)
{
	return IsValidClient(client) && !IsFakeClient(client);
}

bool GetPlayerSteamId(int client, char[] buffer, int size)
{
	buffer[0] = '\0';
	if (!IsValidHuman(client))
	{
		return false;
	}

	// Use SteamID64 as canonical key to avoid split identities.
	if (GetClientAuthId(client, AuthId_SteamID64, buffer, size) && buffer[0] != '\0')
	{
		return true;
	}

	if (GetClientAuthId(client, AuthId_Steam2, buffer, size) && buffer[0] != '\0')
	{
		return true;
	}

	return false;
}

void TryMergeSteamIdVariantsForClient(int client)
{
	if (!IsValidHuman(client) || g_Db == null)
	{
		return;
	}

	char steam2[32];
	char steam64[32];
	bool hasSteam2 = GetClientAuthId(client, AuthId_Steam2, steam2, sizeof(steam2)) && steam2[0] != '\0';
	bool hasSteam64 = GetClientAuthId(client, AuthId_SteamID64, steam64, sizeof(steam64)) && steam64[0] != '\0';

	if (!hasSteam2 || !hasSteam64 || StrEqual(steam2, steam64, false))
	{
		return;
	}

	char query[2048];

	Format(query, sizeof(query),
		"INSERT OR IGNORE INTO players (steamid, name, first_name, last_name, total_points, rounds_played, last_seen) "
		... "VALUES ('%s', '', '', '', 0.0, 0, strftime('%%s', 'now'));",
		steam64);
	g_Db.Query(SQL_ErrorOnly, query);

	Format(query, sizeof(query),
		"UPDATE players SET "
		... "total_points = total_points + COALESCE((SELECT total_points FROM players WHERE steamid='%s'), 0.0), "
		... "rounds_played = rounds_played + COALESCE((SELECT rounds_played FROM players WHERE steamid='%s'), 0), "
		... "last_seen = MAX(last_seen, COALESCE((SELECT last_seen FROM players WHERE steamid='%s'), last_seen)), "
		... "first_name = CASE WHEN first_name='' THEN COALESCE((SELECT first_name FROM players WHERE steamid='%s' LIMIT 1), '') ELSE first_name END, "
		... "last_name = COALESCE((SELECT last_name FROM players WHERE steamid='%s' LIMIT 1), last_name), "
		... "name = last_name "
		... "WHERE steamid='%s';",
		steam2, steam2, steam2, steam2, steam2, steam64);
	g_Db.Query(SQL_ErrorOnly, query);

	Format(query, sizeof(query),
		"UPDATE round_stats SET steamid='%s' WHERE steamid='%s';",
		steam64, steam2);
	g_Db.Query(SQL_ErrorOnly, query);

	Format(query, sizeof(query),
		"DELETE FROM players WHERE steamid='%s';",
		steam2);
	g_Db.Query(SQL_ErrorOnly, query);
}

void BuildDisplayName(int client, char[] buffer, int size)
{
	buffer[0] = '\0';

	char last[MAX_NAME_LENGTH];
	char first[MAX_NAME_LENGTH];
	last[0] = '\0';
	first[0] = '\0';

	if (client > 0 && client <= MaxClients)
	{
		if (g_sLastName[client][0] != '\0')
		{
			strcopy(last, sizeof(last), g_sLastName[client]);
		}
		else
		{
			GetClientName(client, last, sizeof(last));
		}

		if (g_sFirstName[client][0] != '\0')
		{
			strcopy(first, sizeof(first), g_sFirstName[client]);
		}
	}

	if (last[0] == '\0')
	{
		strcopy(last, sizeof(last), "Unknown");
	}

	if (first[0] != '\0' && !StrEqual(first, last, false))
	{
		Format(buffer, size, "%s (%s)", last, first);
	}
	else
	{
		strcopy(buffer, size, last);
	}
}

bool IsTankInPlayActive()
{
	return L4D2_IsTankInPlay();
}

bool IsRoundEligibleForStats()
{
	// Judged on the roster captured at go-live, not on who happens to still be
	// connected when the round ends. A round that never went live scores nobody.
	if (g_bReadyUpAvailable)
	{
		return (g_iLiveSurvCount >= 3 && g_iLiveInfCount >= 3);
	}

	// No ready-up plugin: fall back to counting the current teams.
	int surv = 0;
	int inf = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidHuman(i))
		{
			continue;
		}

		int team = GetClientTeam(i);
		if (team == TEAM_SURVIVOR)
		{
			surv++;
			g_bWasLive[i] = true;
		}
		else if (team == TEAM_INFECTED)
		{
			inf++;
			g_bWasLive[i] = true;
		}
	}

	return (surv >= 3 && inf >= 3);
}

float GetFlowPercentSafe(int client)
{
	float maxFlow = L4D2Direct_GetMapMaxFlowDistance();
	if (maxFlow <= 0.0)
	{
		return g_fFlowBest[client];
	}

	float flow = L4D2Direct_GetFlowDistance(client);
	if (flow < 0.0)
	{
		flow = 0.0;
	}

	return (flow / maxFlow) * 100.0;
}
