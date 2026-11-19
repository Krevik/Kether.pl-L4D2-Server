#if defined __ksr_stat_registry_included
	#endinput
#endif
#define __ksr_stat_registry_included

// The handful of cvars that define the model rather than tune it. A stale value
// here does not misconfigure the plugin slightly - it runs a different model.
void CheckModelCvar(ConVar cv, int &mismatches)
{
	char current[32];
	char preferred[32];
	cv.GetString(current, sizeof(current));
	cv.GetDefault(preferred, sizeof(preferred));

	if (StrEqual(current, preferred))
	{
		return;
	}

	char name[64];
	cv.GetName(name, sizeof(name));
	LogError("[SkillRating] %s is %s but this build expects %s. A stale cfg/sourcemod/%s.cfg pins the old value - delete it and let it regenerate, or set the cvar.",
		name, current, preferred, KSR_CONFIG_NAME);
	PrintToServer("[SkillRating] WARNING: %s = %s, build expects %s", name, current, preferred);
	mismatches++;
}

public Action Timer_WarnStaleConfig(Handle timer)
{
	int mismatches = 0;
	CheckModelCvar(g_CvarRatingEmaMin, mismatches);
	CheckModelCvar(g_CvarRatingShrinkRounds, mismatches);
	CheckModelCvar(g_CvarRatingScale, mismatches);
	CheckModelCvar(g_CvarCarryWeight, mismatches);
	CheckModelCvar(g_CvarWeightSurvivalSec, mismatches);
	CheckModelCvar(g_CvarWeightFlowPercent, mismatches);
	CheckModelCvar(g_CvarWeightInfDamage, mismatches);
	CheckModelCvar(g_CvarWeightPinAssist, mismatches);
	CheckModelCvar(g_CvarWeightTankHoldSec, mismatches);
	CheckModelCvar(g_CvarWeightBoomerVomitCast, mismatches);
	CheckModelCvar(g_CvarMixShrink, mismatches);
	CheckModelCvar(g_CvarWeightInfDamageIncapped, mismatches);
	CheckModelCvar(g_CvarWeightTankDamageRel, mismatches);

	if (mismatches > 0)
	{
		PrintToServer("[SkillRating] %d model cvar(s) differ from this build. The ranking is not running the model you think it is.", mismatches);
	}

	return Plugin_Stop;
}

void RegisterStat(const char[] label, const char[] column, int side, int category, ConVar weight, bool lowerIsBetter)
{
	if (g_iStatCount >= KSR_MAX_STATS)
	{
		LogError("[SkillRating] Stat registry full, '%s' dropped. Raise KSR_MAX_STATS.", label);
		return;
	}

	strcopy(g_Stats[g_iStatCount].label, 28, label);
	strcopy(g_Stats[g_iStatCount].column, 28, column);
	g_Stats[g_iStatCount].side = side;
	g_Stats[g_iStatCount].category = category;
	g_Stats[g_iStatCount].weight = weight;
	g_Stats[g_iStatCount].lowerIsBetter = lowerIsBetter;
	g_iStatCount++;
}

