#if defined __ksr_tracking_included
	#endinput
#endif
#define __ksr_tracking_included

int GetRecentPinner(int victim, float window, int &zclass)
{
	int pinner = g_iLastPinner[victim];
	if (pinner > 0 && IsValidHuman(pinner) && GetClientTeam(pinner) == TEAM_INFECTED)
	{
		// While the pin is still running the window must not expire, otherwise the
		// longest pins - the ones that earn the assist - stop counting.
		float ago = g_bPinActive[victim] ? 0.0 : (GetEngineTime() - g_fLastPinEnd[victim]);
		if (ago <= window)
		{
			zclass = g_iLastPinnerClass[victim];
			return pinner;
		}
	}
	zclass = 0;
	return 0;
}

void MarkPinStart(int pinner, int victim, int zclass)
{
	if (!IsValidHuman(pinner) || GetClientTeam(pinner) != TEAM_INFECTED || !IsValidClient(victim))
	{
		return;
	}
	float now = GetEngineTime();

	// A smoker pin arrives as tongue_grab and then choke_start, a charger pin as
	// carry and then pummel. Both halves land here, so the second one within a few
	// seconds on the same victim is the same pin, not a new one.
	bool samePin = (g_iLastPinner[victim] == pinner && (now - g_fLastPinStart[victim]) <= 10.0);
	if (!samePin || (zclass != ZC_SMOKER && zclass != ZC_CHARGER))
	{
		g_iPinsLanded[pinner]++;
	}

	g_iLastPinner[victim] = pinner;
	g_iLastPinnerClass[victim] = zclass;
	g_bPinActive[victim] = true;
	g_fLastPinStart[victim] = now;
	g_fLastPinEnd[victim] = now;
}

void MarkPinEnd(int victim)
{
	if (!IsValidClient(victim))
	{
		return;
	}
	g_bPinActive[victim] = false;
	g_fLastPinEnd[victim] = GetEngineTime();
}

void AddPinAssistForVictim(int victim)
{
	int zc;
	int pinner = GetRecentPinner(victim, PIN_ASSIST_WINDOW, zc);
	if (pinner > 0)
	{
		g_iPinAssists[pinner]++;
	}
}

void AddSpitMultiHit(int spitter, int victim)
{
	if (!IsValidHuman(spitter) || GetClientTeam(spitter) != TEAM_INFECTED || victim <= 0)
	{
		return;
	}

	float now = GetEngineTime();
	if (now - g_fSpitHitWindowStart[spitter] > 0.4)
	{
		g_fSpitHitWindowStart[spitter] = now;
		g_iSpitHitWindowCount[spitter] = 0;
		g_iSpitHitWindowLastVictim[spitter] = 0;
	}

	if (g_iSpitHitWindowCount[spitter] > 0 && g_iSpitHitWindowLastVictim[spitter] != victim)
	{
		g_iSpitMultiHits[spitter]++;
	}

	g_iSpitHitWindowLastVictim[spitter] = victim;
	g_iSpitHitWindowCount[spitter]++;
}

void AddTankSupportAssist(int victim)
{
	if (!IsValidClient(victim))
	{
		return;
	}
	float now = GetEngineTime();

	// Boomer setup
	if (g_iLastBoomerForVictim[victim] > 0 && (now - g_fLastBoomTime[victim]) <= 5.0)
	{
		int boomer = g_iLastBoomerForVictim[victim];
		if (IsValidHuman(boomer) && GetClientTeam(boomer) == TEAM_INFECTED)
		{
			g_iTankSupportAssist[boomer]++;
		}
	}

	// Pin setup
	int zc;
	int pinner = GetRecentPinner(victim, PIN_ASSIST_WINDOW, zc);
	if (pinner > 0 && (now - g_fLastPinEnd[victim]) <= 5.0)
	{
		g_iTankSupportAssist[pinner]++;
	}
}

void AddChainControlIfSmoker(int victim)
{
	int zc;
	int smoker = GetRecentPinner(victim, 5.0, zc);
	if (smoker > 0 && zc == ZC_SMOKER)
	{
		g_iChainControlAssist[smoker]++;
	}
}

