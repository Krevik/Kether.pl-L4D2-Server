#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2lib>
#include <colors>
#include <l4d2_saferoom_detect>

Handle hCvarValveSurvivalBonus = INVALID_HANDLE;
Handle g_hCvarDefibPenalty = INVALID_HANDLE;

float totalBonus[2];
float healthItemsBonus[2];
float healthBonus[2];
float survivalBonus[2];
float tankPassKillBonus[2];
float witchCrownBonus[2];
int survivorsSurvived[2];
int teamSize;
float mapDistanceFactor;
int playerIncaps[64];

int WITCH_CROWN_BONUS = 24;
int TANK_KILL_PASS_BONUS = 24;
int SURVIVOR_SURVIVED_BONUS_BASE = 24;
int FULL_HP_SURVIVOR_SURVIVED_BONUS_BASE = 24;
int PILLS_ADRENALINE_BONUS_BASE = 12;
int MEDKIT_BONUS_BASE = 28;

public Plugin myinfo =
{
	name = "L4D2 Scoring plugin",
	author = "Krevik",
	description = "Gives score bonuses for pills, adrenaline, HP, tank kill/pass, witch crown",
	version = "1.9.9.9.9.10",
	url = "kether.pl"
};

public void OnPluginStart()
{
	g_hCvarDefibPenalty = FindConVar("vs_defib_penalty");
	hCvarValveSurvivalBonus = FindConVar("vs_survival_bonus");
	teamSize = GetConVarInt(FindConVar("survivor_limit"));

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
    mapDistanceFactor = GetMapDistanceFactor();
}

public void OnMapEnd()
{
	clearSavedBonusParameters();
}

public void Event_RoundStart(Event hEvent, const char[] sEventName, bool bDontBroadcast){
	int team = InSecondHalfOfRound();
	if(team == 0){
		clearSavedBonusParameters();
	}
    mapDistanceFactor = GetMapDistanceFactor();
	//Rest player incaps counter
	for (new i = 1; i <= MaxClients; i++)
	{
		playerIncaps[i] = 0;
	}
}

//Events
public void Event_OnPlayerIncapped(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsSurvivor(client))
	{
		playerIncaps[client]+= 1;
	} 
}

//commands
//bonus info
public Action CMD_print_bonus_info(int client, int args)
{
	CPrintToChat(client, "[{green}Point Bonus{default}] [HP] Full HP Survivor bonus for the map: {green}%d", RoundToNearest(float(FULL_HP_SURVIVOR_SURVIVED_BONUS_BASE) * mapDistanceFactor) );	
	CPrintToChat(client, "[{green}Point Bonus{default}] [SB] 1x Survivor in saferoom bonus: {green}%d", RoundToNearest(float(SURVIVOR_SURVIVED_BONUS_BASE) * mapDistanceFactor) );	
	CPrintToChat(client, "[{green}Point Bonus{default}] [SB] The above bonus depends on number of incaps: {green}%d", RoundToNearest(float(SURVIVOR_SURVIVED_BONUS_BASE) * mapDistanceFactor) );	
	CPrintToChat(client, "[{green}Point Bonus{default}] [HIB] Bonus per 1 medkit for the map: {green}%d", RoundToNearest(float(MEDKIT_BONUS_BASE) * mapDistanceFactor) );	
	CPrintToChat(client, "[{green}Point Bonus{default}] [HIB] Bonus per 1 pills/adrenaline for the map: {green}%d", RoundToNearest(float(PILLS_ADRENALINE_BONUS_BASE) * mapDistanceFactor) );
	CPrintToChat(client, "[{green}Point Bonus{default}] [TB] Bonus per 1 tank pass/kill for the map: {green}%d", RoundToNearest(float(TANK_KILL_PASS_BONUS)) );	
	CPrintToChat(client, "[{green}Point Bonus{default}] [WB] Bonus per 1 witch crown for the map: {green}%d", RoundToNearest(float(WITCH_CROWN_BONUS)) );	
	CPrintToChat(client, "[{green}Point Bonus{default}] Map distance factor: {green}%f", mapDistanceFactor );	

	return Plugin_Handled;
}

