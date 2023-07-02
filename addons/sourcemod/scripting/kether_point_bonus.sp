#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2lib>
#include <colors>
#include <l4d2_saferoom_detect>

//Data storage
int teamSize;
int witchCrownBonus[2];
int tankKillBonus[2];
int tankPassBonus[2];
int healthBonus[2];
int healthItemsBonus[2];
int aliveSurvivors[2];
int totalBonus[2];
float mapFactor;
int survivorsAliveBonus[2];

//Custom ConVars
ConVar cVarWitchCrownBonus;
ConVar cVarTankKillBonus;
ConVar cVarTankPassBonus;
ConVar cVarFullHPSurvivorBonus;
ConVar cVarSurvivorSurvivedBonus;
ConVar cVarMedkitBonus;
ConVar cVarPillsBonus;


public Plugin myinfo =
{
	name = "L4D2 Bonus For pills",
	author = "Krevik",
	description = "Scoring bonus management",
	version = "1.2",
	url = "kether.pl"
};

public void OnPluginStart()
{
    //Commands
	RegConsoleCmd("sm_health", CMD_print_bonuses, "Let's print actual bonuses");
	RegConsoleCmd("sm_bonus", CMD_print_bonuses, "Let's print actual bonuses");
	RegConsoleCmd("sm_bonusinfo", CMD_print_bonus_info, "Let's print those bonuses info.");
	RegConsoleCmd("sm_binfo", CMD_print_bonus_info, "Let's print those bonuses info.");
	RegConsoleCmd("sm_minfo", CMD_print_bonus_info, "Let's print those bonuses info.");
	RegConsoleCmd("sm_mapinfo", CMD_print_bonus_info, "Let's print those bonuses info.");

    //Existing ConVars
	teamSize = GetConVarInt(FindConVar("survivor_limit"));

    //Custom ConVars
	cVarWitchCrownBonus = CreateConVar("cVarWitchCrownBonus", "25", "Point bonus for witch crown - has to be constant", _, true, 0.0, true, 5000.0);
	cVarTankKillBonus = CreateConVar("cVarTankKillBonus", "25", "Point bonus for tank kill - has to be constant", _, true, 0.0, true, 5000.0);
	cVarTankPassBonus = CreateConVar("cVarTankPassBonus", "25", "Point bonus for tank pass - has to be constant", _, true, 0.0, true, 5000.0);
	cVarFullHPSurvivorBonus = CreateConVar("cVarFullHPSurvivorBonus", "20", "Point bonus for full hp survivor reaching safehouse", _, true, 0.0, true, 5000.0);
	cVarSurvivorSurvivedBonus = CreateConVar("cVarSurvivorSurvivedBonus", "10", "Point bonus for survivor reaching the saferoom", _, true, 0.0, true, 5000.0);
	cVarMedkitBonus = CreateConVar("cVarMedkitBonus", "40", "Point bonus for 1 medkit", _, true, 0.0, true, 5000.0);
	cVarPillsBonus = CreateConVar("cVarPillsBonus", "15", "Point bonus for 1 pills", _, true, 0.0, true, 5000.0);

}

public OnPluginEnd()
{
	ResetConVar(FindConVar("vs_defib_penalty"));
	ResetConVar(FindConVar("vs_survival_bonus"));
}

public void OnMapStart()
{
	ClearBonusParameters();
}

public void OnMapEnd()
{
	ClearBonusParameters();
}

public void Event_RoundStart(Event hEvent, const char[] sEventName, bool bDontBroadcast){
	int round = InSecondHalfOfRound();
	if(round == 0){
		ClearBonusParameters();
		mapFactor = GetMapDistanceFactor();
	}
}

public void TP_OnTankPass(){
	int round = InSecondHalfOfRound();
	int bonusToApply = GetConVarInt(cVarTankPassBonus);
	tankPassBonus[round] += bonusToApply;
	CPrintToChatAll("Tank has been passed resulting in: {olive}%d {default}points bonus", bonusToApply );
}

