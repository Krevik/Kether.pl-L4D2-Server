#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2lib>
#include <colors>

new Handle:hCvarBonusPerPills;
new Handle:hCvarBonusPerAdrenaline;
new Handle:hCvarBonusPerHPSurvivor;

new iTeamSize;
new Handle:hCvarValveSurvivalBonus;

public Plugin:myinfo =
{
	name = "L4D2 Bonus For pills",
	author = "Krevik",
	description = "Gives score bonuses pills, adrenaline and HP",
	version = "1.0.0",
	url = "krevik.github.io/kether/"
};

public OnPluginStart()
{
	RegConsoleCmd("sm_bonus", CMD_print_bonuses, "Let's print those bonuses");

	hCvarValveSurvivalBonus = FindConVar("vs_survival_bonus");
	iTeamSize = GetConVarInt(FindConVar("survivor_limit"));
  
	hCvarBonusPerPills = CreateConVar("sm_bonus_per_pills", "12", "Bonus per pills", FCVAR_NONE);
	hCvarBonusPerAdrenaline = CreateConVar("sm_bonus_per_adrenaline", "12", "Bonus per adrenaline", FCVAR_NONE);
	hCvarBonusPerHPSurvivor = CreateConVar("sm_bonus_per_full_hp_survivor", "48", "Bonus per full health survivor reaching safehouse.", FCVAR_NONE);
}

public Action:CMD_print_bonuses(client, args)
{
	CPrintToChat(client, "Bonus for {blue} pills{default}: {green}%d {default}, {blue}adrenaline{default}: {green}%d{default}. Survivor with full HP can yield additional {green}%d {default}points.", GetConVarInt(hCvarBonusPerPills), GetConVarInt(hCvarBonusPerAdrenaline), GetConVarInt(hCvarBonusPerHPSurvivor));
	return Plugin_Handled;
}

public OnPluginEnd()
{
	ResetConVar(hCvarValveSurvivalBonus);
}

public Action:L4D2_OnEndVersusModeRound(bool:countSurvivors)
{
	new iSurvivalMultiplier = GetUprightSurvivors();
	if(iSurvivalMultiplier>0){
		SetConVarInt(hCvarValveSurvivalBonus, RoundToNearest(GetSurvivorTotalBonus()/iSurvivalMultiplier + 25));
	}else{
		SetConVarInt(hCvarValveSurvivalBonus, RoundToNearest(25));
	}
	new pills = RoundToNearest(countPillsAndAdrenaline());
	if(iSurvivalMultiplier>0){
		CPrintToChatAll("[{green}Point Bonus{default}]{green}%d{default} survivors reached safehouse with {green}%d{default} {blue} pills/adrenaline.", iSurvivalMultiplier, pills);
		CPrintToChatAll("[{green}Point Bonus{default}]{default}The final bonus is high as {green}%d {default}points", RoundToNearest((GetSurvivorTotalBonus()/iSurvivalMultiplier + 25)*iSurvivalMultiplier));
	}
	return Plugin_Continue;
}


bool:IsPlayerLedged(client)
{
	return bool:(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") | GetEntProp(client, Prop_Send, "m_isFallingFromLedge"));
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
			if (IsPlayerAlive(i))
			{
				aliveCount++;
			}
		}
	}
	return aliveCount;
}

Float:countPillsAndAdrenaline()
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
				if(HasPills(i)){
					totalPills += 1;
				}
				if(HasAdrenaline(i)){
					totalPills += 1;
				}
			}
		}
	}
	return Float:float(totalPills);
}

Float:GetSurvivorTotalBonus()
{	
	new survivorCount;		
	new totalBonus;
	for (new i = 1; i <= MaxClients && survivorCount < iTeamSize; i++)
	{
		if (IsSurvivor(i))
		{
			survivorCount++;
			if (IsPlayerAlive(i))
			{
				new permHealthOfTheSurvivor = GetSurvivorPermanentHealth(i);
				new tempHealthOfTheSurvivor = GetSurvivorTempHealth(i);
				new numberOfIncaps = GetSurvivorIncapCount(i);
				float incapsImportanceModifier = 1;
				if(numberOfIncaps = 0) {incapsImportanceModifier = 0.48;}
				if(numberOfIncaps = 1) {incapsImportanceModifier = 0.32;}
				if(numberOfIncaps >= 2) {incapsImportanceModifier = 0.12;}
				
				new totalHealthBonusPerSurvivor = 0;
				if(tempHealthOfTheSurvivor > 100){
					totalHealthBonusPerSurvivor = 0;
				}else{
					totalHealthBonusPerSurvivor += permHealthOfTheSurvivor * incapsImportanceModifier;
				    totalHealthBonusPerSurvivor += tempHealthOfTheSurvivor * incapsImportanceModifier * 0.5;
				}
				totalBonus += totalHealthBonusPerSurvivor;
				
				if(HasPills(i)){
					totalBonus += GetConVarInt(hCvarBonusPerPills);
				}
				if(HasAdrenaline(i)){
					totalBonus += GetConVarInt(hCvarBonusPerAdrenaline);
				}
			}
		}
	}
	return Float:float(totalBonus);
}

/************/
/** Stocks **/
/************/

bool:IsSurvivor(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
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

stock GetSurvivorPermanentHealth(client)
{
    return GetEntProp(client, Prop_Send, "m_iHealth");
}

stock GetSurvivorTempHealth(client)
{
	new temphp = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(FindConVar("pain_pills_decay_rate")))) - 1;
	return (temphp > 0 ? temphp : 0);
}

stock GetSurvivorIncapCount(client)
{
    return GetEntProp(client, Prop_Send, "m_currentReviveCount");
}