#if defined __ksr_events_included
	#endinput
#endif
#define __ksr_events_included

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bRoundActive || !g_CvarEnabled.BoolValue)
	{
		return;
	}

	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int damage = event.GetInt("dmg_health") + event.GetInt("dmg_armor");
	int hitgroup = event.GetInt("hitgroup");

	if (damage <= 0 || attacker == victim)
	{
		return;
	}

	bool attackerValid = IsValidHuman(attacker);
	int attackerTeam = attackerValid ? GetClientTeam(attacker) : 0;

	if (!attackerValid)
	{
		if (IsValidClient(victim) && GetClientTeam(victim) == TEAM_SURVIVOR)
		{
			int spitter = g_iLastSpitterForVictim[victim];
			if (spitter > 0 && (GetEngineTime() - g_fLastSpitTime[victim]) <= SPIT_SETUP_WINDOW)
			{
				AddSpitMultiHit(spitter, victim);
			}
		}
		return;
	}
	if (attackerTeam == TEAM_INFECTED)
	{
		if (IsValidClient(victim) && GetClientTeam(victim) == TEAM_SURVIVOR)
		{
			// A survivor charged into a kill trigger is reported as one 10000 point
			// hit credited to the charger - three times in the data so far, each one
			// worth more than a hundred normal rounds. No real hit can take more
			// than a standing survivor's 100 or an incapped one's 300.
			int hitCap = g_bIncapped[victim] ? 300 : 100;
			if (damage > hitCap)
			{
				damage = hitCap;
			}

			g_iDamageAsInfected[attacker] += damage;
			AddPinDpsAssist(attacker, victim, damage);

			int zClassAtt = GetEntProp(attacker, Prop_Send, "m_zombieClass");

			// Spit keeps burning after the spitter died and came back as something
			// else, so the class is read off the weapon for it rather than off the
			// player.
			char hurtWeapon[32];
			event.GetString("weapon", hurtWeapon, sizeof(hurtWeapon));
			int logClass = StrEqual(hurtWeapon, "insect_swarm", false) ? ZC_SPITTER : zClassAtt;
			if (logClass == ZC_TANK)
			{
				g_iDamageAsTank[attacker] += damage;
			}
			else if (logClass >= ZC_SMOKER && logClass <= ZC_CHARGER)
			{
				g_iClassDamage[logClass][attacker] += damage;
			}

			// KSR's own incap flag is raised by player_incapacitated, which arrives
			// after the hurt event of the hit that caused it, so that hit still counts
			// as damage on a standing survivor.
			if (g_bIncapped[victim])
			{
				g_iDamageOnIncapped[attacker] += damage;
			}
			else if (logClass == ZC_TANK)
			{
				g_iTankDamageUpright[attacker] += damage;
			}
			else
			{
				g_iSiDamageUpright[attacker] += damage;
			}
			float now = GetEngineTime();

			// Shared focus fire (multiple SI on same target)
			int prevAttacker = g_iLastAttackerForVictim[victim];
			if (prevAttacker > 0 && prevAttacker != attacker && IsValidHuman(prevAttacker) && GetClientTeam(prevAttacker) == TEAM_INFECTED && (now - g_fLastAttackTime[victim]) <= 3.0)
			{
				g_iSharedFocus[attacker]++;
				g_iSharedFocus[prevAttacker]++;
			}
			g_iLastAttackerForVictim[victim] = attacker;
			g_fLastAttackTime[victim] = now;

			int spitter = 0;
			// Spitter utility on pinned/incapped
			if (zClassAtt == ZC_SPITTER)
			{
				spitter = attacker;
				g_iLastSpitterForVictim[victim] = attacker;
				g_fLastSpitTime[victim] = now;
				int tmpClass;
				if (GetRecentPinner(victim, PIN_ASSIST_WINDOW, tmpClass) > 0)
				{
					g_iSpitPinnedTicks[attacker]++;
				}
				if (g_bIncapped[victim])
				{
					g_iSpitIncapTicks[attacker]++;
				}
				g_iLastStaggerer[victim] = attacker;
				g_fLastStaggerTime[victim] = now;
			}
			else if (g_iLastSpitterForVictim[victim] > 0 && (GetEngineTime() - g_fLastSpitTime[victim]) <= SPIT_SETUP_WINDOW)
			{
				spitter = g_iLastSpitterForVictim[victim];
			}

			if (spitter > 0)
			{
				AddSpitMultiHit(spitter, victim);
			}

			// Big-hit assist: tank/charger damage helped by pins or boom.
			if (zClassAtt == ZC_CHARGER || zClassAtt == ZC_TANK)
			{
				AddBigHitAssistForVictim(victim, damage);
				AddBoomAssistIfRecent(victim);
				AddSpitSetupAssist(victim);
				if (zClassAtt == ZC_CHARGER)
				{
					g_iLastStaggerer[victim] = attacker;
					g_fLastStaggerTime[victim] = now;
				}
				if (zClassAtt == ZC_TANK)
				{
					AddTankSupportAssist(victim);
					g_iLastStaggerer[victim] = attacker;
					g_fLastStaggerTime[victim] = now;
				}
			}

			// Boom follow-up focus (credit boomer)
			if (g_iLastBoomerForVictim[victim] > 0 && g_iLastBoomerForVictim[victim] != attacker && (now - g_fLastBoomTime[victim]) <= 10.0)
			{
				g_iBoomFocusAssist[g_iLastBoomerForVictim[victim]]++;
			}

			// Stagger setup (spit/rock/charge/tank) -> other SI hit
			if (g_iLastStaggerer[victim] > 0 && g_iLastStaggerer[victim] != attacker && (now - g_fLastStaggerTime[victim]) <= 3.0)
			{
				g_iStaggerSetup[g_iLastStaggerer[victim]]++;
			}

			// Revive interrupt: if victim is reviver or revivee in active window
			for (int rev = 1; rev <= MaxClients; rev++)
			{
				if (g_iReviveTargetForReviver[rev] == 0 || !IsValidHuman(rev) || GetClientTeam(rev) != TEAM_SURVIVOR)
				{
					continue;
				}
				if ((GetEngineTime() - g_fReviveStartTime[rev]) > 5.0)
				{
					g_iReviveTargetForReviver[rev] = 0;
					g_fReviveStartTime[rev] = 0.0;
					continue;
				}
				if (victim == rev || victim == g_iReviveTargetForReviver[rev])
				{
					g_iReviveInterrupts[attacker]++;
					g_iReviveTargetForReviver[rev] = 0;
					g_fReviveStartTime[rev] = 0.0;
					break;
				}
			}
		}
		return;
	}

	if (attackerTeam != TEAM_SURVIVOR)
	{
		return;
	}

	if (IsValidClient(victim) && GetClientTeam(victim) == TEAM_INFECTED)
	{
		g_iDamageAsSurvivor[attacker] += damage;

		int zClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
		if (zClass == ZC_TANK)
		{
			g_iTankDamageAsSurvivor[attacker] += damage;
		}
		if (hitgroup == 1)
		{
			g_iHeadshotSI[attacker]++;
		}
	}
	else if (IsValidClient(victim) && GetClientTeam(victim) == TEAM_SURVIVOR)
	{
		g_iFriendlyFireDealt[attacker] += damage;
		g_iFriendlyFireTaken[victim] += damage;
	}
}