public void OnTankDeath(){
	int round = InSecondHalfOfRound();
	int bonusToApply = GetConVarInt(cVarTankKillBonus);
	tankKillBonus[round] += bonusToApply;
	CPrintToChatAll("Tank has been killed resulting in: {olive}%d {default}points bonus", bonusToApply );
}

public void Kether_OnWitchDrawCrown(){
	int round = InSecondHalfOfRound();
	int bonusToApply = GetConVarInt(cVarWitchCrownBonus);
	witchCrownBonus[round] += bonusToApply;
	CPrintToChatAll("Witch has been draw-crowned resulting in: {olive}%d {default}points bonus", bonusToApply );
}

public void Kether_OnWitchCrown(){
	int round = InSecondHalfOfRound();
	int bonusToApply = GetConVarInt(FindConVar("cVarWitchCrownBonus"));
	witchCrownBonus[round] += bonusToApply;
	CPrintToChatAll("Witch has been crowned resulting in: {olive}%d {default}points bonus", bonusToApply );
}

public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	// int round = InSecondHalfOfRound();

	//Calculate bonuses
	CalculateSetAndPrintFinalBonuses();

	//Print bonuses
	CreateTimer(3.5, PrintRoundEndStats, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public Action PrintRoundEndStats(Handle timer) {
	int round = InSecondHalfOfRound();
	if(round == 0){
		if(totalBonus[0] == 0){
			CPrintToChatAll("{green}[{blue}R#0 {default}Bonus{green}] {green}Total: {olive}0");
		}else{
			PrintRoundFinalBonusToAll(0);
		}
	}else{
		if(totalBonus[0] == 0){
			CPrintToChatAll("{green}[{blue}R#0 {default}Bonus{green}] {green}Total: {olive}0");
		}else{
			PrintRoundFinalBonusToAll(0);
		}
		if(totalBonus[1] == 0){
			CPrintToChatAll("{green}[{blue}R#1 {default}Bonus{green}] {green}Total: {olive}0");
		}else{
			PrintRoundFinalBonusToAll(1);
		}
	}
	return Plugin_Handled;
}


public void PrintRoundFinalBonusToAll(int round){
	CPrintToChatAll("{green}[{blue}R#%d {default}Bonus{green}] {green}Total: {olive}%d {green}[{green}HB:{olive}%d {default}| {green}HIB:{olive}%d {default}| {green}TB:{olive}%d {default}| {green}WB:{olive}%d {default}| {green}SB:{olive}%d{green}]", round, totalBonus[round], healthBonus[round], healthItemsBonus[round], tankPassBonus[round] + tankKillBonus[round], witchCrownBonus[round], survivorsAliveBonus[round]);
	CPrintToChatAll("{green}[{blue}R#%d {default}Bonus{green}] {green}Map mult:{olive}%f", round, mapFactor);
}

public void PrintBonusForPlayer(int client, int round){
	CPrintToChat(client, "{green}[{blue}R#%d {default}Bonus{green}] {green}T: {olive}%d {green}[{green}HB:{olive}%d {default}| {green}HIB:{olive}%d {default}| {green}TB:{olive}%d {default}| {green}WB:{olive}%d {default}| {green}SB:{olive}%d{green} {default}| {green}M:{olive}%f{green}]", round, totalBonus[round], healthBonus[round], healthItemsBonus[round], tankPassBonus[round] + tankKillBonus[round], witchCrownBonus[round], survivorsAliveBonus[round], mapFactor);
	CPrintToChatAll("{green}[{blue}R#%d {default}Bonus{green}] {green}Map mult:{olive}%f", round, mapFactor);
}

public void CalculateSetAndPrintFinalBonuses(){
	// int round = InSecondHalfOfRound();
	CalculateAndApplyFinalBonuses();
}

public void CalculateAndApplyFinalBonuses(){
	float CONSTANT_MULTIPLIER = 0.4;
	int round = InSecondHalfOfRound();
	int survivorCount;
	int validSurvivorsCount = 0;
	healthBonus[round] = 0;
	healthItemsBonus[round] = 0;
	for (int i = 1; i <= MaxClients && survivorCount < teamSize; i++)
	{
		if (IsSurvivor(i))
		{
			survivorCount++;
			if (IsPlayerAlive(i) && L4D_IsInLastCheckpoint(i))
			{
				validSurvivorsCount++;
				//health bonus
				if(!IsIncapacitated(i) && !L4D_IsPlayerHangingFromLedge(i) && !L4D_IsPlayerIncapacitated(i)){
					healthBonus[round] += RoundToFloor(GetSurvivorPermanentHealth(i)/float(GetConVarInt(cVarFullHPSurvivorBonus)) * 100.0);
				}
				//health items bonus
					//medkits
					if(HasMedkit(i)){
						healthItemsBonus[round] += GetConVarInt(cVarMedkitBonus);
					}
					//pills or adrenaline
					if(HasPills(i) || HasAdrenaline(i)){
						healthItemsBonus[round] += GetConVarInt(cVarPillsBonus);
					}
			}
		}
	}
	healthBonus[round] = RoundToFloor(float(healthBonus[round])*CONSTANT_MULTIPLIER);
	healthItemsBonus[round] = RoundToFloor(float(healthItemsBonus[round])*CONSTANT_MULTIPLIER);
	//amount of survivors
	aliveSurvivors[round] = validSurvivorsCount;
	//map distance factor
	mapFactor = GetMapDistanceFactor();
	//survivors survived bonus
	survivorsAliveBonus[round] = RoundToFloor(float(GetSurvivorsInSaferoom()) * float(GetConVarInt(cVarSurvivorSurvivedBonus)) * CONSTANT_MULTIPLIER);
	//sum bonuses
	totalBonus[round] = healthBonus[round] + healthItemsBonus[round] + tankPassBonus[round] + tankKillBonus[round] + witchCrownBonus[round] + survivorsAliveBonus[round];
	//apply map factor to receive total bonus
	totalBonus[round] = RoundToFloor(float(totalBonus[round]) * mapFactor);
	int fractionedBonus = RoundToFloor(float(totalBonus[round]) / float(validSurvivorsCount));
	FindConVar("vs_survival_bonus").SetInt(fractionedBonus);
}

//Commands
public Action CMD_print_bonus_info(int client, int args)
{
	// int round = InSecondHalfOfRound();
	mapFactor = GetMapDistanceFactor();
	CPrintToChat(client, "[{green}Point Bonus{default}] Full HP Survivor bonus: {green}%d", GetConVarInt(cVarFullHPSurvivorBonus) );	
	CPrintToChat(client, "[{green}Point Bonus{default}] Survivor reaching safehouse bonus: {green}%d", GetConVarInt(cVarSurvivorSurvivedBonus) );	
	CPrintToChat(client, "[{green}Point Bonus{default}] Bonus per 1 medkit: {green}%d", GetConVarInt(cVarMedkitBonus) );	
	CPrintToChat(client, "[{green}Point Bonus{default}] Bonus per 1 pills/adrenaline: {green}%d", GetConVarInt(cVarPillsBonus) );
	CPrintToChat(client, "[{green}Point Bonus{default}] Bonus per 1 tank pass: {green}%d", GetConVarInt(cVarTankPassBonus) );	
	CPrintToChat(client, "[{green}Point Bonus{default}] Bonus per 1 tank kill: {green}%d", GetConVarInt(cVarTankKillBonus) );	
	CPrintToChat(client, "[{green}Point Bonus{default}] Bonus per 1 witch crown: {green}%d", GetConVarInt(cVarWitchCrownBonus) );	
	CPrintToChat(client, "[{green}Point Bonus{default}] Bonus is then multiplayed by map distance factor. Current: {green}%f", mapFactor );	

	return Plugin_Handled;
}


public void CalculateAndSetBonusesForPrint(int round){
	float CONSTANT_MULTIPLIER = 0.4;
	int survivorCount;
	int validSurvivorsCount = 0;
	healthBonus[round] = 0;
	healthItemsBonus[round] = 0;
	for (int i = 1; i <= MaxClients && survivorCount < teamSize; i++)
	{
		if (IsSurvivor(i))
		{
			survivorCount++;
			if (IsPlayerAlive(i))
			{
				validSurvivorsCount++;
				//health bonus
				if(!IsIncapacitated(i) && !L4D_IsPlayerHangingFromLedge(i) && !L4D_IsPlayerIncapacitated(i)){
					healthBonus[round] += RoundToFloor(GetSurvivorPermanentHealth(i)/float(GetConVarInt(cVarFullHPSurvivorBonus)) * 100.0);
				}
				//health items bonus
					//medkits
					if(HasMedkit(i)){
						healthItemsBonus[round] += GetConVarInt(cVarMedkitBonus);
					}
					//pills or adrenaline
					if(HasPills(i) || HasAdrenaline(i)){
						healthItemsBonus[round] += GetConVarInt(cVarPillsBonus);
					}
			}
		}
	}
	healthBonus[round] = RoundToFloor(float(healthBonus[round])*CONSTANT_MULTIPLIER);
	healthItemsBonus[round] = RoundToFloor(float(healthItemsBonus[round])*CONSTANT_MULTIPLIER);
	//amount of survivors
	aliveSurvivors[round] = validSurvivorsCount;
	//survivors survived bonus
	survivorsAliveBonus[round] = RoundToFloor(float(validSurvivorsCount) * float(GetConVarInt(cVarSurvivorSurvivedBonus)) * CONSTANT_MULTIPLIER);
	//sum bonuses
	totalBonus[round] = healthBonus[round] + healthItemsBonus[round] + tankPassBonus[round] + tankKillBonus[round] + witchCrownBonus[round] + survivorsAliveBonus[round];
	//apply map factor to receive total bonus
	totalBonus[round] = RoundToFloor(float(totalBonus[round]) * mapFactor);
}

public Action CMD_print_bonuses(int client, int args)
{
	mapFactor = GetMapDistanceFactor();
	int round = InSecondHalfOfRound();
	if(round == 1){
		//round == 0 -> just print
		PrintBonusForPlayer(client, 0);
		CalculateAndSetBonusesForPrint(1);
		PrintBonusForPlayer(client, 1);
		//round == 1 -> calculate and print
	}else{
		//calculate and print
		CalculateAndSetBonusesForPrint(0);
		PrintBonusForPlayer(client, 0);
	}
	return Plugin_Handled;
}


//util functions

float GetMapDistanceFactor(){
	return float(L4D_GetVersusMaxCompletionScore())/400.0;
}

public void ClearBonusParameters(){
	witchCrownBonus[0] = 0;
	witchCrownBonus[1] = 0;
	tankKillBonus[0] = 0;
	tankKillBonus[1] = 0;
	tankPassBonus[0] = 0;
	tankPassBonus[1] = 0;
	healthBonus[0] = 0;
	healthBonus[1] = 0;
	healthItemsBonus[0] = 0;
	healthItemsBonus[1] = 0;
	aliveSurvivors[0] = 0;
	aliveSurvivors[1] = 0;
	survivorsAliveBonus[0] = 0;
	survivorsAliveBonus[1] = 0;
	totalBonus[0] = 0;
	totalBonus[1] = 0;
	mapFactor = 0.0;
}

stock InSecondHalfOfRound()
{
	return GameRules_GetProp("m_bInSecondHalfOfRound");
}

bool IsSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

int GetSurvivorsInSaferoom()
{
	int aliveCount;
	int survivorCount;
	for (int i = 1; i <= MaxClients && survivorCount < teamSize; i++)
	{
		if (IsSurvivor(i))
		{
			survivorCount++;
			if (L4D_IsInLastCheckpoint(i))
			{
					aliveCount++;
			}
		}
	}
	return aliveCount;
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

stock GetSurvivorPermanentHealth(client)
{
    return GetEntProp(client, Prop_Send, "m_iHealth");
}

stock IsIncapacitated(client) return GetEntProp(client, Prop_Send, "m_isIncapacitated");
