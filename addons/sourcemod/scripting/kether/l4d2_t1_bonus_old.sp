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
new Handle:hCvarBonusPerMedkit;
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
	hCvarBonusPerMedkit = CreateConVar("sm_bonus_per_medkit", "24", "Bonus per medkit", FCVAR_NONE);
}

public Action:CMD_print_bonuses(client, args)
{
	CPrintToChat(client, "Bonus is in work yet.");	
	return Plugin_Handled;
}

public OnPluginEnd()
{
	ResetConVar(hCvarValveSurvivalBonus);
}

public Action:L4D2_OnEndVersusModeRound(bool:countSurvivors)
{
	new iSurvivalMultiplier = GetUprightSurvivors();
	//bonus: pills, adrenaline, HP (perm HP*1.0, tmp HP *0.5)
	new pillsCount = RoundToNearest(countPillsAndAdrenaline());
	new medkitsCount = RoundToNearest(countMedkits());
	new totalBonus = RoundToNearest( GetMedkitsTotalBonus() + GetPillsTotalBonus() + float(GetTotalHealthBonus()) );
	
	if(iSurvivalMultiplier>0){
		CPrintToChatAll("[{green}Point Bonus{default}]{green}%d{default} survivors reached safehouse with {green}%d{default} {blue} medkits{default}, {green}%d{default} {blue} pills/adrenaline{default}.", iSurvivalMultiplier, medkitsCount, pillsCount);
		CPrintToChatAll("[{green}Point Bonus{default}]{default}The final bonus is high as {green}%d {default}points.", totalBonus);

		SetConVarInt(hCvarValveSurvivalBonus, RoundToNearest(float(totalBonus)/iSurvivalMultiplier) );
	}else{
		SetConVarInt(hCvarValveSurvivalBonus, RoundToNearest(0));
	}
	
	return Plugin_Continue;
}


bool:IsPlayerLedged(client)
{
	return bool:(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") | GetEntProp(client, Prop_Send, "m_isFallingFromLedge"));
}

bool:IsIncapped(client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

Float:GetTotalHealthBonus(){
	new Float:mapDistanceMultiplier = float(GetMapMaxScore())/500.0;
	new survivorCount;		
	new Float:totalBonus = 0;
	for (new i = 1; i <= MaxClients && survivorCount < iTeamSize; i++)
	{
		if (IsSurvivor(i))
		{
			survivorCount++;
			if (IsPlayerAlive(i) && !IsPlayerLedged(i) && !IsIncapped(i))
			{
				new numberOfIncaps = GetSurvivorIncapCount(i);
				new Float:incapsFactor = 1.0;
				if(numberOfIncaps == 1) {incapsFactor = 0.75;}
				if(numberOfIncaps >= 2) {incapsFactor = 0.25;}
				
				new Float:bonusForPermHealth = GetSurvivorPermanentHealth(i)*0.75*incapsFactor;				
				new Float:bonusForTmpHealth = GetSurvivorTempHealth(i)*0.25*incapsFactor;				
				new Float:totalBonusToAdd = (bonusForPermHealth+bonusForTmpHealth)*mapDistanceMultiplier;
				totalBonus = totalBonus + totalBonusToAdd;
			}
		}
	}
	return RoundToNearest(totalBonus);
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
				if(!IsPlayerLedged(i) && !IsIncapped(i))
				{
					aliveCount++;
				}
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
	return float(totalPills);
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

Float:GetPillsTotalBonus()
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
				if(HasPills(i)){
					totalBonus += GetConVarInt(hCvarBonusPerPills);
				}
				if(HasAdrenaline(i)){
					totalBonus += GetConVarInt(hCvarBonusPerAdrenaline);
				}
			}
		}
	}
	return float(totalBonus);
}

Float:GetMedkitsTotalBonus()
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
				if(HasMedkit(i)){
					totalBonus += GetConVarInt(hCvarBonusPerMedkit);
				}
			}
		}
	}
	return float(totalBonus);
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

GetSurvivorTempHealth(client)
{
	new temphp = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(FindConVar("pain_pills_decay_rate")))) - 1;
	return (temphp > 0 ? temphp : 0);
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