#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2lib>
#include <builtinvotes>
#include <l4d2_skill_detect>
#include <readyup>

#define PLUGIN_VERSION "2.0.0"
#define DB_NAME "kether_skill_rating"

// Scoring model revision. Bumped whenever weights or detection semantics change,
// so rounds from different revisions can be told apart in round_stats.
#define KSR_SCORING_VERSION 2

#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

#define ZC_TANK 8
#define ZC_JOCKEY 5
#define ZC_BOOMER 2
#define ZC_SPITTER 4
#define ZC_SMOKER 1
#define ZC_HUNTER 3
#define ZC_CHARGER 6

#define PIN_ASSIST_WINDOW 10.0
#define BOOM_ASSIST_WINDOW 20.0
#define CHARGE_ASSIST_WINDOW 10.0
#define SPIT_SETUP_WINDOW 2.0

#define MIX_MIN_TEAM_SIZE 1
#define MIX_MAX_TEAM_SIZE 8
#define SKILL_RANK_LIST_MAX 512
#define SKILL_SIMILAR_COUNT 5
#define SKILL_TOP_MIN_ROUNDS_FLOOR 20

// Rating scale: KSR = KSR_BASE + scale * shrunk rating. Rating itself is an EMA of
// per-round z-scores, so it is centred on 0 with a spread of roughly +-0.4.
#define KSR_BASE 1000.0
#define KSR_Z_CLAMP 3.0

stock float FloatClamp(float value, float minVal, float maxVal)
{
	if (value < minVal)
	{
		return minVal;
	}
	if (value > maxVal)
	{
		return maxVal;
	}
	return value;
}

// Every scored component, so the "where do my points come from" screen covers the
// whole model rather than a hand-picked sample of it. Adding a weight to
// ComputeRawRoundScore means adding a line to RegisterStats() as well.
#define KSR_MAX_STATS 64
#define KSR_CATEGORIES 12

enum struct KsrStat
{
	char label[28];
	char column[28];
	int side;
	int category;
	ConVar weight;
	bool lowerIsBetter;
}

KsrStat g_Stats[KSR_MAX_STATS];
int g_iStatCount = 0;

char g_sCategoryName[KSR_CATEGORIES][] = {
	"Damage and kills",
	"Clears and saves",
	"Technical plays",
	"Support",
	"Progress",
	"Discipline",
	"Pins and control",
	"Big plays",
	"Boomer",
	"Spitter",
	"Tank",
	"Teamwork and damage"
};

// Cached result of the last breakdown query, per viewer, so the category
// drill-down does not have to hit the database again.
float g_fBdMine[MAXPLAYERS + 1][KSR_MAX_STATS];
float g_fBdAvg[MAXPLAYERS + 1][KSR_MAX_STATS];
int g_iBdRounds[MAXPLAYERS + 1][4];
char g_sBdName[MAXPLAYERS + 1][160];
bool g_bBdReady[MAXPLAYERS + 1];

Database g_Db = null;

ConVar g_CvarEnabled;
ConVar g_CvarRoundPool;
ConVar g_CvarWeightInfDamage;
ConVar g_CvarWeightSurvDamage;
ConVar g_CvarWeightTankDamage;
ConVar g_CvarWeightWitchDamage;
ConVar g_CvarWeightCommonKills;
ConVar g_CvarWeightSpecialClear;
ConVar g_CvarWeightSelfClear;
ConVar g_CvarWeightSkeet;
ConVar g_CvarWeightSkeetMelee;
ConVar g_CvarWeightDeadstop;
ConVar g_CvarWeightBoomerPop;
ConVar g_CvarWeightBoomerPopSplash;
ConVar g_CvarWeightPinAssist;
ConVar g_CvarWeightPinDpsAssist;
ConVar g_CvarWeightSpitPinnedTick;
ConVar g_CvarWeightSpitIncapTick;
ConVar g_CvarWeightTankBoomAssist;
ConVar g_CvarWeightWitchAssist;
ConVar g_CvarWeightSpitSetupAssist;
ConVar g_CvarWeightBoomKillAssist;
ConVar g_CvarWeightBigHitAssistScore;
ConVar g_CvarWeightShoveSI;
ConVar g_CvarWeightWitchCrown;
ConVar g_CvarWeightChargerMulti;
ConVar g_CvarWeightSpitMulti;
ConVar g_CvarWeightRockSkeet;
ConVar g_CvarWeightChainClearBoom;
ConVar g_CvarWeightSafeSave;
ConVar g_CvarWeightZeroFFBonus;
ConVar g_CvarWeightSharedFocus;
ConVar g_CvarWeightBoomFocus;
ConVar g_CvarWeightStaggerSetup;
ConVar g_CvarWeightChainControl;
ConVar g_CvarWeightTankSupport;
ConVar g_CvarWeightAlarmPenalty;
ConVar g_CvarWeightTankHoldSec;
ConVar g_CvarWeightTankKill;
ConVar g_CvarWeightTankPassPenalty;
ConVar g_CvarWeightTankWipe;
ConVar g_CvarWeightChargerLevel;
ConVar g_CvarWeightTongueCut;
ConVar g_CvarWeightSpecialShove;
ConVar g_CvarWeightRockEatenPenalty;
ConVar g_CvarWeightReviveInterrupt;
ConVar g_CvarWeightRevive;
ConVar g_CvarWeightMedkitGive;
ConVar g_CvarWeightRescue;
ConVar g_CvarWeightJockeyBlock;
ConVar g_CvarWeightTankPlayAction;
ConVar g_CvarWeightFriendlyFire;
ConVar g_CvarWeightHeadshotSI;
ConVar g_CvarWeightSurvivalSec;
ConVar g_CvarWeightFlowPercent;
ConVar g_CvarWeightBoomerVomitHit;
ConVar g_CvarWeightBoomerVomitCast;
ConVar g_CvarTopMinRounds;
ConVar g_CvarMixVotePct;
ConVar g_CvarWeightCommonDamage;
ConVar g_CvarWeightWitchKill;
ConVar g_CvarRatingScale;
ConVar g_CvarRatingEmaMin;
ConVar g_CvarRatingShrinkRounds;
ConVar g_CvarBaselineEma;
ConVar g_CvarSeedSurvMean;
ConVar g_CvarSeedSurvSd;
ConVar g_CvarSeedInfMean;
ConVar g_CvarSeedInfSd;
ConVar g_CvarWeightDeathCharge;
ConVar g_CvarWeightHunterPounceDmg;
ConVar g_CvarWeightJockeyHighPounce;
ConVar g_CvarMixTolerance;
ConVar g_CvarMixWarnDelta;
ConVar g_CvarReadyBalanceInfo;

bool g_bRoundActive = false;
bool g_bRoundFinalized = false;
bool g_bRoundLive = false;
bool g_bPaused = false;
int g_iRoundNumber = 0;
char g_sMapName[64];
bool g_bReadyUpAvailable = false;

float g_fTotalPoints[MAXPLAYERS + 1];
int g_iRoundsPlayed[MAXPLAYERS + 1];

// New rating model: EMA of per-round z-scores, centred on 0.
float g_fRating[MAXPLAYERS + 1];
int g_iRatingRounds[MAXPLAYERS + 1];

// The profile query is asynchronous. Until it lands the in-memory rating is a
// zero placeholder, and writing that back would erase the player's real history.
bool g_bProfileLoaded[MAXPLAYERS + 1];

// Survivor and infected ability correlate at 0.78 - close, but not the same
// player. Tracked separately for the profile card and for matching the shape of
// the two teams during a mix; the ranking itself still uses the combined number.
float g_fRatingSide[4][MAXPLAYERS + 1];
int g_iRatingSideRounds[4][MAXPLAYERS + 1];

// z-score of the round just scored, written to round_stats so recent form can be
// read back without recomputing anything.
float g_fLastRoundZ[MAXPLAYERS + 1];

// Rolling per-side baselines used to turn a raw round score into a z-score.
float g_fBaseMean[4];
float g_fBaseSd[4];
int g_iBaseCount[4];

// Roster snapshot taken when the round goes live, so a late leaver cannot
// invalidate the round for everyone else.
bool g_bWasLive[MAXPLAYERS + 1];
int g_iLiveSurvCount = 0;
int g_iLiveInfCount = 0;

int g_iReadyFooterIndex = -1;
char g_sFirstName[MAXPLAYERS + 1][MAX_NAME_LENGTH];
char g_sLastName[MAXPLAYERS + 1][MAX_NAME_LENGTH];

int g_iDamageAsInfected[MAXPLAYERS + 1];
int g_iDamageAsSurvivor[MAXPLAYERS + 1];
int g_iTankDamageAsSurvivor[MAXPLAYERS + 1];
int g_iWitchDamageAsSurvivor[MAXPLAYERS + 1];
int g_iCommonDamageAsSurvivor[MAXPLAYERS + 1];
int g_iCommonKillsAsSurvivor[MAXPLAYERS + 1];
int g_iWitchKills[MAXPLAYERS + 1];

int g_iSpecialClears[MAXPLAYERS + 1];
int g_iSmokerSelfClears[MAXPLAYERS + 1];
int g_iSkeets[MAXPLAYERS + 1];
int g_iSkeetsMelee[MAXPLAYERS + 1];
int g_iDeadstops[MAXPLAYERS + 1];
int g_iBoomerPopsNoVomit[MAXPLAYERS + 1];
int g_iBoomerPopsSplash[MAXPLAYERS + 1];
int g_iPinAssists[MAXPLAYERS + 1];
int g_iBigHitAssists[MAXPLAYERS + 1];
float g_fPinDpsAssists[MAXPLAYERS + 1];
int g_iSpitPinnedTicks[MAXPLAYERS + 1];
int g_iSpitIncapTicks[MAXPLAYERS + 1];
int g_iTankBoomAssists[MAXPLAYERS + 1];
int g_iWitchAssists[MAXPLAYERS + 1];
int g_iSpitSetupAssists[MAXPLAYERS + 1];
int g_iBoomKillAssists[MAXPLAYERS + 1];
float g_fBigHitAssistScore[MAXPLAYERS + 1];
int g_iShoveSI[MAXPLAYERS + 1];
int g_iWitchCrowns[MAXPLAYERS + 1];
int g_iChargerMulti[MAXPLAYERS + 1];
int g_iSpitMultiHits[MAXPLAYERS + 1];
int g_iChargeImpactCount[MAXPLAYERS + 1];
float g_fChargeImpactStart[MAXPLAYERS + 1];
float g_fSpitHitWindowStart[MAXPLAYERS + 1];
int g_iSpitHitWindowCount[MAXPLAYERS + 1];
int g_iSpitHitWindowLastVictim[MAXPLAYERS + 1];
int g_iRockSkeets[MAXPLAYERS + 1];
int g_iChainClearBoom[MAXPLAYERS + 1];
int g_iSafeSaves[MAXPLAYERS + 1];
int g_iZeroFFBonus[MAXPLAYERS + 1];
int g_iSharedFocus[MAXPLAYERS + 1];
int g_iBoomFocusAssist[MAXPLAYERS + 1];
int g_iStaggerSetup[MAXPLAYERS + 1];
int g_iChainControlAssist[MAXPLAYERS + 1];
int g_iTankSupportAssist[MAXPLAYERS + 1];
int g_iAlarmTriggers[MAXPLAYERS + 1];
float g_fTankHoldTime[MAXPLAYERS + 1];
int g_iTankPasses[MAXPLAYERS + 1];
int g_iTankKills[MAXPLAYERS + 1];
int g_iTankWipeBonus[MAXPLAYERS + 1];
int g_iChargerLevels[MAXPLAYERS + 1];
int g_iTongueCuts[MAXPLAYERS + 1];
int g_iSpecialShoveSaves[MAXPLAYERS + 1];
int g_iRockEatenPenalty[MAXPLAYERS + 1];
int g_iReviveInterrupts[MAXPLAYERS + 1];
int g_iDeathCharges[MAXPLAYERS + 1];
int g_iHunterPounceDamage[MAXPLAYERS + 1];
int g_iJockeyHighPounces[MAXPLAYERS + 1];

