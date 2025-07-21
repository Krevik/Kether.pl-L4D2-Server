#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2lib>
#include <colors>
#include <l4d2_saferoom_detect>
#include <timers>

Handle hCvarValveSurvivalBonus = INVALID_HANDLE;
Handle g_hCvarDefibPenalty	   = INVALID_HANDLE;

float  totalBonus[2];
float  healthItemsBonus[2];
float  healthBonus[2];
float  survivalBonus[2];
float  tankKillBonus[2];
float  tankPassBonus[2];
float  witchCrownBonus[2];
int	   survivorsSurvived[2]; // Excluding incaps
int	   aliveSurvs[2]; // Including incaps
int	   teamSize;
float  mapDistanceFactor;
int	   playerIncaps[64];

float  WITCH_CROWN_BONUS					= 24.0;
float  TANK_KILL_BONUS						= 24.0;
float  TANK_PASS_BONUS						= 48.0;
float  SURVIVOR_SURVIVED_BONUS_BASE			= 36.0;
float  FULL_HP_SURVIVOR_SURVIVED_BONUS_BASE = 24.0;
float  PILLS_ADRENALINE_BONUS_BASE			= 12.0;
float  MEDKIT_BONUS_BASE					= 28.0;

public Plugin myinfo =
{
	name		= "L4D2 Scoring plugin",
	author		= "Krevik",
	description = "Gives score bonuses for pills, adrenaline, HP, tank kill/pass, witch crown",
	version		= "1.10",
	url			= "kether.pl"
};

public void OnPluginStart()
{
	g_hCvarDefibPenalty		= FindConVar("vs_defib_penalty");
	hCvarValveSurvivalBonus = FindConVar("vs_survival_bonus");
	teamSize				= GetConVarInt(FindConVar("survivor_limit"));

	RegConsoleCmd("sm_health", CMD_print_bonuses, "Let's print those bonuses");
	RegConsoleCmd("sm_bonus", CMD_print_bonuses, "Let's print those bonuses");

	RegConsoleCmd("sm_bonusinfo", CMD_print_bonus_info, "Let's print those bonuses info.");
	RegConsoleCmd("sm_binfo", CMD_print_bonus_info, "Let's print those bonuses info.");
	RegConsoleCmd("sm_minfo", CMD_print_bonus_info, "Let's print those bonuses info.");
	RegConsoleCmd("sm_mapinfo", CMD_print_bonus_info, "Let's print those bonuses info.");

	HookEvent("player_incapacitated", Event_OnPlayerIncapped);
}

public OnPluginEnd()
{
	ResetConVar(hCvarValveSurvivalBonus);
	ResetConVar(g_hCvarDefibPenalty);
}

public void OnMapStart()
{
	clearSavedBonusParameters();
	CreateTimer(0.1, UpdateMapDistanceFactor);
}

public void OnMapEnd()
{
	clearSavedBonusParameters();
}

public void Event_RoundStart(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int team = InSecondHalfOfRound();
	if (team == 0)
	{
		clearSavedBonusParameters();
	}
	CreateTimer(0.1, UpdateMapDistanceFactor);
	// Rest player incaps counter
	for (int i = 1; i <= MaxClients; i++)
	{
		playerIncaps[i] = 0;
	}
}

// Events
public void Event_OnPlayerIncapped(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsSurvivor(client))
	{
		playerIncaps[client] += 1;
	}
}

