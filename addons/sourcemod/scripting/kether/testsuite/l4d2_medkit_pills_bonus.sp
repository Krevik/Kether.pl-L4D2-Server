#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2lib>
#include <colors>
#include <l4d2_saferoom_detect>


new Handle:hCvarBonusPerMedkit;
new Handle:hCvarBonusPerPills;
new Handle:hCvarBonusPerAdrenaline;
new iTeamSize;
new Handle:hCvarValveSurvivalBonus;

public Plugin:myinfo =
{
	name = "L4D2 Bonus For pills and medkit",
	author = "Krevik",
	description = "Gives score bonuses for medkits and pills",
	version = "1.0.0",
	url = "krevik.github.io/kether/"
};

public OnPluginStart()
{
	RegConsoleCmd("sm_bonus", CMD_print_bonuses, "Let's print those bonuses");

	hCvarValveSurvivalBonus = FindConVar("vs_survival_bonus");
	iTeamSize = GetConVarInt(FindConVar("survivor_limit"));
  
	hCvarBonusPerMedkit = CreateConVar("sm_bonus_per_medkit", "24", "Bonus per medkit", FCVAR_NONE);
	hCvarBonusPerPills = CreateConVar("sm_bonus_per_pills", "12", "Bonus per pills", FCVAR_NONE);
	hCvarBonusPerAdrenaline = CreateConVar("sm_bonus_per_adrenaline", "12", "Bonus per adrenaline", FCVAR_NONE);
}

public Action:CMD_print_bonuses(client, args)
{
	CPrintToChat(client, "Bonus for {blue}medkit{default}: {green}%d {default}, {blue} pills{default}: {green}%d {default},{blue}adrenaline{default}: {green}%d", GetConVarInt(hCvarBonusPerMedkit), GetConVarInt(hCvarBonusPerPills), GetConVarInt(hCvarBonusPerAdrenaline));
	return Plugin_Handled;
}

public OnPluginEnd()
{
	ResetConVar(hCvarValveSurvivalBonus);
}

public Action:L4D2_OnEndVersusModeRound(bool:countSurvivors)
{
	//empty comment
	new iSurvivalMultiplier = GetUprightSurvivors();
	if(iSurvivalMultiplier>0){
		SetConVarInt(hCvarValveSurvivalBonus, RoundToNearest(GetSurvivorTotalBonus()/iSurvivalMultiplier + 25));
	}else{
		SetConVarInt(hCvarValveSurvivalBonus, RoundToNearest(25));
	}
	new medkits = RoundToNearest(countMedkits());
	new pills = RoundToNearest(countPillsAndAdrenaline());
	if(iSurvivalMultiplier>0){
		CPrintToChatAll("[{green}Point Bonus{default}]{green}%d{default} survivors reached safehouse with {green}%d{default} {blue}medkits {default}and {green}%d{default} {blue} pills/adrenaline", iSurvivalMultiplier, medkits, pills);
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
			if (L4D_IsInLastCheckpoint(i))
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
			if (L4D_IsInLastCheckpoint(i))
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

Float:countMedkits()
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
	return Float:float(totalMedkits);
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
			if (L4D_IsInLastCheckpoint(i))
			{
				if(HasPills(i)){
					totalBonus += GetConVarInt(hCvarBonusPerPills);
				}
				if(HasMedkit(i)){
					totalBonus += GetConVarInt(hCvarBonusPerMedkit);
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