int g_iReviveTargetForReviver[MAXPLAYERS + 1];
float g_fReviveStartTime[MAXPLAYERS + 1];
int g_iRevives[MAXPLAYERS + 1];
int g_iMedkitGives[MAXPLAYERS + 1];
int g_iRescuesFromSpecial[MAXPLAYERS + 1];
int g_iJockeyBlocks[MAXPLAYERS + 1];
int g_iTankPlayActions[MAXPLAYERS + 1];
int g_iFriendlyFireDealt[MAXPLAYERS + 1];
int g_iFriendlyFireTaken[MAXPLAYERS + 1];
int g_iHeadshotSI[MAXPLAYERS + 1];
int g_iBoomerVomitCasts[MAXPLAYERS + 1];
int g_iBoomerVomitHits[MAXPLAYERS + 1];

float g_fLifeStart[MAXPLAYERS + 1];
float g_fSurvivalTime[MAXPLAYERS + 1];
bool g_bAliveAtEnd[MAXPLAYERS + 1];
float g_fFlowBest[MAXPLAYERS + 1];
Handle g_hFlowTimer = null;
bool g_bIncapped[MAXPLAYERS + 1];
int g_iCurrentTank = 0;
int g_iLastHumanTank = 0;
float g_fTankHoldStart = 0.0;

int g_iLastBoomerKiller[MAXPLAYERS + 1];
float g_fLastBoomerDeathTime[MAXPLAYERS + 1];
int g_iLastPinner[MAXPLAYERS + 1];
int g_iLastPinnerClass[MAXPLAYERS + 1];
bool g_bPinActive[MAXPLAYERS + 1];
float g_fLastPinStart[MAXPLAYERS + 1];
float g_fLastPinEnd[MAXPLAYERS + 1];
int g_iLastBoomerForVictim[MAXPLAYERS + 1];
float g_fLastBoomTime[MAXPLAYERS + 1];
int g_iLastSpitterForVictim[MAXPLAYERS + 1];
float g_fLastSpitTime[MAXPLAYERS + 1];
int g_iLastAttackerForVictim[MAXPLAYERS + 1];
float g_fLastAttackTime[MAXPLAYERS + 1];
int g_iLastStaggerer[MAXPLAYERS + 1];
float g_fLastStaggerTime[MAXPLAYERS + 1];

bool g_bHealStartedToOther[MAXPLAYERS + 1];

bool g_bMixVoteInProgress = false;
Handle g_hMixVote = INVALID_HANDLE;

