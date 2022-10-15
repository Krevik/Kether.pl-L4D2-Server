#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2lib>
#include <colors>
#include <l4d2_saferoom_detect>

new iTeamSize;
new Handle:hCvarValveSurvivalBonus;

float fSurvivorBonus[2];
int iSurvivorsAlive[2];

public Plugin:myinfo =
{
	name = "L4D2 Bonus For pills",
	author = "Krevik",
	description = "Gives score bonuses for pills, adrenaline and HP",
	version = "1.0.0",
	url = "krevik.github.io/kether/"
};

public OnPluginStart()
{
	RegConsoleCmd("sm_bonus", CMD_print_bonuses, "Let's print those bonuses");
	RegConsoleCmd("sm_health", CMD_print_bonuses, "Let's print those bonuses");
	RegConsoleCmd("sm_bonusinfo", CMD_print_bonus_info, "Let's print those bonuses info.");
	RegConsoleCmd("sm_binfo", CMD_print_bonus_info, "Let's print those bonuses info.");
	RegConsoleCmd("sm_minfo", CMD_print_bonus_info, "Let's print those bonuses info.");
	RegConsoleCmd("sm_mapinfo", CMD_print_bonus_info, "Let's print those bonuses info.");

	hCvarValveSurvivalBonus = FindConVar("vs_survival_bonus");
	iTeamSize = GetConVarInt(FindConVar("survivor_limit"));



}

public Action:CMD_print_bonuses(client, args)
{
	bool isTankInPlay = IsTankInPlay();
	new team = InSecondHalfOfRound();
	if(isTankInPlay){
		CPrintToChat(client, "[{green}Point Bonus{default}] Tank Is in Play. Cannot calculate the bonus when tank is alive.");	
	}else{
		if(team == 0){
				int actualBonus = GetActualBonusPerAliveSurvivor();
				int aliveSurvivors = GetAliveSurvivors();
				int totalBonus = actualBonus*aliveSurvivors;
				if(actualBonus > 0){
					CPrintToChat(client, "{blue}Team 1{default}: [{green}Point Bonus{default}] Current Point Bonus: {green}%d", totalBonus );	
				}
		}else{
			if( RoundToNearest(fSurvivorBonus[0]) > 0 && iSurvivorsAlive[0] > 0){
				int finalBonus = RoundToNearest(fSurvivorBonus[0] * float(iSurvivorsAlive[0]) );
				CPrintToChat(client, "{blue}Team 1{default}: [{green}Point Bonus{default}] Point Bonus: {green}%d", finalBonus );	
			}else{
				CPrintToChat(client, "{blue}Team 1{default}: [{green}Point Bonus{default}] Point Bonus: {green}0" );	
			}

			if( RoundToNearest(fSurvivorBonus[1]) > 0 && iSurvivorsAlive[1] > 0){
				int finalBonus = RoundToNearest(fSurvivorBonus[1] * float(iSurvivorsAlive[1]) );
				CPrintToChat(client, "{blue}Team 2{default}: [{green}Point Bonus{default}] Point Bonus: {green}%d", finalBonus );
			}else{
				int actualBonus = GetActualBonusPerAliveSurvivor();
				int aliveSurvivors = GetAliveSurvivors();
				int totalBonus = actualBonus*aliveSurvivors;
				if(actualBonus > 0){
					CPrintToChat(client, "{blue}Team 2{default}: [{green}Point Bonus{default}] Current Point Bonus: {green}%d", totalBonus );	
				}else{
					CPrintToChat(client, "{blue}Team 2{default}: [{green}Point Bonus{default}] Point Bonus: {green}0" );	
				}
			}

		}
	}

	return Plugin_Handled;
}

public Action:CMD_print_bonus_info(client, args)
{
	bool isTankInPlay = IsTankInPlay();
	if(isTankInPlay){
		CPrintToChat(client, "[{green}Point Bonus{default}] Tank Is in Play. Cannot show the bonus, while tank is in play.");	
	}else{
		CPrintToChat(client, "[{green}Point Bonus{default}] Full HP Survivor bonus for the map: {green}%d", RoundToNearest(GetMaximumBonusPerSurvivor()));	
		CPrintToChat(client, "[{green}Point Bonus{default}] Bonus for 1 medkit for the map: {green}%d", RoundToNearest(GetBonusForMedkit()));	
		CPrintToChat(client, "[{green}Point Bonus{default}] Bonus for 1 pills/adrenaline for the map: {green}%d", RoundToNearest(GetBonusForPillsAdrenaline()));	
	}

	return Plugin_Handled;
}

public OnPluginEnd()
{
	ResetConVar(hCvarValveSurvivalBonus);
}


int GetActualBonusPerAliveSurvivor(){
	new iSurvivalMultiplier = GetAliveSurvivors();
	new medkitsCount = RoundToNearest(countMedkitsForAlive());
	new pillsCount = RoundToNearest(countPillsAndAdrenalineForAlive());
	float bonusForHP = GetTotalHealthBonusForAlive();
	
	float totalBonus = bonusForHP + ((GetBonusForMedkit()*medkitsCount) + (GetBonusForPillsAdrenaline()*pillsCount));
	return RoundToNearest( totalBonus/float(iSurvivalMultiplier) );
}

