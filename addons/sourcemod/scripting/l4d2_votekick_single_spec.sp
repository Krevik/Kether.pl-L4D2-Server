#pragma semicolon 1

#include <multicolors>
#include <sourcemod>
#include <builtinvotes>
int targetKickClientID = -1;

public Plugin myinfo = 
{
    name = "Votekick a Single Spectator",
    author = "Krevik, StarterX4",
    description = "Provides basic voting to allow casting a vote to kick a single spectator in a team-neutral manner.",
    version = "0.1.0",
    url = ""
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
    return APLRes_Success;
} 

public void OnPluginStart()
{
    RegConsoleCmd("sm_vks", Voting_CMD, "Let's call a vote!");
	RegConsoleCmd("sm_votekickspec", Voting_CMD, "Let's call a vote!");
}

public Action Voting_CMD(int client, int args)
{
	if(IsValidClient(client) && args > 0){
        char arg[128];
        GetCmdArg(1, arg, sizeof(arg));
        char target_name[MAX_TARGET_LENGTH];
        int target_list[MAXPLAYERS];
		int target_count;
		bool tn_is_ml;
        if ((target_count = ProcessTargetString(
                arg,
                client,
                target_list,
                MAXPLAYERS,
                COMMAND_FILTER_DEAD,
                target_name,
                sizeof(target_name),
                tn_is_ml)) <= 0)
        {
            ReplyToTargetError(client, target_list[0]);
            return Plugin_Handled;
        }

        targetKickClientID = target_list[0];

        if(GetClientTeam(targetKickClientID) != 1){
            ReplyToTargetError(client, target_list[0]);
			PrintToChat(client, "[SM] Only spectating players can be voted off!");
            return Plugin_Handled;
        }

		if(!IsValidForKicking(targetKickClientID)){
			ReplyToTargetError(client, target_list[0]);
			return Plugin_Handled;
		}

        startKickVoting(targetKickClientID, client);
	}
	return Plugin_Handled;
}

public void startKickVoting(int target, int sender)
{
	if(target == 0)
	{
		PrintToChat(sender, "[SM]Client is invalid");
		return;
	}
	if(target == -1)
	{
		PrintToChat(sender, "[SM]No targets with the given name!");
		return;
	}
	
	// Get all spectating players
	int iNumPlayers;
	int[] iPlayers = new int[MaxClients];
	for (int i=1; i<=MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) != 1) )
		{
			continue;
		}
		iPlayers[iNumPlayers++] = i;
	}

    char voteTitle[256];
	char targetName[256];
	GetClientName(target, targetName, sizeof(targetName) );
    Format(voteTitle, sizeof(voteTitle), "Kick spectator %s?", targetName );
    Handle votingHandle = CreateBuiltinVote(KickVoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
	SetBuiltinVoteArgument(votingHandle, voteTitle);
	SetBuiltinVoteInitiator(votingHandle, sender);
	SetBuiltinVoteResultCallback(votingHandle, KickVoteResultHandler);
	DisplayBuiltinVote(votingHandle, iPlayers, iNumPlayers, 20);
	FakeClientCommand(sender, "Vote Yes");
}

public void KickVoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
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

public void KickVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	char targetName[256];
	char successMessage[256];
	char failMessage[256];
	GetClientName(targetKickClientID, targetName, sizeof(targetName));
	Format(successMessage, sizeof(successMessage), "Kicking spectator %s...", targetName);
	Format(failMessage, sizeof(failMessage), "Cannot Kick spectator %s...", targetName);
	for (int i=0; i<num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2) )
			{
				char targetName[256];
				GetClientName(targetKickClientID, targetName, sizeof(targetName) );
				if(IsValidForKicking(targetKickClientID)){
					DisplayBuiltinVotePass(vote, successMessage );
					//FakeClientCommand(targetKickClientID, "disconnect");
					ServerCommand("sm_ban %s 3", targetKickClientID);
				}else{
					DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses );
					CPrintToChatAll("{blue}<{green}VoteKick a Spectator{blue}>{default} %s", failMessage);
				}
				return;
			}
		}
	}
	
	// Vote Failed
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return;
}

bool IsValidForKicking(int client){
	return IsValidClient(client) && GetClientTeam(client) == 1;
}

stock bool IsValidClient(int client)
{ 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client)) return false; 
    return true;
}