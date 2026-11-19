#if defined __ksr_profiles_included
	#endinput
#endif
#define __ksr_profiles_included

void LoadPlayerProfile(int client)
{
	if (!IsValidHuman(client))
	{
		return;
	}

	char steamid[32];
	if (!GetPlayerSteamId(client, steamid, sizeof(steamid)))
	{
		return;
	}

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	strcopy(g_sLastName[client], sizeof(g_sLastName[]), name);
	if (g_sFirstName[client][0] == '\0')
	{
		strcopy(g_sFirstName[client], sizeof(g_sFirstName[]), name);
	}

	char escName[MAX_NAME_LENGTH * 2 + 1];
	g_Db.Escape(name, escName, sizeof(escName));

	char qInsert[512];
	Format(qInsert, sizeof(qInsert),
		"INSERT OR IGNORE INTO players (steamid, name, first_name, last_name, total_points, rounds_played, last_seen) "
		... "VALUES ('%s', '%s', '%s', '%s', 0.0, 0, strftime('%%s', 'now'));",
		steamid, escName, escName, escName);
	g_Db.Query(SQL_ErrorOnly, qInsert);

	char qTouch[512];
	Format(qTouch, sizeof(qTouch),
		"UPDATE players SET "
		... "name='%s', "
		... "last_name='%s', "
		... "first_name=CASE WHEN first_name='' THEN '%s' ELSE first_name END, "
		... "last_seen=strftime('%%s', 'now') "
		... "WHERE steamid='%s';",
		escName, escName, escName, steamid);
	g_Db.Query(SQL_ErrorOnly, qTouch);

	char qLoad[256];
	Format(qLoad, sizeof(qLoad),
		"SELECT total_points, rounds_played, first_name, last_name, rating, rating_rounds, "
		... "rating_surv, rating_surv_rounds, rating_inf, rating_inf_rounds "
		... "FROM players WHERE steamid='%s';", steamid);
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	g_Db.Query(SQL_LoadPlayerProfile, qLoad, pack);
}

public void SQL_LoadPlayerProfile(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	delete pack;

	if (!IsValidClient(client))
	{
		return;
	}

	if (results == null)
	{
		LogError("[SkillRating] Profile load failed for client %d: %s", client, error);
		return;
	}

	if (!results.FetchRow())
	{
		// No row yet: the INSERT OR IGNORE above created a blank one, so a zero
		// rating is the truth here rather than a missing read.
		g_bProfileLoaded[client] = true;
		return;
	}

	g_fTotalPoints[client] = results.FetchFloat(0);
	g_iRoundsPlayed[client] = results.FetchInt(1);
	results.FetchString(2, g_sFirstName[client], sizeof(g_sFirstName[]));
	results.FetchString(3, g_sLastName[client], sizeof(g_sLastName[]));
	g_fRating[client] = results.FetchFloat(4);
	g_iRatingRounds[client] = results.FetchInt(5);
	g_fRatingSide[TEAM_SURVIVOR][client] = results.FetchFloat(6);
	g_iRatingSideRounds[TEAM_SURVIVOR][client] = results.FetchInt(7);
	g_fRatingSide[TEAM_INFECTED][client] = results.FetchFloat(8);
	g_iRatingSideRounds[TEAM_INFECTED][client] = results.FetchInt(9);
	g_bProfileLoaded[client] = true;

	// The rating only exists once this query returns, so the redraw triggered by
	// the connect itself would still have shown this player as an unknown 1000.
	RequestReadyFooterUpdate();

	if (g_sLastName[client][0] == '\0')
	{
		GetClientName(client, g_sLastName[client], sizeof(g_sLastName[]));
	}
	if (g_sFirstName[client][0] == '\0')
	{
		strcopy(g_sFirstName[client], sizeof(g_sFirstName[]), g_sLastName[client]);
	}
}