//PRINT actual bonuses
public Action CMD_print_bonuses(int client, int args)
{
	int round = InSecondHalfOfRound();
    if(round == 0){
        if(totalBonus[0] > 0.0){
			CPrintToChat(client,"{green}[{blue}R#%d {default}Bonus{green}] {green}Total: {olive}%d {green}[{blue}HB:{olive}%d {default}| {blue}HIB:{olive}%d {default}| {blue}TB:{olive}%d {default}| {blue}WB:{olive}%d {default}| {blue}SB:{olive}%d{green}]",
            1, 
            RoundToNearest(totalBonus[0]), 
            RoundToNearest(healthBonus[0]),
            RoundToNearest(healthItemsBonus[0]),
            RoundToNearest(tankPassKillBonus[0]),
            RoundToNearest(witchCrownBonus[0]),
			RoundToNearest(survivalBonus[0]));
        }else{
            //calculate current bonus
			CPrintToChat(client,"{green}[{blue}R#%d {default}Bonus{green}] {green}Total: {olive}%d {green}[{blue}HB:{olive}%d {default}| {blue}HIB:{olive}%d {default}| {blue}TB:{olive}%d {default}| {blue}WB:{olive}%d {default}| {blue}SB:{olive}%d{green}]", 
            1, 
            RoundToNearest(GetCurrentTotalBonus()), 
            RoundToNearest(GetCurrentHealthBonus()),
            RoundToNearest(GetCurrentHealthItemsBonus()),
            RoundToNearest(tankPassKillBonus[0]),
            RoundToNearest(witchCrownBonus[0]),
			RoundToNearest(GetCurrentSurvivalBonus()));
        }
    }else if(round == 1){
        //round 0
		CPrintToChat(client,"{green}[{blue}R#%d {default}Bonus{green}] {green}Total: {olive}%d {green}[{blue}HB:{olive}%d {default}| {blue}HIB:{olive}%d {default}| {blue}TB:{olive}%d {default}| {blue}WB:{olive}%d {default}| {blue}SB:{olive}%d{green}]",
        1, 
        RoundToNearest(totalBonus[0]), 
        RoundToNearest(healthBonus[0]),
        RoundToNearest(healthItemsBonus[0]),
        RoundToNearest(tankPassKillBonus[0]),
        RoundToNearest(witchCrownBonus[0]),
		RoundToNearest(survivalBonus[0]));
        //round 1
        //calculate current bonus
		CPrintToChat(client,"{green}[{blue}R#%d {default}Bonus{green}] {green}Total: {olive}%d {green}[{blue}HB:{olive}%d {default}| {blue}HIB:{olive}%d {default}| {blue}TB:{olive}%d {default}| {blue}WB:{olive}%d {default}| {blue}SB:{olive}%d{green}]", 
        2, 
        RoundToNearest(GetCurrentTotalBonus()), 
        RoundToNearest(GetCurrentHealthBonus()),
        RoundToNearest(GetCurrentHealthItemsBonus()),
        RoundToNearest(tankPassKillBonus[1]),
        RoundToNearest(witchCrownBonus[1]),
		RoundToNearest(GetCurrentSurvivalBonus()));
    }
	return Plugin_Handled;
}


//apply bonus functions
public void TP_OnTankPass(){
	int round = InSecondHalfOfRound();
	tankPassKillBonus[round] += TANK_KILL_PASS_BONUS;
	int survs = GetSurvivorsCountForRound(round);
	if(survs > 0){
		CPrintToChatAll("Tank has been passed resulting in: {olive}%d {default}points bonus", TANK_KILL_PASS_BONUS );
	}
}

public void OnTankDeath(){
	int round = InSecondHalfOfRound();
	tankPassKillBonus[round] += TANK_KILL_PASS_BONUS;
	int survs = GetSurvivorsCountForRound(round);
	if(survs > 0){
		CPrintToChatAll("Tank has been killed resulting in: {olive}%d {default}points bonus", TANK_KILL_PASS_BONUS );
	}
}

public void Kether_OnWitchDrawCrown(){
	int round = InSecondHalfOfRound();
	witchCrownBonus[round] += WITCH_CROWN_BONUS;
	CPrintToChatAll("Witch has been draw-crowned resulting in: {olive}%d {default}points bonus", WITCH_CROWN_BONUS );
}

public void Kether_OnWitchCrown(){
	int round = InSecondHalfOfRound();
	witchCrownBonus[round] += WITCH_CROWN_BONUS;
	CPrintToChatAll("Witch has been crowned resulting in: {olive}%d {default}points bonus", WITCH_CROWN_BONUS );
}

public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	CalculateSetAndPrintFinalBonus();
	return Plugin_Continue;
}