public void Event_InfectedHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bRoundActive || !g_CvarEnabled.BoolValue)
	{
		return;
	}

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!IsValidHuman(attacker) || GetClientTeam(attacker) != TEAM_SURVIVOR)
	{
		return;
	}

	int amount = event.GetInt("amount");
	if (amount <= 0)
	{
		return;
	}

	// infected_hurt fires for common infected as well as for the witch. Splitting
	// them keeps horde clearing out of the witch damage bucket.
	int entity = event.GetInt("entityid");
	if (entity > 0 && IsValidEntity(entity))
	{
		char cls[32];
		if (GetEntityClassname(entity, cls, sizeof(cls)) && StrEqual(cls, "witch", false))
		{
			g_iWitchDamageAsSurvivor[attacker] += amount;
			return;
		}
	}

	g_iCommonDamageAsSurvivor[attacker] += amount;
}

public void Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bRoundActive || !g_CvarEnabled.BoolValue)
	{
		return;
	}

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (IsValidHuman(attacker) && GetClientTeam(attacker) == TEAM_SURVIVOR)
	{
		g_iCommonKillsAsSurvivor[attacker]++;
	}
}

public void Event_PlayerIncapacitated(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!IsValidClient(victim))
	{
		return;
	}

	if (GetClientTeam(victim) == TEAM_SURVIVOR)
	{
		// Every survivor, bots included, so the half's survival bonus can be rebuilt.
		g_iIncapsTaken[victim]++;
		g_bIncapped[victim] = true;
		if (g_bAliveAtEnd[victim] && g_bRoundLive && !g_bPaused)
		{
			g_fSurvivalTime[victim] += GetEngineTime() - g_fLifeStart[victim];
		}
		g_bAliveAtEnd[victim] = false;
		AddPinAssistForVictim(victim);
		AddBoomAssistIfRecent(victim);
		AddSpitSetupAssist(victim);
		AddBoomKillAssist(victim);
		MarkPinEnd(victim);

		if (IsValidHuman(attacker) && GetClientTeam(attacker) == TEAM_INFECTED)
		{
			g_iInfIncaps[attacker]++;

			int zc = GetEntProp(attacker, Prop_Send, "m_zombieClass");
			if (zc == ZC_CHARGER || zc == ZC_TANK)
			{
				AddBigHitAssistForVictim(victim, 0);
				AddBoomAssistIfRecent(victim);
				AddSpitSetupAssist(victim);
			}
		}
	}
}