// commands
// bonus info
public Action CMD_print_bonus_info(int client, int args)
{
	CPrintToChat(client, "[{green}Point Bonus{default}] [HP] Full HP Survivor bonus for the map: {green}%d", RoundToNearest(FULL_HP_SURVIVOR_SURVIVED_BONUS_BASE * mapDistanceFactor));
	CPrintToChat(client, "[{green}Point Bonus{default}] [SB] 1x Survivor in saferoom bonus: {green}%d", RoundToNearest(SURVIVOR_SURVIVED_BONUS_BASE * mapDistanceFactor));
	CPrintToChat(client, "[{green}Point Bonus{default}] [SB] The above bonus depends on number of incaps: {green}%d", RoundToNearest(SURVIVOR_SURVIVED_BONUS_BASE * mapDistanceFactor));
	CPrintToChat(client, "[{green}Point Bonus{default}] [HIB] Bonus per 1 medkit for the map: {green}%d", RoundToNearest(MEDKIT_BONUS_BASE * mapDistanceFactor));
	CPrintToChat(client, "[{green}Point Bonus{default}] [HIB] Bonus per 1 pills/adrenaline for the map: {green}%d", RoundToNearest(PILLS_ADRENALINE_BONUS_BASE * mapDistanceFactor));
	CPrintToChat(client, "[{green}Point Bonus{default}] [TKB] Bonus per 1 tank kill for the map: {green}%d", RoundToNearest(TANK_KILL_BONUS));
	CPrintToChat(client, "[{green}Point Bonus{default}] [TPB] Bonus per 1 tank pass for the map: {green}%d", RoundToNearest(TANK_PASS_BONUS));
	CPrintToChat(client, "[{green}Point Bonus{default}] [WB] Bonus per 1 witch crown for the map: {green}%d", RoundToNearest(WITCH_CROWN_BONUS));
	CPrintToChat(client, "[{green}Point Bonus{default}] Map distance factor (alters every bonus): {green}%f", mapDistanceFactor);

	return Plugin_Handled;
}

// PRINT actual bonuses
public Action CMD_print_bonuses(int client, int args)
{
	int round				 = InSecondHalfOfRound();
	survivorsSurvived[round] = GetNotIncappedSurvivorsCount();
	UpdateSurvivalBonus(round);
	UpdateCurrentHealthAndHealthItemsBonus(round);
	UpdateTotalBonus(round);

	if (round == 0)
	{
		PrintCurrentBonusInfo(round, client);
	}
	else {
		PrintCurrentBonusInfo(0, client);
		PrintCurrentBonusInfo(1, client);
	}

	return Plugin_Handled;
}

void PrintCurrentBonusInfo(int round, int client = -1)
{
	if (client == -1)
	{
		CPrintToChatAll("{green}[{blue}R#%d {default}Bonus{green}] {green}Total: {olive}%d {green}[{blue}HB:{olive}%d {default}| {blue}HIB:{olive}%d {default}| {blue}TB:{olive}%d {default}| {blue}WB:{olive}%d {default}| {blue}SB:{olive}%d{green}]",
						round+1,
						RoundToNearest(totalBonus[round]),
						RoundToNearest(healthBonus[round]),
						RoundToNearest(healthItemsBonus[round]),
						RoundToNearest(tankPassBonus[round] + tankKillBonus[round]),
						RoundToNearest(witchCrownBonus[round]),
						RoundToNearest(survivalBonus[round]));
	}
	else {
		CPrintToChat(client, "{green}[{blue}R#%d {default}Bonus{green}] {green}Total: {olive}%d {green}[{blue}HB:{olive}%d {default}| {blue}HIB:{olive}%d {default}| {blue}TB:{olive}%d {default}| {blue}WB:{olive}%d {default}| {blue}SB:{olive}%d{green}]",
					 round+1,
					 RoundToNearest(totalBonus[round]),
					 RoundToNearest(healthBonus[round]),
					 RoundToNearest(healthItemsBonus[round]),
					 RoundToNearest(tankPassBonus[round] + tankKillBonus[round]),
					 RoundToNearest(witchCrownBonus[round]),
					 RoundToNearest(survivalBonus[round]));
	}
}

