#if defined __ksr_globals_included
	#endinput
#endif
#define __ksr_globals_included
#define DB_NAME "kether_skill_rating"

// Scoring model revision. Bumped whenever weights or detection semantics change,
// so rounds from different revisions can be told apart in round_stats.
#define KSR_SCORING_VERSION 4

// Bumped whenever a model default changes, because AutoExecConfig will not rewrite
// values in a config that already exists - a new filename is the only way to make
// new defaults actually take effect on a server that already ran the old build.
#define KSR_CONFIG_NAME "kether_skill_rating_v5"

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
// Ranks shown above and below the player on the "around me" screen. Three each
// side plus the player is seven lines, which is exactly one menu page.
#define SKILL_SIMILAR_SIDE 3
#define SKILL_TOP_MIN_ROUNDS_FLOOR 20

// Rating scale: KSR = KSR_BASE + scale * shrunk rating. Rating itself is an EMA of
// per-round z-scores, so it is centred on 0 with a spread of roughly +-0.4.
#define KSR_BASE 1000.0
#define KSR_Z_CLAMP 3.0

// EMA factor per tank life for the "average tank" reference that tank damage is
// judged against. About fifty tank lives of memory.
#define KSR_TANK_BASE_EMA 0.02

// kether_scoring_system constants, mirrored so every half can be logged with the
// bonus it was actually worth. Keep in step with that plugin.
#define KSS_HEALTH_BONUS 24.0
#define KSS_SURVIVED_BONUS 9.0
#define KSS_MEDKIT_BONUS 28.0
#define KSS_PILLS_BONUS 12.0
#define KSS_TANK_PASS_BONUS 48.0
#define KSS_TANK_KILL_BONUS 24.0
#define KSS_WITCH_BONUS 24.0

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
ConVar g_CvarTopListMax;
ConVar g_CvarTopMinRounds;
ConVar g_CvarMixVotePct;
ConVar g_CvarWeightCommonDamage;
ConVar g_CvarWeightWitchKill;
ConVar g_CvarRatingScale;
ConVar g_CvarCarryWeight;
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
ConVar g_CvarMixShapeWarn;
ConVar g_CvarMixStackPenalty;
ConVar g_CvarMixLowStackPenalty;
ConVar g_CvarMixWeakMargin;
ConVar g_CvarMixWeakGroupPenalty;
ConVar g_CvarMixTolerance;
ConVar g_CvarMixWarnDelta;
ConVar g_CvarReadyBalanceInfo;
ConVar g_CvarMixShrink;
ConVar g_CvarMixLowCompress;
ConVar g_CvarWeightInfDamageIncapped;
ConVar g_CvarWeightTankDamageRel;
ConVar g_CvarSeedTankDmgLife;

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
Handle g_hReadyFooterTimer = null;
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

// Logged with every round but not scored yet. The infected score separates players
// far less reliably than the survivor one, and these are the candidates for fixing
// that: they need a few hundred rounds of data before any of them earns a weight.
int g_iDamageAsTank[MAXPLAYERS + 1];
int g_iInfIncaps[MAXPLAYERS + 1];
int g_iInfKills[MAXPLAYERS + 1];
int g_iPinsLanded[MAXPLAYERS + 1];
int g_iGotSkeeted[MAXPLAYERS + 1];
int g_iGotDeadstopped[MAXPLAYERS + 1];
int g_iGotPopped[MAXPLAYERS + 1];
int g_iGotLeveled[MAXPLAYERS + 1];
int g_iGotTongueCut[MAXPLAYERS + 1];
// Indexed by zombie class, smoker (1) to charger (6): which class a player rolled
// is luck, so damage has to be read against the lives he actually had on it.
int g_iClassDamage[ZC_CHARGER + 1][MAXPLAYERS + 1];
int g_iClassSpawns[ZC_CHARGER + 1][MAXPLAYERS + 1];

// Infected damage split by what it was worth. Damage on a standing survivor costs
// him health bonus and pushes him towards an incap; damage on an incapped one
// comes off a 300 point bleed-out pool and only matters if it finishes him, which
// the kill is credited for separately.
int g_iSiDamageUpright[MAXPLAYERS + 1];
int g_iDamageOnIncapped[MAXPLAYERS + 1];
int g_iTankDamageUpright[MAXPLAYERS + 1];
int g_iTankLives[MAXPLAYERS + 1];
float g_fTankDmgRel[MAXPLAYERS + 1];
// Sum over the survivors this player killed of the map they still had ahead of
// them, in percent. Distance is scored per survivor, so a kill at 20% denies far
// more than the same kill at 95%.
float g_fKillFlowDenied[MAXPLAYERS + 1];

// Rolling reference: standing-survivor damage an average human tank does per life.
float g_fTankBaseLife = 100.0;
int g_iTankBaseCount = 0;

// End-of-half survivor state and the half's bonus, so the real versus score can be
// rebuilt offline and used as the target the weights are calibrated against.
int g_iIncapsTaken[MAXPLAYERS + 1];
int g_iEndStanding[MAXPLAYERS + 1];
int g_iEndPermHp[MAXPLAYERS + 1];
int g_iEndTempHp[MAXPLAYERS + 1];
int g_iEndMedkit[MAXPLAYERS + 1];
int g_iEndPills[MAXPLAYERS + 1];
int g_iHalfIndex = 0;
int g_iHalfMaxScore = 0;
int g_iLastMaxScore = 0;
float g_fHalfBonus = 0.0;
int g_iHalfTankPasses = 0;
int g_iHalfTankKills = 0;
int g_iHalfWitchBonus = 0;

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