public void Event_PlayerBoomed(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int boomer = GetClientOfUserId(event.GetInt("attacker"));
	if (!IsValidClient(victim))
	{
		return;
	}
	if (!IsValidHuman(boomer) || GetClientTeam(boomer) != TEAM_INFECTED)
	{
		return;
	}
	g_iLastBoomerForVictim[victim] = boomer;
	g_fLastBoomTime[victim] = GetEngineTime();
}

public void Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bRoundActive || !g_CvarEnabled.BoolValue)
	{
		return;
	}

	int reviver = GetClientOfUserId(event.GetInt("userid"));
	int revived = GetClientOfUserId(event.GetInt("subject"));
	if (IsValidClient(revived) && GetClientTeam(revived) == TEAM_SURVIVOR)
	{
		g_bIncapped[revived] = false;
		g_bAliveAtEnd[revived] = true;
		g_fLifeStart[revived] = GetEngineTime();
	}
	if (IsValidHuman(reviver) && IsValidClient(revived) && reviver != revived && GetClientTeam(reviver) == TEAM_SURVIVOR)
	{
		g_iRevives[reviver]++;
		if (IsTankInPlayActive())
		{
			g_iTankPlayActions[reviver]++;
		}
		RegisterSaveCoop(reviver, revived);
	}
	g_iReviveTargetForReviver[reviver] = 0;
	g_fReviveStartTime[reviver] = 0.0;
}

public void Event_HealBegin(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bRoundActive || !g_CvarEnabled.BoolValue)
	{
		return;
	}

	int healer = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));
	if (!IsValidHuman(healer) || GetClientTeam(healer) != TEAM_SURVIVOR)
	{
		return;
	}

	g_bHealStartedToOther[healer] = (subject > 0 && subject != healer);
}

public void Event_HealSuccess(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bRoundActive || !g_CvarEnabled.BoolValue)
	{
		return;
	}

	int healer = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));
	if (!IsValidHuman(healer) || GetClientTeam(healer) != TEAM_SURVIVOR)
	{
		return;
	}

	if (subject > 0 && subject != healer && g_bHealStartedToOther[healer])
	{
		g_iMedkitGives[healer]++;
		if (IsTankInPlayActive())
		{
			g_iTankPlayActions[healer]++;
		}
	}
	g_bHealStartedToOther[healer] = false;
}

public void Event_ReviveBegin(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bRoundActive || !g_CvarEnabled.BoolValue)
	{
		return;
	}
	int reviver = GetClientOfUserId(event.GetInt("userid"));
	int revived = GetClientOfUserId(event.GetInt("subject"));
	if (!IsValidHuman(reviver) || GetClientTeam(reviver) != TEAM_SURVIVOR || !IsValidClient(revived))
	{
		return;
	}
	g_iReviveTargetForReviver[reviver] = revived;
	g_fReviveStartTime[reviver] = GetEngineTime();
}

public void Event_ReviveEnd(Event event, const char[] name, bool dontBroadcast)
{
	int reviver = GetClientOfUserId(event.GetInt("userid"));
	if (reviver > 0)
	{
		g_iReviveTargetForReviver[reviver] = 0;
		g_fReviveStartTime[reviver] = 0.0;
	}
}

