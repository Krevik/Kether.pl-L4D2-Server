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

float fSurvivorTotalBonus[2];
float fSurvivorHealthItemsBonus[2];
float fSurvivorHealthBonus[2];
float fSurvivorTankKillPassBonus[2];
float fSurvivorWitchCrownBonus[2];
int iSurvivorsAlive[2];
int iTeamSize;
ConVar g_hCvarDefibPenalty = null;

public Plugin myinfo =
{
	name = "L4D2 Bonus For pills",
	author = "Krevik",
	description = "Gives score bonuses for pills, adrenaline, HP, tank kill/pass, witch crown",
	version = "1.1.0",
	url = "krevik.github.io/kether/"
};

public void OnPluginStart()
{
	g_hCvarDefibPenalty = FindConVar("vs_defib_penalty");
	RegConsoleCmd("sm_health", CMD_print_bonuses, "Let's print those bonuses");
	RegConsoleCmd("sm_bonus", CMD_print_bonuses, "Let's print those bonuses");
	RegConsoleCmd("sm_bonusinfo", CMD_print_bonus_info, "Let's print those bonuses info.");
	RegConsoleCmd("sm_binfo", CMD_print_bonus_info, "Let's print those bonuses info.");
	RegConsoleCmd("sm_minfo", CMD_print_bonus_info, "Let's print those bonuses info.");
	RegConsoleCmd("sm_mapinfo", CMD_print_bonus_info, "Let's print those bonuses info.");

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	hCvarValveSurvivalBonus = FindConVar("vs_survival_bonus");
	iTeamSize = GetConVarInt(FindConVar("survivor_limit"));
}

public OnPluginEnd()
{
	ResetConVar(hCvarValveSurvivalBonus);
	ResetConVar(g_hCvarDefibPenalty);
}

public void OnMapStart()
{
	clearSavedBonusParameters();
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
}

public void TP_OnTankPass(){
	int team = InSecondHalfOfRound();
	float bonus = GetBonusForTankKillPass();
	fSurvivorTankKillPassBonus[team] += bonus;
	int survs = GetUprightSurvivors();
	if(survs > 0){
		CPrintToChatAll("Tank has been passed resulting in: {olive}%d {default}points bonus", RoundToNearest(bonus) );
	}
}

public void OnTankDeath(){
	int team = InSecondHalfOfRound();
	float bonus = GetBonusForTankKillPass();
	fSurvivorTankKillPassBonus[team] += bonus;
	int survs = GetUprightSurvivors();
	if(survs > 0){
		CPrintToChatAll("Tank has been killed resulting in: {olive}%d {default}points bonus", RoundToNearest(bonus) );
	}
}

public void Kether_OnWitchDrawCrown(){
	int team = InSecondHalfOfRound();
	float bonus = GetBonusForWitchCrown();
	fSurvivorWitchCrownBonus[team] += bonus;
	CPrintToChatAll("Witch has been draw-crowned resulting in: {olive}%d {default}points bonus", RoundToNearest(bonus) );
}

public void Kether_OnWitchCrown(){
	int team = InSecondHalfOfRound();
	float bonus = GetBonusForWitchCrown();
	fSurvivorWitchCrownBonus[team] += bonus;
	CPrintToChatAll("Witch has been crowned resulting in: {olive}%d {default}points bonus", RoundToNearest(bonus) );
}