public void TP_OnTankPass(int old_tank, int new_tank)
{
	// Same condition kether_scoring_system pays the survivors 48 points on.
	if (g_bRoundActive && CountStandingSurvivors() > 0)
	{
		g_iHalfTankPasses++;
	}

	if (IsValidHuman(old_tank))
	{
		EndTankHoldSegment(old_tank);
		g_iTankPasses[old_tank]++;
	}
	StartTankHold(new_tank);
}

public void OnChargerLevel(int survivor, int charger)
{
	CountAgainstInfected(g_iGotLeveled, charger);

	if (!g_bRoundActive || !IsValidHuman(survivor) || GetClientTeam(survivor) != TEAM_SURVIVOR)
	{
		return;
	}
	g_iChargerLevels[survivor]++;
}

// A "full" level needs the killing melee hit to do more than 65% of the charger's
// health. This server caps melee against chargers at 390 of 600 - exactly 65%, not
// more - so the full version can never fire here and every level arrives as the
// chipped one. Same play, same credit.
public void OnChargerLevelHurt(int survivor, int charger, int damage)
{
	OnChargerLevel(survivor, charger);
}

void CountAgainstInfected(int counter[MAXPLAYERS + 1], int client)
{
	if (g_bRoundActive && IsValidHuman(client) && GetClientTeam(client) == TEAM_INFECTED)
	{
		counter[client]++;
	}
}

public void L4D_OnMaterializeFromGhost(int client)
{
	if (!g_bRoundActive || !IsValidHuman(client) || GetClientTeam(client) != TEAM_INFECTED)
	{
		return;
	}

	int zc = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (zc >= ZC_SMOKER && zc <= ZC_CHARGER)
	{
		g_iClassSpawns[zc][client]++;
	}
}

public void OnTongueCut(int survivor, int smoker)
{
	CountAgainstInfected(g_iGotTongueCut, smoker);

	if (!g_bRoundActive || !IsValidHuman(survivor) || GetClientTeam(survivor) != TEAM_SURVIVOR)
	{
		return;
	}
	g_iTongueCuts[survivor]++;
}

public void OnTankRockEaten(int tank, int survivor)
{
	if (!g_bRoundActive || !IsValidHuman(survivor) || GetClientTeam(survivor) != TEAM_SURVIVOR)
	{
		return;
	}
	g_iRockEatenPenalty[survivor]++;
}

void StartTankHold(int client)
{
	if (!IsValidHuman(client) || GetClientTeam(client) != TEAM_INFECTED)
	{
		return;
	}
	// A pass can arrive both as tank_spawn and as TP_OnTankPass; one life either way.
	if (g_iCurrentTank != client)
	{
		g_iTankLives[client]++;
	}
	g_iCurrentTank = client;
	g_iLastHumanTank = client;
	g_fTankHoldStart = GetEngineTime();
}

void EndTankHoldSegment(int client)
{
	if (g_iCurrentTank != client)
	{
		return;
	}
	float now = GetEngineTime();
	if (g_fTankHoldStart > 0.0)
	{
		g_fTankHoldTime[client] += (now - g_fTankHoldStart);
	}
	g_iCurrentTank = 0;
	g_fTankHoldStart = 0.0;
}

void RegisterSaveCoop(int saver, int victim)
{
	if (!IsValidHuman(saver) || !IsValidClient(victim))
	{
		return;
	}
	float now = GetEngineTime();

	// Chain clear after boom
	if (g_iLastBoomerForVictim[victim] > 0 && (now - g_fLastBoomTime[victim]) <= 3.0)
	{
		g_iChainClearBoom[saver]++;
	}

	// Safe-save timing: fast after pin start or low HP
	int health = GetClientHealth(victim);
	if ((now - g_fLastPinStart[victim]) <= 2.0 || health > 0 && health <= 10)
	{
		g_iSafeSaves[saver]++;
	}
}