public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	int round				 = InSecondHalfOfRound();
	// save factors
	mapDistanceFactor		 = GetMapDistanceFactor();
	survivorsSurvived[round] = GetNotIncappedSurvivorsCount();
	UpdateSurvivalBonus(round);
	UpdateCurrentHealthAndHealthItemsBonus(round);
	UpdateTotalBonus(round);

	if (survivorsSurvived[round] > 1)
	{
		SetConVarInt(hCvarValveSurvivalBonus, RoundToNearest(totalBonus[round] / survivorsSurvived[round]));
	}
	else {
		GameRules_SetProp("m_iVersusDefibsUsed", 1, 4, GameRules_GetProp("m_bAreTeamsFlipped", 4, 0));
		SetConVarInt(g_hCvarDefibPenalty, -RoundToNearest(totalBonus[round]));
	}
	CreateTimer(3.5, PrintRoundEndStats, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public Action PrintRoundEndStats(Handle timer)
{
	int round = InSecondHalfOfRound();
	if (round == 0)
	{
		PrintCurrentBonusInfo(0);
	}
	else {
		PrintCurrentBonusInfo(0);
		PrintCurrentBonusInfo(1);
	}
	return Plugin_Handled;
}

public void clearSavedBonusParameters()
{
	SetConVarInt(hCvarValveSurvivalBonus, 0);
	SetConVarInt(g_hCvarDefibPenalty, 0);

	for (int round = 0; round <= 1; round++)
	{
		aliveSurvs[round]		 = 0;
		totalBonus[round]		 = 0.0;
		healthItemsBonus[round]	 = 0.0;
		healthBonus[round]		 = 0.0;
		survivalBonus[round]	 = 0.0;
		tankPassBonus[round]	 = 0.0;
		tankKillBonus[round]	 = 0.0;
		witchCrownBonus[round]	 = 0.0;
		survivorsSurvived[round] = 0;
		mapDistanceFactor		 = 0.0;
	}

	CreateTimer(0.1, UpdateMapDistanceFactor);
}

void UpdateSurvivalBonus(int round)
{
	survivalBonus[round] = 0.0;
	int survivorCount	 = 0;
	for (int i = 1; i <= MaxClients && survivorCount < teamSize; i++)
	{
		if (IsSurvivor(i) && IsPlayerAlive(i) && (!L4D_IsPlayerIncapacitated(i) || L4D_IsInLastCheckpoint(i)))
		{
			int	  timesIncapped = playerIncaps[i];
			float incapFactor	= 1.0;
			if (timesIncapped > 3)
			{
				incapFactor = 0.1;
			}
			else if (timesIncapped > 2) {
				incapFactor = 0.25;
			}
			else if (timesIncapped > 1) {
				incapFactor = 0.5;
			}
			else if (timesIncapped > 0) {
				incapFactor = 0.75;
			}
			survivalBonus[round] += SURVIVOR_SURVIVED_BONUS_BASE * mapDistanceFactor * incapFactor;
		}
	}
}

void UpdateTotalBonus(int round)
{
	totalBonus[round] = 0.0;
	totalBonus[round] = healthItemsBonus[round] + healthBonus[round] + survivalBonus[round] + tankPassBonus[round] + tankKillBonus[round] + witchCrownBonus[round];
}

void UpdateCurrentHealthAndHealthItemsBonus(int round)
{
	int survivorCount		= 0;
	healthBonus[round]		= 0.0;
	healthItemsBonus[round] = 0.0;
	for (int i = 1; i <= MaxClients && survivorCount < teamSize; i++)
	{
		if (IsSurvivor(i) && IsPlayerAlive(i) && (!L4D_IsPlayerIncapacitated(i) || L4D_IsInLastCheckpoint(i)))
		{
			survivorCount++;
			if (GetSurvivorPermanentHealth(i) < 101)
			{
				healthBonus[round] += ((FULL_HP_SURVIVOR_SURVIVED_BONUS_BASE * GetSurvivorPermanentHealth(i)) / 100.0) * mapDistanceFactor;
			}
			if (HasMedkit(i))
			{
				healthItemsBonus[round] += MEDKIT_BONUS_BASE * mapDistanceFactor;
			}
			if (HasAdrenaline(i) || HasPills(i))
			{
				healthItemsBonus[round] += PILLS_ADRENALINE_BONUS_BASE * mapDistanceFactor;
			}
		}
	}
}

int GetNotIncappedSurvivorsCount()
{
	int survivorCount = 0;
	for (int i = 1; i <= MaxClients && survivorCount < teamSize; i++)
	{
		if (IsSurvivor(i) && IsPlayerAlive(i) && (!L4D_IsPlayerIncapacitated(i) || L4D_IsInLastCheckpoint(i)))
		{
			survivorCount++;
		}
	}
	return survivorCount;
}

public Action UpdateMapDistanceFactor(Handle timer)
{
	if(L4D2_IsTankInPlay() || L4D_GetVersusMaxCompletionScore() == 0) {
		CreateTimer(2.0, UpdateMapDistanceFactor);
		return Plugin_Continue;
	}
	
	float newFactor = GetMapDistanceFactor();
	if (newFactor > 0.0) {  // Only update if we get a valid value
		mapDistanceFactor = newFactor;
	}

	return Plugin_Continue;
}

float GetMapDistanceFactor()
{
	return float(GetMapMaxScore()) / 400.0;
}

int InSecondHalfOfRound()
{
	return GameRules_GetProp("m_bInSecondHalfOfRound");
}

int GetMapMaxScore()
{
	return L4D_GetVersusMaxCompletionScore();
}

stock GetSurvivorPermanentHealth(client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}

bool IsSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

bool HasMedkit(int client)
{
	int item = GetPlayerWeaponSlot(client, 3);
	if (IsValidEdict(item))
	{
		char buffer[64];
		GetEdictClassname(item, buffer, sizeof(buffer));
		return StrEqual(buffer, "weapon_first_aid_kit");
	}
	return false;
}

bool HasPills(int client)
{
	int item = GetPlayerWeaponSlot(client, 4);
	if (IsValidEdict(item))
	{
		char buffer[64];
		GetEdictClassname(item, buffer, sizeof(buffer));
		return StrEqual(buffer, "weapon_pain_pills");
	}
	return false;
}

bool HasAdrenaline(int client)
{
	int item = GetPlayerWeaponSlot(client, 4);
	if (IsValidEdict(item))
	{
		char buffer[64];
		GetEdictClassname(item, buffer, sizeof(buffer));
		return StrEqual(buffer, "weapon_adrenaline");
	}
	return false;
}

// apply bonus functions
public void TP_OnTankPass()
{
	int round = InSecondHalfOfRound();
	int survs = GetNotIncappedSurvivorsCount();
	if (survs > 0)
	{
		tankPassBonus[round] += TANK_PASS_BONUS;
		CPrintToChatAll("Tank has been passed resulting in: {olive}%d {default}points bonus", RoundToNearest(TANK_PASS_BONUS));
	}
}

public void OnTankDeath()
{
	int round = InSecondHalfOfRound();
	int survs = GetNotIncappedSurvivorsCount();
	if (survs > 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsSurvivor(i) && IsPlayerAlive(i))
			{
				aliveSurvs[round]++;
			}
		}
		//float difficultyMultipier = (float(survs[round]) / float(teamSize)); // ¼
		float difficultyMultipier = ((float(aliveSurvs[round]) + float(teamSize)) / (2.0 * float(teamSize)));
		tankKillBonus[round] += TANK_KILL_BONUS / difficultyMultipier;
		CPrintToChatAll("Tank has been killed resulting in: {olive}%d {default}points bonus", RoundToNearest(tankKillBonus[round]));
	}
}

public void Kether_OnWitchDrawCrown()
{
	int round = InSecondHalfOfRound();
	witchCrownBonus[round] += WITCH_CROWN_BONUS;
	CPrintToChatAll("Witch has been draw-crowned resulting in: {olive}%d {default}points bonus", RoundToNearest(WITCH_CROWN_BONUS));

}

public void Kether_OnWitchCrown()
{
	int round = InSecondHalfOfRound();
	witchCrownBonus[round] += WITCH_CROWN_BONUS;
	CPrintToChatAll("Witch has been crowned resulting in: {olive}%d {default}points bonus", RoundToNearest(WITCH_CROWN_BONUS));
}