//util functions
public void CalculateSetAndPrintFinalBonus(){
	int round = InSecondHalfOfRound();
    mapDistanceFactor = GetMapDistanceFactor();
    survivorsSurvived[round] = float(GetSurvivorsInSaferoom());
    GetAndSetHealthAndHealthItemsBonus(round);
    totalBonus[round] = healthItemsBonus[round] + healthBonus[round] + survivalBonus[round] + tankPassKillBonus[round] + witchCrownBonus[round];
    //set total bonus as cvar and print round end stats
	if(survivorsSurvived[round]>1.0){
    	SetConVarInt(hCvarValveSurvivalBonus, RoundToNearest( FloatDiv(totalBonus[round], survivorsSurvived[round])) );
	}else{
		GameRules_SetProp("m_iVersusDefibsUsed", 1, 4, GameRules_GetProp("m_bAreTeamsFlipped", 4, 0));
		SetConVarInt(g_hCvarDefibPenalty, -RoundToNearest( totalBonus[round] ) );
	}
    CreateTimer(3.5, PrintRoundEndStats, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void GetAndSetHealthAndHealthItemsBonus(int round){
    int survivorCount = 0;	
    healthItemsBonus[round] = 0.0;
    healthBonus[round] = 0.0;
    survivalBonus[round] = 0.0;
    for (new i = 1; i <= MaxClients && survivorCount < teamSize; i++)
	{
		float survivalBonusMultiplayer = 1.0;
		if(playerIncaps[i] == 1){
			survivalBonusMultiplayer = 0.75;
		}else if(playerIncaps[i] == 2){
			survivalBonusMultiplayer = 0.5;
		}else if(playerIncaps[i] >= 3){
			survivalBonusMultiplayer = 0.25;
		}
		if (IsSurvivor(i) && IsPlayerAlive(i) && L4D_IsInLastCheckpoint(i))
		{
			survivorCount++;
            survivalBonus[round] += float(SURVIVOR_SURVIVED_BONUS_BASE) * mapDistanceFactor * survivalBonusMultiplayer;     
            if(GetSurvivorPermanentHealth(i) <= 100){
                healthBonus[round] += ((float(FULL_HP_SURVIVOR_SURVIVED_BONUS_BASE) * GetSurvivorPermanentHealth(i)) / 100.0) * mapDistanceFactor;
            }
            if(HasMedkit(i)){
                healthItemsBonus[round] += float(MEDKIT_BONUS_BASE) * mapDistanceFactor;
            }
            if(HasAdrenaline(i) || HasPills(i)){
                healthItemsBonus[round] += float(PILLS_ADRENALINE_BONUS_BASE) * mapDistanceFactor;
            }
		}
	}
}

public float GetCurrentTotalBonus(){
	int round = InSecondHalfOfRound();
	return GetCurrentHealthItemsBonus() + GetCurrentHealthBonus() + GetCurrentSurvivalBonus() + tankPassKillBonus[round] + witchCrownBonus[round];
}

public Action PrintRoundEndStats(Handle timer) {
	int round = InSecondHalfOfRound();
	if(round == 0){
		CPrintToChatAll("{green}[{blue}R#%d {default}Bonus{green}] {green}Total: {olive}%d {green}[{blue}HB:{olive}%d {default}| {blue}HIB:{olive}%d {default}| {blue}TB:{olive}%d {default}| {blue}WB:{olive}%d {default}| {blue}SB:{olive}%d{green}]",
        1, 
        RoundToNearest(totalBonus[round]), 
        RoundToNearest(healthBonus[round]),
        RoundToNearest(healthItemsBonus[round]),
        RoundToNearest(tankPassKillBonus[round]),
        RoundToNearest(witchCrownBonus[round]),
		RoundToNearest(survivalBonus[round]));
	}
	else if(round == 1){
        //round 0
		CPrintToChatAll("{green}[{blue}R#%d {default}Bonus{green}] {green}Total: {olive}%d {green}[{blue}HB:{olive}%d {default}| {blue}HIB:{olive}%d {default}| {blue}TB:{olive}%d {default}| {blue}WB:{olive}%d {default}| {blue}SB:{olive}%d{green}]",
		1, 
        RoundToNearest(totalBonus[0]), 
        RoundToNearest(healthBonus[0]),
        RoundToNearest(healthItemsBonus[0]),
        RoundToNearest(tankPassKillBonus[0]),
        RoundToNearest(witchCrownBonus[0]),
		RoundToNearest(survivalBonus[0]));
        //round 1
		CPrintToChatAll("{green}[{blue}R#%d {default}Bonus{green}] {green}Total: {olive}%d {green}[{blue}HB:{olive}%d {default}| {blue}HIB:{olive}%d {default}| {blue}TB:{olive}%d {default}| {blue}WB:{olive}%d {default}| {blue}SB:{olive}%d{green}]", 
        2, 
        RoundToNearest(totalBonus[1]), 
        RoundToNearest(healthBonus[1]),
        RoundToNearest(healthItemsBonus[1]),
        RoundToNearest(tankPassKillBonus[1]),
        RoundToNearest(witchCrownBonus[1]),
		RoundToNearest(survivalBonus[1]));
	}
	return Plugin_Handled;
}

public void clearSavedBonusParameters(){
    SetConVarInt(hCvarValveSurvivalBonus, 0);
    SetConVarInt(g_hCvarDefibPenalty, 0);

    mapDistanceFactor = 0.0;
    for(int round=0; round<= 1; round++){
        totalBonus[round] = 0.0;
        healthItemsBonus[round] = 0.0;
        healthBonus[round] = 0.0;
        survivalBonus[round] = 0.0;
        tankPassKillBonus[round] = 0.0;
        witchCrownBonus[round] = 0.0;
        survivorsSurvived[round] = 0;
    }
}

int GetSurvivorsCountForRound(int targetRound){
    if(survivorsSurvived[targetRound] > 0.0){
        return RoundToNearest(survivorsSurvived[targetRound]);
    }else{
        return GetAliveSurvivors();
    }
}

public float GetCurrentSurvivalBonus(){
    int survivorCount = 0;	
	float survivalBonus = 0.0;
    for (new i = 1; i <= MaxClients && survivorCount < teamSize; i++)
	{
		
		if (IsSurvivor(i) && IsPlayerAlive(i))
		{
			float survivalBonusMultiplayer = 1.0;
			if(playerIncaps[i] == 1){
				survivalBonusMultiplayer = 0.75;
			}else if(playerIncaps[i] == 2){
				survivalBonusMultiplayer = 0.5;
			}else if(playerIncaps[i] >= 3){
				survivalBonusMultiplayer = 0.25;
			}
			survivorCount++;
			survivalBonus += float(SURVIVOR_SURVIVED_BONUS_BASE) * mapDistanceFactor * survivalBonusMultiplayer;     
		}
	}
	return survivalBonus;
}


public float GetCurrentHealthBonus(){
    int survivorCount = 0;	
	float healthBonus = 0.0;
    for (new i = 1; i <= MaxClients && survivorCount < teamSize; i++)
	{
		if (IsSurvivor(i) && IsPlayerAlive(i))
		{
			survivorCount++;
            if(GetSurvivorPermanentHealth(i) <= 100){
                healthBonus += ((float(FULL_HP_SURVIVOR_SURVIVED_BONUS_BASE) * GetSurvivorPermanentHealth(i)) / 100.0) * mapDistanceFactor;
            }
		}
	}
	return healthBonus;
}

public float GetCurrentHealthItemsBonus(){
    int survivorCount = 0;	
	float healthItemsBonus = 0.0;
    for (new i = 1; i <= MaxClients && survivorCount < teamSize; i++)
	{
		if (IsSurvivor(i) && IsPlayerAlive(i))
		{
			survivorCount++;
            if(HasMedkit(i)){
                healthItemsBonus += float(MEDKIT_BONUS_BASE) * mapDistanceFactor;
            }
            if(HasAdrenaline(i) || HasPills(i)){
                healthItemsBonus += float(PILLS_ADRENALINE_BONUS_BASE) * mapDistanceFactor;
            }
		}
	}
	return healthItemsBonus;
}

int GetAliveSurvivors(){
    int survivorCount = 0;	
    for (new i = 1; i <= MaxClients && survivorCount < teamSize; i++)
	{
		if (IsSurvivor(i) && IsPlayerAlive(i))
		{
			survivorCount++;
		}
	}
    return survivorCount;
}

int GetSurvivorsInSaferoom(){
    int survivorCount = 0;	
    for (new i = 1; i <= MaxClients && survivorCount < teamSize; i++)
	{
		if (IsSurvivor(i) && IsPlayerAlive(i) && L4D_IsInLastCheckpoint(i))
		{
			survivorCount++;
		}
	}
    return survivorCount;
}

float GetMapDistanceFactor(){
	return float(GetMapMaxScore())/400.0;
}

stock InSecondHalfOfRound()
{
	return GameRules_GetProp("m_bInSecondHalfOfRound");
}

stock GetMapMaxScore()
{
	return L4D_GetVersusMaxCompletionScore();
}

stock IsIncapacitated(client) return GetEntProp(client, Prop_Send, "m_isIncapacitated");

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
	new item = GetPlayerWeaponSlot(client, 3);
	if (IsValidEdict(item))
	{
		decl String:buffer[64];
		GetEdictClassname(item, buffer, sizeof(buffer));
		return StrEqual(buffer, "weapon_first_aid_kit");
	}
	return false;
}

bool HasPills(int client)
{
	new item = GetPlayerWeaponSlot(client, 4);
	if (IsValidEdict(item))
	{
		decl String:buffer[64];
		GetEdictClassname(item, buffer, sizeof(buffer));
		return StrEqual(buffer, "weapon_pain_pills");
	}
	return false;
}

bool HasAdrenaline(int client)
{
	new item = GetPlayerWeaponSlot(client, 4);
	if (IsValidEdict(item))
	{
		decl String:buffer[64];
		GetEdictClassname(item, buffer, sizeof(buffer));
		return StrEqual(buffer, "weapon_adrenaline");
	}
	return false;
}