public Action:L4D2_OnEndVersusModeRound(bool:countSurvivors)
{
	new team = InSecondHalfOfRound();
	new iSurvivalMultiplier = GetUprightSurvivors();
	new medkitsCount = RoundToNearest(countMedkits());
	new pillsCount = RoundToNearest(countPillsAndAdrenaline());
	float bonusForHP = GetTotalHealthBonus();
	
	float totalBonus = bonusForHP + ((GetBonusForMedkit()*medkitsCount) + (GetBonusForPillsAdrenaline()*pillsCount));

	fSurvivorBonus[team] = totalBonus/float(iSurvivalMultiplier);
	if(iSurvivalMultiplier == 0){
		fSurvivorBonus[team] = 0.0;
	}
	iSurvivorsAlive[team] = iSurvivalMultiplier;
	SetConVarInt(hCvarValveSurvivalBonus, RoundToNearest(fSurvivorBonus[team]) );
	CreateTimer(3.5, PrintRoundEndStats, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public Action PrintRoundEndStats(Handle timer) {
	new team = InSecondHalfOfRound();
	new iSurvivalMultiplier = GetUprightSurvivors();
	if(team == 0){
		if(RoundToNearest(fSurvivorBonus[team])>0 && iSurvivorsAlive[team] > 0){
			CPrintToChatAll("[{green}Point Bonus{default}] Total bonus: {green}%d{default}x{green}%d", iSurvivalMultiplier, RoundToNearest(fSurvivorBonus[team]) );
		}
	}else{
		if(RoundToNearest(fSurvivorBonus[0])>0  && iSurvivorsAlive[0] > 0){
			CPrintToChatAll("{blue}Team 1{default}: [{green}Point Bonus{default}] Total bonus: {green}%d{default}x{green}%d", iSurvivorsAlive[0], RoundToNearest(fSurvivorBonus[0]) );
		}
		if(RoundToNearest(fSurvivorBonus[1])>0  && iSurvivorsAlive[1] > 0){
			CPrintToChatAll("{blue}Team 2{default}: [{green}Point Bonus{default}] Total bonus: {green}%d{default}x{green}%d", iSurvivalMultiplier, RoundToNearest(fSurvivorBonus[1]) );
		}
	}
	if(team == 1 ){
		fSurvivorBonus[0] = 0.0;
		fSurvivorBonus[1] = 0.0;
		iSurvivorsAlive[0] = 0;
		iSurvivorsAlive[1] = 0;
	}

	return Plugin_Handled;
}

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

float GetTotalHealthBonus(){
	float mapDistanceMultiplier = GetMapDistanceMultiplier();
	new survivorCount;		
	float totalBonus = 0.0;
	for (new i = 1; i <= MaxClients && survivorCount < iTeamSize; i++)
	{
		if (IsSurvivor(i))
		{
			survivorCount++;
			if (L4D_IsInLastCheckpoint(i))
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
			if (IsPlayerAlive(i))
			{	if(GetSurvivorPermanentHealth(i) < 100){
					float bonusForPermHealth = GetSurvivorPermanentHealth(i)/4.0;				
					float totalBonusToAdd = (bonusForPermHealth)*mapDistanceMultiplier;
					totalBonus = totalBonus + totalBonusToAdd;
				}
			}
		}
	}
	return totalBonus;
}

GetUprightSurvivors()
{
	new aliveCount;
	new survivorCount;
	for (new i = 1; i <= MaxClients && survivorCount < iTeamSize; i++)
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
	new aliveCount;
	new survivorCount;
	for (new i = 1; i <= MaxClients && survivorCount < iTeamSize; i++)
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

/************/
/** Stocks **/
/************/

bool:IsSurvivor(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

bool:HasMedkit(client)
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

bool:HasPills(client)
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

bool:HasAdrenaline(client)
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

GetSurvivorPermanentHealth(client)
{
	// Survivors always have minimum 1 permanent hp
	// so that they don't faint in place just like that when all temp hp run out
	// We'll use a workaround for the sake of fair calculations
	// Edit 2: "Incapped HP" are stored in m_iHealth too; we heard you like workarounds, dawg, so we've added a workaround in a workaround
	return GetEntProp(client, Prop_Send, "m_currentReviveCount") > 0 ? 0 : (GetEntProp(client, Prop_Send, "m_iHealth") > 0 ? GetEntProp(client, Prop_Send, "m_iHealth") : 0);
}

stock GetSurvivorIncapCount(client)
{
    return GetEntProp(client, Prop_Send, "m_currentReviveCount");
}

stock GetMapMaxScore()
{
	return L4D_GetVersusMaxCompletionScore();
}

InSecondHalfOfRound()
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