// The split is decided when the vote is called, not when it passes, so that the
// teams people see in the preview are the teams they get.
int g_iPlannedSurv[MAXPLAYERS + 1];
int g_iPlannedInf[MAXPLAYERS + 1];
int g_iPlannedSurvCount = 0;
int g_iPlannedInfCount = 0;
Handle g_hMixApplyTimer = null;
int g_iMixApplyStep = 0;

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
	g_CvarRoundPool = CreateConVar("sm_skill_rating_round_pool", "100.0", "Points distributed per team per round", FCVAR_NONE, true, 1.0, false);
	g_CvarWeightInfDamage = CreateConVar("sm_skill_w_inf_damage", "0.207", "Infected damage weight (damage dealt to survivors)", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSurvDamage = CreateConVar("sm_skill_w_surv_damage", "0.0073", "Survivor damage weight (all damage to infected, tank included)", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTankDamage = CreateConVar("sm_skill_w_tank_damage", "0.018", "Extra weight for tank damage, stacks on top of sm_skill_w_surv_damage", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightWitchDamage = CreateConVar("sm_skill_w_witch_damage", "0.010", "Damage dealt to a witch (real witch only, see sm_skill_w_common_damage)", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightCommonKills = CreateConVar("sm_skill_w_common_kills", "0.190", "Common infected kill weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSpecialClear = CreateConVar("sm_skill_w_special_clear", "18.0", "Special clear weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSelfClear = CreateConVar("sm_skill_w_self_clear", "45.0", "Smoker self clear weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSkeet = CreateConVar("sm_skill_w_skeet", "65.0", "Skeet weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSkeetMelee = CreateConVar("sm_skill_w_skeet_melee", "85.0", "Melee skeet weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightDeadstop = CreateConVar("sm_skill_w_deadstop", "40.0", "Deadstop weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightBoomerPop = CreateConVar("sm_skill_w_boomer_pop", "20.0", "No-vomit boomer pop weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightBoomerPopSplash = CreateConVar("sm_skill_w_boomer_pop_splash", "-25.0", "Penalty per teammate hit when a popped boomer still vomits", FCVAR_NONE, false, 0.0, false);
	g_CvarWeightPinAssist = CreateConVar("sm_skill_w_pin_assist", "38.0", "Assist weight for pin -> kill/incap synergy", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightPinDpsAssist = CreateConVar("sm_skill_w_pin_dps_assist", "0.58", "Assist weight per damage dealt to a pinned target by a teammate", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSpitPinnedTick = CreateConVar("sm_skill_w_spit_pinned_tick", "2.1", "Spitter tick on pinned target", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSpitIncapTick = CreateConVar("sm_skill_w_spit_incap_tick", "1.3", "Spitter tick on incapped target", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTankBoomAssist = CreateConVar("sm_skill_w_tank_boom_assist", "11.0", "Boomer assist when tank hits boomed target", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightWitchAssist = CreateConVar("sm_skill_w_witch_assist", "20.0", "Assist when witch downs a recently pinned/boomed target", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSpitSetupAssist = CreateConVar("sm_skill_w_spit_setup_assist", "6.0", "Assist when spit sets up a big hit within a short window", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightBoomKillAssist = CreateConVar("sm_skill_w_boom_kill_assist", "20.0", "Boomer assist when any SI kills a boomed target", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightBigHitAssistScore = CreateConVar("sm_skill_w_bighit_assist_score", "11.0", "Assist weight scaled by damage for CC-enabled big hits", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightShoveSI = CreateConVar("sm_skill_w_shove_si", "4.0", "Weight per shove on special infected", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightWitchCrown = CreateConVar("sm_skill_w_witch_crown", "45.0", "Weight for a validated witch crown", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightChargerMulti = CreateConVar("sm_skill_w_charger_multi", "25.0", "Weight per extra survivor clipped by one charge (charger_impact)", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSpitMulti = CreateConVar("sm_skill_w_spit_multi", "1.5", "Weight for spitter hitting multiple survivors in same tick window", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightRockSkeet = CreateConVar("sm_skill_w_rock_skeet", "40.0", "Weight per tank rock skeet by survivors", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightChainClearBoom = CreateConVar("sm_skill_w_chain_clear_boom", "20.0", "Weight for clearing/picking up a boomed teammate quickly", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSafeSave = CreateConVar("sm_skill_w_safe_save", "8.0", "Weight for fast save on pinned/incapped teammate", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightZeroFFBonus = CreateConVar("sm_skill_w_zero_ff_bonus", "15.0", "Bonus for a round with zero FF and sufficient actions", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSharedFocus = CreateConVar("sm_skill_w_shared_focus", "0.85", "Weight per shared focus hit (multiple SI on same target window)", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightBoomFocus = CreateConVar("sm_skill_w_boom_focus", "1.5", "Weight for boomer when teammates follow-up on boomed target", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightStaggerSetup = CreateConVar("sm_skill_w_stagger_setup", "2.7", "Weight for setups (stagger/slow) that enable other SI", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightChainControl = CreateConVar("sm_skill_w_chain_control", "25.0", "Weight for Smoker->Hunter/Jockey chain control assist", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTankSupport = CreateConVar("sm_skill_w_tank_support", "8.0", "Weight for assisting tank hits via boom/pin setup", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightAlarmPenalty = CreateConVar("sm_skill_w_alarm_penalty", "-35.0", "Penalty per car alarm triggered", FCVAR_NONE, false, 0.0, false);
	g_CvarWeightTankHoldSec = CreateConVar("sm_skill_w_tank_hold_sec", "0.73", "Weight per second holding tank", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTankKill = CreateConVar("sm_skill_w_tank_kill", "60.0", "Weight per survivor kill by tank", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTankPassPenalty = CreateConVar("sm_skill_w_tank_pass_penalty", "-60.0", "Penalty per voluntary tank pass", FCVAR_NONE, false, 0.0, false);
	g_CvarWeightTankWipe = CreateConVar("sm_skill_w_tank_wipe", "60.0", "Bonus when the human tank wipes the survivors", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightChargerLevel = CreateConVar("sm_skill_w_charger_level", "35.0", "Weight for leveling/interrupting charger", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTongueCut = CreateConVar("sm_skill_w_tongue_cut", "25.0", "Weight for cutting smoker tongue", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSpecialShove = CreateConVar("sm_skill_w_special_shove", "10.0", "Weight for a shove that actually broke a pin", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightRockEatenPenalty = CreateConVar("sm_skill_w_rock_eaten_penalty", "-25.0", "Penalty when survivor eats a tank rock", FCVAR_NONE, false, 0.0, false);
	g_CvarWeightReviveInterrupt = CreateConVar("sm_skill_w_revive_interrupt", "20.0", "Weight for interrupting a revive (infected)", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightRevive = CreateConVar("sm_skill_w_revive", "20.0", "Revive weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightMedkitGive = CreateConVar("sm_skill_w_medkit_give", "25.0", "Heal other with medkit weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightRescue = CreateConVar("sm_skill_w_rescue", "6.0", "Extra weight when the clear saved a teammate rather than yourself", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightJockeyBlock = CreateConVar("sm_skill_w_jockey_block", "4.0", "Jockey clear bonus, on top of the special clear", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTankPlayAction = CreateConVar("sm_skill_w_tankplay_action", "3.0", "Bonus for high-skill actions performed while tank is in play", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightFriendlyFire = CreateConVar("sm_skill_w_ff", "-3.0", "Penalty per friendly fire damage dealt", FCVAR_NONE, false, 0.0, false);
	g_CvarWeightHeadshotSI = CreateConVar("sm_skill_w_headshot_si", "1.5", "Weight per headshot on special infected", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSurvivalSec = CreateConVar("sm_skill_w_survival_sec", "0.029", "Weight per second alive in round", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightFlowPercent = CreateConVar("sm_skill_w_flow_percent", "0.32", "Weight per % flow progress (best without tank)", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightBoomerVomitHit = CreateConVar("sm_skill_w_boomer_vomit_hit", "25.0", "Weight per boomer vomit victim (infected side)", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightBoomerVomitCast = CreateConVar("sm_skill_w_boomer_vomit_cast", "-10.0", "Penalty per boomer vomit cast (infected side)", FCVAR_NONE, false, 0.0, false);
	g_CvarTopMinRounds = CreateConVar("sm_skill_top_min_rounds", "20", "Minimum rounds for KSR top/similar ranking (hard floor 20)", FCVAR_NONE, true, 0.0, false);
	g_CvarMixVotePct = CreateConVar("sm_skill_mix_vote_pct", "51", "Percent votes required for skill mix", FCVAR_NONE, true, 1.0, true, 100.0);
	g_CvarWeightCommonDamage = CreateConVar("sm_skill_w_common_damage", "0.0", "Damage dealt to common infected (0 = already covered by sm_skill_w_common_kills)", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightWitchKill = CreateConVar("sm_skill_w_witch_kill", "6.0", "Weight for killing a witch without a clean crown", FCVAR_NONE, true, 0.0, false);

	g_CvarRatingScale = CreateConVar("sm_skill_rating_scale", "600.0", "KSR points per 1.0 of internal rating. Higher = wider spread between players", FCVAR_NONE, true, 50.0, false);
	g_CvarRatingEmaMin = CreateConVar("sm_skill_rating_ema", "0.03", "Minimum EMA factor per round. 0.03 is roughly a 65 round memory", FCVAR_NONE, true, 0.001, true, 1.0);
	g_CvarRatingShrinkRounds = CreateConVar("sm_skill_rating_shrink", "20", "Rounds of shrinkage towards the average for players with little history", FCVAR_NONE, true, 0.0, false);
	g_CvarBaselineEma = CreateConVar("sm_skill_baseline_ema", "0.003", "EMA factor for the rolling per-side score baseline, applied once per scored player", FCVAR_NONE, true, 0.0001, true, 1.0);
	g_CvarSeedSurvMean = CreateConVar("sm_skill_seed_surv_mean", "248.0", "Seed value for the survivor raw score baseline", FCVAR_NONE, true, 1.0, false);
	g_CvarSeedSurvSd = CreateConVar("sm_skill_seed_surv_sd", "141.0", "Seed value for the survivor raw score spread", FCVAR_NONE, true, 1.0, false);
	g_CvarSeedInfMean = CreateConVar("sm_skill_seed_inf_mean", "218.0", "Seed value for the infected raw score baseline", FCVAR_NONE, true, 1.0, false);
	g_CvarSeedInfSd = CreateConVar("sm_skill_seed_inf_sd", "146.0", "Seed value for the infected raw score spread", FCVAR_NONE, true, 1.0, false);
	g_CvarWeightDeathCharge = CreateConVar("sm_skill_w_death_charge", "60.0", "Weight per death charge - the highest value single play the infected side has", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightHunterPounceDmg = CreateConVar("sm_skill_w_hunter_pounce_dmg", "0.5", "Weight per point of damage on a hunter high pounce", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightJockeyHighPounce = CreateConVar("sm_skill_w_jockey_high_pounce", "20.0", "Weight per jockey high pounce", FCVAR_NONE, true, 0.0, false);
	g_CvarMixTolerance = CreateConVar("sm_skill_mix_tolerance", "0.0", "KSR the split search may give up on team-sum balance for a better shaped match-up. 0 = never trade away balance, secondary criteria only break exact ties", FCVAR_NONE, true, 0.0, false);
	g_CvarMixWarnDelta = CreateConVar("sm_skill_mix_warn_delta", "150.0", "KSR gap between teams above which a mix is suggested during ready-up", FCVAR_NONE, true, 0.0, false);
	g_CvarReadyBalanceInfo = CreateConVar("sm_skill_ready_balance_info", "1", "Announce team KSR balance when the live countdown starts", FCVAR_NONE, true, 0.0, true, 1.0);

	// v2 changed almost every weight default. AutoExecConfig never rewrites values
	// that already exist in a config, so the old file would silently pin the whole
	// plugin back to the v1 weights - hence the new filename.
	AutoExecConfig(true, "kether_skill_rating_v2");

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

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidHuman(i))
		{
			LoadPlayerProfile(i);
		}
	}
}

public void OnMapStart()
{
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));
}

public void OnAllPluginsLoaded()
{
	g_bReadyUpAvailable = LibraryExists("readyup");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "readyup"))
	{
		g_bReadyUpAvailable = true;
		// readyup keeps its footer list for the lifetime of the plugin, so the slot
		// is only stale when readyup itself was reloaded.
		g_iReadyFooterIndex = -1;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "readyup"))
	{
		g_bReadyUpAvailable = false;
		g_iReadyFooterIndex = -1;
	}
}

public void OnMapEnd()
{
	FinalizeRoundIfNeeded();
	delete g_hFlowTimer;
	delete g_hMixApplyTimer;
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_CvarEnabled.BoolValue)
	{
		return;
	}
	int client = GetClientOfUserId(event.GetInt("userid"));
	StartTankHold(client);
}

public void OnClientPostAdminCheck(int client)
{
	if (!IsValidHuman(client))
	{
		return;
	}

	TryMergeSteamIdVariantsForClient(client);
	ResetRoundStats(client);
	g_fTotalPoints[client] = 0.0;
	g_iRoundsPlayed[client] = 0;
	ResetRatingCache(client);
	g_bWasLive[client] = false;
	LoadPlayerProfile(client);
}

public void OnClientDisconnect(int client)
{
	if (g_iCurrentTank == client)
	{
		EndTankHoldSegment(client);
	}
	ResetRoundStats(client);
	g_fTotalPoints[client] = 0.0;
	g_iRoundsPlayed[client] = 0;
	ResetRatingCache(client);
	g_bWasLive[client] = false;
	g_sFirstName[client][0] = '\0';
	g_sLastName[client][0] = '\0';
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_CvarEnabled.BoolValue)
	{
		return;
	}

	g_bRoundActive = true;
	g_bRoundLive = g_bReadyUpAvailable ? false : true;
	g_bRoundFinalized = false;
	g_bPaused = false;
	g_iRoundNumber++;
	g_iCurrentTank = 0;
	g_iLastHumanTank = 0;
	g_fTankHoldStart = 0.0;
	g_iLiveSurvCount = 0;
	g_iLiveInfCount = 0;
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));

	for (int i = 1; i <= MaxClients; i++)
	{
		ResetRoundStats(i);
		g_fLifeStart[i] = GetEngineTime();
		g_bAliveAtEnd[i] = true;
		g_bWasLive[i] = false;
	}

	delete g_hFlowTimer;
	g_hFlowTimer = CreateTimer(1.0, Timer_FlowSnapshot, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_FlowSnapshot(Handle timer)
{
	if (!g_bRoundActive || g_bRoundFinalized)
	{
		// Clear the handle first: SourceMod frees a repeating timer that returns
		// Plugin_Stop, and a later delete on the stale handle would throw.
		g_hFlowTimer = null;
		return Plugin_Stop;
	}

	if (!g_bRoundLive || g_bPaused)
	{
		return Plugin_Continue;
	}

	if (IsTankInPlayActive())
	{
		return Plugin_Continue;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidHuman(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i))
		{
			continue;
		}

		float progress = GetFlowPercentSafe(i);
		if (progress > g_fFlowBest[i])
		{
			g_fFlowBest[i] = progress;
		}
	}

	return Plugin_Continue;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	FinalizeRoundIfNeeded();
}

// Everybody readied up and the countdown started: this is the last moment where
// the teams can still be judged before the round runs, so announce the balance.
public void OnRoundLiveCountdown()
{
	if (!g_CvarEnabled.BoolValue || !g_CvarReadyBalanceInfo.BoolValue)
	{
		return;
	}

	AnnounceTeamBalance();
}

public void OnReadyUpInitiate()
{
	UpdateReadyFooter();
}

public void OnPlayerReady(int client)
{
	UpdateReadyFooter();
}

public void OnPlayerUnready(int client)
{
	UpdateReadyFooter();
}

void AnnounceTeamBalance()
{
	float sumSurv = 0.0;
	float sumInf = 0.0;
	int survCount = 0;
	int infCount = 0;

	if (!CollectTeamRatings(sumSurv, sumInf, survCount, infCount))
	{
		return;
	}

	float avgSurv = sumSurv / float(survCount);
	float avgInf = sumInf / float(infCount);

	PrintToChatAll("\x04[KSR]\x01 \x04Survivors\x01 \x05%.0f\x01 (avg \x05%.0f\x01)  |  \x08Infected\x01 \x05%.0f\x01 (avg \x05%.0f\x01)",
		sumSurv, avgSurv, sumInf, avgInf);

	char balanceLine[192];
	BuildBalanceLine(avgSurv, avgInf, balanceLine, sizeof(balanceLine));
	PrintToChatAll("%s", balanceLine);

	float gap = avgSurv - avgInf;
	if (gap < 0.0)
	{
		gap = -gap;
	}

	if (gap >= g_CvarMixWarnDelta.FloatValue && IsValidMixSetup(survCount, infCount))
	{
		PrintToChatAll("\x04[KSR]\x01 Teams look lopsided. Type \x05!skillmix\x01 to re-draw them.");
	}
}

bool CollectTeamRatings(float &sumSurv, float &sumInf, int &survCount, int &infCount)
{
	sumSurv = 0.0;
	sumInf = 0.0;
	survCount = 0;
	infCount = 0;

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

	return (survCount > 0 && infCount > 0);
}

// Keeps a live balance line in the ready panel, so the teams can be judged while
// people are still picking sides instead of only once the countdown fires.
void UpdateReadyFooter()
{
	if (!g_CvarEnabled.BoolValue || !g_bReadyUpAvailable || !g_CvarReadyBalanceInfo.BoolValue)
	{
		return;
	}

	float sumSurv = 0.0;
	float sumInf = 0.0;
	int survCount = 0;
	int infCount = 0;

	char footer[128];
	if (!CollectTeamRatings(sumSurv, sumInf, survCount, infCount))
	{
		Format(footer, sizeof(footer), "KSR: teams not set");
	}
	else
	{
		float avgSurv = sumSurv / float(survCount);
		float avgInf = sumInf / float(infCount);
		float gap = avgSurv - avgInf;
		Format(footer, sizeof(footer), "KSR  S %.0f  vs  I %.0f   (gap %s%.0f)",
			avgSurv, avgInf, (gap >= 0.0) ? "+" : "-", (gap >= 0.0) ? gap : -gap);
	}

	if (g_iReadyFooterIndex < 0)
	{
		g_iReadyFooterIndex = AddStringToReadyFooter(footer);
		return;
	}

	if (!EditFooterStringAtIndex(g_iReadyFooterIndex, footer))
	{
		g_iReadyFooterIndex = AddStringToReadyFooter(footer);
	}
}

public void OnRoundIsLive()
{
	if (!g_CvarEnabled.BoolValue || g_bRoundFinalized)
	{
		return;
	}

	g_bRoundLive = true;
	g_bPaused = false;

	float now = GetEngineTime();
	g_iLiveSurvCount = 0;
	g_iLiveInfCount = 0;

	// Snapshot the roster the moment the round goes live. Eligibility is judged on
	// this snapshot, so one player dropping at the end no longer voids the round
	// for everybody, and a late joiner cannot bank a round he barely played.
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidHuman(i))
		{
			continue;
		}

		int team = GetClientTeam(i);
		if (team == TEAM_SURVIVOR)
		{
			g_bWasLive[i] = true;
			g_iLiveSurvCount++;
			if (IsPlayerAlive(i))
			{
				g_fLifeStart[i] = now;
			}
		}
		else if (team == TEAM_INFECTED)
		{
			g_bWasLive[i] = true;
			g_iLiveInfCount++;
		}
	}
}

public void OnPause()
{
	if (!g_bRoundActive || g_bRoundFinalized || g_bPaused)
	{
		return;
	}

	g_bPaused = true;
	float now = GetEngineTime();
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidHuman(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i))
		{
			continue;
		}
		if (g_bRoundLive)
		{
			g_fSurvivalTime[i] += now - g_fLifeStart[i];
		}
		g_fLifeStart[i] = now;
	}
}

public void OnUnpause()
{
	if (!g_bRoundActive || g_bRoundFinalized)
	{
		return;
	}

	g_bPaused = false;

	if (!g_bRoundLive)
	{
		return;
	}

	float now = GetEngineTime();
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidHuman(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i))
		{
			continue;
		}
		g_fLifeStart[i] = now;
	}
}

public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	FinalizeRoundIfNeeded();
	return Plugin_Continue;
}

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

		ApplyRoundRating(i, team, rawScore[i]);
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
		+ g_iSkeetsMelee[client] + g_iDeadstops[client] + g_iBoomerPopsNoVomit[client] + g_iRevives[client]
		+ g_iMedkitGives[client] + g_iRescuesFromSpecial[client] + g_iJockeyBlocks[client]
		+ g_iTankPlayActions[client] + g_iChainClearBoom[client] + g_iSafeSaves[client];

	if (actionCount >= 5)
	{
		g_iZeroFFBonus[client] = 1;
	}
}

// Converts a raw round score into a z-score against the rolling baseline for that
// side, then folds it into the player's rating with an EMA. Unlike the old pool
// share this does not depend on how good the other three players were, so the
// rating measures the player rather than the gap to his own team - which is what
// makes the numbers comparable between teams, and therefore usable for a mix.
void ApplyRoundRating(int client, int team, float raw)
{
	float sd = g_fBaseSd[team];
	if (sd < 1.0)
	{
		sd = 1.0;
	}

	float z = FloatClamp((raw - g_fBaseMean[team]) / sd, -KSR_Z_CLAMP, KSR_Z_CLAMP);

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
		score += float(g_iDamageAsInfected[client]) * g_CvarWeightInfDamage.FloatValue;
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
			g_iDamageAsInfected[attacker] += damage;
			AddPinDpsAssist(attacker, victim, damage);

			int zClassAtt = GetEntProp(attacker, Prop_Send, "m_zombieClass");
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
		g_bIncapped[victim] = true;
		g_bAliveAtEnd[victim] = false;
		if (g_bRoundLive && !g_bPaused)
		{
			g_fSurvivalTime[victim] += GetEngineTime() - g_fLifeStart[victim];
		}
		AddPinAssistForVictim(victim);
		AddBoomAssistIfRecent(victim);
		AddSpitSetupAssist(victim);
		AddBoomKillAssist(victim);
		MarkPinEnd(victim);

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
	if (IsValidHuman(reviver) && IsValidClient(revived) && reviver != revived && GetClientTeam(reviver) == TEAM_SURVIVOR)
	{
		g_iRevives[reviver]++;
		if (IsTankInPlayActive())
		{
			g_iTankPlayActions[reviver]++;
		}
		g_bIncapped[revived] = false;
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

public void OnJockeyHighPounce(int survivor, int jockey, float height, bool reportedHigh)
{
	// Note the argument order: this forward puts the survivor first, unlike the
	// hunter one.
	if (!g_bRoundActive || !IsValidHuman(jockey) || GetClientTeam(jockey) != TEAM_INFECTED)
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
		if (zcAtt == ZC_TANK && IsValidClient(victim) && GetClientTeam(victim) == TEAM_SURVIVOR)
		{
			g_iTankKills[attacker]++;
		}
	}

	if (IsValidClient(victim) && GetClientTeam(victim) == TEAM_SURVIVOR)
	{
		g_bAliveAtEnd[victim] = false;
		if (g_bRoundLive && !g_bPaused)
		{
			g_fSurvivalTime[victim] += GetEngineTime() - g_fLifeStart[victim];
		}
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
	if (!g_bRoundActive || !IsValidHuman(survivor))
	{
		return;
	}

	if (GetClientTeam(survivor) == TEAM_SURVIVOR)
	{
		g_iSkeetsMelee[survivor]++;
		if (IsTankInPlayActive())
		{
			g_iTankPlayActions[survivor]++;
		}
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

public Action Command_Skill(int client, int args)
{
	if (!g_CvarEnabled.BoolValue)
	{
		ReplyToCommand(client, "[KSR] Plugin is disabled.");
		return Plugin_Handled;
	}

	if (!IsValidHuman(client))
	{
		ReplyToCommand(client, "[KSR] This command is in-game only.");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		ShowSkillMainMenu(client);
		return Plugin_Handled;
	}

	int target = client;
	if (args >= 1)
	{
		char arg[64];
		GetCmdArg(1, arg, sizeof(arg));
		target = FindTarget(client, arg, true, false);
		if (target <= 0)
		{
			return Plugin_Handled;
		}
	}

	ShowSkillForTarget(client, target, false);

	return Plugin_Handled;
}

void ShowSkillForTarget(int client, int target, bool showBackButton)
{
	if (!IsValidHuman(client) || !IsValidClient(target))
	{
		return;
	}

	char steamid[32];
	if (!GetPlayerSteamId(target, steamid, sizeof(steamid)))
	{
		ReplyToCommand(client, "[KSR] Cannot resolve SteamID for target.");
		return;
	}

	// Recent form is the average z of the last rounds, which lives in round_stats.
	char query[512];
	Format(query, sizeof(query),
		"SELECT AVG(rating_z), COUNT(*) FROM "
		... "(SELECT rating_z FROM round_stats WHERE steamid='%s' AND rating_z != 0.0 "
		... "ORDER BY ts DESC, id DESC LIMIT 30);",
		steamid);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(GetClientUserId(target));
	pack.WriteCell(showBackButton ? 1 : 0);
	g_Db.Query(SQL_ShowProfileCard, query, pack);
}

public void SQL_ShowProfileCard(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	int target = GetClientOfUserId(pack.ReadCell());
	bool showBackButton = view_as<bool>(pack.ReadCell());
	delete pack;

	if (!IsValidHuman(client) || !IsValidClient(target))
	{
		return;
	}

	float formZ = 0.0;
	int formRounds = 0;
	if (results != null && results.FetchRow())
	{
		if (!results.IsFieldNull(0))
		{
			formZ = results.FetchFloat(0);
		}
		formRounds = results.FetchInt(1);
	}

	Menu menu = new Menu(MenuHandler_InfoBack, MENU_ACTIONS_DEFAULT);
	char title[128];
	char displayName[160];
	BuildDisplayName(target, displayName, sizeof(displayName));
	Format(title, sizeof(title), "KSR: %s", displayName);
	menu.SetTitle(title);

	char line[256];
	char ksr[32];

	FormatKSRWithConfidence(g_fRating[target], g_iRatingRounds[target], ksr, sizeof(ksr));
	Format(line, sizeof(line), "KSR: %s   |   %d rated rounds", ksr, g_iRatingRounds[target]);
	menu.AddItem("x", line, ITEMDRAW_DISABLED);

	if (g_iRatingRounds[target] < GetTopMinRounds())
	{
		Format(line, sizeof(line), "Provisional - %d more rounds to qualify",
			GetTopMinRounds() - g_iRatingRounds[target]);
		menu.AddItem("x", line, ITEMDRAW_DISABLED);
	}

	menu.AddItem("x", "--- By side ---", ITEMDRAW_DISABLED);
	Format(line, sizeof(line), "Survivor: %.0f   (%d rounds)",
		GetSideKSR(target, TEAM_SURVIVOR), g_iRatingSideRounds[TEAM_SURVIVOR][target]);
	menu.AddItem("x", line, ITEMDRAW_DISABLED);
	Format(line, sizeof(line), "Infected: %.0f   (%d rounds)",
		GetSideKSR(target, TEAM_INFECTED), g_iRatingSideRounds[TEAM_INFECTED][target]);
	menu.AddItem("x", line, ITEMDRAW_DISABLED);

	if (formRounds >= 5)
	{
		// Same scale as the rating, so form and KSR can be read side by side.
		float formKsr = KSR_BASE + g_CvarRatingScale.FloatValue * formZ;
		float diff = formKsr - RatingToKSR(g_fRating[target], g_iRatingRounds[target]);
		Format(line, sizeof(line), "Form (last %d): %.0f   [%s%.0f vs rating]",
			formRounds, formKsr, (diff >= 0.0) ? "+" : "", diff);
		menu.AddItem("x", line, ITEMDRAW_DISABLED);
	}
	else
	{
		menu.AddItem("x", "Form: not enough rounds on the new model yet", ITEMDRAW_DISABLED);
	}

	menu.ExitBackButton = showBackButton;
	menu.Display(client, 25);
}

public Action Command_SkillTop(int client, int args)
{
	if (!g_CvarEnabled.BoolValue)
	{
		ReplyToCommand(client, "[KSR] Plugin is disabled.");
		return Plugin_Handled;
	}

	int limit = 10;
	if (args >= 1)
	{
		char arg[16];
		GetCmdArg(1, arg, sizeof(arg));
		limit = StringToInt(arg);
		if (limit < 1)
		{
			limit = 1;
		}
		if (limit > 20)
		{
			limit = 20;
		}
	}

	RequestTopMenu(client, limit, GetTopMinRounds(), false);

	return Plugin_Handled;
}

public Action Command_SkillSim(int client, int args)
{
	if (!g_CvarEnabled.BoolValue)
	{
		ReplyToCommand(client, "[KSR] Plugin is disabled.");
		return Plugin_Handled;
	}

	if (!IsValidHuman(client))
	{
		ReplyToCommand(client, "[KSR] This command is in-game only.");
		return Plugin_Handled;
	}

	int target = client;
	if (args >= 1)
	{
		char arg[64];
		GetCmdArg(1, arg, sizeof(arg));
		target = FindTarget(client, arg, true, false);
		if (target <= 0)
		{
			return Plugin_Handled;
		}
	}

	RequestSimilarityMenu(client, target, false);

	return Plugin_Handled;
}

public Action Command_SkillBreakdown(int client, int args)
{
	if (!g_CvarEnabled.BoolValue)
	{
		ReplyToCommand(client, "[KSR] Plugin is disabled.");
		return Plugin_Handled;
	}

	if (!IsValidHuman(client))
	{
		ReplyToCommand(client, "[KSR] This command is in-game only.");
		return Plugin_Handled;
	}

	int target = client;
	if (args >= 1)
	{
		char arg[64];
		GetCmdArg(1, arg, sizeof(arg));
		target = FindTarget(client, arg, true, false);
		if (target <= 0)
		{
			return Plugin_Handled;
		}
	}

	RequestBreakdown(client, target, false);
	return Plugin_Handled;
}

// Player averages next to the server averages for every scored component, shown
// as the points each one actually contributes per round. This is the screen that
// answers "why is my rating what it is" without anyone having to guess.
void RequestBreakdown(int client, int target, bool showBackButton)
{
	char steamid[32];
	if (!GetPlayerSteamId(target, steamid, sizeof(steamid)))
	{
		ReplyToCommand(client, "[KSR] Cannot resolve SteamID for target.");
		return;
	}

	// Roughly 21 bytes per stat, repeated four times in the UNION below. At 60 stats
	// that is about 5 KB, so the buffers carry room for a good deal more.
	char cols[4096];
	cols[0] = '\0';
	for (int i = 0; i < g_iStatCount; i++)
	{
		Format(cols, sizeof(cols), "%s, AVG(%s)", cols, g_Stats[i].column);
	}

	char query[12288];
	Format(query, sizeof(query),
		"SELECT 0%s, COUNT(*) FROM round_stats WHERE steamid='%s' AND team=%d"
		... " UNION ALL SELECT 1%s, COUNT(*) FROM round_stats WHERE team=%d"
		... " UNION ALL SELECT 2%s, COUNT(*) FROM round_stats WHERE steamid='%s' AND team=%d"
		... " UNION ALL SELECT 3%s, COUNT(*) FROM round_stats WHERE team=%d;",
		cols, steamid, TEAM_SURVIVOR,
		cols, TEAM_SURVIVOR,
		cols, steamid, TEAM_INFECTED,
		cols, TEAM_INFECTED);

	char displayName[160];
	BuildDisplayName(target, displayName, sizeof(displayName));

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(showBackButton ? 1 : 0);
	pack.WriteString(displayName);
	g_Db.Query(SQL_ShowBreakdown, query, pack);
}

public void SQL_ShowBreakdown(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	bool showBackButton = view_as<bool>(pack.ReadCell());
	char displayName[160];
	pack.ReadString(displayName, sizeof(displayName));
	delete pack;

	if (!IsValidHuman(client))
	{
		return;
	}

	if (results == null)
	{
		ReplyToCommand(client, "[KSR] Breakdown query failed: %s", error);
		return;
	}

	for (int i = 0; i < g_iStatCount; i++)
	{
		g_fBdMine[client][i] = 0.0;
		g_fBdAvg[client][i] = 0.0;
	}
	g_iBdRounds[client][TEAM_SURVIVOR] = 0;
	g_iBdRounds[client][TEAM_INFECTED] = 0;

	while (results.FetchRow())
	{
		int row = results.FetchInt(0);
		int side = (row < 2) ? TEAM_SURVIVOR : TEAM_INFECTED;
		bool mine = (row == 0 || row == 2);

		for (int i = 0; i < g_iStatCount; i++)
		{
			if (g_Stats[i].side != side)
			{
				continue;
			}

			float v = results.IsFieldNull(i + 1) ? 0.0 : results.FetchFloat(i + 1);
			if (mine)
			{
				g_fBdMine[client][i] = v;
			}
			else
			{
				g_fBdAvg[client][i] = v;
			}
		}

		if (mine)
		{
			g_iBdRounds[client][side] = results.FetchInt(g_iStatCount + 1);
		}
	}

	strcopy(g_sBdName[client], sizeof(g_sBdName[]), displayName);
	g_bBdReady[client] = true;

	ShowBreakdownCategories(client, showBackButton);
}

void ShowBreakdownCategories(int client, bool showBackButton)
{
	Menu menu = new Menu(MenuHandler_BreakdownCategory, MENU_ACTIONS_DEFAULT);
	char title[192];
	Format(title, sizeof(title), "Points per round: %s", g_sBdName[client]);
	menu.SetTitle(title);
	menu.ExitBackButton = showBackButton;

	if (g_iBdRounds[client][TEAM_SURVIVOR] < 5 && g_iBdRounds[client][TEAM_INFECTED] < 5)
	{
		menu.AddItem("x", "Not enough rounds recorded yet.", ITEMDRAW_DISABLED);
		menu.Display(client, 30);
		return;
	}

	char line[192];
	char info[8];
	int lastSide = 0;

	for (int cat = 0; cat < KSR_CATEGORIES; cat++)
	{
		int side = CategorySide(cat);
		if (g_iBdRounds[client][side] < 5)
		{
			continue;
		}

		if (side != lastSide)
		{
			Format(line, sizeof(line), "--- %s (%d rounds) ---",
				(side == TEAM_SURVIVOR) ? "Survivor" : "Infected", g_iBdRounds[client][side]);
			menu.AddItem("x", line, ITEMDRAW_DISABLED);
			lastSide = side;
		}

		float mine = 0.0;
		float avg = 0.0;
		CategoryPoints(client, cat, mine, avg);

		Format(info, sizeof(info), "%d", cat);
		Format(line, sizeof(line), "%s: %.1f pts (avg %.1f) %s",
			g_sCategoryName[cat], mine, avg, DeltaLabel(mine, avg, false));
		menu.AddItem(info, line);
	}

	menu.Display(client, 30);
}

int CategorySide(int category)
{
	return (category < 6) ? TEAM_SURVIVOR : TEAM_INFECTED;
}

void CategoryPoints(int client, int category, float &mine, float &avg)
{
	mine = 0.0;
	avg = 0.0;

	for (int i = 0; i < g_iStatCount; i++)
	{
		if (g_Stats[i].category != category)
		{
			continue;
		}

		float w = g_Stats[i].weight.FloatValue;
		mine += g_fBdMine[client][i] * w;
		avg += g_fBdAvg[client][i] * w;
	}
}

public int MenuHandler_BreakdownCategory(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack && IsValidHuman(client))
	{
		ShowSkillMainMenu(client);
		return 0;
	}

	if (action != MenuAction_Select || !IsValidHuman(client) || !g_bBdReady[client])
	{
		return 0;
	}

	char info[8];
	menu.GetItem(item, info, sizeof(info));
	ShowBreakdownDetail(client, StringToInt(info));
	return 0;
}

void ShowBreakdownDetail(int client, int category)
{
	if (category < 0 || category >= KSR_CATEGORIES)
	{
		return;
	}

	Menu menu = new Menu(MenuHandler_BreakdownDetail, MENU_ACTIONS_DEFAULT);
	char title[192];
	Format(title, sizeof(title), "%s: %s", g_sCategoryName[category], g_sBdName[client]);
	menu.SetTitle(title);
	menu.ExitBackButton = true;

	char line[192];
	for (int i = 0; i < g_iStatCount; i++)
	{
		if (g_Stats[i].category != category)
		{
			continue;
		}

		float w = g_Stats[i].weight.FloatValue;
		float minePts = g_fBdMine[client][i] * w;
		float avgPts = g_fBdAvg[client][i] * w;

		// Counts as well as points: a raw average of 3200 damage says more about
		// what you actually do than the 23 points it turns into.
		if (g_fBdMine[client][i] >= 100.0 || g_fBdAvg[client][i] >= 100.0)
		{
			Format(line, sizeof(line), "%s: %.0f -> %.1f pts (avg %.1f) %s",
				g_Stats[i].label, g_fBdMine[client][i], minePts, avgPts,
				DeltaLabel(g_fBdMine[client][i], g_fBdAvg[client][i], g_Stats[i].lowerIsBetter));
		}
		else
		{
			Format(line, sizeof(line), "%s: %.2f -> %.1f pts (avg %.1f) %s",
				g_Stats[i].label, g_fBdMine[client][i], minePts, avgPts,
				DeltaLabel(g_fBdMine[client][i], g_fBdAvg[client][i], g_Stats[i].lowerIsBetter));
		}

		menu.AddItem("x", line, ITEMDRAW_DISABLED);
	}

	menu.Display(client, 30);
}

public int MenuHandler_BreakdownDetail(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack && IsValidHuman(client))
	{
		ShowBreakdownCategories(client, true);
	}

	return 0;
}

// lowerIsBetter flips the sign, so "friendly fire -40%" reads as a good thing.
char[] DeltaLabel(float mine, float avg, bool lowerIsBetter)
{
	char out[24];

	if (avg > 0.0001 || avg < -0.0001)
	{
		float pct = ((mine / avg) - 1.0) * 100.0;
		if (lowerIsBetter)
		{
			pct = -pct;
		}
		Format(out, sizeof(out), "%s%.0f%%", (pct >= 0.0) ? "+" : "", pct);
	}
	else
	{
		strcopy(out, sizeof(out), "");
	}

	return out;
}

public Action Command_SkillMixVote(int client, int args)
{
	if (!g_CvarEnabled.BoolValue)
	{
		ReplyToCommand(client, "[KSR] Plugin is disabled.");
		return Plugin_Handled;
	}

	if (!IsValidHuman(client))
	{
		ReplyToCommand(client, "[KSR] This command is in-game only.");
		return Plugin_Handled;
	}

	if (GetClientTeam(client) == TEAM_SPECTATOR)
	{
		ReplyToCommand(client, "[KSR] Spectators cannot call this vote.");
		return Plugin_Handled;
	}

	if (g_bMixVoteInProgress || IsBuiltinVoteInProgress())
	{
		ReplyToCommand(client, "[KSR] A vote is already in progress.");
		return Plugin_Handled;
	}

	if (!IsMixAllowedNow())
	{
		ReplyToCommand(client, "[KSR] Teams can only be mixed during ready-up.");
		return Plugin_Handled;
	}

	int survCount = 0;
	int infCount = 0;
	int voters[MAXPLAYERS + 1];
	int voterCount = CollectEligibleVoters(voters, survCount, infCount);

	if (!IsValidMixSetup(survCount, infCount))
	{
		ReplyToCommand(client, "[KSR] Mix requires equal teams, from 1v1 up to %dv%d.", MIX_MAX_TEAM_SIZE, MIX_MAX_TEAM_SIZE);
		return Plugin_Handled;
	}

	if (!BuildPlannedSplit())
	{
		ReplyToCommand(client, "[KSR] Could not work out a split for the current teams.");
		return Plugin_Handled;
	}

	AnnouncePlannedSplit();

	g_hMixVote = CreateBuiltinVote(Handle_MixVoteAction, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
	SetBuiltinVoteArgument(g_hMixVote, "Mix teams by KSR?");
	SetBuiltinVoteInitiator(g_hMixVote, client);
	SetBuiltinVoteResultCallback(g_hMixVote, Handle_MixVoteResult);
	DisplayBuiltinVote(g_hMixVote, voters, voterCount, 15);
	FakeClientCommand(client, "Vote Yes");

	g_bMixVoteInProgress = true;

	return Plugin_Handled;
}

void ShowSkillMainMenu(int client)
{
	Menu menu = new Menu(MenuHandler_SkillMain, MENU_ACTIONS_DEFAULT);
	menu.SetTitle("=== Kether Skill Rating (KSR) ===");
	menu.AddItem("my", "My KSR profile");
	menu.AddItem("break", "Where my points come from");
	menu.AddItem("top", "Top KSR leaderboard");
	menu.AddItem("sim", "Similar KSR rank");
	menu.AddItem("teams", "Current team balance");
	menu.AddItem("mix", "Call KSR mix vote");
	if (CheckCommandAccess(client, "sm_skill_admin_reset", ADMFLAG_ROOT, true))
	{
		menu.AddItem("reset", "Admin: Reset selected player stats");
	}
	menu.ExitButton = true;
	menu.Display(client, 20);
}

public int MenuHandler_SkillMain(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action != MenuAction_Select || !IsValidHuman(client))
	{
		return 0;
	}

	char info[32];
	menu.GetItem(item, info, sizeof(info));

	if (StrEqual(info, "my"))
	{
		ShowSkillForTarget(client, client, true);
	}
	else if (StrEqual(info, "break"))
	{
		RequestBreakdown(client, client, true);
	}
	else if (StrEqual(info, "top"))
	{
		RequestTopMenu(client, 10, GetTopMinRounds(), true);
	}
	else if (StrEqual(info, "sim"))
	{
		RequestSimilarityMenu(client, client, true);
	}
	else if (StrEqual(info, "teams"))
	{
		PrintTeamKsrSummary(client);
	}
	else if (StrEqual(info, "mix"))
	{
		Command_SkillMixVote(client, 0);
	}
	else if (StrEqual(info, "reset"))
	{
		ShowAdminResetPlayerMenu(client);
	}

	return 0;
}

void ShowAdminResetPlayerMenu(int client)
{
	if (!CheckCommandAccess(client, "sm_skill_admin_reset", ADMFLAG_ROOT, true))
	{
		ReplyToCommand(client, "[KSR] No access.");
		return;
	}

	char query[512];
	Format(query, sizeof(query),
		"SELECT steamid, last_name, first_name, rating, rating_rounds "
		... "FROM players ORDER BY rating_rounds DESC, rating DESC LIMIT 200;");

	DataPack pack = new DataPack();
	pack.WriteCell(client);
	g_Db.Query(SQL_ShowAdminResetPlayersMenu, query, pack);
}

public int MenuHandler_AdminResetPlayer(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack && IsValidHuman(client))
	{
		ShowSkillMainMenu(client);
		return 0;
	}

	if (action != MenuAction_Select || !IsValidHuman(client))
	{
		return 0;
	}

	char steamid[32];
	menu.GetItem(item, steamid, sizeof(steamid));
	ResetPlayerStatsBySteamId(steamid, client);
	ShowAdminResetPlayerMenu(client);
	return 0;
}

public void SQL_ShowAdminResetPlayersMenu(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	delete pack;

	if (!IsValidHuman(client))
	{
		return;
	}

	if (results == null)
	{
		ReplyToCommand(client, "[KSR] Failed to load admin reset list: %s", error);
		return;
	}

	Menu menu = new Menu(MenuHandler_AdminResetPlayer, MENU_ACTIONS_DEFAULT);
	menu.SetTitle("Admin: Reset Player Stats");
	menu.AddItem("x", "Select player from database:", ITEMDRAW_DISABLED);

	int added = 0;
	while (results.FetchRow())
	{
		char steamid[32];
		char lastName[MAX_NAME_LENGTH];
		char firstName[MAX_NAME_LENGTH];
		float rating = results.FetchFloat(3);
		int rounds = results.FetchInt(4);
		float ksr = RatingToKSR(rating, rounds);
		results.FetchString(0, steamid, sizeof(steamid));
		results.FetchString(1, lastName, sizeof(lastName));
		results.FetchString(2, firstName, sizeof(firstName));

		if (lastName[0] == '\0' && firstName[0] != '\0')
		{
			strcopy(lastName, sizeof(lastName), firstName);
		}

		char label[192];
		if (firstName[0] != '\0' && !StrEqual(firstName, lastName, false))
		{
			Format(label, sizeof(label), "%s (%s) | rounds %d | KSR %.0f", lastName, firstName, rounds, ksr);
		}
		else
		{
			Format(label, sizeof(label), "%s | rounds %d | KSR %.0f", lastName, rounds, ksr);
		}
		menu.AddItem(steamid, label);
		added++;
	}

	if (added == 0)
	{
		menu.AddItem("x", "No players found in database.", ITEMDRAW_DISABLED);
	}

	menu.ExitBackButton = true;
	menu.Display(client, 30);
}

void ResetPlayerStatsBySteamId(const char[] steamid, int adminClient)
{
	if (steamid[0] == '\0')
	{
		return;
	}

	char q1[256];
	Format(q1, sizeof(q1), "DELETE FROM round_stats WHERE steamid='%s';", steamid);
	g_Db.Query(SQL_ErrorOnly, q1);

	char q2[256];
	Format(q2, sizeof(q2), "UPDATE players SET total_points=0.0, rounds_played=0, rating=0.0, rating_rounds=0, "
		... "rating_surv=0.0, rating_surv_rounds=0, rating_inf=0.0, rating_inf_rounds=0 WHERE steamid='%s';", steamid);
	g_Db.Query(SQL_ErrorOnly, q2);

	int target = FindOnlineClientBySteamId(steamid);
	if (target > 0)
	{
		g_fTotalPoints[target] = 0.0;
		g_iRoundsPlayed[target] = 0;
		ResetRatingCache(target);
		g_bProfileLoaded[target] = true;
		ResetRoundStats(target);
		PrintToChat(target, "[KSR] Your KSR stats were reset by admin.");
	}

	ReplyToCommand(adminClient, "[KSR] Stats reset for steamid %s", steamid);
}

public void Handle_MixVoteAction(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			g_hMixVote = INVALID_HANDLE;
			g_bMixVoteInProgress = false;
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
			g_bMixVoteInProgress = false;
		}
	}
}

public void Handle_MixVoteResult(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	int yesVotes = 0;
	for (int i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			yesVotes = item_info[i][BUILTINVOTEINFO_ITEM_VOTES];
			break;
		}
	}

	// Against the eligible players, not against however few people bothered to
	// vote - the initiator auto-votes yes, so the old maths passed a 1/1 vote.
	int denominator = (num_clients > 0) ? num_clients : num_votes;

	float yesPct = 0.0;
	if (denominator > 0)
	{
		yesPct = (float(yesVotes) / float(denominator)) * 100.0;
	}

	if (yesPct < g_CvarMixVotePct.FloatValue)
	{
		DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
		return;
	}

	DisplayBuiltinVotePass(vote, "Applying KSR mix...");
	PerformSkillMix();
}

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
	}
}

// Exhaustive search over every way to cut the lobby in half. For 8 players that
// is 35 distinct splits, so this is free and always returns the true optimum -
// a greedy walk only approximates it.
//
// Balance means equal total strength, so the difference in sums is the objective
// and nothing is allowed to trade it away. The secondary criteria - not stacking
// both stars on one side, matching the internal spread, and matching the two
// teams on each half of the map - only pick between splits whose sums are already
// within sm_skill_mix_tolerance of the best one available, which defaults to 0:
// the smallest possible gap always wins, shape only decides exact ties.
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

	// Pass one: how close can the sums possibly get?
	for (int mask = 0; mask < combos; mask++)
	{
		if (!(mask & 1) || !HasExactBits(mask, count, teamSize))
		{
			continue;
		}

		float diff = SplitSumDiff(mask, rating, count);
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

		if (SplitSumDiff(mask, rating, count) > limit)
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
			survA += GetSideKSR(c, TEAM_SURVIVOR);
			infA += GetSideKSR(c, TEAM_INFECTED);
		}
		else
		{
			if (firstB || r > topB) { topB = r; }
			if (firstB || r < lowB) { lowB = r; }
			firstB = false;
			survB += GetSideKSR(c, TEAM_SURVIVOR);
			infB += GetSideKSR(c, TEAM_INFECTED);
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

int GetTopMinRounds()
{
	int minRounds = g_CvarTopMinRounds.IntValue;
	if (minRounds < SKILL_TOP_MIN_ROUNDS_FLOOR)
	{
		minRounds = SKILL_TOP_MIN_ROUNDS_FLOOR;
	}
	return minRounds;
}

void RequestTopMenu(int client, int limit, int minRounds, bool showBackButton)
{
	char query[512];
	Format(query, sizeof(query),
		"SELECT last_name, first_name, rating, rating_rounds, rating AS score "
		... "FROM players WHERE rating_rounds >= %d ORDER BY score DESC, rating_rounds DESC LIMIT %d;",
		minRounds, limit);

	DataPack pack = new DataPack();
	pack.WriteCell(client);
	pack.WriteCell(showBackButton ? 1 : 0);
	pack.WriteCell(minRounds);
	pack.WriteCell(limit);
	g_Db.Query(SQL_ShowTop, query, pack);
}

void RequestSimilarityMenu(int client, int target, bool showBackButton)
{
	char targetSteamid[32];
	if (!GetPlayerSteamId(target, targetSteamid, sizeof(targetSteamid)))
	{
		ReplyToCommand(client, "[KSR] Cannot resolve SteamID for target.");
		return;
	}

	char targetName[MAX_NAME_LENGTH * 2];
	if (g_sFirstName[target][0] != '\0' && !StrEqual(g_sFirstName[target], g_sLastName[target], false))
	{
		Format(targetName, sizeof(targetName), "%s (%s)", g_sLastName[target], g_sFirstName[target]);
	}
	else if (g_sLastName[target][0] != '\0')
	{
		strcopy(targetName, sizeof(targetName), g_sLastName[target]);
	}
	else
	{
		GetClientName(target, targetName, sizeof(targetName));
	}

	int minRounds = GetTopMinRounds();
	char query[512];
	Format(query, sizeof(query),
		"SELECT steamid, last_name, first_name, rating, rating_rounds, rating AS score "
		... "FROM players WHERE rating_rounds >= %d "
		... "ORDER BY score DESC, rating_rounds DESC;",
		minRounds);

	DataPack pack = new DataPack();
	pack.WriteCell(client);
	pack.WriteCell(showBackButton ? 1 : 0);
	pack.WriteString(targetSteamid);
	pack.WriteString(targetName);
	pack.WriteCell(minRounds);
	g_Db.Query(SQL_ShowRankNeighbors, query, pack);
}

public int MenuHandler_InfoBack(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack && IsValidHuman(client))
	{
		ShowSkillMainMenu(client);
	}

	return 0;
}

public void SQL_ShowTop(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	bool showBackButton = view_as<bool>(pack.ReadCell());
	int minRounds = pack.ReadCell();
	int limit = pack.ReadCell();
	delete pack;

	if (!IsValidClient(client))
	{
		return;
	}

	if (results == null)
	{
		ReplyToCommand(client, "[KSR] Top query failed: %s", error);
		return;
	}

	Menu menu = new Menu(MenuHandler_InfoBack, MENU_ACTIONS_DEFAULT);
	char title[128];
	Format(title, sizeof(title), "Top %d KSR Leaderboard", limit);
	menu.SetTitle(title);
	menu.ExitBackButton = showBackButton;

	char reqLine[128];
	Format(reqLine, sizeof(reqLine), "Requires minimum %d rounds played to qualify.", minRounds);
	menu.AddItem("x", reqLine, ITEMDRAW_DISABLED);
	menu.AddItem("x", "--- Ranked players ---", ITEMDRAW_DISABLED);

	int rank = 1;
	while (results.FetchRow())
	{
		char lastName[MAX_NAME_LENGTH];
		char firstName[MAX_NAME_LENGTH];
		results.FetchString(0, lastName, sizeof(lastName));
		results.FetchString(1, firstName, sizeof(firstName));
		int rounds = results.FetchInt(3);
		float avg = results.FetchFloat(4);

		if (rounds < minRounds)
		{
			continue;
		}

		if (lastName[0] == '\0' && firstName[0] != '\0')
		{
			strcopy(lastName, sizeof(lastName), firstName);
		}

		char ksr[32];
		FormatKSRValue(avg, rounds, ksr, sizeof(ksr));

		char line[192];
		if (firstName[0] != '\0' && !StrEqual(firstName, lastName, false))
		{
			Format(line, sizeof(line), "#%d %s (%s) | KSR %s | rounds %d", rank, lastName, firstName, ksr, rounds);
		}
		else
		{
			Format(line, sizeof(line), "#%d %s | KSR %s | rounds %d", rank, lastName, ksr, rounds);
		}
		menu.AddItem("x", line, ITEMDRAW_DISABLED);
		rank++;
	}

	if (rank == 1)
	{
		menu.AddItem("x", "No players match KSR ranking criteria.", ITEMDRAW_DISABLED);
	}

	menu.Display(client, 20);
}

void FormatSkillPlayerName(const char[] lastName, const char[] firstName, char[] buffer, int size)
{
	if (lastName[0] == '\0' && firstName[0] != '\0')
	{
		strcopy(buffer, size, firstName);
		return;
	}

	if (firstName[0] != '\0' && !StrEqual(firstName, lastName, false))
	{
		Format(buffer, size, "%s (%s)", lastName, firstName);
	}
	else
	{
		strcopy(buffer, size, lastName);
	}
}

public void SQL_ShowRankNeighbors(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	bool showBackButton = view_as<bool>(pack.ReadCell());
	char targetSteamid[32];
	pack.ReadString(targetSteamid, sizeof(targetSteamid));
	char targetName[MAX_NAME_LENGTH * 2];
	pack.ReadString(targetName, sizeof(targetName));
	int minRounds = pack.ReadCell();
	delete pack;

	if (!IsValidClient(client))
	{
		return;
	}

	Menu menu = new Menu(MenuHandler_InfoBack, MENU_ACTIONS_DEFAULT);
	menu.ExitBackButton = showBackButton;

	if (results == null)
	{
		ReplyToCommand(client, "[KSR] Ranking query failed: %s", error);
		return;
	}

	char rankSteamid[SKILL_RANK_LIST_MAX][32];
	char rankName[SKILL_RANK_LIST_MAX][MAX_NAME_LENGTH * 2];
	float rankAvg[SKILL_RANK_LIST_MAX];
	int rankRounds[SKILL_RANK_LIST_MAX];
	int rankCount = 0;

	while (results.FetchRow() && rankCount < SKILL_RANK_LIST_MAX)
	{
		char lastName[MAX_NAME_LENGTH];
		char firstName[MAX_NAME_LENGTH];
		results.FetchString(0, rankSteamid[rankCount], sizeof(rankSteamid[]));
		results.FetchString(1, lastName, sizeof(lastName));
		results.FetchString(2, firstName, sizeof(firstName));
		results.FetchFloat(3); // total_points (unused here)
		rankRounds[rankCount] = results.FetchInt(4);
		rankAvg[rankCount] = results.FetchFloat(5);

		if (rankRounds[rankCount] < minRounds)
		{
			continue;
		}

		FormatSkillPlayerName(lastName, firstName, rankName[rankCount], sizeof(rankName[]));
		rankCount++;
	}

	int targetIdx = -1;
	for (int i = 0; i < rankCount; i++)
	{
		if (StrEqual(rankSteamid[i], targetSteamid, false))
		{
			targetIdx = i;
			break;
		}
	}

	if (targetIdx == -1)
	{
		menu.SetTitle("KSR Similar Rank");
		char line[128];
		Format(line, sizeof(line), "%s needs at least %d rounds for KSR ranking.", targetName, minRounds);
		menu.AddItem("x", line, ITEMDRAW_DISABLED);
		menu.Display(client, 20);
		return;
	}

	int targetRank = targetIdx + 1;
	char title[160];
	Format(title, sizeof(title), "KSR rank near %s (#%d)", targetName, targetRank);
	menu.SetTitle(title);

	char selfKsr[32];
	FormatKSRWithConfidence(rankAvg[targetIdx], rankRounds[targetIdx], selfKsr, sizeof(selfKsr));
	char selfLine[192];
	Format(selfLine, sizeof(selfLine), "You: #%d | KSR %s | rounds %d", targetRank, selfKsr, rankRounds[targetIdx]);
	menu.AddItem("x", selfLine, ITEMDRAW_DISABLED);
	menu.AddItem("x", "--- Nearest KSR ranks ---", ITEMDRAW_DISABLED);

	int pickIdx[SKILL_SIMILAR_COUNT];
	int pickRank[SKILL_SIMILAR_COUNT];
	float pickAvg[SKILL_SIMILAR_COUNT];
	int pickRounds[SKILL_SIMILAR_COUNT];
	char pickName[SKILL_SIMILAR_COUNT][MAX_NAME_LENGTH * 2];
	int pickDist[SKILL_SIMILAR_COUNT];
	int pickCount = 0;

	for (int i = 0; i < SKILL_SIMILAR_COUNT; i++)
	{
		pickDist[i] = 999999;
		pickIdx[i] = -1;
	}

	for (int i = 0; i < rankCount; i++)
	{
		if (i == targetIdx)
		{
			continue;
		}

		int playerRank = i + 1;
		int dist = playerRank - targetRank;
		if (dist < 0)
		{
			dist = -dist;
		}

		int worst = 0;
		for (int slot = 1; slot < SKILL_SIMILAR_COUNT; slot++)
		{
			if (pickDist[slot] > pickDist[worst])
			{
				worst = slot;
			}
		}

		bool replace = false;
		if (pickCount < SKILL_SIMILAR_COUNT)
		{
			replace = true;
		}
		else if (dist < pickDist[worst])
		{
			replace = true;
		}
		else if (dist == pickDist[worst] && playerRank < pickRank[worst])
		{
			replace = true;
		}

		if (!replace)
		{
			continue;
		}

		pickIdx[worst] = i;
		pickRank[worst] = playerRank;
		pickAvg[worst] = rankAvg[i];
		pickRounds[worst] = rankRounds[i];
		strcopy(pickName[worst], sizeof(pickName[]), rankName[i]);
		pickDist[worst] = dist;
		if (pickCount < SKILL_SIMILAR_COUNT)
		{
			pickCount++;
		}
	}

	for (int n = 0; n < SKILL_SIMILAR_COUNT; n++)
	{
		int bestSlot = -1;
		for (int slot = 0; slot < SKILL_SIMILAR_COUNT; slot++)
		{
			if (pickIdx[slot] == -1)
			{
				continue;
			}
			if (bestSlot == -1 || pickRank[slot] < pickRank[bestSlot])
			{
				bestSlot = slot;
			}
		}

		if (bestSlot == -1)
		{
			break;
		}

		char neighborKsr[32];
		FormatKSRValue(pickAvg[bestSlot], pickRounds[bestSlot], neighborKsr, sizeof(neighborKsr));
		char line[192];
		Format(line, sizeof(line), "#%d %s | KSR %s | rounds %d", pickRank[bestSlot], pickName[bestSlot], neighborKsr, pickRounds[bestSlot]);
		menu.AddItem("x", line, ITEMDRAW_DISABLED);
		pickIdx[bestSlot] = -1;
	}

	if (pickCount == 0)
	{
		menu.AddItem("x", "No other KSR-ranked players nearby.", ITEMDRAW_DISABLED);
	}

	menu.Display(client, 20);
}

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
	pack.WriteCell(client);
	g_Db.Query(SQL_LoadPlayerProfile, qLoad, pack);
}

public void SQL_LoadPlayerProfile(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
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

	char qRound[2048];
	Format(qRound, sizeof(qRound),
		"INSERT INTO round_stats (steamid, name, round_index, map_name, team, raw_points, awarded_points, "
		... "dmg_infected, dmg_survivor, dmg_tank, dmg_witch, common_kills, special_clears, self_clears, skeets, skeets_melee, deadstops, boomer_pops, boomer_pops_splash, pin_assists, pin_dps_assist, big_hit_assists, big_hit_assist_score, spit_ticks_pinned, spit_ticks_incap, tank_boom_assists, witch_assists, spit_setup_assists, boom_kill_assists, charger_multi, spit_multi_hits, shove_si, witch_crowns, rock_skeets, chain_clear_boom, safe_saves, zero_ff_bonus, shared_focus, boom_focus, stagger_setup, chain_control, tank_support, alarm_triggers, tank_hold_time, tank_passes, tank_kills, tank_wipe_bonus, charger_levels, tongue_cuts, special_shove_saves, rock_eaten_penalty, revive_interrupts, revives, medkit_gives, special_rescues, jockey_blocks, tank_play_actions, ff_dealt, ff_taken, headshot_si, boomer_vomit_casts, boomer_vomit_hits, flow_percent, survival_time, alive_end, common_damage, witch_kills, scoring_version, rating_z, death_charges, hunter_pounce_dmg, jockey_high_pounces, ts) "
		... "VALUES ('%s', '%s', %d, '%s', %d, %.4f, %.4f, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %.2f, %d, %.2f, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %.2f, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %.2f, %.2f, %d, %d, %d, %d, %.4f, %d, %d, %d, strftime('%%s', 'now'));",
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
	g_iJockeyHighPounces[client]);
	g_Db.Query(SQL_ErrorOnly, qRound);

	g_fTotalPoints[client] += awarded;
	g_iRoundsPlayed[client]++;
}

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
	g_iLastPinner[victim] = pinner;
	g_iLastPinnerClass[victim] = zclass;
	g_bPinActive[victim] = true;
	float now = GetEngineTime();
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
	if (IsValidHuman(old_tank))
	{
		EndTankHoldSegment(old_tank);
		g_iTankPasses[old_tank]++;
	}
	StartTankHold(new_tank);
}

public void OnChargerLevel(int survivor, int charger)
{
	if (!g_bRoundActive || !IsValidHuman(survivor) || GetClientTeam(survivor) != TEAM_SURVIVOR)
	{
		return;
	}
	g_iChargerLevels[survivor]++;
}

public void OnTongueCut(int survivor, int smoker)
{
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
// average one rather than as whatever his first round happened to look like.
float GetMixRating(int client)
{
	return RatingToKSR(g_fRating[client], g_iRatingRounds[client]);
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

void CreateTables()
{
	char query[4096];

	Format(query, sizeof(query),
		"CREATE TABLE IF NOT EXISTS players ("
		... "steamid TEXT PRIMARY KEY, "
		... "name TEXT NOT NULL DEFAULT '', "
		... "first_name TEXT NOT NULL DEFAULT '', "
		... "last_name TEXT NOT NULL DEFAULT '', "
		... "total_points REAL NOT NULL DEFAULT 0.0, "
		... "rounds_played INTEGER NOT NULL DEFAULT 0, "
		... "last_seen INTEGER NOT NULL DEFAULT (strftime('%%s', 'now'))"
		... ");");
	g_Db.Query(SQL_ErrorOnly, query);

	Format(query, sizeof(query),
		"CREATE TABLE IF NOT EXISTS round_stats ("
		... "id INTEGER PRIMARY KEY AUTOINCREMENT, "
		... "steamid TEXT NOT NULL, "
		... "name TEXT NOT NULL DEFAULT '', "
		... "round_index INTEGER NOT NULL, "
		... "map_name TEXT NOT NULL DEFAULT '', "
		... "team INTEGER NOT NULL DEFAULT 0, "
		... "raw_points REAL NOT NULL DEFAULT 0.0, "
		... "awarded_points REAL NOT NULL DEFAULT 0.0, "
		... "dmg_infected INTEGER NOT NULL DEFAULT 0, "
		... "dmg_survivor INTEGER NOT NULL DEFAULT 0, "
		... "dmg_tank INTEGER NOT NULL DEFAULT 0, "
		... "dmg_witch INTEGER NOT NULL DEFAULT 0, "
		... "common_kills INTEGER NOT NULL DEFAULT 0, "
		... "special_clears INTEGER NOT NULL DEFAULT 0, "
		... "self_clears INTEGER NOT NULL DEFAULT 0, "
		... "skeets INTEGER NOT NULL DEFAULT 0, "
		... "skeets_melee INTEGER NOT NULL DEFAULT 0, "
		... "deadstops INTEGER NOT NULL DEFAULT 0, "
		... "boomer_pops INTEGER NOT NULL DEFAULT 0, "
		... "boomer_pops_splash INTEGER NOT NULL DEFAULT 0, "
		... "pin_assists INTEGER NOT NULL DEFAULT 0, "
		... "pin_dps_assist REAL NOT NULL DEFAULT 0.0, "
		... "big_hit_assists INTEGER NOT NULL DEFAULT 0, "
		... "big_hit_assist_score REAL NOT NULL DEFAULT 0.0, "
		... "spit_ticks_pinned INTEGER NOT NULL DEFAULT 0, "
		... "spit_ticks_incap INTEGER NOT NULL DEFAULT 0, "
		... "tank_boom_assists INTEGER NOT NULL DEFAULT 0, "
		... "witch_assists INTEGER NOT NULL DEFAULT 0, "
		... "spit_setup_assists INTEGER NOT NULL DEFAULT 0, "
		... "boom_kill_assists INTEGER NOT NULL DEFAULT 0, "
		... "charger_multi INTEGER NOT NULL DEFAULT 0, "
		... "spit_multi_hits INTEGER NOT NULL DEFAULT 0, "
		... "shove_si INTEGER NOT NULL DEFAULT 0, "
		... "witch_crowns INTEGER NOT NULL DEFAULT 0, "
		... "rock_skeets INTEGER NOT NULL DEFAULT 0, "
		... "chain_clear_boom INTEGER NOT NULL DEFAULT 0, "
		... "safe_saves INTEGER NOT NULL DEFAULT 0, "
		... "zero_ff_bonus INTEGER NOT NULL DEFAULT 0, "
		... "shared_focus INTEGER NOT NULL DEFAULT 0, "
		... "boom_focus INTEGER NOT NULL DEFAULT 0, "
		... "stagger_setup INTEGER NOT NULL DEFAULT 0, "
		... "chain_control INTEGER NOT NULL DEFAULT 0, "
		... "tank_support INTEGER NOT NULL DEFAULT 0, "
		... "alarm_triggers INTEGER NOT NULL DEFAULT 0, "
		... "tank_hold_time REAL NOT NULL DEFAULT 0.0, "
		... "tank_passes INTEGER NOT NULL DEFAULT 0, "
		... "tank_kills INTEGER NOT NULL DEFAULT 0, "
		... "tank_wipe_bonus INTEGER NOT NULL DEFAULT 0, "
		... "charger_levels INTEGER NOT NULL DEFAULT 0, "
		... "tongue_cuts INTEGER NOT NULL DEFAULT 0, "
		... "special_shove_saves INTEGER NOT NULL DEFAULT 0, "
		... "rock_eaten_penalty INTEGER NOT NULL DEFAULT 0, "
		... "revive_interrupts INTEGER NOT NULL DEFAULT 0, "
		... "revives INTEGER NOT NULL DEFAULT 0, "
		... "medkit_gives INTEGER NOT NULL DEFAULT 0, "
		... "special_rescues INTEGER NOT NULL DEFAULT 0, "
		... "jockey_blocks INTEGER NOT NULL DEFAULT 0, "
		... "tank_play_actions INTEGER NOT NULL DEFAULT 0, "
		... "ff_dealt INTEGER NOT NULL DEFAULT 0, "
		... "ff_taken INTEGER NOT NULL DEFAULT 0, "
		... "headshot_si INTEGER NOT NULL DEFAULT 0, "
		... "boomer_vomit_casts INTEGER NOT NULL DEFAULT 0, "
		... "boomer_vomit_hits INTEGER NOT NULL DEFAULT 0, "
		... "flow_percent REAL NOT NULL DEFAULT 0.0, "
		... "survival_time REAL NOT NULL DEFAULT 0.0, "
		... "alive_end INTEGER NOT NULL DEFAULT 0, "
		... "ts INTEGER NOT NULL DEFAULT (strftime('%%s', 'now'))"
		... ");");
	g_Db.Query(SQL_ErrorOnly, query);

	EnsureColumn("round_stats", "jockey_blocks", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "tank_play_actions", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "skeets_melee", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "boomer_pops_splash", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "pin_assists", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "big_hit_assists", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "big_hit_assist_score", "REAL NOT NULL DEFAULT 0.0");
	EnsureColumn("round_stats", "pin_dps_assist", "REAL NOT NULL DEFAULT 0.0");
	EnsureColumn("round_stats", "spit_ticks_pinned", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "spit_ticks_incap", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "tank_boom_assists", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "witch_assists", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "spit_setup_assists", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "boom_kill_assists", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "charger_multi", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "spit_multi_hits", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "shove_si", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "witch_crowns", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "rock_skeets", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "chain_clear_boom", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "safe_saves", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "zero_ff_bonus", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "shared_focus", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "boom_focus", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "stagger_setup", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "chain_control", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "tank_support", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "alarm_triggers", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "tank_hold_time", "REAL NOT NULL DEFAULT 0.0");
	EnsureColumn("round_stats", "tank_passes", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "tank_kills", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "tank_wipe_bonus", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "charger_levels", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "tongue_cuts", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "special_shove_saves", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "rock_eaten_penalty", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "revive_interrupts", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "ff_dealt", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "ff_taken", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "headshot_si", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "boomer_vomit_casts", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "boomer_vomit_hits", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "flow_percent", "REAL NOT NULL DEFAULT 0.0");
	EnsureColumn("round_stats", "survival_time", "REAL NOT NULL DEFAULT 0.0");
	EnsureColumn("round_stats", "alive_end", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "common_damage", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "witch_kills", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "scoring_version", "INTEGER NOT NULL DEFAULT 1");
	EnsureColumn("players", "first_name", "TEXT NOT NULL DEFAULT ''");
	EnsureColumn("players", "last_name", "TEXT NOT NULL DEFAULT ''");
	EnsureColumn("players", "rating", "REAL NOT NULL DEFAULT 0.0");
	EnsureColumn("players", "rating_rounds", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("players", "rating_surv", "REAL NOT NULL DEFAULT 0.0");
	EnsureColumn("players", "rating_surv_rounds", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("players", "rating_inf", "REAL NOT NULL DEFAULT 0.0");
	EnsureColumn("players", "rating_inf_rounds", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "rating_z", "REAL NOT NULL DEFAULT 0.0");
	EnsureColumn("round_stats", "death_charges", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "hunter_pounce_dmg", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "jockey_high_pounces", "INTEGER NOT NULL DEFAULT 0");

	Format(query, sizeof(query),
		"CREATE TABLE IF NOT EXISTS baselines ("
		... "team INTEGER PRIMARY KEY, "
		... "mean REAL NOT NULL DEFAULT 0.0, "
		... "sd REAL NOT NULL DEFAULT 1.0, "
		... "samples INTEGER NOT NULL DEFAULT 0"
		... ");");
	g_Db.Query(SQL_ErrorOnly, query);

	Format(query, sizeof(query), "UPDATE players SET first_name = CASE WHEN first_name='' THEN name ELSE first_name END;");
	g_Db.Query(SQL_ErrorOnly, query);
	Format(query, sizeof(query), "UPDATE players SET last_name = CASE WHEN last_name='' THEN name ELSE last_name END;");
	g_Db.Query(SQL_ErrorOnly, query);
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
	RegisterStat("Damage to survivors", "dmg_infected", TEAM_INFECTED, 11, g_CvarWeightInfDamage, false);
}

void SeedBaselines()
{
	g_fBaseMean[TEAM_SURVIVOR] = g_CvarSeedSurvMean.FloatValue;
	g_fBaseSd[TEAM_SURVIVOR] = g_CvarSeedSurvSd.FloatValue;
	g_fBaseMean[TEAM_INFECTED] = g_CvarSeedInfMean.FloatValue;
	g_fBaseSd[TEAM_INFECTED] = g_CvarSeedInfSd.FloatValue;
	g_iBaseCount[TEAM_SURVIVOR] = 0;
	g_iBaseCount[TEAM_INFECTED] = 0;
}

void LoadBaselines()
{
	g_Db.Query(SQL_LoadBaselines, "SELECT team, mean, sd, samples FROM baselines;");
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