void SaveRoundAndUpdatePlayer(int client, int team, float rawScore, float awarded)
{
	char steamid[32];
	if (!GetPlayerSteamId(client, steamid, sizeof(steamid)))
	{
		return;
	}

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	char escName[MAX_NAME_LENGTH * 2 + 1];
	g_Db.Escape(name, escName, sizeof(escName));

	char qInsertPlayer[512];
	Format(qInsertPlayer, sizeof(qInsertPlayer),
		"INSERT OR IGNORE INTO players (steamid, name, first_name, last_name, total_points, rounds_played, last_seen) "
		... "VALUES ('%s', '%s', '%s', '%s', 0.0, 0, strftime('%%s', 'now'));",
		steamid, escName, escName, escName);
	g_Db.Query(SQL_ErrorOnly, qInsertPlayer);

	char qUpdatePlayer[1024];
	Format(qUpdatePlayer, sizeof(qUpdatePlayer),
		"UPDATE players SET name='%s', last_name='%s', total_points=total_points+%.4f, rounds_played=rounds_played+1, "
		... "rating=%.6f, rating_rounds=%d, "
		... "rating_surv=%.6f, rating_surv_rounds=%d, rating_inf=%.6f, rating_inf_rounds=%d, "
		... "last_seen=strftime('%%s', 'now'), "
		... "first_name=CASE WHEN first_name='' THEN '%s' ELSE first_name END "
		... "WHERE steamid='%s';",
		escName, escName, awarded, g_fRating[client], g_iRatingRounds[client],
		g_fRatingSide[TEAM_SURVIVOR][client], g_iRatingSideRounds[TEAM_SURVIVOR][client],
		g_fRatingSide[TEAM_INFECTED][client], g_iRatingSideRounds[TEAM_INFECTED][client],
		escName, steamid);
	g_Db.Query(SQL_ErrorOnly, qUpdatePlayer);

	char escMap[128];
	g_Db.Escape(g_sMapName, escMap, sizeof(escMap));

	char qRound[6144];
	Format(qRound, sizeof(qRound),
		"INSERT INTO round_stats (steamid, name, round_index, map_name, team, raw_points, awarded_points, "
		... "dmg_infected, dmg_survivor, dmg_tank, dmg_witch, common_kills, special_clears, self_clears, skeets, skeets_melee, deadstops, boomer_pops, boomer_pops_splash, pin_assists, pin_dps_assist, big_hit_assists, big_hit_assist_score, spit_ticks_pinned, spit_ticks_incap, tank_boom_assists, witch_assists, spit_setup_assists, boom_kill_assists, charger_multi, spit_multi_hits, shove_si, witch_crowns, rock_skeets, chain_clear_boom, safe_saves, zero_ff_bonus, shared_focus, boom_focus, stagger_setup, chain_control, tank_support, alarm_triggers, tank_hold_time, tank_passes, tank_kills, tank_wipe_bonus, charger_levels, tongue_cuts, special_shove_saves, rock_eaten_penalty, revive_interrupts, revives, medkit_gives, special_rescues, jockey_blocks, tank_play_actions, ff_dealt, ff_taken, headshot_si, boomer_vomit_casts, boomer_vomit_hits, flow_percent, survival_time, alive_end, common_damage, witch_kills, scoring_version, rating_z, death_charges, hunter_pounce_dmg, jockey_high_pounces, dmg_as_tank, inf_incaps, inf_kills, pins_landed, got_skeeted, got_deadstopped, got_popped, got_leveled, got_tongue_cut, dmg_smoker, dmg_boomer, dmg_hunter, dmg_spitter, dmg_jockey, dmg_charger, spawns_smoker, spawns_boomer, spawns_hunter, spawns_spitter, spawns_jockey, spawns_charger, dmg_si_upright, dmg_on_incapped, dmg_tank_upright, tank_lives, tank_dmg_rel, kill_flow_denied, incaps_taken, end_standing, end_perm_hp, end_temp_hp, end_medkit, end_pills, half_index, half_max_score, half_bonus, half_tank_passes, half_tank_kills, half_witch_bonus, ts) "
		... "VALUES ('%s', '%s', %d, '%s', %d, %.4f, %.4f, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %.2f, %d, %.2f, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %.2f, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %.2f, %.2f, %d, %d, %d, %d, %.4f, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %.2f, %.2f, %d, %d, %d, %d, %d, %d, %d, %d, %.2f, %d, %d, %d, strftime('%%s', 'now'));",
		steamid, escName, g_iRoundNumber, escMap, team, rawScore, awarded,
		g_iDamageAsInfected[client],
		g_iDamageAsSurvivor[client],
		g_iTankDamageAsSurvivor[client],
		g_iWitchDamageAsSurvivor[client],
		g_iCommonKillsAsSurvivor[client],
		g_iSpecialClears[client],
		g_iSmokerSelfClears[client],
		g_iSkeets[client],
		g_iSkeetsMelee[client],
		g_iDeadstops[client],
		g_iBoomerPopsNoVomit[client],
		g_iBoomerPopsSplash[client],
		g_iPinAssists[client],
		g_fPinDpsAssists[client],
		g_iBigHitAssists[client],
		g_fBigHitAssistScore[client],
		g_iSpitPinnedTicks[client],
		g_iSpitIncapTicks[client],
		g_iTankBoomAssists[client],
		g_iWitchAssists[client],
		g_iSpitSetupAssists[client],
		g_iBoomKillAssists[client],
		g_iChargerMulti[client],
		g_iSpitMultiHits[client],
		g_iShoveSI[client],
		g_iWitchCrowns[client],
		g_iRockSkeets[client],
		g_iChainClearBoom[client],
		g_iSafeSaves[client],
		g_iZeroFFBonus[client],
		g_iSharedFocus[client],
		g_iBoomFocusAssist[client],
		g_iStaggerSetup[client],
		g_iChainControlAssist[client],
		g_iTankSupportAssist[client],
		g_iAlarmTriggers[client],
		g_fTankHoldTime[client],
		g_iTankPasses[client],
		g_iTankKills[client],
		g_iTankWipeBonus[client],
		g_iChargerLevels[client],
		g_iTongueCuts[client],
		g_iSpecialShoveSaves[client],
		g_iRockEatenPenalty[client],
		g_iReviveInterrupts[client],
	g_iRevives[client],
	g_iMedkitGives[client],
	g_iRescuesFromSpecial[client],
	g_iJockeyBlocks[client],
	g_iTankPlayActions[client],
	g_iFriendlyFireDealt[client],
	g_iFriendlyFireTaken[client],
	g_iHeadshotSI[client],
	g_iBoomerVomitCasts[client],
	g_iBoomerVomitHits[client],
	g_fFlowBest[client],
	g_fSurvivalTime[client],
	g_bAliveAtEnd[client] ? 1 : 0,
	g_iCommonDamageAsSurvivor[client],
	g_iWitchKills[client],
	KSR_SCORING_VERSION,
	g_fLastRoundZ[client],
	g_iDeathCharges[client],
	g_iHunterPounceDamage[client],
	g_iJockeyHighPounces[client],
	g_iDamageAsTank[client],
	g_iInfIncaps[client],
	g_iInfKills[client],
	g_iPinsLanded[client],
	g_iGotSkeeted[client],
	g_iGotDeadstopped[client],
	g_iGotPopped[client],
	g_iGotLeveled[client],
	g_iGotTongueCut[client],
	g_iClassDamage[ZC_SMOKER][client],
	g_iClassDamage[ZC_BOOMER][client],
	g_iClassDamage[ZC_HUNTER][client],
	g_iClassDamage[ZC_SPITTER][client],
	g_iClassDamage[ZC_JOCKEY][client],
	g_iClassDamage[ZC_CHARGER][client],
	g_iClassSpawns[ZC_SMOKER][client],
	g_iClassSpawns[ZC_BOOMER][client],
	g_iClassSpawns[ZC_HUNTER][client],
	g_iClassSpawns[ZC_SPITTER][client],
	g_iClassSpawns[ZC_JOCKEY][client],
	g_iClassSpawns[ZC_CHARGER][client],
	g_iSiDamageUpright[client],
	g_iDamageOnIncapped[client],
	g_iTankDamageUpright[client],
	g_iTankLives[client],
	g_fTankDmgRel[client],
	g_fKillFlowDenied[client],
	g_iIncapsTaken[client],
	g_iEndStanding[client],
	g_iEndPermHp[client],
	g_iEndTempHp[client],
	g_iEndMedkit[client],
	g_iEndPills[client],
	g_iHalfIndex,
	g_iHalfMaxScore,
	g_fHalfBonus,
	g_iHalfTankPasses,
	g_iHalfTankKills,
	g_iHalfWitchBonus);
	g_Db.Query(SQL_ErrorOnly, qRound);

	g_fTotalPoints[client] += awarded;
	g_iRoundsPlayed[client]++;
}
