#if defined __ksr_state_included
	#endinput
#endif
#define __ksr_state_included

void ResetRatingCache(int client)
{
	g_fRating[client] = 0.0;
	g_iRatingRounds[client] = 0;
	g_fLastRoundZ[client] = 0.0;
	g_bProfileLoaded[client] = false;
	g_bBdReady[client] = false;

	for (int t = TEAM_SURVIVOR; t <= TEAM_INFECTED; t++)
	{
		g_fRatingSide[t][client] = 0.0;
		g_iRatingSideRounds[t][client] = 0;
	}
}

void ResetRoundStats(int client)
{
	if (client < 1 || client > MaxClients)
	{
		return;
	}

	g_iDamageAsInfected[client] = 0;
	g_iDamageAsSurvivor[client] = 0;
	g_iCommonDamageAsSurvivor[client] = 0;
	g_iWitchKills[client] = 0;
	g_bPinActive[client] = false;
	g_iTankDamageAsSurvivor[client] = 0;
	g_iWitchDamageAsSurvivor[client] = 0;
	g_iCommonKillsAsSurvivor[client] = 0;

	g_iSpecialClears[client] = 0;
	g_iSmokerSelfClears[client] = 0;
	g_iSkeets[client] = 0;
	g_iSkeetsMelee[client] = 0;
	g_iDeadstops[client] = 0;
	g_iBoomerPopsNoVomit[client] = 0;
	g_iBoomerPopsSplash[client] = 0;
	g_iPinAssists[client] = 0;
	g_fPinDpsAssists[client] = 0.0;
	g_iBigHitAssists[client] = 0;
	g_iChargerMulti[client] = 0;
	g_iChargeImpactCount[client] = 0;
	g_fChargeImpactStart[client] = 0.0;
	g_iSpitMultiHits[client] = 0;
	g_fSpitHitWindowStart[client] = 0.0;
	g_iSpitHitWindowCount[client] = 0;
	g_iSpitHitWindowLastVictim[client] = 0;
	g_iSpitPinnedTicks[client] = 0;
	g_iSpitIncapTicks[client] = 0;
	g_iTankBoomAssists[client] = 0;
	g_iWitchAssists[client] = 0;
	g_iRevives[client] = 0;
	g_iMedkitGives[client] = 0;
	g_iRescuesFromSpecial[client] = 0;
	g_iJockeyBlocks[client] = 0;
	g_iTankPlayActions[client] = 0;
	g_iFriendlyFireDealt[client] = 0;
	g_iFriendlyFireTaken[client] = 0;
	g_iHeadshotSI[client] = 0;
	g_iBoomerVomitCasts[client] = 0;
	g_iBoomerVomitHits[client] = 0;
	g_iShoveSI[client] = 0;
	g_iWitchCrowns[client] = 0;
	g_iRockSkeets[client] = 0;
	g_iChainClearBoom[client] = 0;
	g_iSafeSaves[client] = 0;
	g_iZeroFFBonus[client] = 0;
	g_iSharedFocus[client] = 0;
	g_iBoomFocusAssist[client] = 0;
	g_iStaggerSetup[client] = 0;
	g_iChainControlAssist[client] = 0;
	g_iTankSupportAssist[client] = 0;
	g_iAlarmTriggers[client] = 0;
	g_fTankHoldTime[client] = 0.0;
	g_iTankPasses[client] = 0;
	g_iTankKills[client] = 0;
	g_iTankWipeBonus[client] = 0;
	g_iChargerLevels[client] = 0;
	g_iTongueCuts[client] = 0;
	g_iSpecialShoveSaves[client] = 0;
	g_iRockEatenPenalty[client] = 0;
	g_iReviveInterrupts[client] = 0;
	g_iDeathCharges[client] = 0;
	g_iHunterPounceDamage[client] = 0;
	g_iJockeyHighPounces[client] = 0;
	g_iDamageAsTank[client] = 0;
	g_iSiDamageUpright[client] = 0;
	g_iDamageOnIncapped[client] = 0;
	g_iTankDamageUpright[client] = 0;
	g_iTankLives[client] = 0;
	g_fTankDmgRel[client] = 0.0;
	g_fKillFlowDenied[client] = 0.0;
	g_iIncapsTaken[client] = 0;
	g_iEndStanding[client] = 0;
	g_iEndPermHp[client] = 0;
	g_iEndTempHp[client] = 0;
	g_iEndMedkit[client] = 0;
	g_iEndPills[client] = 0;
	g_iInfIncaps[client] = 0;
	g_iInfKills[client] = 0;
	g_iPinsLanded[client] = 0;
	g_iGotSkeeted[client] = 0;
	g_iGotDeadstopped[client] = 0;
	g_iGotPopped[client] = 0;
	g_iGotLeveled[client] = 0;
	g_iGotTongueCut[client] = 0;
	for (int zc = 0; zc <= ZC_CHARGER; zc++)
	{
		g_iClassDamage[zc][client] = 0;
		g_iClassSpawns[zc][client] = 0;
	}
	g_iReviveTargetForReviver[client] = 0;
	g_fReviveStartTime[client] = 0.0;
	g_iLastBoomerKiller[client] = 0;
	g_fLastBoomerDeathTime[client] = 0.0;
	g_iLastPinner[client] = 0;
	g_iLastPinnerClass[client] = 0;
	g_fLastPinStart[client] = 0.0;
	g_fLastPinEnd[client] = 0.0;
	g_iLastBoomerForVictim[client] = 0;
	g_fLastBoomTime[client] = 0.0;
	g_iLastSpitterForVictim[client] = 0;
	g_fLastSpitTime[client] = 0.0;
	g_iLastAttackerForVictim[client] = 0;
	g_fLastAttackTime[client] = 0.0;
	g_iLastStaggerer[client] = 0;
	g_fLastStaggerTime[client] = 0.0;
	g_fSurvivalTime[client] = 0.0;
	g_fFlowBest[client] = 0.0;
	g_bAliveAtEnd[client] = true;
	g_fLifeStart[client] = GetEngineTime();
	g_bIncapped[client] = false;

	g_bHealStartedToOther[client] = false;
}
