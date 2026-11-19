#if defined __ksr_scoring_included
	#endinput
#endif
#define __ksr_scoring_included

void FinalizeRoundIfNeeded()
{
	if (!g_CvarEnabled.BoolValue || !g_bRoundActive || g_bRoundFinalized)
	{
		return;
	}

	g_bRoundFinalized = true;
	g_bRoundActive = false;

	delete g_hFlowTimer;

	if (!IsRoundEligibleForStats())
	{
		PrintToServer("[SkillRating] Round skipped: needs at least 3v3 humans at go-live.");
		return;
	}

	int survAlive = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidHuman(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i))
		{
			survAlive++;
		}
	}

	if (g_iCurrentTank > 0)
	{
		EndTankHoldSegment(g_iCurrentTank);
	}

	// The wipe bonus goes to the last human tank of the round even if he died to
	// the final survivor; the old check needed him to still be the "current" tank,
	// which is why it never once fired in six months of data.
	if (survAlive == 0 && g_iLastHumanTank > 0 && IsValidHuman(g_iLastHumanTank)
		&& GetClientTeam(g_iLastHumanTank) == TEAM_INFECTED && g_fTankHoldTime[g_iLastHumanTank] > 0.0)
	{
		g_iTankWipeBonus[g_iLastHumanTank]++;
	}

	CaptureHalfResult();

	// Tank damage against the average tank, using the reference as it stood before
	// this half - nobody is measured against a baseline his own round moved.
	for (int i = 1; i <= MaxClients; i++)
	{
		g_fTankDmgRel[i] = float(g_iTankDamageUpright[i]) - g_fTankBaseLife * float(g_iTankLives[i]);
	}

	float rawScore[MAXPLAYERS + 1];
	float teamRawSum[4];
	int teamCount[4];

	for (int t = 0; t < 4; t++)
	{
		teamRawSum[t] = 0.0;
		teamCount[t] = 0;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		rawScore[i] = 0.0;

		if (!IsValidHuman(i) || !g_bWasLive[i] || !g_bProfileLoaded[i])
		{
			continue;
		}

		int team = GetClientTeam(i);
		if (team != TEAM_SURVIVOR && team != TEAM_INFECTED)
		{
			continue;
		}

		if (team == TEAM_SURVIVOR && g_bAliveAtEnd[i] && g_bRoundLive && !g_bPaused)
		{
			g_fSurvivalTime[i] += GetEngineTime() - g_fLifeStart[i];
		}

		UpdateZeroFFBonus(i, team);

		rawScore[i] = ComputeRawRoundScore(i, team);
		teamRawSum[team] += rawScore[i];
		teamCount[team]++;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidHuman(i) || !g_bWasLive[i] || !g_bProfileLoaded[i])
		{
			continue;
		}

		int team = GetClientTeam(i);
		if (team != TEAM_SURVIVOR && team != TEAM_INFECTED)
		{
			continue;
		}

		// Legacy pool share. Kept only so the historical column stays populated and
		// comparable; nothing in the ranking reads it any more. The median damping
		// and the roster multiplier are gone - both of them only squashed the top.
		float awarded = 0.0;
		if (teamCount[team] > 0)
		{
			if (teamRawSum[team] > 0.0001)
			{
				awarded = g_CvarRoundPool.FloatValue * (rawScore[i] / teamRawSum[team]);
			}
			else
			{
				awarded = g_CvarRoundPool.FloatValue / float(teamCount[team]);
			}
		}

		float teamMean = (teamCount[team] > 0) ? (teamRawSum[team] / float(teamCount[team])) : rawScore[i];
		ApplyRoundRating(i, team, rawScore[i], teamMean);
		SaveRoundAndUpdatePlayer(i, team, rawScore[i], awarded);
	}

	// Baselines are updated only after every player has been scored, so nobody is
	// measured against a reference this same round already moved.
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidHuman(i) || !g_bWasLive[i] || !g_bProfileLoaded[i])
		{
			continue;
		}

		int team = GetClientTeam(i);
		if (team == TEAM_SURVIVOR || team == TEAM_INFECTED)
		{
			UpdateBaseline(team, rawScore[i]);
		}
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidHuman(i) || !g_bWasLive[i] || g_iTankLives[i] <= 0)
		{
			continue;
		}
		float perLife = float(g_iTankDamageUpright[i]) / float(g_iTankLives[i]);
		for (int life = 0; life < g_iTankLives[i]; life++)
		{
			g_fTankBaseLife += KSR_TANK_BASE_EMA * (perLife - g_fTankBaseLife);
			g_iTankBaseCount++;
		}
	}

	SaveBaselines();

	g_bRoundLive = false;
	g_bPaused = false;
}