void AddPinDpsAssist(int attacker, int victim, int damage)
{
	if (damage <= 0)
	{
		return;
	}

	int zc;
	int pinner = GetRecentPinner(victim, PIN_ASSIST_WINDOW, zc);
	if (pinner > 0 && pinner != attacker)
	{
		g_fPinDpsAssists[pinner] += float(damage);
	}
}

void AddBigHitAssistForVictim(int victim, int damage)
{
	int zc;
	int pinner = GetRecentPinner(victim, CHARGE_ASSIST_WINDOW, zc);
	if (pinner > 0)
	{
		float factor = 1.0;
		if (damage > 0)
		{
			factor = FloatClamp(float(damage) / 100.0, 0.25, 1.5);
		}
		g_fBigHitAssistScore[pinner] += factor;
		g_iBigHitAssists[pinner]++; // count for reference
	}
}

void AddBoomAssistIfRecent(int victim)
{
	int boomer = g_iLastBoomerForVictim[victim];
	if (boomer > 0 && IsValidHuman(boomer) && GetClientTeam(boomer) == TEAM_INFECTED)
	{
		if ((GetEngineTime() - g_fLastBoomTime[victim]) <= BOOM_ASSIST_WINDOW)
		{
			g_iTankBoomAssists[boomer]++;
		}
	}
}

void AddBoomKillAssist(int victim)
{
	int boomer = g_iLastBoomerForVictim[victim];
	if (boomer > 0 && IsValidHuman(boomer) && GetClientTeam(boomer) == TEAM_INFECTED)
	{
		if ((GetEngineTime() - g_fLastBoomTime[victim]) <= BOOM_ASSIST_WINDOW)
		{
			g_iBoomKillAssists[boomer]++;
		}
	}
}

void AddWitchAssistHeuristic(int victim)
{
	int zc;
	int pinner = GetRecentPinner(victim, PIN_ASSIST_WINDOW, zc);
	if (pinner > 0)
	{
		g_iWitchAssists[pinner]++;
	}
	int boomer = g_iLastBoomerForVictim[victim];
	if (boomer > 0 && (GetEngineTime() - g_fLastBoomTime[victim]) <= BOOM_ASSIST_WINDOW)
	{
		g_iWitchAssists[boomer]++;
	}
}

void AddSpitSetupAssist(int victim)
{
	int spitter = g_iLastSpitterForVictim[victim];
	if (spitter > 0 && IsValidHuman(spitter) && GetClientTeam(spitter) == TEAM_INFECTED)
	{
		if ((GetEngineTime() - g_fLastSpitTime[victim]) <= SPIT_SETUP_WINDOW)
		{
			g_iSpitSetupAssists[spitter]++;
		}
	}
}

// Credits the kill with the share of the map the survivor still had ahead of him.
// A survivor who bleeds out has no attacker, so the infected who last hurt him
// within 20 seconds takes it - usually the one who put him down.
void CreditKillDistance(int victim, int attacker)
{
	if (!g_bRoundActive)
	{
		return;
	}

	int killer = 0;
	if (IsValidHuman(attacker) && GetClientTeam(attacker) == TEAM_INFECTED)
	{
		killer = attacker;
	}
	else
	{
		int last = g_iLastAttackerForVictim[victim];
		if (last > 0 && IsValidHuman(last) && GetClientTeam(last) == TEAM_INFECTED
			&& (GetEngineTime() - g_fLastAttackTime[victim]) <= 20.0)
		{
			killer = last;
		}
	}

	if (killer <= 0)
	{
		return;
	}

	float left = 100.0 - g_fFlowBest[victim];
	if (left > 0.0)
	{
		g_fKillFlowDenied[killer] += left;
	}
}

// kether_scoring_system's notion of a survivor who still scores: alive, and either
// standing or incapped inside the end saferoom.
bool IsScoringSurvivor(int client)
{
	return IsValidClient(client) && GetClientTeam(client) == TEAM_SURVIVOR && IsPlayerAlive(client)
		&& (!L4D_IsPlayerIncapacitated(client) || L4D_IsInLastCheckpoint(client));
}

