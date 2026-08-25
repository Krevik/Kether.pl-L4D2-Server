#if defined __ph_globals_included
	#endinput
#endif
#define __ph_globals_included

// L4D2 team numbers (also defined this way in confoglcompmod/includes/constants.sp).
#define PH_TEAM_SPECTATOR	1
#define PH_TEAM_HUNTER		2		// Survivor team - the seekers.
#define PH_TEAM_PROP		3		// Infected team - the hiders.

// m_zombieClass value for L4D_SetClass()/m_zombieClass - Hunter.
#define PH_ZOMBIECLASS_HUNTER	3

enum PHRoundPhase
{
	PHPhase_Warmup = 0,	// Not enough players / mode just loaded, waiting.
	PHPhase_Hide,		// Hunters frozen+blinded, props pick a disguise and hide.
	PHPhase_Seek,		// Hunters released, round timer running.
	PHPhase_End			// Between-round pause before the next PH_StartRound().
};

enum PHPropType
{
	PHProp_None = 0,
	PHProp_Static,
	PHProp_Dynamic,
	PHProp_Physics
};

PHRoundPhase g_ePhase = PHPhase_Warmup;

// Per-client round state.
bool g_bPropEliminated[MAXPLAYERS + 1];	// True once a prop has died this round - blocks re-materializing.
bool g_bPropDisguised[MAXPLAYERS + 1];		// True once a prop has picked a model this round.
bool g_bPropFrozen[MAXPLAYERS + 1];		// Rotation-lock state.
bool g_bThirdperson[MAXPLAYERS + 1];
int g_iVisualProp[MAXPLAYERS + 1] = {-1, ...};	// Entity reference of the parented visual prop.
char g_sDisguiseModel[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
PHPropType g_ePropType[MAXPLAYERS + 1];
int g_iPropChanges[MAXPLAYERS + 1];		// How many times this client re-picked a model this round.
float g_flNextTauntTime[MAXPLAYERS + 1];
float g_flAutoFreezeIdleSince[MAXPLAYERS + 1];
float g_flNextChangeAllowed[MAXPLAYERS + 1];

// Rotation / fairness (teams.sp).
int g_iGuaranteedHunterTurns[MAXPLAYERS + 1];	// Rounds left before this client can be picked as hunter again.
bool g_bHunterVolunteer[MAXPLAYERS + 1];
bool g_bWasHunterLastRound[MAXPLAYERS + 1];

// Round bookkeeping (rounds.sp).
int g_iPropsAliveCount = 0;
int g_iPropsTotalCount = 0;
int g_iRoundNumber = 0;
float g_flPhaseEndTime = 0.0;	// GetGameTime() value the current Hide/Seek phase ends at, for the HUD countdown.

Handle g_hHudSync = null;

Handle g_hTimerHidePhaseEnd = null;
Handle g_hTimerRoundTimeUp = null;
Handle g_hTimerRoundEndDelay = null;
Handle g_hTimerHudUpdate = null;
Handle g_hTimerPeriodicCue = null;
Handle g_hTimerAntiCheatScan = null;

stock bool PH_IsHunter(int client)
{
	return GetClientTeam(client) == PH_TEAM_HUNTER;
}

stock bool PH_IsProp(int client)
{
	return GetClientTeam(client) == PH_TEAM_PROP;
}

stock bool PH_IsModeActive()
{
	if (GetFeatureStatus(FeatureType_Native, "LGO_IsMatchModeLoaded") != FeatureStatus_Available)
		return false;

	if (!LGO_IsMatchModeLoaded())
		return false;

	char name[64];
	LGO_GetConfigName(name, sizeof(name));
	return StrEqual(name, "prophunt", false);
}

stock void PH_ResetClientRoundState(int client)
{
	g_bPropEliminated[client] = false;
	g_bPropDisguised[client] = false;
	g_bPropFrozen[client] = false;
	g_iPropChanges[client] = 0;
	g_flNextTauntTime[client] = 0.0;
	g_flAutoFreezeIdleSince[client] = 0.0;
	g_flNextChangeAllowed[client] = 0.0;
	g_sDisguiseModel[client][0] = '\0';
	g_ePropType[client] = PHProp_None;
}