void UpdateZeroFFBonus(int client, int team)
{
	g_iZeroFFBonus[client] = 0;

	if (team != TEAM_SURVIVOR || g_iFriendlyFireDealt[client] != 0)
	{
		return;
	}

	int actionCount = g_iSpecialClears[client] + g_iSmokerSelfClears[client] + g_iSkeets[client]
		+ g_iDeadstops[client] + g_iBoomerPopsNoVomit[client] + g_iRevives[client]
		+ g_iMedkitGives[client] + g_iRescuesFromSpecial[client] + g_iJockeyBlocks[client]
		+ g_iTankPlayActions[client] + g_iChainClearBoom[client] + g_iSafeSaves[client];

	if (actionCount >= 5)
	{
		g_iZeroFFBonus[client] = 1;
	}
}

// Converts a raw round score into a z-score, then folds it into the player's
// rating with an EMA.
//
// The z is a blend of two views of the same round:
//
//   absolute - against the rolling server baseline. Comparable between teams,
//              which is what makes the numbers addable for a mix, but it moves
//              with the round result: when a team gets wiped early, everyone on
//              it scores badly, including whoever played well.
//   carry    - against the player's own team in that round. Immune to the result
//              by construction: standing out from your team is exactly what
//              carrying a losing round looks like.
//
// Measured over the whole database, blending the two halves cuts how much a
// player's score is really his team's score from 0.73 to 0.28, leaves ranking
// stability untouched at 0.94, and slightly improves how well the rating predicts
// round outcomes. Pure carry would score better still on coupling, but a purely
// team-relative number averages to zero on every team and stops being comparable
// between them, which would break the mix.
void ApplyRoundRating(int client, int team, float raw, float teamMean)
{
	float sd = g_fBaseSd[team];
	if (sd < 1.0)
	{
		sd = 1.0;
	}

	float carry = g_CvarCarryWeight.FloatValue;
	float zAbsolute = (raw - g_fBaseMean[team]) / sd;
	float zCarry = (raw - teamMean) / sd;

	float z = FloatClamp((1.0 - carry) * zAbsolute + carry * zCarry, -KSR_Z_CLAMP, KSR_Z_CLAMP);

	// Running average while history is thin, EMA once there is enough of it: new
	// players converge fast, veterans keep a rolling window instead of a lifetime
	// mean that no amount of recent form can move.
	float k = 1.0 / float(g_iRatingRounds[client] + 1);
	float kMin = g_CvarRatingEmaMin.FloatValue;
	if (k < kMin)
	{
		k = kMin;
	}

	g_fRating[client] += k * (z - g_fRating[client]);
	g_iRatingRounds[client]++;
	g_fLastRoundZ[client] = z;

	float ks = 1.0 / float(g_iRatingSideRounds[team][client] + 1);
	if (ks < kMin)
	{
		ks = kMin;
	}
	g_fRatingSide[team][client] += ks * (z - g_fRatingSide[team][client]);
	g_iRatingSideRounds[team][client]++;
}