public Action Event_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bRoundActive || !g_CvarEnabled.BoolValue)
	{
		return Plugin_Continue;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidHuman(client) || GetClientTeam(client) != TEAM_INFECTED)
	{
		return Plugin_Continue;
	}

	char ability[64];
	event.GetString("ability", ability, sizeof(ability));
	if (StrEqual(ability, "ability_vomit", false))
	{
		g_iBoomerVomitCasts[client]++;
	}

	return Plugin_Continue;
}

public void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bRoundActive || !g_CvarEnabled.BoolValue)
	{
		return;
	}

	int killer = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidHuman(killer) && GetClientTeam(killer) == TEAM_SURVIVOR)
	{
		// Crowns are credited by skill_detect through OnWitchCrown; this only
		// counts the witch going down at all.
		g_iWitchKills[killer]++;
	}
}

// The three plays that decide infected rounds and were, until now, worth nothing.
// This matters more than it looks: the infected side separates players 2.2x less
// than the survivor side does, and these are exactly the plays that should be
// doing that separating.
public void OnDeathCharge(int charger, int survivor, float height, float distance, bool wasCarried)
{
	if (!g_bRoundActive || !IsValidHuman(charger) || GetClientTeam(charger) != TEAM_INFECTED)
	{
		return;
	}

	g_iDeathCharges[charger]++;
}

public void OnHunterHighPounce(int hunter, int survivor, int actualDamage, float calculatedDamage, float height, bool reportedHigh)
{
	if (!g_bRoundActive || !IsValidHuman(hunter) || GetClientTeam(hunter) != TEAM_INFECTED)
	{
		return;
	}

	// Scored by the damage actually landed, so a 25 point pounce and a 60 point one
	// are not worth the same.
	if (actualDamage > 0)
	{
		g_iHunterPounceDamage[hunter] += actualDamage;
	}
}

public void OnJockeyHighPounce(int first, int second, float height, bool reportedHigh)
{
	// The include documents (survivor, jockey), the detection plugin pushes
	// (jockey, survivor). Trusting the include meant the team check below always
	// saw the survivor and threw every pounce away - 0 hits in 5535 rows. Take
	// whichever of the two is actually on the infected team.
	//
	// The forward also fires for every ride that started from a jump, so only the
	// ones over the height threshold count.
	if (!g_bRoundActive || !reportedHigh)
	{
		return;
	}

	int jockey = (IsValidHuman(first) && GetClientTeam(first) == TEAM_INFECTED) ? first : second;
	if (!IsValidHuman(jockey) || GetClientTeam(jockey) != TEAM_INFECTED)
	{
		return;
	}

	g_iJockeyHighPounces[jockey]++;
}

// Replaces the raw triggered_car_alarm hook: this one says who set the alarm off
// and how, so a survivor is no longer charged for a car a tank threw or a boomer
// splashed.
public void OnCarAlarmTriggered(int survivor, int infected, CarAlarmTriggerReason reason)
{
	if (!g_bRoundActive || !g_CvarEnabled.BoolValue)
	{
		return;
	}

	if (reason == CarAlarmTrigger_Boomer)
	{
		return;
	}

	if (IsValidHuman(survivor) && GetClientTeam(survivor) == TEAM_SURVIVOR)
	{
		g_iAlarmTriggers[survivor]++;
	}
}

public void OnWitchCrown(int survivor, int damage)
{
	if (!g_bRoundActive || !IsValidHuman(survivor) || GetClientTeam(survivor) != TEAM_SURVIVOR)
	{
		return;
	}

	g_iWitchCrowns[survivor]++;
	if (IsTankInPlayActive())
	{
		g_iTankPlayActions[survivor]++;
	}
}

