/*  
*    Copyright (C) 2023  StarterX4		starterx4(at)gmail(dot)com
*    Copyright (C) 2023  Kether.pl
*
*    This program is free software: you can redistribute it and/or modify
*    it under the terms of the GNU General Public License as published by
*    the Free Software Foundation, either version 3 of the License, or
*    (at your option) any later version.
*
*    This program is distributed in the hope that it will be useful,
*    but WITHOUT ANY WARRANTY; without even the implied warranty of
*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*    GNU General Public License for more details.
*
*    You should have received a copy of the GNU General Public License
*    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#pragma tabsize 0
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <left4dhooks>
#include <l4d2_saferoom_detect>

//#define CVAR_FLAGS	FCVAR_NOTIFY

public Plugin myinfo =
{
	name = "BW/ThirdStrike Summary",
	author = "StarterX4",
	description = "Prints the summary with a list of the BW players, who made it into the saferoom",
	version = "0.1",
	url = "https://kether.pl"
};

public OnPluginStart()
{
    decl String:GameName[12];
    GetGameFolderName(GameName, sizeof(GameName));
    if (!StrEqual(GameName, "left4dead2"))
        SetFailState("BW Summary is only supported on Left 4 Dead 2.");

	new String:GameMode[32];
    GetConVarString(FindConVar("mp_gamemode"), GameMode, 32);
    if (!StrContains(GameMode, "versus", false) || !StrContains(GameMode, "campaign", false) || !StrContains(GameMode, "realism", false))
    	SetFailState("BW Summary works only on Versus and Campaign (+Realism) gamemodes!");
}

bool IsBW(int client)
{
	return GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike") != 0;
}

public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	decl String:bwPlayers[MaxClients][MAX_NAME_LENGTH];
	int count;

	for(int client = 1; client <= MaxClients; client++)
    {
		if (IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
		{
			if (SAFEDETECT_IsPlayerInEndSaferoom(client) && IsBW(client))
			{
				GetClientName(client, bwPlayers[count++], MAX_NAME_LENGTH);
			}
		}
	}

	if(count)
	{
		char bwMessage[192];
		ImplodeStrings(bwPlayers, count, ", ", bwMessage, sizeof(bwMessage));
		CPrintToChatAll("[{lightgreen}BW Summary{default}] {default}Alive BW Survivors:");
		CPrintToChatAll("\x04%s.", bwMessage);
		
	}
	return Plugin_Continue;
}