//PRINT actual bonuses
public Action CMD_print_bonuses(int client, int args)
{
	bool isTankInPlay = IsTankInPlay();
	int team = InSecondHalfOfRound();
	if(isTankInPlay){
		CPrintToChat(client, "[{green}Point Bonus{default}] Tank Is in Play. Cannot calculate the bonus when tank is alive.");	
	}else{
		int actualTotalBonus = GetActualTotalBonus();
		if(team == 0){
			if(actualTotalBonus > 0 ){
				CPrintToChat(client, "{green}[{blue}R#%d {default}Bonus{green}] {green}Total: {olive}%d {green}[{green}HB: {olive}%d {default}| {green}HIB: {olive}%d {default}| {green}TB: {olive}%d {default}| {green}WB: {olive}%d{green}]", team+1, actualTotalBonus,
				GetActualHealthBonus(), GetActualHealthItemsBonus(), RoundToNearest(fSurvivorTankKillPassBonus[0]), RoundToNearest(fSurvivorWitchCrownBonus[0]));
			}else{
				CPrintToChat(client, "{green}[{blue}R#%d {default}Bonus{green}] {green}TB: {olive}0", team+1 );
			}
		}
		if(team == 1){
			if(RoundToNearest(fSurvivorTotalBonus[0])>0){
				CPrintToChat(client, "{green}[{blue}R#%d {default}Bonus{green}] {green}Total: {olive}%d {green}[{green}HB: {olive}%d {default}| {green}HIB: {olive}%d {default}| {green}TB: {olive}%d {default}| {green}WB: {olive}%d{green}]", 1, RoundToNearest(fSurvivorTotalBonus[0]),
				RoundToNearest(fSurvivorHealthBonus[0]), RoundToNearest(fSurvivorHealthItemsBonus[0]), RoundToNearest(fSurvivorTankKillPassBonus[0]), RoundToNearest(fSurvivorWitchCrownBonus[0]));
			}else{
				CPrintToChat(client, "{green}[{blue}R#%d {default}Bonus{green}] {green}Total: {olive}0", 0 );
			}
			if(actualTotalBonus>0){
				CPrintToChat(client, "{green}[{blue}R#%d {default}Bonus{green}] {green}Total: {olive}%d {green}[{green}HB: {olive}%d {default}| {green}HIB: {olive}%d {default}| {green}TB: {olive}%d {default}| {green}WB: {olive}%d{green}]", team+1, actualTotalBonus,
				GetActualHealthBonus(), GetActualHealthItemsBonus(), RoundToNearest(fSurvivorTankKillPassBonus[team]), RoundToNearest(fSurvivorWitchCrownBonus[team]));
			}else{
				CPrintToChat(client, "{green}[{blue}R#%d {default}Bonus{green}] {green}Total: {olive}0", team+1 );
			}
		}
	}

	return Plugin_Handled;
}

public int GetActualTotalBonus(){
	return GetActualHealthBonus() + GetActualHealthItemsBonus() + GetActualTankKillPassBonus() + GetActualWitchCrownBonus();
}

public int GetActualHealthBonus(){
	return RoundToNearest(GetTotalHealthBonusForAlive());
}

public int GetActualHealthItemsBonus(){
	int medkitsCount = RoundToNearest(countMedkitsForAlive());
	int pillsCount = RoundToNearest(countPillsAndAdrenalineForAlive());
	float totalBonusForHealthItems = ((GetBonusForMedkit()*medkitsCount) + (GetBonusForPillsAdrenaline()*pillsCount));
	return RoundToNearest(totalBonusForHealthItems);

}

public int GetActualTankKillPassBonus(){
	int team = InSecondHalfOfRound();
	return RoundToNearest(fSurvivorTankKillPassBonus[team]);
}

public int GetActualWitchCrownBonus(){
	int team = InSecondHalfOfRound();
	return RoundToNearest(fSurvivorWitchCrownBonus[team]);
}

public Action CMD_print_bonus_info(int client, int args)
{
	bool isTankInPlay = IsTankInPlay();
	if(isTankInPlay){
		CPrintToChat(client, "[{green}Point Bonus{default}] Tank Is in Play. Cannot show the bonus, while tank is in play.");	
	}else{
		CPrintToChat(client, "[{green}Point Bonus{default}] Full HP Survivor bonus for the map: {green}%d", RoundToNearest(GetMaximumBonusPerSurvivor()));	
		CPrintToChat(client, "[{green}Point Bonus{default}] Bonus per 1 medkit for the map: {green}%d", RoundToNearest(GetBonusForMedkit()));	
		CPrintToChat(client, "[{green}Point Bonus{default}] Bonus per 1 pills/adrenaline for the map: {green}%d", RoundToNearest(GetBonusForPillsAdrenaline()));
		CPrintToChat(client, "[{green}Point Bonus{default}] Bonus per 1 tank pass/kill for the map: {green}%d", RoundToNearest(GetBonusForTankKillPass()));	
		CPrintToChat(client, "[{green}Point Bonus{default}] Bonus per 1 witch crown for the map: {green}%d", RoundToNearest(GetBonusForWitchCrown()));	
	}

	return Plugin_Handled;
}