public void Event_ChargerImpact(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bRoundActive || !g_CvarEnabled.BoolValue)
	{
		return;
	}

	// charger_impact fires for every survivor clipped during a charge beyond the
	// one actually carried, which is the real "multi charge" signal.
	int charger = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidHuman(charger) || GetClientTeam(charger) != TEAM_INFECTED)
	{
		return;
	}

	// charger_impact fires once per survivor clipped by the charge. The first one
	// is the intended target and is already paid for elsewhere; only the extra
	// bodies in a multi-charge earn anything.
	float now = GetEngineTime();
	if (now - g_fChargeImpactStart[charger] > 3.0)
	{
		g_fChargeImpactStart[charger] = now;
		g_iChargeImpactCount[charger] = 0;
	}

	g_iChargeImpactCount[charger]++;
	if (g_iChargeImpactCount[charger] > 1)
	{
		g_iChargerMulti[charger]++;
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (IsValidHuman(attacker) && GetClientTeam(attacker) == TEAM_INFECTED)
	{
		int zcAtt = GetEntProp(attacker, Prop_Send, "m_zombieClass");
		if (IsValidClient(victim) && GetClientTeam(victim) == TEAM_SURVIVOR)
		{
			g_iInfKills[attacker]++;
			if (zcAtt == ZC_TANK)
			{
				g_iTankKills[attacker]++;
			}
		}
	}

	if (IsValidClient(victim) && GetClientTeam(victim) == TEAM_SURVIVOR)
	{
		CreditKillDistance(victim, attacker);
		if (g_bAliveAtEnd[victim] && g_bRoundLive && !g_bPaused)
		{
			g_fSurvivalTime[victim] += GetEngineTime() - g_fLifeStart[victim];
		}
		g_bAliveAtEnd[victim] = false;
		AddPinAssistForVictim(victim);
		AddBoomAssistIfRecent(victim);
		AddSpitSetupAssist(victim);
		AddBoomKillAssist(victim);
		MarkPinEnd(victim);
	}

	if (IsValidClient(victim))
	{
		int zClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
		if (zClass == ZC_BOOMER)
		{
			if (IsValidHuman(attacker) && GetClientTeam(attacker) == TEAM_SURVIVOR)
			{
				g_iLastBoomerKiller[victim] = attacker;
				g_fLastBoomerDeathTime[victim] = GetEngineTime();
			}
		}
	}

	// Charger lethal synergy assist window
	if (IsValidHuman(attacker) && GetClientTeam(attacker) == TEAM_INFECTED)
	{
		int zc = GetEntProp(attacker, Prop_Send, "m_zombieClass");
		if (zc == ZC_CHARGER || zc == ZC_TANK)
		{
			AddBigHitAssistForVictim(victim, 0);
			AddBoomAssistIfRecent(victim);
			AddSpitSetupAssist(victim);
		}
	}
	else if (!IsValidClient(attacker))
	{
		// Heuristic witch assist (non-client attacker)
		AddWitchAssistHeuristic(victim);
	}

	if (IsValidHuman(victim) && GetClientTeam(victim) == TEAM_INFECTED)
	{
		int zcV = GetEntProp(victim, Prop_Send, "m_zombieClass");
		if (zcV == ZC_TANK)
		{
			EndTankHoldSegment(victim);
		}
	}
}

public void Event_PinStart_Smoker(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	int victim = GetClientOfUserId(event.GetInt("victim"));
	MarkPinStart(attacker, victim, ZC_SMOKER);
}

public void Event_PinStart_Jockey(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	int victim = GetClientOfUserId(event.GetInt("victim"));
	AddChainControlIfSmoker(victim);
	MarkPinStart(attacker, victim, ZC_JOCKEY);
}

public void Event_PinStart_Charger(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	int victim = GetClientOfUserId(event.GetInt("victim"));
	MarkPinStart(attacker, victim, ZC_CHARGER);
}

public void Event_PinStart_Hunter(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	int victim = GetClientOfUserId(event.GetInt("victim"));
	AddChainControlIfSmoker(victim);
	MarkPinStart(attacker, victim, ZC_HUNTER);
}

public void Event_PinEnd_Generic(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("victim"));
	if (victim <= 0)
	{
		victim = GetClientOfUserId(event.GetInt("userid"));
	}
	MarkPinEnd(victim);
}

public void OnBoomerVomitLanded(int boomer, int amount)
{
	if (amount <= 0)
	{
		return;
	}

	if (IsValidHuman(boomer) && GetClientTeam(boomer) == TEAM_INFECTED)
	{
		g_iBoomerVomitHits[boomer] += amount;
	}

	// If boomer already dead and recently killed by a survivor, treat as splash pop.
	if (!IsPlayerAlive(boomer) && g_iLastBoomerKiller[boomer] > 0 && (GetEngineTime() - g_fLastBoomerDeathTime[boomer]) <= 1.0)
	{
		int killer = g_iLastBoomerKiller[boomer];
		if (IsValidHuman(killer) && GetClientTeam(killer) == TEAM_SURVIVOR)
		{
			g_iBoomerPopsSplash[killer] += amount;
		}
	}
}