int CountStandingSurvivors()
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsScoringSurvivor(i))
		{
			count++;
		}
	}
	return count;
}

bool SlotItemIs(int client, int slot, const char[] cls)
{
	int item = GetPlayerWeaponSlot(client, slot);
	if (item <= MaxClients || !IsValidEdict(item))
	{
		return false;
	}
	char buffer[64];
	GetEdictClassname(item, buffer, sizeof(buffer));
	return StrEqual(buffer, cls);
}

// Snapshot of every survivor at the end of the half and the bonus kether_scoring_system
// pays for it, computed the same way that plugin does.
void CaptureHalfResult()
{
	g_iHalfIndex = GameRules_GetProp("m_bInSecondHalfOfRound");
	int maxScore = L4D_GetVersusMaxCompletionScore();
	g_iHalfMaxScore = (maxScore > 0) ? maxScore : g_iLastMaxScore;
	float factor = float(g_iHalfMaxScore) / 400.0;

	ConVar limit = FindConVar("survivor_limit");
	int teamSize = (limit != null) ? limit.IntValue : 4;
	int counted = 0;
	float bonus = 0.0;

	for (int i = 1; i <= MaxClients; i++)
	{
		g_iEndStanding[i] = 0;
		g_iEndPermHp[i] = 0;
		g_iEndTempHp[i] = 0;
		g_iEndMedkit[i] = 0;
		g_iEndPills[i] = 0;

		if (!IsScoringSurvivor(i))
		{
			continue;
		}

		g_iEndStanding[i] = 1;
		g_iEndPermHp[i] = GetEntProp(i, Prop_Send, "m_iHealth");
		g_iEndTempHp[i] = L4D_GetPlayerTempHealth(i);
		g_iEndMedkit[i] = SlotItemIs(i, 3, "weapon_first_aid_kit") ? 1 : 0;
		g_iEndPills[i] = (SlotItemIs(i, 4, "weapon_pain_pills") || SlotItemIs(i, 4, "weapon_adrenaline")) ? 1 : 0;

		float incapFactor = 1.0;
		int incaps = g_iIncapsTaken[i];
		if (incaps > 3)
		{
			incapFactor = 0.1;
		}
		else if (incaps > 2)
		{
			incapFactor = 0.25;
		}
		else if (incaps > 1)
		{
			incapFactor = 0.5;
		}
		else if (incaps > 0)
		{
			incapFactor = 0.75;
		}
		bonus += KSS_SURVIVED_BONUS * factor * incapFactor;

		if (counted < teamSize)
		{
			counted++;
			if (g_iEndPermHp[i] < 101)
			{
				bonus += KSS_HEALTH_BONUS * float(g_iEndPermHp[i]) / 100.0 * factor;
			}
			bonus += float(g_iEndMedkit[i]) * KSS_MEDKIT_BONUS * factor;
			bonus += float(g_iEndPills[i]) * KSS_PILLS_BONUS * factor;
		}
	}

	bonus += float(g_iHalfTankPasses) * KSS_TANK_PASS_BONUS;
	bonus += float(g_iHalfTankKills) * KSS_TANK_KILL_BONUS;
	bonus += float(g_iHalfWitchBonus) * KSS_WITCH_BONUS;
	g_fHalfBonus = bonus;
}

// Mirrors kether_scoring_system: a tank that dies while a survivor still stands is
// worth 24 to the survivors, a crown or a draw-crown another 24.
public void OnTankDeath()
{
	if (g_bRoundActive && CountStandingSurvivors() > 0)
	{
		g_iHalfTankKills++;
	}
}

public void Kether_OnWitchCrown(int survivor, int witch)
{
	if (g_bRoundActive)
	{
		g_iHalfWitchBonus++;
	}
}

public void Kether_OnWitchDrawCrown(int survivor, int witch)
{
	if (g_bRoundActive)
	{
		g_iHalfWitchBonus++;
	}
}