public Action PrintRoundEndStats(Handle timer) {
	int team = InSecondHalfOfRound();
	if(team == 0){
		if(RoundToNearest(fSurvivorTotalBonus[0])>0){
			CPrintToChatAll("{green}[{blue}R#%d {default}Bonus{green}] {green}Total: {olive}%d {green}[{green}HB: {olive}%d {default}| {green}HIB: {olive}%d {default}| {green}TB: {olive}%d {default}| {green}WB: {olive}%d{green}]", team+1, RoundToNearest(fSurvivorTotalBonus[0]),
			RoundToNearest(fSurvivorHealthBonus[0]), RoundToNearest(fSurvivorHealthItemsBonus[0]), RoundToNearest(fSurvivorTankKillPassBonus[0]), RoundToNearest(fSurvivorWitchCrownBonus[0]));
		}else{
			CPrintToChatAll("{green}[{blue}R#%d {default}Bonus{green}] {green}Total: {olive}0", team+1 );
		}
	}
	if(team == 1){
		if(RoundToNearest(fSurvivorTotalBonus[0])>0){
			CPrintToChatAll("{green}[{blue}R#%d {default}Bonus{green}] {green}Total: {olive}%d {green}[{green}HB: {olive}%d {default}| {green}HIB: {olive}%d {default}| {green}TB: {olive}%d {default}| {green}WB: {olive}%d{green}]", 1, RoundToNearest(fSurvivorTotalBonus[0]),
			RoundToNearest(fSurvivorHealthBonus[0]), RoundToNearest(fSurvivorHealthItemsBonus[0]), RoundToNearest(fSurvivorTankKillPassBonus[0]), RoundToNearest(fSurvivorWitchCrownBonus[0]));
		}else{
			CPrintToChatAll("{green}[{blue}R#%d {default}Bonus{green}] {green}Total: {olive}0", 1 );
		}
		if(RoundToNearest(fSurvivorTotalBonus[1])>0){
			CPrintToChatAll("{green}[{blue}R#%d {default}Bonus{green}] {green}Total: {olive}%d {green}[{green}HB: {olive}%d {default}| {green}HIB: {olive}%d {default}| {green}TB: {olive}%d {default}| {green}WB: {olive}%d{green}]", team+1, RoundToNearest(fSurvivorTotalBonus[1]),
			RoundToNearest(fSurvivorHealthBonus[1]), RoundToNearest(fSurvivorHealthItemsBonus[1]), RoundToNearest(fSurvivorTankKillPassBonus[1]), RoundToNearest(fSurvivorWitchCrownBonus[1]));
		}else{
			CPrintToChatAll("{green}[{blue}R#%d {default}Bonus{green}] {green}Total: {olive}0", team+1 );
		}
		clearSavedBonusParameters();
	}

	return Plugin_Handled;
}

public void clearSavedBonusParameters(){
	fSurvivorTotalBonus[0] = 0.0;
	fSurvivorTotalBonus[1] = 0.0;
	iSurvivorsAlive[0] = 0;
	iSurvivorsAlive[1] = 0;
	fSurvivorHealthBonus[0] = 0.0;
	fSurvivorHealthBonus[1] = 0.0;
	fSurvivorHealthItemsBonus[0] = 0.0;
	fSurvivorHealthItemsBonus[1] = 0.0;
	fSurvivorTankKillPassBonus[0] = 0.0;
	fSurvivorTankKillPassBonus[1] = 0.0;
	fSurvivorWitchCrownBonus[0] = 0.0;
	fSurvivorWitchCrownBonus[1] = 0.0;
}


