#pragma semicolon 1

#include <multicolors>
#include <sourcemod>
#include <builtinvotes>
//int targetSwitchClientID = -1;
char sScavengeBotsDS[32];

public Plugin myinfo = 
{
    name = "Switch Bots Cans Filling",
    author = "StarterX4",
    description = "Provides basic voting to switch bots ability to fill the cans in Scavenge mode",
    version = "0.1",
    url = ""
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
    return APLRes_Success;
} 

public void OnPluginStart()
{
    RegConsoleCmd("sm_sbs", Voting_CMD, "Let's call a vote!");
	RegConsoleCmd("sm_sbswitch", Voting_CMD, "Let's call a vote!");
	RegConsoleCmd("sm_votebots", Voting_CMD, "Let's call a vote!");
}

public Action Voting_CMD(int client, int args)
{
	// Currently supported only for the Scavenge
	decl String:gamemode[56];
	GetConVarString(FindConVar("mp_gamemode"), gamemode, sizeof(gamemode));
	if (StrContains(gamemode, "scavenge", false) > -1){
	}
	else {
		PrintToChat(client, "[ScavengeBots Switch] Not a Scavenge gamemode! Found \"%s\"", gamemode);
		return Plugin_Handled;
	}

	Format(sScavengeBotsDS, sizeof(sScavengeBotsDS), "scavengebotsds_on");
	bool bScavengeBotsDS = GetConVarBool(FindConVar(sScavengeBotsDS));

	if(IsValidClient(client)){
        int target_list[MAXPLAYERS];

        //targetSwitchClientID = target_list[0];

		int voteCasterTeam = GetClientTeam(client);
		if(voteCasterTeam == 1){
			ReplyToTargetError(client, target_list[0]);
			return Plugin_Handled;
		}

		if(!IsValidClient(client)){
			ReplyToTargetError(client, target_list[0]);
			return Plugin_Handled;
		}

        startSwitchVoting(bScavengeBotsDS, client);
	}
	return Plugin_Handled;
}

public void startSwitchVoting(bool result, int sender)
{
	// Get all non-spectating players
	int iNumPlayers;
	int[] iPlayers = new int[MaxClients];
	for (int i=1; i<=MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) == 1) || GetClientTeam(i) != GetClientTeam(sender) )
		{
			continue;
		}
		iPlayers[iNumPlayers++] = i;
	}

	if(result == 0)
	{
		char voteTitle[256];
		Format(voteTitle, sizeof(voteTitle), "Enable Scavenge Bots (Bots filling cans)?");
		Handle votingHandle = CreateBuiltinVote(SwitchVoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(votingHandle, voteTitle);
		SetBuiltinVoteInitiator(votingHandle, sender);
		SetBuiltinVoteResultCallback(votingHandle, SwitchVoteResultHandler);
		DisplayBuiltinVote(votingHandle, iPlayers, iNumPlayers, 8);
		FakeClientCommand(sender, "Vote Yes");
	}
	if(result == 1)
	{
		char voteTitle[256];
		Format(voteTitle, sizeof(voteTitle), "Disable Scavenge Bots (Bots filling cans)?");
		Handle votingHandle = CreateBuiltinVote(SwitchVoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(votingHandle, voteTitle);
		SetBuiltinVoteInitiator(votingHandle, sender);
		SetBuiltinVoteResultCallback(votingHandle, SwitchVoteResultHandler2);
		DisplayBuiltinVote(votingHandle, iPlayers, iNumPlayers, 8);
		FakeClientCommand(sender, "Vote Yes");
	}
}

public void SwitchVoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
		}
	}
}

// To enable
public void SwitchVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	char successMessage[256];
	char failMessage[256];
	Format(successMessage, sizeof(successMessage), "Enabling Scavenge Bots...");
	Format(failMessage, sizeof(failMessage), "Vote Failed. Leaving ScavengeBots Unchanged...");
	for (int i=0; i<num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_clients / 2) )
			{
				if(!GetConVarBool(FindConVar(sScavengeBotsDS))){
					DisplayBuiltinVotePass(vote, successMessage );
					ServerCommand("sm_cvar scavengebotsds_on 1");
				}else{
					DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses );
					CPrintToChatAll("{blue}[{green}ScavengeBots Switch{blue}]{default} %s", failMessage);
				}
				return;
			}
		}
	}
	
	// Vote Failed
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return;
}

// To disable
public void SwitchVoteResultHandler2(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	char successMessage[256];
	char failMessage[256];
	Format(successMessage, sizeof(successMessage), "Disabling Scavenge Bots...");
	Format(failMessage, sizeof(failMessage), "Vote Failed. Leaving ScavengeBots Unchanged...");
	for (int i=0; i<num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_clients / 2) )
			{
				if(GetConVarBool(FindConVar(sScavengeBotsDS))){
					DisplayBuiltinVotePass(vote, successMessage );
					ServerCommand("sm_cvar scavengebotsds_on 0");
				}else{
					DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses );
					CPrintToChatAll("{blue}[{green}ScavengeBots Switch{blue}]{default} %s", failMessage);
				}
				return;
			}
		}
	}
	
	// Vote Failed
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return;
}

bool IsValidForVoting(int client){
	return IsValidClient(client) && GetClientTeam(client) > 1;
}

stock bool IsValidClient(int client)
{ 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client)) return false; 
    return true;
}