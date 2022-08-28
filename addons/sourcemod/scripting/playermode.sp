#pragma semicolon 1
#define DEBUG 0
#define CVARS_PATH "configs/playermode_cvars.txt"

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <builtinvotes>
#include "includes/hardcoop_util.sp"

new Handle:hCvarMaxSurvivors;
new Handle:vote;

int g_iPlayerMode = 4;

public Plugin:myinfo = 
{
	name = "Player Mode",
	author = "breezy",
	description = "Allows survivors to change the team limit and adapts gameplay cvars to these changes",
	version = "2.0",
	url = ""
};

public OnPluginStart() {
	hCvarMaxSurvivors = CreateConVar( "pm_max_survivors", "8", "Maximum number of survivors allowed in the game" );
	RegConsoleCmd( "sm_playermode", Cmd_PlayerMode, "Change the number of survivors and adapt appropriately" );
	
	decl String:sGameFolder[128];
	GetGameFolderName( sGameFolder, sizeof(sGameFolder) );
	if( !StrEqual(sGameFolder, "left4dead2", false) ) {
		SetFailState("Plugin supports Left 4 dead 2 only!");
	} 
}

public OnPluginEnd() {
	ResetConVar( FindConVar("survivor_limit") );
	if ( FindConVar("confogl_pills_limit") != INVALID_HANDLE ) 
	{
		ResetConVar(FindConVar("confogl_pills_limit"));	
	}
}

public Action Cmd_PlayerMode(int client, int args) {	
	// Get all non-spectating players
	int iNumPlayers;
	int[] iPlayers = new int[MaxClients];
	for (int i=1; i<=MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) == 1))
		{
			continue;
		}
		iPlayers[iNumPlayers++] = i;
	}
	if( IsSurvivor(client) || IsGenericAdmin(client) ) {
		if( args == 1 ) {
			new String:sValue[32]; 
			GetCmdArg(1, sValue, sizeof(sValue));
			new iValue = StringToInt(sValue);
			if( iValue > 0 && iValue <= GetConVarInt(hCvarMaxSurvivors) ) 
			{
				if (!IsNewBuiltinVoteAllowed())
				{
					ReplyToCommand(client, "New voting is not allowed now.");
					return Plugin_Handled;
				}
				
				vote = CreateBuiltinVote(YesNoHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
				//team_vote = CreateBuiltinVote(TeamMixVoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);

				g_iPlayerMode = iValue;
				SetBuiltinVoteInitiator(vote, client);
				char voteStimulus[64];
				Format(voteStimulus, sizeof(voteStimulus), "Change to %d player mode?", iValue);
				SetBuiltinVoteArgument(vote, voteStimulus);
				FakeClientCommand(client, "Vote Yes");
				SetBuiltinVoteResultCallback(vote, PlayermodeVoteResultHandler);
				DisplayBuiltinVote(vote, iPlayers, iNumPlayers, 20);
			} else {
				ReplyToCommand( client, "Command restricted to values from 1 to %d", GetConVarInt(hCvarMaxSurvivors) );
			}
		} else {
			ReplyToCommand( client, "Usage: playermode <value> [ 1 <= value <= %d", GetConVarInt(hCvarMaxSurvivors) );
		}
	} else {
		ReplyToCommand(client, "You do not have access to this command");
	}
	return Plugin_Handled;
}

public void YesNoHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			vote = INVALID_HANDLE;
			CloseHandle(vote);
		}
		
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
		}
	}
}

public void PlayermodeVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i=0; i<num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_clients / 2))
			{
				char msgVoteSuccess[64];
				Format(msgVoteSuccess, sizeof(msgVoteSuccess), "Changing to %d playermode!", g_iPlayerMode);
				DisplayBuiltinVotePass(vote, "msgVoteSuccess");
				SetConVarInt(FindConVar("survivor_limit"), g_iPlayerMode);
				if ( FindConVar("confogl_pills_limit")  != INVALID_HANDLE )
				{
					SetConVarInt(FindConVar("confogl_pills_limit"), g_iPlayerMode);	
				}
				return;
			}
		}
	}
	
	// Vote Failed
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return;
}