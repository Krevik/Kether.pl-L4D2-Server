#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2lib>
#include <builtinvotes>
#include <l4d2_skill_detect>
#include <readyup>

#define PLUGIN_VERSION "2.4.0"

#include "kether_skill_rating/globals.sp"

public Plugin myinfo =
{
	name = "Kether Skill Rating",
	author = "Kether + gpt-5.3-codex",
	description = "Round-normalized skill rating with local SQLite and skill mix vote",
	version = PLUGIN_VERSION,
	url = "kether.pl"
};

public void OnPluginStart()
{
	char error[256];
	g_Db = SQLite_UseDatabase(DB_NAME, error, sizeof(error));
	if (g_Db == null)
	{
		SetFailState("Failed to open SQLite DB '%s': %s", DB_NAME, error);
	}

	CreateTables();

	g_CvarEnabled = CreateConVar("sm_skill_rating_enabled", "1", "Enable/disable skill rating plugin", FCVAR_NONE, true, 0.0, true, 1.0);
	g_CvarEnabled.AddChangeHook(OnRatingEnabledChanged);
	g_CvarRoundPool = CreateConVar("sm_skill_rating_round_pool", "100.0", "Points distributed per team per round", FCVAR_NONE, true, 1.0, false);
	g_CvarWeightInfDamage = CreateConVar("sm_skill_w_inf_damage", "0.62", "Weight per point of damage a special infected deals to a standing survivor. Damage as tank and damage on incapped survivors have their own weights", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSurvDamage = CreateConVar("sm_skill_w_surv_damage", "0.0073", "Survivor damage weight (all damage to infected, tank included)", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTankDamage = CreateConVar("sm_skill_w_tank_damage", "0.018", "Extra weight for tank damage, stacks on top of sm_skill_w_surv_damage", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightWitchDamage = CreateConVar("sm_skill_w_witch_damage", "0.010", "Damage dealt to a witch (real witch only, see sm_skill_w_common_damage)", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightCommonKills = CreateConVar("sm_skill_w_common_kills", "0.190", "Common infected kill weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSpecialClear = CreateConVar("sm_skill_w_special_clear", "18.0", "Special clear weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSelfClear = CreateConVar("sm_skill_w_self_clear", "45.0", "Smoker self clear weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSkeet = CreateConVar("sm_skill_w_skeet", "65.0", "Skeet weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSkeetMelee = CreateConVar("sm_skill_w_skeet_melee", "0.0", "Melee skeet weight. Zero by default: melee kills a hunter in one hit on this server, so it is not the feat a shotgun skeet is", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightDeadstop = CreateConVar("sm_skill_w_deadstop", "40.0", "Deadstop weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightBoomerPop = CreateConVar("sm_skill_w_boomer_pop", "20.0", "No-vomit boomer pop weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightBoomerPopSplash = CreateConVar("sm_skill_w_boomer_pop_splash", "-25.0", "Penalty per teammate hit when a popped boomer still vomits", FCVAR_NONE, false, 0.0, false);
	g_CvarWeightPinAssist = CreateConVar("sm_skill_w_pin_assist", "0.0", "Assist weight for pin -> kill/incap synergy", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightPinDpsAssist = CreateConVar("sm_skill_w_pin_dps_assist", "0.0", "Assist weight per damage dealt to a pinned target by a teammate", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSpitPinnedTick = CreateConVar("sm_skill_w_spit_pinned_tick", "0.0", "Spitter tick on pinned target", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSpitIncapTick = CreateConVar("sm_skill_w_spit_incap_tick", "0.0", "Spitter tick on incapped target", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTankBoomAssist = CreateConVar("sm_skill_w_tank_boom_assist", "0.0", "Boomer assist when tank hits boomed target", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightWitchAssist = CreateConVar("sm_skill_w_witch_assist", "0.0", "Assist when witch downs a recently pinned/boomed target", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSpitSetupAssist = CreateConVar("sm_skill_w_spit_setup_assist", "6.0", "Assist when spit sets up a big hit within a short window", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightBoomKillAssist = CreateConVar("sm_skill_w_boom_kill_assist", "20.0", "Boomer assist when any SI kills a boomed target", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightBigHitAssistScore = CreateConVar("sm_skill_w_bighit_assist_score", "11.0", "Assist weight scaled by damage for CC-enabled big hits", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightShoveSI = CreateConVar("sm_skill_w_shove_si", "4.0", "Weight per shove on special infected", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightWitchCrown = CreateConVar("sm_skill_w_witch_crown", "45.0", "Weight for a validated witch crown", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightChargerMulti = CreateConVar("sm_skill_w_charger_multi", "0.0", "Weight per extra survivor clipped by one charge (charger_impact)", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSpitMulti = CreateConVar("sm_skill_w_spit_multi", "0.0", "Weight for spitter hitting multiple survivors in same tick window", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightRockSkeet = CreateConVar("sm_skill_w_rock_skeet", "40.0", "Weight per tank rock skeet by survivors", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightChainClearBoom = CreateConVar("sm_skill_w_chain_clear_boom", "20.0", "Weight for clearing/picking up a boomed teammate quickly", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSafeSave = CreateConVar("sm_skill_w_safe_save", "8.0", "Weight for fast save on pinned/incapped teammate", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightZeroFFBonus = CreateConVar("sm_skill_w_zero_ff_bonus", "15.0", "Bonus for a round with zero FF and sufficient actions", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSharedFocus = CreateConVar("sm_skill_w_shared_focus", "0.0", "Weight per shared focus hit (multiple SI on same target window)", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightBoomFocus = CreateConVar("sm_skill_w_boom_focus", "0.0", "Weight for boomer when teammates follow-up on boomed target", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightStaggerSetup = CreateConVar("sm_skill_w_stagger_setup", "0.0", "Weight for setups (stagger/slow) that enable other SI", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightChainControl = CreateConVar("sm_skill_w_chain_control", "40.0", "Weight for Smoker->Hunter/Jockey chain control assist", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTankSupport = CreateConVar("sm_skill_w_tank_support", "0.0", "Weight for assisting tank hits via boom/pin setup", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightAlarmPenalty = CreateConVar("sm_skill_w_alarm_penalty", "-35.0", "Penalty per car alarm triggered", FCVAR_NONE, false, 0.0, false);
	g_CvarWeightTankHoldSec = CreateConVar("sm_skill_w_tank_hold_sec", "0.0", "Weight per second holding tank. Zero by default: who gets the tank is a lottery, and what he does with it already counts as damage", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTankKill = CreateConVar("sm_skill_w_tank_kill", "0.0", "Weight per survivor kill by tank", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTankPassPenalty = CreateConVar("sm_skill_w_tank_pass_penalty", "-60.0", "Penalty per voluntary tank pass. kether_scoring_system pays the survivors a flat 48 points for every pass, even if they wipe later, so the passer costs his team real score", FCVAR_NONE, false, 0.0, false);
	g_CvarWeightTankWipe = CreateConVar("sm_skill_w_tank_wipe", "0.0", "Bonus when the human tank wipes the survivors", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightChargerLevel = CreateConVar("sm_skill_w_charger_level", "35.0", "Weight for leveling/interrupting charger", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTongueCut = CreateConVar("sm_skill_w_tongue_cut", "25.0", "Weight for cutting smoker tongue", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSpecialShove = CreateConVar("sm_skill_w_special_shove", "10.0", "Weight for a shove that actually broke a pin", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightRockEatenPenalty = CreateConVar("sm_skill_w_rock_eaten_penalty", "-25.0", "Penalty when survivor eats a tank rock", FCVAR_NONE, false, 0.0, false);
	g_CvarWeightReviveInterrupt = CreateConVar("sm_skill_w_revive_interrupt", "0.0", "Weight for interrupting a revive (infected)", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightRevive = CreateConVar("sm_skill_w_revive", "20.0", "Revive weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightMedkitGive = CreateConVar("sm_skill_w_medkit_give", "25.0", "Heal other with medkit weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightRescue = CreateConVar("sm_skill_w_rescue", "6.0", "Extra weight when the clear saved a teammate rather than yourself", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightJockeyBlock = CreateConVar("sm_skill_w_jockey_block", "4.0", "Jockey clear bonus, on top of the special clear", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTankPlayAction = CreateConVar("sm_skill_w_tankplay_action", "3.0", "Bonus for high-skill actions performed while tank is in play", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightFriendlyFire = CreateConVar("sm_skill_w_ff", "-3.0", "Penalty per friendly fire damage dealt", FCVAR_NONE, false, 0.0, false);
	g_CvarWeightHeadshotSI = CreateConVar("sm_skill_w_headshot_si", "1.5", "Weight per headshot on special infected", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSurvivalSec = CreateConVar("sm_skill_w_survival_sec", "0.0", "Weight per second alive in round. Zero by default: how long the team survived is the round result, not a measure of the player", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightFlowPercent = CreateConVar("sm_skill_w_flow_percent", "0.0", "Weight per % flow progress. Zero by default: map progress is the round result, shared by the whole team", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightBoomerVomitHit = CreateConVar("sm_skill_w_boomer_vomit_hit", "25.0", "Weight per boomer vomit victim (infected side)", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightBoomerVomitCast = CreateConVar("sm_skill_w_boomer_vomit_cast", "-25.0", "Penalty per boomer vomit cast (infected side). Equal to one hit, so a boomer scores on hits per cast, not on casts", FCVAR_NONE, false, 0.0, false);
	g_CvarTopListMax = CreateConVar("sm_skill_top_list_max", "100", "How many ranked players the leaderboard loads. The menu pages through them seven at a time", FCVAR_NONE, true, 7.0, false);
	g_CvarTopMinRounds = CreateConVar("sm_skill_top_min_rounds", "20", "Minimum rounds for KSR top/similar ranking (hard floor 20)", FCVAR_NONE, true, 0.0, false);
	g_CvarMixVotePct = CreateConVar("sm_skill_mix_vote_pct", "51", "Percent votes required for skill mix", FCVAR_NONE, true, 1.0, true, 100.0);
	g_CvarWeightCommonDamage = CreateConVar("sm_skill_w_common_damage", "0.0", "Damage dealt to common infected (0 = already covered by sm_skill_w_common_kills)", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightWitchKill = CreateConVar("sm_skill_w_witch_kill", "6.0", "Weight for killing a witch without a clean crown", FCVAR_NONE, true, 0.0, false);

	g_CvarRatingScale = CreateConVar("sm_skill_rating_scale", "1200.0", "KSR points per 1.0 of internal rating. Higher = wider spread between players. Pure presentation: it cannot change the order, only how far apart the numbers look", FCVAR_NONE, true, 50.0, false);
	g_CvarCarryWeight = CreateConVar("sm_skill_carry_weight", "0.5", "How much of the round score is judged against your own team instead of the server average. 0 = pure absolute score, which drags a good player down whenever his team loses. 1 = pure carry, which stops being comparable between teams", FCVAR_NONE, true, 0.0, true, 1.0);
	g_CvarRatingEmaMin = CreateConVar("sm_skill_rating_ema", "0.004", "Minimum EMA factor per round. 0.004 is roughly a 500 round memory. A short window tracks form but makes the ranking itself unstable, and form has its own line in the profile", FCVAR_NONE, true, 0.001, true, 1.0);
	g_CvarRatingShrinkRounds = CreateConVar("sm_skill_rating_shrink", "80", "Rounds of shrinkage towards the average for players with little history. Measured: at 20, players with 25 rounds outranked 700 round regulars", FCVAR_NONE, true, 0.0, false);
	g_CvarBaselineEma = CreateConVar("sm_skill_baseline_ema", "0.003", "EMA factor for the rolling per-side score baseline, applied once per scored player", FCVAR_NONE, true, 0.0001, true, 1.0);
	g_CvarSeedSurvMean = CreateConVar("sm_skill_seed_surv_mean", "213.0", "Seed value for the survivor raw score baseline", FCVAR_NONE, true, 1.0, false);
	g_CvarSeedSurvSd = CreateConVar("sm_skill_seed_surv_sd", "142.0", "Seed value for the survivor raw score spread", FCVAR_NONE, true, 1.0, false);
	g_CvarSeedInfMean = CreateConVar("sm_skill_seed_inf_mean", "130.0", "Seed value for the infected raw score baseline", FCVAR_NONE, true, 1.0, false);
	g_CvarSeedInfSd = CreateConVar("sm_skill_seed_inf_sd", "84.0", "Seed value for the infected raw score spread", FCVAR_NONE, true, 1.0, false);
	g_CvarWeightDeathCharge = CreateConVar("sm_skill_w_death_charge", "60.0", "Weight per death charge - the highest value single play the infected side has", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightHunterPounceDmg = CreateConVar("sm_skill_w_hunter_pounce_dmg", "0.5", "Weight per point of damage on a hunter high pounce", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightJockeyHighPounce = CreateConVar("sm_skill_w_jockey_high_pounce", "20.0", "Weight per jockey high pounce", FCVAR_NONE, true, 0.0, false);
	g_CvarMixShapeWarn = CreateConVar("sm_skill_mix_shape_warn", "250.0", "Difference in internal spread between the two teams, in KSR, above which the mix preview warns that equal sums hide an uneven match-up. 0 disables the warning", FCVAR_NONE, true, 0.0, false);
	g_CvarMixStackPenalty = CreateConVar("sm_skill_mix_stack_penalty", "75.0", "Extra team-sum difference, in KSR, that is acceptable in order to keep the two highest rated players apart. Kept small: over 494 lobbies a team holding both top players did no better than its sum predicted", FCVAR_NONE, true, 0.0, false);
	g_CvarMixLowStackPenalty = CreateConVar("sm_skill_mix_low_stack_penalty", "150.0", "Extra team-sum difference, in KSR, that is acceptable in order to keep the two lowest rated players apart. 150 keeps them apart in 98% of 4v4 lobbies; set it very high (1000) to make it a hard rule, at the price of a much worse sum balance in uneven lobbies. 0 disables it", FCVAR_NONE, true, 0.0, false);
	g_CvarMixWeakMargin = CreateConVar("sm_skill_mix_weak_margin", "100.0", "How far below the lobby's average mix KSR a player has to be to count as weak for sm_skill_mix_weak_group_penalty. At 100 a full lobby has three weak players about half the time and four about one time in five", FCVAR_NONE, true, 0.0, false);
	g_CvarMixWeakGroupPenalty = CreateConVar("sm_skill_mix_weak_group_penalty", "150.0", "Extra team-sum difference, in KSR, accepted per player it would take to split the weak group evenly (four weak players two and two). 150 splits four weak players evenly in 95% of 4v4 lobbies; 1000 makes it a hard rule. 0 disables it", FCVAR_NONE, true, 0.0, false);
	g_CvarMixTolerance = CreateConVar("sm_skill_mix_tolerance", "40.0", "Team-sum KSR the split search may give up for a better shaped match-up (stars apart, equal spread, both halves of the map even). 0 = secondary criteria only break exact ties, which in practice means never", FCVAR_NONE, true, 0.0, false);
	g_CvarMixWarnDelta = CreateConVar("sm_skill_mix_warn_delta", "75.0", "Average KSR gap between teams above which a mix is suggested during ready-up. At 75 the stronger side wins about 60 percent of maps", FCVAR_NONE, true, 0.0, false);
	g_CvarMixLowCompress = CreateConVar("sm_skill_mix_low_compress", "0.75", "Share of the distance below 1000 that counts in the mix number. On real map results a KSR point under 1000 was worth about 55% of one above it; 0.75 removes half of that bias while staying clear of overfitting. 1 = no compression", FCVAR_NONE, true, 0.1, true, 1.0);
	g_CvarMixShrink = CreateConVar("sm_skill_mix_shrink", "20", "Rounds of shrinkage used for the number the mix and the balance lines work on. Lower than sm_skill_rating_shrink on purpose: the ladder has to be hard to climb on a short history, but a mix only has to predict the next map, and measured on 619 maps the lightly shrunk number does that better", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightInfDamageIncapped = CreateConVar("sm_skill_w_inf_damage_incapped", "0.15", "Weight per point of infected damage on an incapped survivor. Low on purpose: it comes off the 300 point bleed-out pool and is worth nothing unless it finishes him", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTankDamageRel = CreateConVar("sm_skill_w_tank_damage_rel", "0.62", "Weight per point of standing-survivor damage as tank, counted against what an average tank does per life. Getting the tank is a lottery worth half a standard deviation by itself; this way only playing it better or worse than average counts", FCVAR_NONE, true, 0.0, false);
	g_CvarSeedTankDmgLife = CreateConVar("sm_skill_seed_tank_dmg_life", "100.0", "Starting value for the standing-survivor damage an average tank does per life, used until the server has learned its own", FCVAR_NONE, true, 0.0, false);
	g_CvarReadyBalanceInfo = CreateConVar("sm_skill_ready_balance_info", "1", "Announce team KSR balance when the live countdown starts", FCVAR_NONE, true, 0.0, true, 1.0);

	// v2 changed almost every weight default. AutoExecConfig never rewrites values
	// that already exist in a config, so the old file would silently pin the whole
	// plugin back to the v1 weights - hence the new filename.
	AutoExecConfig(true, KSR_CONFIG_NAME);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	HookEvent("infected_hurt", Event_InfectedHurt, EventHookMode_Post);
	HookEvent("infected_death", Event_InfectedDeath, EventHookMode_Post);
	HookEvent("player_incapacitated", Event_PlayerIncapacitated, EventHookMode_Post);
	HookEvent("player_now_it", Event_PlayerBoomed, EventHookMode_Post);
	HookEvent("tongue_grab", Event_PinStart_Smoker, EventHookMode_Post);
	HookEvent("tongue_pull_stopped", Event_PinEnd_Generic, EventHookMode_Post);
	HookEvent("choke_start", Event_PinStart_Smoker, EventHookMode_Post);
	HookEvent("choke_stopped", Event_PinEnd_Generic, EventHookMode_Post);
	HookEvent("jockey_ride", Event_PinStart_Jockey, EventHookMode_Post);
	HookEvent("jockey_ride_end", Event_PinEnd_Generic, EventHookMode_Post);
	HookEvent("charger_carry_start", Event_PinStart_Charger, EventHookMode_Post);
	HookEvent("charger_carry_end", Event_PinEnd_Generic, EventHookMode_Post);
	HookEvent("charger_pummel_start", Event_PinStart_Charger, EventHookMode_Post);
	HookEvent("charger_pummel_end", Event_PinEnd_Generic, EventHookMode_Post);
	HookEvent("lunge_pounce", Event_PinStart_Hunter, EventHookMode_Post);
	HookEvent("revive_success", Event_ReviveSuccess, EventHookMode_Post);
	HookEvent("heal_begin", Event_HealBegin, EventHookMode_Post);
	HookEvent("heal_success", Event_HealSuccess, EventHookMode_Post);
	HookEvent("revive_begin", Event_ReviveBegin, EventHookMode_Post);
	HookEvent("revive_end", Event_ReviveEnd, EventHookMode_Post);
	HookEvent("ability_use", Event_AbilityUse, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);
	HookEvent("witch_killed", Event_WitchKilled, EventHookMode_Post);
	HookEvent("tank_spawn", Event_TankSpawn, EventHookMode_PostNoCopy);
	HookEvent("charger_impact", Event_ChargerImpact, EventHookMode_Post);

	RegConsoleCmd("sm_skill", Command_Skill, "Open KSR (Kether Skill Rating) menu");
	RegConsoleCmd("sm_myskill", Command_Skill, "Open KSR (Kether Skill Rating) menu");
	RegConsoleCmd("sm_skilltop", Command_SkillTop, "Show top KSR leaderboard");
	RegConsoleCmd("sm_skillsim", Command_SkillSim, "Show players with similar KSR rank");
	RegConsoleCmd("sm_skillmix", Command_SkillMixVote, "Call vote to mix teams by KSR");
	RegConsoleCmd("sm_skillstats", Command_SkillBreakdown, "Show where your KSR points come from");

	g_bReadyUpAvailable = LibraryExists("readyup");

	RegisterStats();

	SeedBaselines();
	LoadBaselines();

	// AutoExecConfig only ever ADDS missing cvars to an existing config; it never
	// rewrites a value that is already in the file. So once the config exists, every
	// later change to a default in this plugin is silently ignored on that server.
	// That bit us for real: the model shipped with a 500 round memory while the live
	// server kept running the 65 round one from the first generated config, and
	// nobody could see it. Checked one tick after AutoExecConfig has run.
	CreateTimer(1.0, Timer_WarnStaleConfig, _, TIMER_FLAG_NO_MAPCHANGE);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidHuman(i))
		{
			LoadPlayerProfile(i);
		}
	}
}

#include "kether_skill_rating/lifecycle.sp"

#include "kether_skill_rating/scoring.sp"

#include "kether_skill_rating/events.sp"

#include "kether_skill_rating/menus.sp"

#include "kether_skill_rating/votes_admin.sp"

#include "kether_skill_rating/mix.sp"

#include "kether_skill_rating/ranking.sp"

#include "kether_skill_rating/profiles.sp"

#include "kether_skill_rating/tracking.sp"

#include "kether_skill_rating/state.sp"

#include "kether_skill_rating/helpers.sp"

#include "kether_skill_rating/schema.sp"

#include "kether_skill_rating/stat_registry.sp"

#include "kether_skill_rating/database.sp"