public void OnSpecialClear(int clearer, int pinner, int pinvictim, int zombieClass, float timeA, float timeB, bool withShove)
{
	if (!g_bRoundActive || !IsValidHuman(clearer))
	{
		return;
	}

	if (GetClientTeam(clearer) == TEAM_SURVIVOR)
	{
		g_iSpecialClears[clearer]++;
		if (clearer != pinvictim)
		{
			g_iRescuesFromSpecial[clearer]++;
		}
		if (zombieClass == ZC_JOCKEY)
		{
			g_iJockeyBlocks[clearer]++;
		}
		if (IsTankInPlayActive())
		{
			g_iTankPlayActions[clearer]++;
		}
		RegisterSaveCoop(clearer, pinvictim);
	}
	MarkPinEnd(pinvictim);
}

public void OnSmokerSelfClear(int survivor, int smoker, bool withShove)
{
	if (!g_bRoundActive || !IsValidHuman(survivor))
	{
		return;
	}

	if (GetClientTeam(survivor) == TEAM_SURVIVOR)
	{
		g_iSmokerSelfClears[survivor]++;
		if (IsTankInPlayActive())
		{
			g_iTankPlayActions[survivor]++;
		}
	}
	MarkPinEnd(survivor);
}

public void OnSkeet(int survivor, int hunter)
{
	CountAgainstInfected(g_iGotSkeeted, hunter);

	if (!g_bRoundActive || !IsValidHuman(survivor))
	{
		return;
	}

	if (GetClientTeam(survivor) == TEAM_SURVIVOR)
	{
		g_iSkeets[survivor]++;
		if (IsTankInPlayActive())
		{
			g_iTankPlayActions[survivor]++;
		}
	}
}

public void OnSkeetMelee(int survivor, int hunter)
{
	CountAgainstInfected(g_iGotSkeeted, hunter);

	if (!g_bRoundActive || !IsValidHuman(survivor))
	{
		return;
	}

	// Still counted for the stats screen, but worth nothing: melee one-shots a
	// hunter here, so it is not the same feat as a shotgun skeet. That includes
	// the tank-in-play bonus, which would otherwise pay for it through the back door.
	if (GetClientTeam(survivor) == TEAM_SURVIVOR)
	{
		g_iSkeetsMelee[survivor]++;
	}
}

public void OnSkeetSniper(int survivor, int hunter)
{
	OnSkeet(survivor, hunter);
}

public void OnSkeetGL(int survivor, int hunter)
{
	OnSkeet(survivor, hunter);
}

public void OnTankRockSkeeted(int survivor, int tank)
{
	if (!g_bRoundActive || !IsValidHuman(survivor))
	{
		return;
	}

	if (GetClientTeam(survivor) == TEAM_SURVIVOR)
	{
		g_iRockSkeets[survivor]++;
		if (IsTankInPlayActive())
		{
			g_iTankPlayActions[survivor]++;
		}
	}
}

public void OnHunterDeadstop(int survivor, int hunter)
{
	CountAgainstInfected(g_iGotDeadstopped, hunter);

	if (!g_bRoundActive || !IsValidHuman(survivor))
	{
		return;
	}

	if (GetClientTeam(survivor) == TEAM_SURVIVOR)
	{
		g_iDeadstops[survivor]++;
		if (IsTankInPlayActive())
		{
			g_iTankPlayActions[survivor]++;
		}
	}
}

public void OnBoomerPop(int survivor, int boomer, int shoveCount, float timeAlive)
{
	CountAgainstInfected(g_iGotPopped, boomer);

	if (!g_bRoundActive || !IsValidHuman(survivor))
	{
		return;
	}

	if (GetClientTeam(survivor) == TEAM_SURVIVOR)
	{
		g_iBoomerPopsNoVomit[survivor]++;
		if (IsTankInPlayActive())
		{
			g_iTankPlayActions[survivor]++;
		}
	}
}

public void OnSpecialShoved(int survivor, int infected, int zombieClass)
{
	if (!g_bRoundActive || !IsValidHuman(survivor))
	{
		return;
	}

	if (GetClientTeam(survivor) != TEAM_SURVIVOR)
	{
		return;
	}

	g_iShoveSI[survivor]++;

	// A shove that interrupts an active pin is worth far more than a poke at a
	// specials that was not doing anything. The jockey bonus itself is credited
	// through OnSpecialClear so it cannot stack three times on one shove.
	if (infected > 0 && infected <= MaxClients && g_bPinActive[survivor])
	{
		g_iSpecialShoveSaves[survivor]++;
		if (IsTankInPlayActive())
		{
			g_iTankPlayActions[survivor]++;
		}
	}
	MarkPinEnd(survivor);
}
