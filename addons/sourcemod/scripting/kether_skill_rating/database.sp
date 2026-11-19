#if defined __ksr_database_included
	#endinput
#endif
#define __ksr_database_included

public void SQL_LoadTankBaseline(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("[SkillRating] Tank baseline load failed: %s", error);
		return;
	}

	if (results.FetchRow() && !results.IsFieldNull(0))
	{
		float value = results.FetchFloat(0);
		if (value > 0.0)
		{
			g_fTankBaseLife = value;
			g_iTankBaseCount = results.IsFieldNull(1) ? 0 : results.FetchInt(1);
		}
	}
}

void SeedBaselines()
{
	g_fTankBaseLife = g_CvarSeedTankDmgLife.FloatValue;
	g_iTankBaseCount = 0;

	g_fBaseMean[TEAM_SURVIVOR] = g_CvarSeedSurvMean.FloatValue;
	g_fBaseSd[TEAM_SURVIVOR] = g_CvarSeedSurvSd.FloatValue;
	g_fBaseMean[TEAM_INFECTED] = g_CvarSeedInfMean.FloatValue;
	g_fBaseSd[TEAM_INFECTED] = g_CvarSeedInfSd.FloatValue;
	g_iBaseCount[TEAM_SURVIVOR] = 0;
	g_iBaseCount[TEAM_INFECTED] = 0;
}

void LoadBaselines()
{
	g_Db.Query(SQL_LoadTankBaseline,
		"SELECT (SELECT value FROM meta WHERE key='tank_dmg_life'), (SELECT value FROM meta WHERE key='tank_dmg_life_n');");

	g_Db.Query(SQL_LoadBaselines,
		"SELECT team, mean, sd, samples, (SELECT value FROM meta WHERE key='baseline_scoring_version') FROM baselines;");
}

public void SQL_LoadBaselines(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("[SkillRating] Baseline load failed: %s", error);
		return;
	}

	while (results.FetchRow())
	{
		int team = results.FetchInt(0);
		if (team != TEAM_SURVIVOR && team != TEAM_INFECTED)
		{
			continue;
		}

		if (results.IsFieldNull(4) || results.FetchInt(4) != KSR_SCORING_VERSION)
		{
			PrintToServer("[SkillRating] Stored baselines belong to another scoring version - starting from the seed values. Run tools/ksr_recompute.py to replay the history under the current weights.");
			return;
		}

		float mean = results.FetchFloat(1);
		float sd = results.FetchFloat(2);
		if (sd < 1.0)
		{
			continue;
		}

		g_fBaseMean[team] = mean;
		g_fBaseSd[team] = sd;
		g_iBaseCount[team] = results.FetchInt(3);
	}
}

void SaveBaselines()
{
	char query[512];
	for (int t = TEAM_SURVIVOR; t <= TEAM_INFECTED; t++)
	{
		Format(query, sizeof(query),
			"INSERT OR REPLACE INTO baselines (team, mean, sd, samples) VALUES (%d, %.4f, %.4f, %d);",
			t, g_fBaseMean[t], g_fBaseSd[t], g_iBaseCount[t]);
		g_Db.Query(SQL_ErrorOnly, query);
	}

	Format(query, sizeof(query),
		"INSERT OR REPLACE INTO meta (key, value) VALUES ('baseline_scoring_version', '%d');", KSR_SCORING_VERSION);
	g_Db.Query(SQL_ErrorOnly, query);

	Format(query, sizeof(query),
		"INSERT OR REPLACE INTO meta (key, value) VALUES ('tank_dmg_life', '%.4f'), ('tank_dmg_life_n', '%d');",
		g_fTankBaseLife, g_iTankBaseCount);
	g_Db.Query(SQL_ErrorOnly, query);
}

void EnsureColumn(const char[] table, const char[] column, const char[] definition)
{
	char query[256];
	Format(query, sizeof(query), "PRAGMA table_info(%s);", table);

	DataPack pack = new DataPack();
	pack.WriteString(table);
	pack.WriteString(column);
	pack.WriteString(definition);
	g_Db.Query(SQL_CheckColumn, query, pack);
}

public void SQL_CheckColumn(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	char table[64];
	char column[64];
	char definition[128];

	pack.Reset();
	pack.ReadString(table, sizeof(table));
	pack.ReadString(column, sizeof(column));
	pack.ReadString(definition, sizeof(definition));
	delete pack;

	if (results == null)
	{
		LogError("[SkillRating] PRAGMA table_info failed: %s", error);
		return;
	}

	bool found = false;
	while (results.FetchRow())
	{
		char colName[64];
		results.FetchString(1, colName, sizeof(colName));
		if (StrEqual(colName, column, false))
		{
			found = true;
			break;
		}
	}

	if (!found)
	{
		char alter[256];
		Format(alter, sizeof(alter), "ALTER TABLE %s ADD COLUMN %s %s;", table, column, definition);
		g_Db.Query(SQL_ErrorOnly, alter);
	}
}

public void SQL_ErrorOnly(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("[SkillRating] SQL error: %s", error);
	}
}