public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	CalculateSetAndPrintBonuses();
	return Plugin_Continue;
}


//we only need those two here because tank/witch bonuses are set during tank pass/kill || witch crown
public void CalculateSetAndPrintBonuses(){
	int team = InSecondHalfOfRound();
	int iSurvivalMultiplier = GetUprightSurvivors();
	iSurvivorsAlive[team] = iSurvivalMultiplier;
	CalculateAndSetBonusForHealth(team);
	CalculateAndSetBonusForHealthItems(team);
	CalculateAndSetTotalBonus(team);

	// float fSurvivorSplitBonus = (fSurvivorTotalBonus[team])/float(iSurvivorsAlive[team]);
	// if(iSurvivalMultiplier == 0){
	// 	fSurvivorSplitBonus = 0.0;
	// }
	// SetConVarInt(hCvarValveSurvivalBonus, RoundToNearest(fSurvivorSplitBonus));
	SetConVarInt(hCvarValveSurvivalBonus, 0);
	CreateTimer(3.5, PrintRoundEndStats, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void CalculateAndSetBonusForHealth(int team){
	float bonusForHP = GetTotalHealthBonus();
	fSurvivorHealthBonus[team] = bonusForHP;
}

public void CalculateAndSetBonusForHealthItems(int team){
	int medkitsCount = RoundToNearest(countMedkits());
	int pillsCount = RoundToNearest(countPillsAndAdrenaline());
	float totalBonusForHealthItems = ((GetBonusForMedkit()*medkitsCount) + (GetBonusForPillsAdrenaline()*pillsCount));
	fSurvivorHealthItemsBonus[team] = totalBonusForHealthItems;
}

public void CalculateAndSetTotalBonus(int team){
	fSurvivorTotalBonus[team] = fSurvivorHealthBonus[team] + fSurvivorHealthItemsBonus[team] + fSurvivorTankKillPassBonus[team] + fSurvivorWitchCrownBonus[team];
	int iBonus = RoundToNearest(fSurvivorTotalBonus[team]);
	g_hCvarDefibPenalty.SetInt(-iBonus);
	GameRules_SetProp("m_iVersusDefibsUsed", 1, 4, GameRules_GetProp("m_bAreTeamsFlipped", 4, 0));
}

/************/
/** Stocks **/
/************/
float GetMapDistanceMultiplier(){
	return float(GetMapMaxScore())/400.0;
}

Float:GetMaximumBonusPerSurvivor(){
	return (100.0/4.0)*GetMapDistanceMultiplier();				
}

float GetBonusForMedkit(){
	return GetMaximumBonusPerSurvivor()*1.4;
}

float GetBonusForPillsAdrenaline(){
	return 10.0*GetMapDistanceMultiplier();
}

float GetBonusForTankKillPass(){
	return 25.0;
}

float GetBonusForWitchCrown(){
	return 25.0;
}


float GetTotalHealthBonus(){
	float mapDistanceMultiplier = GetMapDistanceMultiplier();
	new survivorCount;		
	float totalBonus = 0.0;
	for (new i = 1; i <= MaxClients && survivorCount < iTeamSize; i++)
	{
		if (IsSurvivor(i))
		{
			survivorCount++;
			if (L4D_IsInLastCheckpoint(i) && IsPlayerAlive(i) && !IsIncapacitated(i))
			{	
				float bonusForPermHealth = GetSurvivorPermanentHealth(i)/4.0;				
				float totalBonusToAdd = (bonusForPermHealth)*mapDistanceMultiplier;
				totalBonus = totalBonus + totalBonusToAdd;
			}
		}
	}
	return totalBonus;
}

float GetTotalHealthBonusForAlive(){
	float mapDistanceMultiplier = GetMapDistanceMultiplier();
	new survivorCount;		
	float totalBonus = 0.0;
	for (new i = 1; i <= MaxClients && survivorCount < iTeamSize; i++)
	{
		if (IsSurvivor(i))
		{
			survivorCount++;
			if (IsPlayerAlive(i) && !IsIncapacitated(i))
			{	if(GetSurvivorPermanentHealth(i) <= 100){
					float bonusForPermHealth = GetSurvivorPermanentHealth(i)/4.0;				
					float totalBonusToAdd = (bonusForPermHealth)*mapDistanceMultiplier;
					totalBonus = totalBonus + totalBonusToAdd;
				}
			}
		}
	}
	return totalBonus;
}

float countMedkits()
{	
	new survivorCount;		
	new totalMedkits;
	for (new i = 1; i <= MaxClients && survivorCount < iTeamSize; i++)
	{
		if (IsSurvivor(i))
		{
			survivorCount++;
			if (L4D_IsInLastCheckpoint(i))
			{
				if(HasMedkit(i)){
					totalMedkits += 1;
				}
			}
		}
	}
	return float(totalMedkits);
}

float countMedkitsForAlive()
{	
	new survivorCount;		
	new totalMedkits;
	for (new i = 1; i <= MaxClients && survivorCount < iTeamSize; i++)
	{
		if (IsSurvivor(i))
		{
			survivorCount++;
			if (IsPlayerAlive(i))
			{
				if(HasMedkit(i)){
					totalMedkits += 1;
				}
			}
		}
	}
	return float(totalMedkits);
}

float countPillsAndAdrenaline()
{	
	new survivorCount;		
	new totalPills;
	for (new i = 1; i <= MaxClients && survivorCount < iTeamSize; i++)
	{
		if (IsSurvivor(i))
		{
			survivorCount++;
			if (L4D_IsInLastCheckpoint(i))
			{
				if(HasPills(i) || HasAdrenaline(i)){
					totalPills += 1;
				}
			}
		}
	}
	return float(totalPills);
}

float countPillsAndAdrenalineForAlive()
{	
	new survivorCount;		
	new totalPills;
	for (new i = 1; i <= MaxClients && survivorCount < iTeamSize; i++)
	{
		if (IsSurvivor(i))
		{
			survivorCount++;
			if (IsPlayerAlive(i))
			{
				if(HasPills(i) || HasAdrenaline(i)){
					totalPills += 1;
				}
			}
		}
	}
	return float(totalPills);
}


GetUprightSurvivors()
{
	int aliveCount;
	int survivorCount;
	for (int i = 1; i <= MaxClients && survivorCount < iTeamSize; i++)
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

GetAliveSurvivors()
{
	int aliveCount;
	int survivorCount;
	for (int i = 1; i <= MaxClients && survivorCount < iTeamSize; i++)
	{
		if (IsSurvivor(i))
		{
			survivorCount++;
			if (IsPlayerAlive(i))
			{
					aliveCount++;
			}
		}
	}
	return aliveCount;
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

stock GetSurvivorPermanentHealth(client)
{
    return GetEntProp(client, Prop_Send, "m_iHealth");
}

stock GetSurvivorIncapCount(int client)
{
    return GetEntProp(client, Prop_Send, "m_currentReviveCount");
}

stock IsIncapacitated(client) return GetEntProp(client, Prop_Send, "m_isIncapacitated");


stock GetMapMaxScore()
{
	return L4D_GetVersusMaxCompletionScore();
}

stock InSecondHalfOfRound()
{
	return GameRules_GetProp("m_bInSecondHalfOfRound");
}

bool IsTankInPlay()
{
	for (int i = 1; i <= MaxClients; i++) {
		if (IsTank(i) && IsPlayerAlive(i)) {
			return true;
		}
	}

	return false;
}

bool IsTank(int client)
{
	return (IsClientInGame(client)
		&& GetClientTeam(client) == 3
		&& GetEntProp(client, Prop_Send, "m_zombieClass") == 8);
}