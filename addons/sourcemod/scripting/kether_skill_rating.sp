#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2lib>
#include <builtinvotes>
#include <l4d2_skill_detect>

#define PLUGIN_VERSION "1.0.0"
#define DB_NAME "kether_skill_rating"

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
#define MIX_MAX_TEAM_SIZE 4

stock float FloatMax(float a, float b)
{
	return (a > b) ? a : b;
}

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
ConVar g_CvarMixVoteCooldown;

bool g_bRoundActive = false;
bool g_bRoundFinalized = false;
bool g_bRoundLive = false;
bool g_bPaused = false;
int g_iRoundNumber = 0;
char g_sMapName[64];
bool g_bReadyUpAvailable = false;

float g_fTotalPoints[MAXPLAYERS + 1];
int g_iRoundsPlayed[MAXPLAYERS + 1];
char g_sFirstName[MAXPLAYERS + 1][MAX_NAME_LENGTH];
char g_sLastName[MAXPLAYERS + 1][MAX_NAME_LENGTH];

int g_iDamageAsInfected[MAXPLAYERS + 1];
int g_iDamageAsSurvivor[MAXPLAYERS + 1];
int g_iTankDamageAsSurvivor[MAXPLAYERS + 1];
int g_iWitchDamageAsSurvivor[MAXPLAYERS + 1];
int g_iCommonKillsAsSurvivor[MAXPLAYERS + 1];

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
int g_iChargerCarryCount[MAXPLAYERS + 1];
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

int g_iReviveTargetForReviver[MAXPLAYERS + 1];
float g_fReviveStartTime[MAXPLAYERS + 1];
// g_iBigHitAssists retained earlier; no duplicate declaration here.
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
float g_fTankHoldStart = 0.0;