float GetSideKSR(int client, int team)
{
	return RatingToKSR(g_fRatingSide[team][client], g_iRatingSideRounds[team][client]);
}

// Rolling mean and spread of a single player's round score on one side. This is
// the reference the z-score is taken against, so it has to describe individual
// rounds - not team averages, which are a much narrower distribution.
void UpdateBaseline(int team, float raw)
{
	if (team != TEAM_SURVIVOR && team != TEAM_INFECTED)
	{
		return;
	}

	float k = g_CvarBaselineEma.FloatValue;
	float delta = raw - g_fBaseMean[team];

	g_fBaseMean[team] += k * delta;

	float variance = g_fBaseSd[team] * g_fBaseSd[team];
	variance += k * ((delta * delta) - variance);
	if (variance < 1.0)
	{
		variance = 1.0;
	}

	g_fBaseSd[team] = SquareRoot(variance);
	g_iBaseCount[team]++;
}

float ComputeRawRoundScore(int client, int team)
{
	float score = 0.0;

	if (team == TEAM_INFECTED)
	{
		score += float(g_iSiDamageUpright[client]) * g_CvarWeightInfDamage.FloatValue;
		score += float(g_iDamageOnIncapped[client]) * g_CvarWeightInfDamageIncapped.FloatValue;
		score += g_fTankDmgRel[client] * g_CvarWeightTankDamageRel.FloatValue;
		score += float(g_iBoomerVomitHits[client]) * g_CvarWeightBoomerVomitHit.FloatValue;
		score += float(g_iBoomerVomitCasts[client]) * g_CvarWeightBoomerVomitCast.FloatValue;
		score += g_fPinDpsAssists[client] * g_CvarWeightPinDpsAssist.FloatValue;
		score += float(g_iPinAssists[client]) * g_CvarWeightPinAssist.FloatValue;
		score += g_fBigHitAssistScore[client] * g_CvarWeightBigHitAssistScore.FloatValue;
		score += float(g_iSpitPinnedTicks[client]) * g_CvarWeightSpitPinnedTick.FloatValue;
		score += float(g_iSpitIncapTicks[client]) * g_CvarWeightSpitIncapTick.FloatValue;
		score += float(g_iTankBoomAssists[client]) * g_CvarWeightTankBoomAssist.FloatValue;
		score += float(g_iWitchAssists[client]) * g_CvarWeightWitchAssist.FloatValue;
		score += float(g_iSpitSetupAssists[client]) * g_CvarWeightSpitSetupAssist.FloatValue;
		score += float(g_iBoomKillAssists[client]) * g_CvarWeightBoomKillAssist.FloatValue;
		score += float(g_iChargerMulti[client]) * g_CvarWeightChargerMulti.FloatValue;
		score += float(g_iSpitMultiHits[client]) * g_CvarWeightSpitMulti.FloatValue;
		score += float(g_iSharedFocus[client]) * g_CvarWeightSharedFocus.FloatValue;
		score += float(g_iBoomFocusAssist[client]) * g_CvarWeightBoomFocus.FloatValue;
		score += float(g_iStaggerSetup[client]) * g_CvarWeightStaggerSetup.FloatValue;
		score += float(g_iChainControlAssist[client]) * g_CvarWeightChainControl.FloatValue;
		score += float(g_iTankSupportAssist[client]) * g_CvarWeightTankSupport.FloatValue;
		score += g_fTankHoldTime[client] * g_CvarWeightTankHoldSec.FloatValue;
		score += float(g_iTankKills[client]) * g_CvarWeightTankKill.FloatValue;
		score += float(g_iTankPasses[client]) * g_CvarWeightTankPassPenalty.FloatValue;
		score += float(g_iTankWipeBonus[client]) * g_CvarWeightTankWipe.FloatValue;
		score += float(g_iReviveInterrupts[client]) * g_CvarWeightReviveInterrupt.FloatValue;
		score += float(g_iDeathCharges[client]) * g_CvarWeightDeathCharge.FloatValue;
		score += float(g_iHunterPounceDamage[client]) * g_CvarWeightHunterPounceDmg.FloatValue;
		score += float(g_iJockeyHighPounces[client]) * g_CvarWeightJockeyHighPounce.FloatValue;
		return score;
	}

	score += float(g_iDamageAsSurvivor[client]) * g_CvarWeightSurvDamage.FloatValue;
	score += float(g_iTankDamageAsSurvivor[client]) * g_CvarWeightTankDamage.FloatValue;
	score += float(g_iWitchDamageAsSurvivor[client]) * g_CvarWeightWitchDamage.FloatValue;
	score += float(g_iCommonDamageAsSurvivor[client]) * g_CvarWeightCommonDamage.FloatValue;
	score += float(g_iCommonKillsAsSurvivor[client]) * g_CvarWeightCommonKills.FloatValue;
	score += float(g_iSpecialClears[client]) * g_CvarWeightSpecialClear.FloatValue;
	score += float(g_iSmokerSelfClears[client]) * g_CvarWeightSelfClear.FloatValue;
	score += float(g_iSkeets[client]) * g_CvarWeightSkeet.FloatValue;
	score += float(g_iSkeetsMelee[client]) * g_CvarWeightSkeetMelee.FloatValue;
	score += float(g_iDeadstops[client]) * g_CvarWeightDeadstop.FloatValue;
	score += float(g_iBoomerPopsNoVomit[client]) * g_CvarWeightBoomerPop.FloatValue;
	score += float(g_iRevives[client]) * g_CvarWeightRevive.FloatValue;
	score += float(g_iMedkitGives[client]) * g_CvarWeightMedkitGive.FloatValue;
	score += float(g_iRescuesFromSpecial[client]) * g_CvarWeightRescue.FloatValue;
	score += float(g_iJockeyBlocks[client]) * g_CvarWeightJockeyBlock.FloatValue;
	score += float(g_iTankPlayActions[client]) * g_CvarWeightTankPlayAction.FloatValue;
	score += float(g_iFriendlyFireDealt[client]) * g_CvarWeightFriendlyFire.FloatValue;
	score += float(g_iHeadshotSI[client]) * g_CvarWeightHeadshotSI.FloatValue;
	score += g_fSurvivalTime[client] * g_CvarWeightSurvivalSec.FloatValue;
	score += g_fFlowBest[client] * g_CvarWeightFlowPercent.FloatValue;
	score += float(g_iBoomerPopsSplash[client]) * g_CvarWeightBoomerPopSplash.FloatValue;
	score += float(g_iShoveSI[client]) * g_CvarWeightShoveSI.FloatValue;
	score += float(g_iWitchCrowns[client]) * g_CvarWeightWitchCrown.FloatValue;
	score += float(g_iWitchKills[client]) * g_CvarWeightWitchKill.FloatValue;
	score += float(g_iRockSkeets[client]) * g_CvarWeightRockSkeet.FloatValue;
	score += float(g_iChainClearBoom[client]) * g_CvarWeightChainClearBoom.FloatValue;
	score += float(g_iSafeSaves[client]) * g_CvarWeightSafeSave.FloatValue;
	score += float(g_iZeroFFBonus[client]) * g_CvarWeightZeroFFBonus.FloatValue;
	score += float(g_iAlarmTriggers[client]) * g_CvarWeightAlarmPenalty.FloatValue;
	score += float(g_iChargerLevels[client]) * g_CvarWeightChargerLevel.FloatValue;
	score += float(g_iTongueCuts[client]) * g_CvarWeightTongueCut.FloatValue;
	score += float(g_iSpecialShoveSaves[client]) * g_CvarWeightSpecialShove.FloatValue;
	score += float(g_iRockEatenPenalty[client]) * g_CvarWeightRockEatenPenalty.FloatValue;

	return score;
}