void RegisterStats()
{
	g_iStatCount = 0;

	RegisterStat("Damage to SI", "dmg_survivor", TEAM_SURVIVOR, 0, g_CvarWeightSurvDamage, false);
	RegisterStat("Tank damage (extra)", "dmg_tank", TEAM_SURVIVOR, 0, g_CvarWeightTankDamage, false);
	RegisterStat("Witch damage", "dmg_witch", TEAM_SURVIVOR, 0, g_CvarWeightWitchDamage, false);
	RegisterStat("Common damage", "common_damage", TEAM_SURVIVOR, 0, g_CvarWeightCommonDamage, false);
	RegisterStat("Common kills", "common_kills", TEAM_SURVIVOR, 0, g_CvarWeightCommonKills, false);
	RegisterStat("Headshots on SI", "headshot_si", TEAM_SURVIVOR, 0, g_CvarWeightHeadshotSI, false);
	RegisterStat("Special clears", "special_clears", TEAM_SURVIVOR, 1, g_CvarWeightSpecialClear, false);
	RegisterStat("Teammate rescues", "special_rescues", TEAM_SURVIVOR, 1, g_CvarWeightRescue, false);
	RegisterStat("Jockey clears", "jockey_blocks", TEAM_SURVIVOR, 1, g_CvarWeightJockeyBlock, false);
	RegisterStat("Fast saves", "safe_saves", TEAM_SURVIVOR, 1, g_CvarWeightSafeSave, false);
	RegisterStat("Clears after boom", "chain_clear_boom", TEAM_SURVIVOR, 1, g_CvarWeightChainClearBoom, false);
	RegisterStat("Shoves on SI", "shove_si", TEAM_SURVIVOR, 1, g_CvarWeightShoveSI, false);
	RegisterStat("Pin-breaking shoves", "special_shove_saves", TEAM_SURVIVOR, 1, g_CvarWeightSpecialShove, false);
	RegisterStat("Skeets", "skeets", TEAM_SURVIVOR, 2, g_CvarWeightSkeet, false);
	RegisterStat("Melee skeets", "skeets_melee", TEAM_SURVIVOR, 2, g_CvarWeightSkeetMelee, false);
	RegisterStat("Deadstops", "deadstops", TEAM_SURVIVOR, 2, g_CvarWeightDeadstop, false);
	RegisterStat("Self clears", "self_clears", TEAM_SURVIVOR, 2, g_CvarWeightSelfClear, false);
	RegisterStat("Rock skeets", "rock_skeets", TEAM_SURVIVOR, 2, g_CvarWeightRockSkeet, false);
	RegisterStat("Clean boomer pops", "boomer_pops", TEAM_SURVIVOR, 2, g_CvarWeightBoomerPop, false);
	RegisterStat("Tongue cuts", "tongue_cuts", TEAM_SURVIVOR, 2, g_CvarWeightTongueCut, false);
	RegisterStat("Charger levels", "charger_levels", TEAM_SURVIVOR, 2, g_CvarWeightChargerLevel, false);
	RegisterStat("Witch crowns", "witch_crowns", TEAM_SURVIVOR, 2, g_CvarWeightWitchCrown, false);
	RegisterStat("Witch kills", "witch_kills", TEAM_SURVIVOR, 2, g_CvarWeightWitchKill, false);
	RegisterStat("Revives", "revives", TEAM_SURVIVOR, 3, g_CvarWeightRevive, false);
	RegisterStat("Heals given", "medkit_gives", TEAM_SURVIVOR, 3, g_CvarWeightMedkitGive, false);
	RegisterStat("Plays during tank", "tank_play_actions", TEAM_SURVIVOR, 3, g_CvarWeightTankPlayAction, false);
	RegisterStat("Time alive", "survival_time", TEAM_SURVIVOR, 4, g_CvarWeightSurvivalSec, false);
	RegisterStat("Map progress", "flow_percent", TEAM_SURVIVOR, 4, g_CvarWeightFlowPercent, false);
	RegisterStat("Friendly fire", "ff_dealt", TEAM_SURVIVOR, 5, g_CvarWeightFriendlyFire, true);
	RegisterStat("Rocks eaten", "rock_eaten_penalty", TEAM_SURVIVOR, 5, g_CvarWeightRockEatenPenalty, true);
	RegisterStat("Car alarms", "alarm_triggers", TEAM_SURVIVOR, 5, g_CvarWeightAlarmPenalty, true);
	RegisterStat("Bad boomer pops", "boomer_pops_splash", TEAM_SURVIVOR, 5, g_CvarWeightBoomerPopSplash, true);
	RegisterStat("Clean rounds", "zero_ff_bonus", TEAM_SURVIVOR, 5, g_CvarWeightZeroFFBonus, false);

	RegisterStat("Pin assists", "pin_assists", TEAM_INFECTED, 6, g_CvarWeightPinAssist, false);
	RegisterStat("Damage on pins", "pin_dps_assist", TEAM_INFECTED, 6, g_CvarWeightPinDpsAssist, false);
	RegisterStat("Chain control", "chain_control", TEAM_INFECTED, 6, g_CvarWeightChainControl, false);
	RegisterStat("Revive interrupts", "revive_interrupts", TEAM_INFECTED, 6, g_CvarWeightReviveInterrupt, false);
	RegisterStat("Death charges", "death_charges", TEAM_INFECTED, 7, g_CvarWeightDeathCharge, false);
	RegisterStat("Hunter pounce dmg", "hunter_pounce_dmg", TEAM_INFECTED, 7, g_CvarWeightHunterPounceDmg, false);
	RegisterStat("Jockey high pounces", "jockey_high_pounces", TEAM_INFECTED, 7, g_CvarWeightJockeyHighPounce, false);
	RegisterStat("Big hits", "big_hit_assist_score", TEAM_INFECTED, 7, g_CvarWeightBigHitAssistScore, false);
	RegisterStat("Multi charges", "charger_multi", TEAM_INFECTED, 7, g_CvarWeightChargerMulti, false);
	RegisterStat("Vomit hits", "boomer_vomit_hits", TEAM_INFECTED, 8, g_CvarWeightBoomerVomitHit, false);
	RegisterStat("Vomit casts", "boomer_vomit_casts", TEAM_INFECTED, 8, g_CvarWeightBoomerVomitCast, true);
	RegisterStat("Boom kill assists", "boom_kill_assists", TEAM_INFECTED, 8, g_CvarWeightBoomKillAssist, false);
	RegisterStat("Boom follow-up", "boom_focus", TEAM_INFECTED, 8, g_CvarWeightBoomFocus, false);
	RegisterStat("Boom for tank", "tank_boom_assists", TEAM_INFECTED, 8, g_CvarWeightTankBoomAssist, false);
	RegisterStat("Spit on pinned", "spit_ticks_pinned", TEAM_INFECTED, 9, g_CvarWeightSpitPinnedTick, false);
	RegisterStat("Spit on incapped", "spit_ticks_incap", TEAM_INFECTED, 9, g_CvarWeightSpitIncapTick, false);
	RegisterStat("Spit multi-hits", "spit_multi_hits", TEAM_INFECTED, 9, g_CvarWeightSpitMulti, false);
	RegisterStat("Spit setups", "spit_setup_assists", TEAM_INFECTED, 9, g_CvarWeightSpitSetupAssist, false);
	RegisterStat("Tank time", "tank_hold_time", TEAM_INFECTED, 10, g_CvarWeightTankHoldSec, false);
	RegisterStat("Tank kills", "tank_kills", TEAM_INFECTED, 10, g_CvarWeightTankKill, false);
	RegisterStat("Tank wipes", "tank_wipe_bonus", TEAM_INFECTED, 10, g_CvarWeightTankWipe, false);
	RegisterStat("Tank passes", "tank_passes", TEAM_INFECTED, 10, g_CvarWeightTankPassPenalty, true);
	RegisterStat("Setups for tank", "tank_support", TEAM_INFECTED, 10, g_CvarWeightTankSupport, false);
	RegisterStat("Focus fire", "shared_focus", TEAM_INFECTED, 11, g_CvarWeightSharedFocus, false);
	RegisterStat("Stagger setups", "stagger_setup", TEAM_INFECTED, 11, g_CvarWeightStaggerSetup, false);
	RegisterStat("Witch assists", "witch_assists", TEAM_INFECTED, 11, g_CvarWeightWitchAssist, false);
	RegisterStat("Damage on standing", "dmg_si_upright", TEAM_INFECTED, 11, g_CvarWeightInfDamage, false);
	RegisterStat("Damage on downed", "dmg_on_incapped", TEAM_INFECTED, 11, g_CvarWeightInfDamageIncapped, false);
	RegisterStat("Tank vs average tank", "tank_dmg_rel", TEAM_INFECTED, 10, g_CvarWeightTankDamageRel, false);
}