int g_iLastBoomerKiller[MAXPLAYERS + 1];
float g_fLastBoomerDeathTime[MAXPLAYERS + 1];
int g_iLastBoomerVomitHits[MAXPLAYERS + 1];
float g_fLastBoomerVomitTime[MAXPLAYERS + 1];
int g_iLastPinner[MAXPLAYERS + 1];
int g_iLastPinnerClass[MAXPLAYERS + 1];
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
float g_fLastMixVoteTime = 0.0;

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
	g_CvarWeightInfDamage = CreateConVar("sm_skill_w_inf_damage", "0.020", "Infected damage weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSurvDamage = CreateConVar("sm_skill_w_surv_damage", "0.012", "Survivor damage weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTankDamage = CreateConVar("sm_skill_w_tank_damage", "0.018", "Tank damage weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightWitchDamage = CreateConVar("sm_skill_w_witch_damage", "0.020", "Witch damage weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightCommonKills = CreateConVar("sm_skill_w_common_kills", "0.250", "Common kills weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSpecialClear = CreateConVar("sm_skill_w_special_clear", "12.0", "Special clear weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSelfClear = CreateConVar("sm_skill_w_self_clear", "14.0", "Self clear weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSkeet = CreateConVar("sm_skill_w_skeet", "15.0", "Skeet weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSkeetMelee = CreateConVar("sm_skill_w_skeet_melee", "22.0", "Melee skeet weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightDeadstop = CreateConVar("sm_skill_w_deadstop", "12.0", "Deadstop weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightBoomerPop = CreateConVar("sm_skill_w_boomer_pop", "8.0", "No-vomit boomer pop weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightBoomerPopSplash = CreateConVar("sm_skill_w_boomer_pop_splash", "-10.0", "Penalty when a popped boomer vomits on teammates", FCVAR_NONE, false, 0.0, false);
	g_CvarWeightPinAssist = CreateConVar("sm_skill_w_pin_assist", "8.0", "Assist weight for pin -> kill/incap synergy", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightPinDpsAssist = CreateConVar("sm_skill_w_pin_dps_assist", "0.08", "Assist weight per damage dealt to pinned target by teammate (awarded to pinner)", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSpitPinnedTick = CreateConVar("sm_skill_w_spit_pinned_tick", "1.0", "Spitter tick on pinned target", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSpitIncapTick = CreateConVar("sm_skill_w_spit_incap_tick", "0.6", "Spitter tick on incapped target", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTankBoomAssist = CreateConVar("sm_skill_w_tank_boom_assist", "3.0", "Boomer assist when tank hits boomed target", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightWitchAssist = CreateConVar("sm_skill_w_witch_assist", "4.0", "Assist when witch downs a recently pinned/boomed target", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSpitSetupAssist = CreateConVar("sm_skill_w_spit_setup_assist", "6.0", "Assist when spit sets up a big hit within a short window", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightBoomKillAssist = CreateConVar("sm_skill_w_boom_kill_assist", "4.0", "Boomer assist when any SI kills a boomed target", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightBigHitAssistScore = CreateConVar("sm_skill_w_bighit_assist_score", "10.0", "Assist weight scaled by damage for CC-enabled big hits", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightShoveSI = CreateConVar("sm_skill_w_shove_si", "3.0", "Weight per effective shove on special infected", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightWitchCrown = CreateConVar("sm_skill_w_witch_crown", "12.0", "Weight for clean witch crown/kill", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightChargerMulti = CreateConVar("sm_skill_w_charger_multi", "6.0", "Weight for charger multi-hit (2nd+ victim in one charge)", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSpitMulti = CreateConVar("sm_skill_w_spit_multi", "4.0", "Weight for spitter hitting multiple survivors in same spit tick window", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightRockSkeet = CreateConVar("sm_skill_w_rock_skeet", "16.0", "Weight per tank rock skeet by survivors", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightChainClearBoom = CreateConVar("sm_skill_w_chain_clear_boom", "6.0", "Weight for clearing/picking up a boomed teammate quickly", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSafeSave = CreateConVar("sm_skill_w_safe_save", "6.0", "Weight for fast save on pinned/incapped teammate", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightZeroFFBonus = CreateConVar("sm_skill_w_zero_ff_bonus", "8.0", "Bonus for a round with zero FF and sufficient actions", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSharedFocus = CreateConVar("sm_skill_w_shared_focus", "3.0", "Weight per shared focus hit (multiple SI on same target window)", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightBoomFocus = CreateConVar("sm_skill_w_boom_focus", "3.0", "Weight for boomer when teammates follow-up on boomed target", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightStaggerSetup = CreateConVar("sm_skill_w_stagger_setup", "3.0", "Weight for setups (stagger/slow) that enable other SI within window", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightChainControl = CreateConVar("sm_skill_w_chain_control", "4.0", "Weight for Smoker->Hunter/Jockey chain control assist", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTankSupport = CreateConVar("sm_skill_w_tank_support", "4.0", "Weight for assisting tank hits via boom/pin setup", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightAlarmPenalty = CreateConVar("sm_skill_w_alarm_penalty", "-8.0", "Penalty per car alarm triggered", FCVAR_NONE, false, 0.0, false);
	g_CvarWeightTankHoldSec = CreateConVar("sm_skill_w_tank_hold_sec", "0.05", "Weight per second holding tank", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTankKill = CreateConVar("sm_skill_w_tank_kill", "12.0", "Weight per survivor kill by tank", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTankPassPenalty = CreateConVar("sm_skill_w_tank_pass_penalty", "-6.0", "Penalty per voluntary tank pass", FCVAR_NONE, false, 0.0, false);
	g_CvarWeightTankWipe = CreateConVar("sm_skill_w_tank_wipe", "20.0", "Bonus when tank is alive and survivors are wiped", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightChargerLevel = CreateConVar("sm_skill_w_charger_level", "10.0", "Weight for leveling/interrupting charger", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTongueCut = CreateConVar("sm_skill_w_tongue_cut", "6.0", "Weight for cutting smoker tongue", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSpecialShove = CreateConVar("sm_skill_w_special_shove", "4.0", "Weight for shoving special infected (from skill_detect forward)", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightRockEatenPenalty = CreateConVar("sm_skill_w_rock_eaten_penalty", "-10.0", "Penalty when survivor eats a tank rock", FCVAR_NONE, false, 0.0, false);
	g_CvarWeightReviveInterrupt = CreateConVar("sm_skill_w_revive_interrupt", "5.0", "Weight for interrupting a revive (infected)", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightRevive = CreateConVar("sm_skill_w_revive", "10.0", "Revive weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightMedkitGive = CreateConVar("sm_skill_w_medkit_give", "10.0", "Heal other with medkit weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightRescue = CreateConVar("sm_skill_w_rescue", "8.0", "Rescue from special pin weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightJockeyBlock = CreateConVar("sm_skill_w_jockey_block", "10.0", "Jockey block/shove-interrupt weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTankPlayAction = CreateConVar("sm_skill_w_tankplay_action", "4.0", "Bonus for high-skill actions performed while tank is in play", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightFriendlyFire = CreateConVar("sm_skill_w_ff", "-0.4", "Penalty per friendly fire damage dealt", FCVAR_NONE, false, 0.0, false);
	g_CvarWeightHeadshotSI = CreateConVar("sm_skill_w_headshot_si", "6.0", "Weight per headshot on special infected", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSurvivalSec = CreateConVar("sm_skill_w_survival_sec", "0.02", "Weight per second alive in round", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightFlowPercent = CreateConVar("sm_skill_w_flow_percent", "0.15", "Weight per % flow progress (best without tank)", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightBoomerVomitHit = CreateConVar("sm_skill_w_boomer_vomit_hit", "2.0", "Weight per boomer vomit victim (infected side)", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightBoomerVomitCast = CreateConVar("sm_skill_w_boomer_vomit_cast", "-0.5", "Penalty per boomer vomit cast (infected side)", FCVAR_NONE, false, 0.0, false);
	g_CvarTopMinRounds = CreateConVar("sm_skill_top_min_rounds", "10", "Minimum rounds for top ranking (hard floor 10)", FCVAR_NONE, true, 0.0, false);
	g_CvarMixVotePct = CreateConVar("sm_skill_mix_vote_pct", "51", "Percent votes required for skill mix", FCVAR_NONE, true, 1.0, true, 100.0);
	g_CvarMixVoteCooldown = CreateConVar("sm_skill_mix_vote_cooldown", "120.0", "Cooldown between skill mix votes", FCVAR_NONE, true, 0.0, false);

	AutoExecConfig(true, "kether_skill_rating");

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
	HookEvent("player_shoved", Event_PlayerShoved, EventHookMode_Post);
	HookEvent("witch_killed", Event_WitchKilled, EventHookMode_Post);
	HookEvent("tank_spawn", Event_TankSpawn, EventHookMode_PostNoCopy);
	HookEvent("charger_carry_end", Event_PinEnd_Generic, EventHookMode_Post);
	HookEvent("triggered_car_alarm", Event_CarAlarmTriggered, EventHookMode_Post);

	RegConsoleCmd("sm_skill", Command_Skill, "Show your skill rating");
	RegConsoleCmd("sm_myskill", Command_Skill, "Show your skill rating");
	RegConsoleCmd("sm_skilltop", Command_SkillTop, "Show top skill players");
	RegConsoleCmd("sm_skillsim", Command_SkillSim, "Show players with a similar profile");
	RegConsoleCmd("sm_skillmix", Command_SkillMixVote, "Call vote to mix teams by skill");

	g_bReadyUpAvailable = LibraryExists("readyup");

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
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "readyup"))
	{
		g_bReadyUpAvailable = false;
	}
}

public void OnMapEnd()
{
	FinalizeRoundIfNeeded();
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
	g_fTankHoldStart = 0.0;
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));

	for (int i = 1; i <= MaxClients; i++)
	{
		ResetRoundStats(i);
		g_fLifeStart[i] = GetEngineTime();
		g_bAliveAtEnd[i] = true;
	}

	if (g_hFlowTimer != null)
	{
		CloseHandle(g_hFlowTimer);
	}
	g_hFlowTimer = CreateTimer(1.0, Timer_FlowSnapshot, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_FlowSnapshot(Handle timer)
{
	if (!g_bRoundActive || g_bRoundFinalized)
	{
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

public void OnRoundIsLive()
{
	if (!g_CvarEnabled.BoolValue || g_bRoundFinalized)
	{
		return;
	}

	g_bRoundLive = true;
	g_bPaused = false;

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

	if (!IsRoundEligibleForStats())
	{
		PrintToServer("[SkillRating] Round skipped: requires minimum 3v3 human players.");
		if (g_hFlowTimer != null)
		{
			CloseHandle(g_hFlowTimer);
			g_hFlowTimer = null;
		}
		return;
	}

	if (g_hFlowTimer != null)
	{
		CloseHandle(g_hFlowTimer);
		g_hFlowTimer = null;
	}

	int survAlive = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidHuman(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i))
		{
			survAlive++;
		}
	}
	if (survAlive == 0 && g_iCurrentTank > 0 && IsValidHuman(g_iCurrentTank) && GetClientTeam(g_iCurrentTank) == TEAM_INFECTED)
	{
		g_iTankWipeBonus[g_iCurrentTank]++;
		EndTankHoldSegment(g_iCurrentTank);
	}
	else if (g_iCurrentTank > 0)
	{
		EndTankHoldSegment(g_iCurrentTank);
	}

	float teamPoolBase = g_CvarRoundPool.FloatValue;
	float teamRawSum[4];
	float teamAdjSum[4];
	int teamCount[4];

	teamRawSum[TEAM_SURVIVOR] = 0.0;
	teamRawSum[TEAM_INFECTED] = 0.0;
	teamAdjSum[TEAM_SURVIVOR] = 0.0;
	teamAdjSum[TEAM_INFECTED] = 0.0;
	teamCount[TEAM_SURVIVOR] = 0;
	teamCount[TEAM_INFECTED] = 0;

	float rawScore[MAXPLAYERS + 1];

	for (int i = 1; i <= MaxClients; i++)
	{
		rawScore[i] = 0.0;

		if (!IsValidHuman(i))
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

		rawScore[i] = ComputeRawRoundScore(i, team);
		teamRawSum[team] += rawScore[i];
		teamCount[team]++;
	}

	// Compute team medians for percentile damping
	float teamMedian[4];
	teamMedian[TEAM_SURVIVOR] = 0.0;
	teamMedian[TEAM_INFECTED] = 0.0;
	for (int t = TEAM_SURVIVOR; t <= TEAM_INFECTED; t++)
	{
		int cnt = 0;
		float values[MAXPLAYERS + 1];
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsValidHuman(i) || GetClientTeam(i) != t)
			{
				continue;
			}
			values[cnt++] = rawScore[i];
		}
		if (cnt > 0)
		{
			// simple insertion sort
			for (int a = 1; a < cnt; a++)
			{
				float key = values[a];
				int b = a - 1;
				while (b >= 0 && values[b] > key)
				{
					values[b + 1] = values[b];
					b--;
				}
				values[b + 1] = key;
			}
			if (cnt % 2 == 1)
			{
				teamMedian[t] = values[cnt / 2];
			}
			else
			{
				teamMedian[t] = (values[(cnt / 2) - 1] + values[cnt / 2]) * 0.5;
			}
		}
	}

	// Roster quality multiplier
	float teamPoolScaled[4];
	for (int t = TEAM_SURVIVOR; t <= TEAM_INFECTED; t++)
	{
		float avgRounds = 0.0;
		if (teamCount[t] > 0)
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsValidHuman(i) && GetClientTeam(i) == t)
				{
					avgRounds += float(g_iRoundsPlayed[i]);
				}
			}
			avgRounds /= float(teamCount[t]);
		}
		float rosterMult = FloatClamp(avgRounds / 50.0, 0.5, 1.0);
		teamPoolScaled[t] = teamPoolBase * rosterMult;
	}

	// Adjust raw scores with percentile/damping and compute adjusted sums
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

		float median = teamMedian[team];
		float adjusted = rawScore[i];
		if (median > 0.0 && adjusted > (1.5 * median))
		{
			adjusted = median + (adjusted - median) * 0.5;
		}
		if (teamRawSum[team] > 0.0 && (rawScore[i] / teamRawSum[team]) > 0.4 && teamRawSum[team] < (median * float(teamCount[team]) * 0.5))
		{
			adjusted *= 0.7;
		}

		// zero FF bonus check (survivor only)
		if (team == TEAM_SURVIVOR && g_iFriendlyFireDealt[i] == 0)
		{
			int actionCount = g_iSpecialClears[i] + g_iSmokerSelfClears[i] + g_iSkeets[i] + g_iSkeetsMelee[i] + g_iDeadstops[i] + g_iBoomerPopsNoVomit[i] + g_iRevives[i] + g_iMedkitGives[i] + g_iRescuesFromSpecial[i] + g_iJockeyBlocks[i] + g_iTankPlayActions[i] + g_iChainClearBoom[i] + g_iSafeSaves[i];
			if (actionCount >= 5)
			{
				g_iZeroFFBonus[i] = 1;
			}
		}

		rawScore[i] = adjusted;
		teamAdjSum[team] += adjusted;
	}

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

		float awarded = 0.0;
		if (teamCount[team] > 0)
		{
			if (teamAdjSum[team] > 0.0001)
			{
				awarded = teamPoolScaled[team] * (rawScore[i] / teamAdjSum[team]);
			}
			else
			{
				awarded = teamPoolScaled[team] / float(teamCount[team]);
			}
		}

		SaveRoundAndUpdatePlayer(i, team, rawScore[i], awarded);
	}

	g_bRoundLive = false;
	g_bPaused = false;
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
		return score;
	}

	score += float(g_iDamageAsSurvivor[client]) * g_CvarWeightSurvDamage.FloatValue;
	score += float(g_iTankDamageAsSurvivor[client]) * g_CvarWeightTankDamage.FloatValue;
	score += float(g_iWitchDamageAsSurvivor[client]) * g_CvarWeightWitchDamage.FloatValue;
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
	score += float(g_iPinAssists[client]) * g_CvarWeightPinAssist.FloatValue;
	score += g_fBigHitAssistScore[client] * g_CvarWeightBigHitAssistScore.FloatValue;
	score += float(g_iSpitPinnedTicks[client]) * g_CvarWeightSpitPinnedTick.FloatValue;
	score += float(g_iSpitIncapTicks[client]) * g_CvarWeightSpitIncapTick.FloatValue;
	score += float(g_iTankBoomAssists[client]) * g_CvarWeightTankBoomAssist.FloatValue;
	score += float(g_iWitchAssists[client]) * g_CvarWeightWitchAssist.FloatValue;
	score += float(g_iSpitSetupAssists[client]) * g_CvarWeightSpitSetupAssist.FloatValue;
	score += float(g_iBoomKillAssists[client]) * g_CvarWeightBoomKillAssist.FloatValue;
	score += float(g_iFriendlyFireDealt[client]) * g_CvarWeightFriendlyFire.FloatValue;
	score += float(g_iHeadshotSI[client]) * g_CvarWeightHeadshotSI.FloatValue;
	score += g_fSurvivalTime[client] * g_CvarWeightSurvivalSec.FloatValue;
	score += g_fFlowBest[client] * g_CvarWeightFlowPercent.FloatValue;
	score += float(g_iBoomerPopsSplash[client]) * g_CvarWeightBoomerPopSplash.FloatValue;
	score += float(g_iShoveSI[client]) * g_CvarWeightShoveSI.FloatValue;
	score += float(g_iWitchCrowns[client]) * g_CvarWeightWitchCrown.FloatValue;
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
	// Track last spitter damage on victim (for setup assists)
	if (attackerTeam == TEAM_INFECTED)
	{
		int zClassAtt = GetEntProp(attacker, Prop_Send, "m_zombieClass");
		if (zClassAtt == ZC_SPITTER && GetClientTeam(victim) == TEAM_SURVIVOR)
		{
			g_iLastSpitterForVictim[victim] = attacker;
			g_fLastSpitTime[victim] = GetEngineTime();
		}
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
	if (amount > 0)
	{
		g_iWitchDamageAsSurvivor[attacker] += amount;
	}
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

public void Event_CarAlarmTriggered(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bRoundActive || !g_CvarEnabled.BoolValue)
	{
		return;
	}
	int survivor = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidHuman(survivor) && GetClientTeam(survivor) == TEAM_SURVIVOR)
	{
		g_iAlarmTriggers[survivor]++;
	}
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

public void Event_PlayerShoved(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bRoundActive || !g_CvarEnabled.BoolValue)
	{
		return;
	}

	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!IsValidHuman(attacker) || GetClientTeam(attacker) != TEAM_SURVIVOR)
	{
		return;
	}
	if (!IsValidHuman(victim) || GetClientTeam(victim) != TEAM_INFECTED)
	{
		return;
	}

	g_iShoveSI[attacker]++;
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
		g_iWitchCrowns[killer]++;
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
	if (IsValidHuman(attacker) && GetClientTeam(attacker) == TEAM_INFECTED)
	{
		if (g_iChargerCarryCount[attacker] > 0)
		{
			AddChargerMultiHit(attacker);
		}
		g_iChargerCarryCount[attacker]++;
	}
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

	int attacker = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidHuman(attacker) && GetClientTeam(attacker) == TEAM_INFECTED)
	{
		int zc = GetEntProp(attacker, Prop_Send, "m_zombieClass");
		if (zc == ZC_CHARGER)
		{
			g_iChargerCarryCount[attacker] = 0;
		}
	}
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
		g_iLastBoomerVomitHits[boomer] = amount;
		g_fLastBoomerVomitTime[boomer] = GetEngineTime();
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
		g_iRescuesFromSpecial[clearer]++;
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

	g_iSpecialShoveSaves[survivor]++;

	// Heuristic: jockey shove-interrupts are treated as "jockey blocks".
	if (zombieClass == ZC_JOCKEY)
	{
		g_iJockeyBlocks[survivor]++;
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
		ReplyToCommand(client, "[Skill] Plugin is disabled.");
		return Plugin_Handled;
	}

	if (!IsValidHuman(client))
	{
		ReplyToCommand(client, "[Skill] This command is in-game only.");
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

	float avg = GetAveragePoints(target);

	Menu menu = new Menu(MenuHandler_InfoBack, MENU_ACTIONS_DEFAULT);
	char title[128];
	char displayName[160];
	BuildDisplayName(target, displayName, sizeof(displayName));
	Format(title, sizeof(title), "Skill Summary: %s", displayName);
	menu.SetTitle(title);

	char line[256];

	// Very short overview only (hide details)
	Format(line, sizeof(line), "Total points: %.2f | Rounds: %d | Avg: %.2f", g_fTotalPoints[target], g_iRoundsPlayed[target], avg);
	menu.AddItem("x", line, ITEMDRAW_DISABLED);
	Format(line, sizeof(line), "Flow best: %.1f%% | Survival (rnd): %.0fs", g_fFlowBest[target], g_fSurvivalTime[target]);
	menu.AddItem("x", line, ITEMDRAW_DISABLED);
	Format(line, sizeof(line), "FF dealt/taken: %d/%d | HS SI: %d", g_iFriendlyFireDealt[target], g_iFriendlyFireTaken[target], g_iHeadshotSI[target]);
	menu.AddItem("x", line, ITEMDRAW_DISABLED);
	menu.AddItem("x", "--- Survivors ---", ITEMDRAW_DISABLED);
	int survActions = g_iSpecialClears[target] + g_iSmokerSelfClears[target] + g_iRevives[target] + g_iMedkitGives[target] + g_iRescuesFromSpecial[target] + g_iJockeyBlocks[target] + g_iChainClearBoom[target] + g_iSafeSaves[target] + g_iTankPlayActions[target];
	Format(line, sizeof(line), "Dmg total: %d | Actions: %d | Skeets: %d", g_iDamageAsSurvivor[target], survActions, g_iSkeets[target] + g_iSkeetsMelee[target]);
	menu.AddItem("x", line, ITEMDRAW_DISABLED);
	Format(line, sizeof(line), "Crowns/Shoves: %d/%d | Alarms: %d", g_iWitchCrowns[target], g_iShoveSI[target], g_iAlarmTriggers[target]);
	menu.AddItem("x", line, ITEMDRAW_DISABLED);
	menu.AddItem("x", "--- Infected ---", ITEMDRAW_DISABLED);
	int infActions = g_iPinAssists[target] + g_iBigHitAssists[target] + g_iSpitSetupAssists[target] + g_iBoomKillAssists[target] + g_iSharedFocus[target] + g_iBoomFocusAssist[target] + g_iChainControlAssist[target] + g_iTankSupportAssist[target] + g_iChargerMulti[target] + g_iSpitMultiHits[target] + g_iReviveInterrupts[target];
	Format(line, sizeof(line), "Dmg: %d | Vomit hits: %d | Actions: %d", g_iDamageAsInfected[target], g_iBoomerVomitHits[target], infActions);
	menu.AddItem("x", line, ITEMDRAW_DISABLED);
	Format(line, sizeof(line), "Tank: hold %.0fs | kills %d | passes %d", g_fTankHoldTime[target], g_iTankKills[target], g_iTankPasses[target]);
	menu.AddItem("x", line, ITEMDRAW_DISABLED);
	menu.AddItem("x", "Tip: use !skilltop / !skillsim", ITEMDRAW_DISABLED);

	menu.ExitBackButton = showBackButton;
	menu.Display(client, 20);
}

public Action Command_SkillTop(int client, int args)
{
	if (!g_CvarEnabled.BoolValue)
	{
		ReplyToCommand(client, "[Skill] Plugin is disabled.");
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

	int minRounds = g_CvarTopMinRounds.IntValue;
	if (minRounds < 10)
	{
		minRounds = 10;
	}

	RequestTopMenu(client, limit, minRounds, false);

	return Plugin_Handled;
}

public Action Command_SkillSim(int client, int args)
{
	if (!g_CvarEnabled.BoolValue)
	{
		ReplyToCommand(client, "[Skill] Plugin is disabled.");
		return Plugin_Handled;
	}

	if (!IsValidHuman(client))
	{
		ReplyToCommand(client, "[Skill] This command is in-game only.");
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

public Action Command_SkillMixVote(int client, int args)
{
	if (!g_CvarEnabled.BoolValue)
	{
		ReplyToCommand(client, "[SkillMix] Plugin is disabled.");
		return Plugin_Handled;
	}

	if (!IsValidHuman(client))
	{
		ReplyToCommand(client, "[SkillMix] This command is in-game only.");
		return Plugin_Handled;
	}

	if (GetClientTeam(client) == TEAM_SPECTATOR)
	{
		ReplyToCommand(client, "[SkillMix] Spectators cannot call this vote.");
		return Plugin_Handled;
	}

	if (g_bMixVoteInProgress || IsBuiltinVoteInProgress())
	{
		ReplyToCommand(client, "[SkillMix] A vote is already in progress.");
		return Plugin_Handled;
	}

	int survCount = 0;
	int infCount = 0;
	int voters[MAXPLAYERS + 1];
	int voterCount = CollectEligibleVoters(voters, survCount, infCount);

	if (!IsValidMixSetup(survCount, infCount))
	{
		ReplyToCommand(client, "[SkillMix] Mix requires equal teams with 1v1 up to 4v4.");
		return Plugin_Handled;
	}

	float now = GetEngineTime();
	float cooldown = g_CvarMixVoteCooldown.FloatValue;
	if ((now - g_fLastMixVoteTime) < cooldown)
	{
		ReplyToCommand(client, "[SkillMix] Vote cooldown active.");
		return Plugin_Handled;
	}

	g_hMixVote = CreateBuiltinVote(Handle_MixVoteAction, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
	SetBuiltinVoteArgument(g_hMixVote, "Mix teams by skill rating?");
	SetBuiltinVoteInitiator(g_hMixVote, client);
	SetBuiltinVoteResultCallback(g_hMixVote, Handle_MixVoteResult);
	DisplayBuiltinVote(g_hMixVote, voters, voterCount, 15);
	FakeClientCommand(client, "Vote Yes");

	g_bMixVoteInProgress = true;
	g_fLastMixVoteTime = now;

	return Plugin_Handled;
}

void ShowSkillMainMenu(int client)
{
	Menu menu = new Menu(MenuHandler_SkillMain, MENU_ACTIONS_DEFAULT);
	menu.SetTitle("=== Skill Rating ===");
	menu.AddItem("x", "Choose an option:", ITEMDRAW_DISABLED);
	menu.AddItem("my", "My skill");
	menu.AddItem("top", "Top players");
	menu.AddItem("sim", "Similar players to me");
	menu.AddItem("mix", "Call skill mix vote");
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
	else if (StrEqual(info, "top"))
	{
		int minRounds = g_CvarTopMinRounds.IntValue;
		if (minRounds < 10)
		{
			minRounds = 10;
		}
		RequestTopMenu(client, 10, minRounds, true);
	}
	else if (StrEqual(info, "sim"))
	{
		RequestSimilarityMenu(client, client, true);
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
		ReplyToCommand(client, "[Skill] No access.");
		return;
	}

	char query[512];
	Format(query, sizeof(query),
		"SELECT steamid, last_name, first_name, total_points, rounds_played "
		... "FROM players ORDER BY rounds_played DESC, total_points DESC LIMIT 200;");

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
		ReplyToCommand(client, "[Skill] Failed to load admin reset list: %s", error);
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
		float total = results.FetchFloat(3);
		int rounds = results.FetchInt(4);
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
			Format(label, sizeof(label), "%s (%s) | rounds %d | total %.1f", lastName, firstName, rounds, total);
		}
		else
		{
			Format(label, sizeof(label), "%s | rounds %d | total %.1f", lastName, rounds, total);
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
	Format(q2, sizeof(q2), "UPDATE players SET total_points=0.0, rounds_played=0 WHERE steamid='%s';", steamid);
	g_Db.Query(SQL_ErrorOnly, q2);

	int target = FindOnlineClientBySteamId(steamid);
	if (target > 0)
	{
		g_fTotalPoints[target] = 0.0;
		g_iRoundsPlayed[target] = 0;
		ResetRoundStats(target);
		PrintToChat(target, "[Skill] Your skill stats were reset by admin.");
	}

	ReplyToCommand(adminClient, "[Skill] Stats reset for steamid %s", steamid);
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

	float yesPct = 0.0;
	if (num_votes > 0)
	{
		yesPct = (float(yesVotes) / float(num_votes)) * 100.0;
	}

	if (yesPct < g_CvarMixVotePct.FloatValue)
	{
		DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
		return;
	}

	DisplayBuiltinVotePass(vote, "Applying skill mix...");
	PerformSkillMix();
}

void PerformSkillMix()
{
	int players[MAXPLAYERS + 1];
	float rating[MAXPLAYERS + 1];
	int count = 0;
	int survCount = 0;
	int infCount = 0;

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
		rating[count] = GetAveragePoints(i);
		count++;

		if (team == TEAM_SURVIVOR)
		{
			survCount++;
		}
		else if (team == TEAM_INFECTED)
		{
			infCount++;
		}
	}

	if (!IsValidMixSetup(survCount, infCount))
	{
		PrintToChatAll("[SkillMix] Mix aborted: teams are no longer valid.");
		return;
	}

	SortByRatingDesc(players, rating, count);

	int teamSize = count / 2;
	int teamSurv[MAXPLAYERS + 1];
	int teamInf[MAXPLAYERS + 1];
	int survIdx = 0;
	int infIdx = 0;
	float sumSurv = 0.0;
	float sumInf = 0.0;

	for (int i = 0; i < count; i++)
	{
		if (survIdx >= teamSize)
		{
			teamInf[infIdx++] = players[i];
			sumInf += rating[i];
			continue;
		}
		if (infIdx >= teamSize)
		{
			teamSurv[survIdx++] = players[i];
			sumSurv += rating[i];
			continue;
		}

		if (sumSurv <= sumInf)
		{
			teamSurv[survIdx++] = players[i];
			sumSurv += rating[i];
		}
		else
		{
			teamInf[infIdx++] = players[i];
			sumInf += rating[i];
		}
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidHuman(i) && GetClientTeam(i) != TEAM_SPECTATOR)
		{
			ChangeClientTeam(i, TEAM_SPECTATOR);
		}
	}

	for (int i = 0; i < survIdx; i++)
	{
		MoveHumanToTeam(teamSurv[i], TEAM_SURVIVOR);
	}
	for (int i = 0; i < infIdx; i++)
	{
		MoveHumanToTeam(teamInf[i], TEAM_INFECTED);
	}

	PrintToChatAll("[SkillMix] Teams mixed by current skill rating.");
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
		int flags = GetCommandFlags("sb_takecontrol");
		SetCommandFlags("sb_takecontrol", flags & ~FCVAR_CHEAT);
		FakeClientCommand(client, "sb_takecontrol");
		SetCommandFlags("sb_takecontrol", flags);
		return true;
	}

	ChangeClientTeam(client, TEAM_SURVIVOR);
	return true;
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

void RequestTopMenu(int client, int limit, int minRounds, bool showBackButton)
{
	char query[512];
	Format(query, sizeof(query),
		"SELECT last_name, first_name, total_points, rounds_played, "
		... "CASE WHEN rounds_played > 0 THEN (total_points / rounds_played) ELSE 0 END AS avg_score "
		... "FROM players WHERE rounds_played >= %d ORDER BY avg_score DESC, total_points DESC LIMIT %d;",
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
	char steamid[32];
	if (!GetPlayerSteamId(target, steamid, sizeof(steamid)))
	{
		ReplyToCommand(client, "[Skill] Cannot resolve SteamID for target.");
		return;
	}

	char query[1024];
	Format(query, sizeof(query),
		"SELECT p.steamid, p.last_name, p.first_name, p.total_points, p.rounds_played, "
		... "COALESCE(SUM(r.dmg_survivor), 0), COALESCE(SUM(r.dmg_infected), 0), COALESCE(SUM(r.dmg_tank), 0), "
		... "COALESCE(SUM(r.special_clears + r.self_clears + r.skeets + r.skeets_melee + r.deadstops + r.boomer_pops + r.revives + r.medkit_gives + r.special_rescues + r.jockey_blocks + r.tank_play_actions), 0) "
		... "FROM players p LEFT JOIN round_stats r ON p.steamid = r.steamid "
		... "WHERE p.steamid = '%s' GROUP BY p.steamid;",
		steamid);

	DataPack pack = new DataPack();
	pack.WriteCell(client);
	pack.WriteCell(showBackButton ? 1 : 0);
	g_Db.Query(SQL_LoadSimilarityTarget, query, pack);
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
		ReplyToCommand(client, "[Skill] Top query failed: %s", error);
		return;
	}

	Menu menu = new Menu(MenuHandler_InfoBack, MENU_ACTIONS_DEFAULT);
	char title[128];
	Format(title, sizeof(title), "Top %d Players (min rounds: %d)", limit, minRounds);
	menu.SetTitle(title);
	menu.ExitBackButton = showBackButton;

	int rank = 1;
	while (results.FetchRow())
	{
		char lastName[MAX_NAME_LENGTH];
		char firstName[MAX_NAME_LENGTH];
		results.FetchString(0, lastName, sizeof(lastName));
		results.FetchString(1, firstName, sizeof(firstName));
		float total = results.FetchFloat(2);
		int rounds = results.FetchInt(3);
		float avg = results.FetchFloat(4);

		if (lastName[0] == '\0' && firstName[0] != '\0')
		{
			strcopy(lastName, sizeof(lastName), firstName);
		}

		char line[192];
		if (firstName[0] != '\0' && !StrEqual(firstName, lastName, false))
		{
			Format(line, sizeof(line), "#%d %s (%s) | avg %.2f | total %.1f | rounds %d", rank, lastName, firstName, avg, total, rounds);
		}
		else
		{
			Format(line, sizeof(line), "#%d %s | avg %.2f | total %.1f | rounds %d", rank, lastName, avg, total, rounds);
		}
		menu.AddItem("x", line, ITEMDRAW_DISABLED);
		rank++;
	}

	if (rank == 1)
	{
		menu.AddItem("x", "No players match ranking criteria.", ITEMDRAW_DISABLED);
	}

	menu.Display(client, 20);
}

public void SQL_LoadSimilarityTarget(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	bool showBackButton = view_as<bool>(pack.ReadCell());
	delete pack;

	if (!IsValidClient(client))
	{
		return;
	}

	if (results == null || !results.FetchRow())
	{
		Menu menu = new Menu(MenuHandler_InfoBack, MENU_ACTIONS_DEFAULT);
		menu.SetTitle("Skill Similarity");
		menu.AddItem("x", "No data available for similarity.", ITEMDRAW_DISABLED);
		menu.ExitBackButton = showBackButton;
		menu.Display(client, 20);
		return;
	}

	char targetSteamid[32];
	results.FetchString(0, targetSteamid, sizeof(targetSteamid));
	char targetLast[MAX_NAME_LENGTH];
	char targetFirst[MAX_NAME_LENGTH];
	results.FetchString(1, targetLast, sizeof(targetLast));
	results.FetchString(2, targetFirst, sizeof(targetFirst));
	float targetTotal = results.FetchFloat(3);
	int targetRounds = results.FetchInt(4);
	float targetDmgSurv = results.FetchFloat(5);
	float targetDmgInf = results.FetchFloat(6);
	float targetDmgTank = results.FetchFloat(7);
	float targetActions = results.FetchFloat(8);

	float r = float(targetRounds > 0 ? targetRounds : 1);
	float targetAvgPts = targetTotal / r;
	float targetAvgSurv = targetDmgSurv / r;
	float targetAvgInf = targetDmgInf / r;
	float targetAvgTank = targetDmgTank / r;
	float targetAvgActions = targetActions / r;

	char targetName[MAX_NAME_LENGTH * 2];
	if (targetFirst[0] != '\0' && !StrEqual(targetFirst, targetLast, false))
	{
		Format(targetName, sizeof(targetName), "%s (%s)", targetLast, targetFirst);
	}
	else
	{
		strcopy(targetName, sizeof(targetName), targetLast);
	}

	char query[1024];
	Format(query, sizeof(query),
		"SELECT p.steamid, p.last_name, p.first_name, p.total_points, p.rounds_played, "
		... "COALESCE(SUM(r.dmg_survivor), 0), COALESCE(SUM(r.dmg_infected), 0), COALESCE(SUM(r.dmg_tank), 0), "
		... "COALESCE(SUM(r.special_clears + r.self_clears + r.skeets + r.skeets_melee + r.deadstops + r.boomer_pops + r.revives + r.medkit_gives + r.special_rescues + r.jockey_blocks + r.tank_play_actions), 0) "
		... "FROM players p LEFT JOIN round_stats r ON p.steamid = r.steamid "
		... "WHERE p.steamid != '%s' GROUP BY p.steamid;",
		targetSteamid);

	DataPack pack2 = new DataPack();
	pack2.WriteCell(client);
	pack2.WriteCell(showBackButton ? 1 : 0);
	pack2.WriteString(targetName);
	pack2.WriteFloat(targetAvgPts);
	pack2.WriteFloat(targetAvgSurv);
	pack2.WriteFloat(targetAvgInf);
	pack2.WriteFloat(targetAvgTank);
	pack2.WriteFloat(targetAvgActions);
	g_Db.Query(SQL_ShowSimilarity, query, pack2);
}

public void SQL_ShowSimilarity(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	bool showBackButton = view_as<bool>(pack.ReadCell());
	char targetName[MAX_NAME_LENGTH * 2];
	pack.ReadString(targetName, sizeof(targetName));
	float targetAvgPts = pack.ReadFloat();
	float targetAvgSurv = pack.ReadFloat();
	float targetAvgInf = pack.ReadFloat();
	float targetAvgTank = pack.ReadFloat();
	float targetAvgActions = pack.ReadFloat();
	delete pack;

	if (!IsValidClient(client))
	{
		return;
	}

	if (results == null)
	{
		ReplyToCommand(client, "[Skill] Similarity query failed: %s", error);
		return;
	}

char topName[5][MAX_NAME_LENGTH * 2];
	float topDist[5];
	float topAvg[5];
	int topRounds[5];

	for (int i = 0; i < 5; i++)
	{
		topDist[i] = 999999.0;
		topAvg[i] = 0.0;
		topRounds[i] = 0;
		topName[i][0] = '\0';
	}

	while (results.FetchRow())
	{
		char lastName[MAX_NAME_LENGTH];
		char firstName[MAX_NAME_LENGTH];
		float total = results.FetchFloat(3);
		int rounds = results.FetchInt(4);
		float dmgSurv = results.FetchFloat(5);
		float dmgInf = results.FetchFloat(6);
		float dmgTank = results.FetchFloat(7);
		float actions = results.FetchFloat(8);
		results.FetchString(1, lastName, sizeof(lastName));
		results.FetchString(2, firstName, sizeof(firstName));

		if (rounds <= 0)
		{
			continue;
		}

		float rr = float(rounds);
		float avgPts = total / rr;
		float avgSurv = dmgSurv / rr;
		float avgInf = dmgInf / rr;
		float avgTank = dmgTank / rr;
		float avgActions = actions / rr;

		float dist = 0.0;
		dist += FloatAbs(avgPts - targetAvgPts) / FloatMax(1.0, targetAvgPts);
		dist += FloatAbs(avgSurv - targetAvgSurv) / FloatMax(1.0, targetAvgSurv);
		dist += FloatAbs(avgInf - targetAvgInf) / FloatMax(1.0, targetAvgInf);
		dist += FloatAbs(avgTank - targetAvgTank) / FloatMax(1.0, targetAvgTank);
		dist += FloatAbs(avgActions - targetAvgActions) / FloatMax(1.0, targetAvgActions);

		int worst = 0;
		for (int i = 1; i < 5; i++)
		{
			if (topDist[i] > topDist[worst])
			{
				worst = i;
			}
		}

		if (dist < topDist[worst])
		{
			topDist[worst] = dist;
			topAvg[worst] = avgPts;
			topRounds[worst] = rounds;
			if (lastName[0] == '\0' && firstName[0] != '\0')
			{
				strcopy(lastName, sizeof(lastName), firstName);
			}
			if (firstName[0] != '\0' && !StrEqual(firstName, lastName, false))
			{
				Format(topName[worst], sizeof(topName[]), "%s (%s)", lastName, firstName);
			}
			else
			{
				strcopy(topName[worst], sizeof(topName[]), lastName);
			}
		}
	}

	Menu menu = new Menu(MenuHandler_InfoBack, MENU_ACTIONS_DEFAULT);
	char title[128];
	Format(title, sizeof(title), "Players similar to %s", targetName);
	menu.SetTitle(title);
	menu.ExitBackButton = showBackButton;

	for (int n = 0; n < 5; n++)
	{
		int best = -1;
		for (int i = 0; i < 5; i++)
		{
			if (topName[i][0] == '\0')
			{
				continue;
			}
			if (best == -1 || topDist[i] < topDist[best])
			{
				best = i;
			}
		}

		if (best == -1)
		{
			break;
		}

		char line[192];
		Format(line, sizeof(line), "%s | avg %.2f | rounds %d", topName[best], topAvg[best], topRounds[best]);
		menu.AddItem("x", line, ITEMDRAW_DISABLED);
		topName[best][0] = '\0';
	}

	if (menu.ItemCount == 0)
	{
		menu.AddItem("x", "No similar players found.", ITEMDRAW_DISABLED);
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
	Format(qLoad, sizeof(qLoad), "SELECT total_points, rounds_played, first_name, last_name FROM players WHERE steamid='%s';", steamid);
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

	if (results == null || !results.FetchRow())
	{
		return;
	}

	g_fTotalPoints[client] = results.FetchFloat(0);
	g_iRoundsPlayed[client] = results.FetchInt(1);
	results.FetchString(2, g_sFirstName[client], sizeof(g_sFirstName[]));
	results.FetchString(3, g_sLastName[client], sizeof(g_sLastName[]));

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

	char qUpdatePlayer[768];
	Format(qUpdatePlayer, sizeof(qUpdatePlayer),
		"UPDATE players SET name='%s', last_name='%s', total_points=total_points+%.4f, rounds_played=rounds_played+1, last_seen=strftime('%%s', 'now'), "
		... "first_name=CASE WHEN first_name='' THEN '%s' ELSE first_name END "
		... "WHERE steamid='%s';",
		escName, escName, awarded, escName, steamid);
	g_Db.Query(SQL_ErrorOnly, qUpdatePlayer);

	char escMap[128];
	g_Db.Escape(g_sMapName, escMap, sizeof(escMap));

	char qRound[2048];
	Format(qRound, sizeof(qRound),
		"INSERT INTO round_stats (steamid, name, round_index, map_name, team, raw_points, awarded_points, "
		... "dmg_infected, dmg_survivor, dmg_tank, dmg_witch, common_kills, special_clears, self_clears, skeets, skeets_melee, deadstops, boomer_pops, boomer_pops_splash, pin_assists, pin_dps_assist, big_hit_assists, big_hit_assist_score, spit_ticks_pinned, spit_ticks_incap, tank_boom_assists, witch_assists, spit_setup_assists, boom_kill_assists, charger_multi, spit_multi_hits, shove_si, witch_crowns, rock_skeets, chain_clear_boom, safe_saves, zero_ff_bonus, shared_focus, boom_focus, stagger_setup, chain_control, tank_support, alarm_triggers, tank_hold_time, tank_passes, tank_kills, tank_wipe_bonus, charger_levels, tongue_cuts, special_shove_saves, rock_eaten_penalty, revive_interrupts, revives, medkit_gives, special_rescues, jockey_blocks, tank_play_actions, ff_dealt, ff_taken, headshot_si, boomer_vomit_casts, boomer_vomit_hits, flow_percent, survival_time, alive_end, ts) "
		... "VALUES ('%s', '%s', %d, '%s', %d, %.4f, %.4f, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %.2f, %d, %.2f, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %.2f, %.2f, %d, strftime('%%s', 'now'));",
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
	g_bAliveAtEnd[client] ? 1 : 0);
	g_Db.Query(SQL_ErrorOnly, qRound);

	g_fTotalPoints[client] += awarded;
	g_iRoundsPlayed[client]++;
}

int GetRecentPinner(int victim, float window, int &zclass)
{
	int pinner = g_iLastPinner[victim];
	if (pinner > 0 && IsValidHuman(pinner) && GetClientTeam(pinner) == TEAM_INFECTED)
	{
		float ago = GetEngineTime() - g_fLastPinEnd[victim];
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

void AddChargerMultiHit(int charger)
{
	if (!IsValidHuman(charger) || GetClientTeam(charger) != TEAM_INFECTED)
	{
		return;
	}
	g_iChargerMulti[charger]++;
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

void ResetRoundStats(int client)
{
	if (client < 1 || client > MaxClients)
	{
		return;
	}

	g_iDamageAsInfected[client] = 0;
	g_iDamageAsSurvivor[client] = 0;
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
	g_iChargerCarryCount[client] = 0;
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
	g_iReviveTargetForReviver[client] = 0;
	g_fReviveStartTime[client] = 0.0;
	g_iLastBoomerKiller[client] = 0;
	g_fLastBoomerDeathTime[client] = 0.0;
	g_iLastBoomerVomitHits[client] = 0;
	g_fLastBoomerVomitTime[client] = 0.0;
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

float GetAveragePoints(int client)
{
	if (g_iRoundsPlayed[client] <= 0)
	{
		return 0.0;
	}
	return g_fTotalPoints[client] / float(g_iRoundsPlayed[client]);
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
		}
		else if (team == TEAM_INFECTED)
		{
			inf++;
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
	EnsureColumn("players", "first_name", "TEXT NOT NULL DEFAULT ''");
	EnsureColumn("players", "last_name", "TEXT NOT NULL DEFAULT ''");

	Format(query, sizeof(query), "UPDATE players SET first_name = CASE WHEN first_name='' THEN name ELSE first_name END;");
	g_Db.Query(SQL_ErrorOnly, query);
	Format(query, sizeof(query), "UPDATE players SET last_name = CASE WHEN last_name='' THEN name ELSE last_name END;");
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
