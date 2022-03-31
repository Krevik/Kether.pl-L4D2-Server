#include <sourcemod>
#include <builtinvotes>
#include <readyup>
#include <colors>

#define MAX_STR_LEN 30
#define MIN_MIX_START_COUNT 4

#define COND_HAS_ALREADY_VOTED 0
#define COND_NEED_MORE_VOTES 1
#define COND_START_MIX 2
#define COND_START_MIX_ADMIN 3
#define COND_NO_PLAYERS 4

#define STATE_FIRST_CAPT 0
#define STATE_SECOND_CAPT 1
#define STATE_NO_MIX 2
#define STATE_PICK_TEAMS 3

#define L4D_TEAM_SPECTATE	1

enum L4D2Team                                                                   
{                                                                               
    L4D2Team_None = 0,                                                          
    L4D2Team_Spectator,                                                         
    L4D2Team_Survivor,                                                          
    L4D2Team_Infected                                                           
}

new currentState = STATE_NO_MIX;
new Menu:mixMenu;
new StringMap:hVoteResultsTrie;
new StringMap:hSwapWhitelist;
new StringMap:hPlayers;
new mixCallsCount = 0;
char currentMaxVotedCaptAuthId[MAX_STR_LEN];
char survCaptainAuthId[MAX_STR_LEN];
char infCaptainAuthId[MAX_STR_LEN];
new maxVoteCount = 0;
new pickCount = 0;
new survivorsPick = 0;
new bool:isMixAllowed = false;
new bool:isPickingCaptain = false;
new Handle:mixStartedForward;
new Handle:mixStoppedForward;
new Handle:captainVoteTimer;
new Handle:team_vote;
new Handle:g_hVote;


public Plugin myinfo =
{
    name = "L4D2 Mix Manager",
    author = "Luckylock",
    description = "Provides ability to pick captains and teams through menus",
    version = "4",
    url = "https://github.com/LuckyServ/"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_oldmix", Cmd_MixStart, "Mix command");
	RegConsoleCmd("sm_mix", Cmd_MixStart, "Mix command");
	RegConsoleCmd("sm_votemix", MixRequest);

    RegAdminCmd("sm_stopmix", Cmd_MixStop, ADMFLAG_CHANGEMAP, "Mix command");
    AddCommandListener(Cmd_OnPlayerJoinTeam, "jointeam");
    hVoteResultsTrie = CreateTrie();
    hSwapWhitelist = CreateTrie();
    hPlayers = CreateTrie();
    mixStartedForward = CreateGlobalForward("OnMixStarted", ET_Event);
    mixStoppedForward = CreateGlobalForward("OnMixStopped", ET_Event);
    PrecacheSound("buttons/blip1.wav");
}

public void OnMapStart()
{
    isMixAllowed = true;
    StopMix();
}

public void OnRoundIsLive() {
    isMixAllowed = false;
    StopMix();
}

public void StartMix()
{
    FakeClientCommandAll("sm_hide");
    Call_StartForward(mixStartedForward);
    Call_Finish();
    //EmitSoundToAll("buttons/blip1.wav"); 
}

public void StopMix()
{
    currentState = STATE_NO_MIX;
    FakeClientCommandAll("sm_show");
    Call_StartForward(mixStoppedForward);
    Call_Finish();

    if (isPickingCaptain && captainVoteTimer != INVALID_HANDLE) {
        KillTimer(captainVoteTimer);
    }
}

public void FakeClientCommandAll(char[] command)
{
    for (new client = 1; client <= MaxClients; ++client) {
        if (IsClientInGame(client) && !IsFakeClient(client)) {
            FakeClientCommand(client, command);
        }  
    }
}

public Action Cmd_OnPlayerJoinTeam(int client, const char[] command, int argc)
{
    char authId[MAX_STR_LEN];
    char cmdArgBuffer[MAX_STR_LEN];
    L4D2Team allowedTeam;
    L4D2Team newTeam;

    if (argc >= 1) {

        GetCmdArg(1, cmdArgBuffer, MAX_STR_LEN);
        newTeam = L4D2Team:StringToInt(cmdArgBuffer);

        if (currentState != STATE_NO_MIX && newTeam != L4D2Team_Spectator && IsHuman(client)) {

            GetClientAuthId(client, AuthId_SteamID64, authId, MAX_STR_LEN); 

            if (!hSwapWhitelist.GetValue(authId, allowedTeam) || allowedTeam != newTeam) {
                PrintToChat(client, "\x04Mix Manager: \x01 You can not join a team without being picked.");
                return Plugin_Stop;
            }
        }
        
    }

    return Plugin_Continue; 
}

public void OnClientPutInServer(int client)
{
    char authId[MAX_STR_LEN];

    if (currentState != STATE_NO_MIX && IsHuman(client))
    {
        GetClientAuthId(client, AuthId_SteamID64, authId, MAX_STR_LEN);
        ChangeClientTeamEx(client, L4D2Team_Spectator);
    }
}

public Action Cmd_MixStop(int client, int args) {
    if (currentState != STATE_NO_MIX) {
        StopMix();
        PrintToChatAll("\x04Mix Manager: \x01Stopped by admin \x03%N\x01.", client);
    } else {
        PrintToChat(client, "\x04Mix Manager: \x01Not currently started.");
    }
}

public Action:MixRequest(client, args)
{
	if ((!client)) return Plugin_Handled;
	if (StartMixVoting(client))
	{
		//caller is voting for
		FakeClientCommand(client, "Vote Yes");
	}
	return Plugin_Handled;
}

bool:StartMixVoting(client)
{
	if (GetClientTeam(client) == L4D_TEAM_SPECTATE)
	{
		CPrintToChat(client, "{blue}[{default}Team Mix{blue}] {default}Mix voting isn't allowed for spectators.");
		return false;
	}
	if (!IsBuiltinVoteInProgress() && currentState == STATE_NO_MIX && isMixAllowed)
	{
		StartMix();
		new iNumPlayers;
		decl iPlayers[MaxClients];
		//list of non-spectators players
		for (new i=1; i<=MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) == L4D_TEAM_SPECTATE))
			{
				continue;
			}
			iPlayers[iNumPlayers++] = i;
		}
		new String:sBuffer[64];
		g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		Format(sBuffer, sizeof(sBuffer), "Mix teams using captain method?");
		SetBuiltinVoteArgument(g_hVote, sBuffer);
		SetBuiltinVoteInitiator(g_hVote, client);
		SetBuiltinVoteResultCallback(g_hVote, MixVotingResultHandler);
		DisplayBuiltinVote(g_hVote, iPlayers, iNumPlayers, 20);
		return true;
	}
	CPrintToChat(client, "{blue}[{default}Match{blue}] {default}Match vote cannot be started now.");
	return false;
}

public VoteActionHandler(Handle:vote, BuiltinVoteAction:action, param1, param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			g_hVote = INVALID_HANDLE;
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, BuiltinVoteFailReason:param1);
			StopMix();
		}
	}
}

public void MixVotingResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (new i=0; i<num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				if(currentState == STATE_NO_MIX && isMixAllowed){
					DisplayBuiltinVotePass(vote, "Starting team mix in 2 seconds. Be patient.");
					CreateTimer(2.0, MixVotingSuccess);
				}
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	StopMix();
}

public Action:MixVotingSuccess(Handle:timer)
{
    if (currentState != STATE_NO_MIX) {
		CPrintToChatAll("{blue}[{default}Team Mix{blue}] {default}Mix already started.");
        return Plugin_Handled;
    } else if (!isMixAllowed) {
		CPrintToChatAll("{blue}[{default}Team Mix{blue}] {default}Mix not allowed on live round.");
        return Plugin_Handled;
    }
    new mixConditions;
    mixConditions = COND_START_MIX_ADMIN;

    if (mixConditions == COND_START_MIX_ADMIN) {
		CPrintToChatAll("{blue}[{default}Team Mix{blue}] {default}Mix started by vote.");


        currentState = STATE_FIRST_CAPT;
        StartMix();
        SwapAllPlayersToSpec();

        // Initialise values
        mixCallsCount = 0;
        hVoteResultsTrie.Clear();
        hSwapWhitelist.Clear();
        maxVoteCount = 0;
        strcopy(currentMaxVotedCaptAuthId, MAX_STR_LEN, " ");
        pickCount = 0;

        if (Menu_Initialise()) {
            Menu_AddAllSpectators();
            Menu_DisplayToAllSpecs();
        }

        captainVoteTimer = CreateTimer(11.0, Menu_StateHandler, _, TIMER_REPEAT); 
        isPickingCaptain = true;

    }
    return Plugin_Handled;
}

stock bool IsPlayer(int client)
{
	int team = GetClientTeam(client);
	return (team == L4D2Team_Survivor || team == L4D2Team_Infected);
}

public Action Cmd_MixStart(int client, int args)
{
    if (currentState != STATE_NO_MIX) {
        PrintToChat(client, "\x04Mix Manager: \x01Already started.");
        return Plugin_Handled;
    } else if (!isMixAllowed) {
        PrintToChat(client, "\x04Mix Manager: \x01Not allowed on live round.");
        return Plugin_Handled;
    }

    new mixConditions;
    mixConditions = GetMixConditionsAfterVote(client);

    if (mixConditions == COND_START_MIX || mixConditions == COND_START_MIX_ADMIN) {
        if (mixConditions == COND_START_MIX_ADMIN) {
            PrintToChatAll("\x04Mix Manager: \x01Started by admin \x03%N\x01.", client);
        } else {
            PrintToChatAll("\x04Mix Manager: \x03%N \x01has voted to start a Mix. Type !mix to vote too!", client);
            PrintToChatAll("\x04Mix Manager: \x01Started by vote.");
        }

        currentState = STATE_FIRST_CAPT;
        StartMix();
        SwapAllPlayersToSpec();

        // Initialise values
        mixCallsCount = 0;
        hVoteResultsTrie.Clear();
        hSwapWhitelist.Clear();
        maxVoteCount = 0;
        strcopy(currentMaxVotedCaptAuthId, MAX_STR_LEN, " ");
        pickCount = 0;

        if (Menu_Initialise()) {
            Menu_AddAllSpectators();
            Menu_DisplayToAllSpecs();
        }

        captainVoteTimer = CreateTimer(11.0, Menu_StateHandler, _, TIMER_REPEAT); 
        isPickingCaptain = true;

    } else if (mixConditions == COND_NEED_MORE_VOTES) {
        PrintToChatAll("\x04Mix Manager: \x03%N \x01has voted to start a Mix. (\x05%d \x01more to start)", client, MIN_MIX_START_COUNT - mixCallsCount);

    } else if (mixConditions == COND_HAS_ALREADY_VOTED) {
        PrintToChat(client, "\x04Mix Manager: \x01You already voted to start a Mix.");

    } else if (mixConditions == COND_NO_PLAYERS) {
        PrintToChat(client, "\x04Mix Manager: \x01Join teams to start a mix.");
    }

    return Plugin_Handled;
}

public int GetMixConditionsAfterVote(int client)
{
    new bool:dummy = false;
    new bool:hasVoted = false;
    char clientAuthId[MAX_STR_LEN];
    GetClientAuthId(client, AuthId_SteamID64, clientAuthId, MAX_STR_LEN);
    hasVoted = GetTrieValue(hVoteResultsTrie, clientAuthId, dummy)

    if (!SavePlayers()) {
        return COND_NO_PLAYERS;
    } else if (hasVoted){
        return COND_HAS_ALREADY_VOTED;
    } else if (++mixCallsCount >= MIN_MIX_START_COUNT) {
        return COND_START_MIX; 
    } else {
        SetTrieValue(hVoteResultsTrie, clientAuthId, true);
        return COND_NEED_MORE_VOTES;
    }
}

public bool SavePlayers() {
    char clientAuthId[MAX_STR_LEN];

    ClearTrie(hPlayers);

    for (new client = 1; client <= MaxClients; client++) {
        if (IsSurvivor(client)) {
            GetClientAuthId(client, AuthId_SteamID64, clientAuthId, MAX_STR_LEN);
        } else if (IsInfected(client)) {
            GetClientAuthId(client, AuthId_SteamID64, clientAuthId, MAX_STR_LEN);
        }

        if (IsSurvivor(client) || IsInfected(client)) {
            SetTrieValue(hPlayers, clientAuthId, true);
        }
    }

    return GetTrieSize(hPlayers) == 8;
}

public bool Menu_Initialise()
{
    if (currentState == STATE_NO_MIX) return false;

    mixMenu = new Menu(Menu_MixHandler, MENU_ACTIONS_ALL);
    mixMenu.ExitButton = false;

    switch(currentState) {
        case STATE_FIRST_CAPT: {
            mixMenu.SetTitle("Mix Manager - Pick first captain");
            return true;
        }

        case STATE_SECOND_CAPT: {
            mixMenu.SetTitle("Mix Manager - Pick second captain");
            return true;
        }

        case STATE_PICK_TEAMS: {
            mixMenu.SetTitle("Mix Manager - Pick team member(s)");
            return true;
        }
    }

    CloseHandle(mixMenu);
    return false;
}

public void Menu_AddAllSpectators()
{
    char clientName[MAX_STR_LEN];
    char clientId[MAX_STR_LEN];

    mixMenu.RemoveAllItems();

    for (new client = 1; client <= MaxClients; ++client) {
        if (IsClientSpec(client) && IsClientInPlayers(client)) {
            GetClientAuthId(client, AuthId_SteamID64, clientId, MAX_STR_LEN);
            GetClientName(client, clientName, MAX_STR_LEN);
            mixMenu.AddItem(clientId, clientName);
        }  
    }
}

public bool IsClientInPlayers(client) {
    bool dummy;
    char clientAuthId[MAX_STR_LEN];
    GetClientAuthId(client, AuthId_SteamID64, clientAuthId, MAX_STR_LEN);
    return GetTrieValue(hPlayers, clientAuthId, dummy);
}

public void Menu_AddTestSubjects()
{
    mixMenu.AddItem("test", "test");
}

public void Menu_DisplayToAllSpecs()
{
    for (new client = 1; client <= MaxClients; ++client) {
        if (IsClientSpec(client) && IsClientInPlayers(client)) {
            mixMenu.Display(client, 10);
        }
    }
}

public int Menu_MixHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select) {
        if (currentState == STATE_FIRST_CAPT || currentState == STATE_SECOND_CAPT) {
            char authId[MAX_STR_LEN];
            menu.GetItem(param2, authId, MAX_STR_LEN);

            new voteCount = 0;

            if (!GetTrieValue(hVoteResultsTrie, authId, voteCount)) {
                voteCount = 0;
            }

            SetTrieValue(hVoteResultsTrie, authId, ++voteCount, true);

            if (voteCount > maxVoteCount) {
                strcopy(currentMaxVotedCaptAuthId, MAX_STR_LEN, authId);
                maxVoteCount = voteCount;
            }

        } else if (currentState == STATE_PICK_TEAMS) {
            char authId[MAX_STR_LEN]; 
            menu.GetItem(param2, authId, MAX_STR_LEN);
            new L4D2Team:team = GetClientTeamEx(param1);

            if (team == L4D2Team_Spectator || (team == L4D2Team_Infected && survivorsPick == 1) || (team == L4D2Team_Survivor && survivorsPick == 0)) {
                PrintToChatAll("\x04Mix Manager: \x01Captain \x03%N \x01found in the wrong team, aborting...", param1);
                StopMix();

            } else {
               
                if (SwapPlayerToTeam(authId, team, 0)) {
                    pickCount++;
                    if (pickCount == 4) {
                        // Do not switch picks 

                    } else if (pickCount > 5) {
                        PrintToChatAll("\x04Mix Manager: \x01 Teams are picked.");
                        StopMix();
                    } else {
                        survivorsPick = survivorsPick == 1 ? 0 : 1;
                    } 
                } else {
                    PrintToChatAll("\x04Mix Manager: \x01The team member who was picked was not found, aborting...", param1);
                    StopMix();
                }
            }
        }
    }

    return 0;
}

public Action Menu_StateHandler(Handle timer, Handle hndl)
{
    switch(currentState) {
        case STATE_FIRST_CAPT: {
            new numVotes = 0;
            GetTrieValue(hVoteResultsTrie, currentMaxVotedCaptAuthId, numVotes);
            ClearTrie(hVoteResultsTrie);
           
            if (SwapPlayerToTeam(currentMaxVotedCaptAuthId, L4D2Team_Survivor, numVotes)) {
                strcopy(survCaptainAuthId, MAX_STR_LEN, currentMaxVotedCaptAuthId);
                currentState = STATE_SECOND_CAPT;
                maxVoteCount = 0;

                if (Menu_Initialise()) {
                    Menu_AddAllSpectators();
                    Menu_DisplayToAllSpecs();
                }
            } else {
                PrintToChatAll("\x04Mix Manager: \x01Failed to find first captain with at least 1 vote from spectators, aborting...");
                StopMix();
            }

            strcopy(currentMaxVotedCaptAuthId, MAX_STR_LEN, " ");
        }

        case STATE_SECOND_CAPT: {
            new numVotes = 0;
            GetTrieValue(hVoteResultsTrie, currentMaxVotedCaptAuthId, numVotes);
            ClearTrie(hVoteResultsTrie);

            if (SwapPlayerToTeam(currentMaxVotedCaptAuthId, L4D2Team_Infected, numVotes)) {
                strcopy(infCaptainAuthId, MAX_STR_LEN, currentMaxVotedCaptAuthId);
                currentState = STATE_PICK_TEAMS;
                CreateTimer(0.5, Menu_StateHandler); 

            } else {
                PrintToChatAll("\x04Mix Manager: \x01Failed to find second captain with at least 1 vote from spectators, aborting...");
                StopMix();
            }

            strcopy(currentMaxVotedCaptAuthId, MAX_STR_LEN, " ");
        }

        case STATE_PICK_TEAMS: {
            isPickingCaptain = false;
            survivorsPick = GetURandomInt() & 1;            
            CreateTimer(1.0, Menu_TeamPickHandler, _, TIMER_REPEAT);
        }
    }

    if (currentState == STATE_NO_MIX || currentState == STATE_PICK_TEAMS) {
        return Plugin_Stop; 
    } else {
        return Plugin_Handled;
    }
}

public Action Menu_TeamPickHandler(Handle timer)
{
    if (currentState == STATE_PICK_TEAMS) {

        if (Menu_Initialise()) {
            Menu_AddAllSpectators();
            new captain;

            if (survivorsPick == 1) {
               captain = GetClientFromAuthId(survCaptainAuthId); 
            } else {
               captain = GetClientFromAuthId(infCaptainAuthId); 
            }

            if (captain > 0) {
                if (GetSpectatorsCount() > 0) {
                    mixMenu.Display(captain, 1); 
                } else {
                    PrintToChatAll("\x04Mix Manager: \x01No more spectators to choose from, aborting...");
                    StopMix();
                    return Plugin_Stop;
                }
            } else {
                PrintToChatAll("\x04Mix Manager: \x01Failed to find the captain, aborting...");
                StopMix();
                return Plugin_Stop;
            }

            return Plugin_Continue;
        }
    }
    return Plugin_Stop;
}

public void SwapAllPlayersToSpec()
{
    for (new client = 1; client <= MaxClients; ++client) {
        if (IsClientInGame(client) && !IsFakeClient(client)) {
            ChangeClientTeamEx(client, L4D2Team_Spectator);
        }
    }
}

public bool SwapPlayerToTeam(const char[] authId, L4D2Team:team, numVotes)
{
    new client = GetClientFromAuthId(authId);
    new bool:foundClient = client > 0;

    if (foundClient) {
        hSwapWhitelist.SetValue(authId, team);
        ChangeClientTeamEx(client, team);

        switch(currentState) {
            case STATE_FIRST_CAPT: {
                PrintToChatAll("\x04Mix Manager: \x01First captain is \x03%N\x01. (\x05%d \x01votes)", client, numVotes);
            }
            
            case STATE_SECOND_CAPT: {
                PrintToChatAll("\x04Mix Manager: \x01Second captain is \x03%N\x01. (\x05%d \x01votes)", client, numVotes);
            }

            case STATE_PICK_TEAMS: {
                if (survivorsPick == 1) {
                    PrintToChatAll("\x04Mix Manager: \x03%N \x01was picked (survivors).", client)
                } else {
                    PrintToChatAll("\x04Mix Manager: \x03%N \x01was picked (infected).", client)
                }
            }
        }
    }

    return foundClient;
}

public void OnClientDisconnect(client)
{
    if (currentState != STATE_NO_MIX && IsClientInPlayers(client))
    {
        PrintToChatAll("\x04Mix Manager: \x01Player \x03%N \x01has left the game, aborting...", client);
        StopMix();
    }
}

public bool IsPlayerCaptain(client)
{
    return GetClientFromAuthId(survCaptainAuthId) == client || GetClientFromAuthId(infCaptainAuthId) == client;
}

public int GetClientFromAuthId(const char[] authId)
{
    char clientAuthId[MAX_STR_LEN];
    new client = 0;
    new i = 0;
    
    while (client == 0 && i < MaxClients) {
        ++i;

        if (IsClientInGame(i) && !IsFakeClient(i)) {
            GetClientAuthId(i, AuthId_SteamID64, clientAuthId, MAX_STR_LEN); 

            if (StrEqual(authId, clientAuthId)) {
                client = i;
            }
        }
    }

    return client;
}

public bool IsClientSpec(int client) {
    return IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 1;
}

public int GetSpectatorsCount()
{
    new count = 0;

    for (new client = 1; client <= MaxClients; ++client) {
        if (IsClientSpec(client)) {
            ++count;
        }
    }

    return count;
}

stock bool:ChangeClientTeamEx(client, L4D2Team:team)
{
    if (GetClientTeamEx(client) == team) {
        return true;
    }

    if (team != L4D2Team_Survivor) {
        ChangeClientTeam(client, _:team);
        return true;
    } else {
        new bot = FindSurvivorBot();

        if (bot > 0) {
            new flags = GetCommandFlags("sb_takecontrol");
            SetCommandFlags("sb_takecontrol", flags & ~FCVAR_CHEAT);
            FakeClientCommand(client, "sb_takecontrol");
            SetCommandFlags("sb_takecontrol", flags);
            return true;
        }
    }
    return false;
}

stock L4D2Team:GetClientTeamEx(client)
{
    return L4D2Team:GetClientTeam(client);
}

stock FindSurvivorBot()
{
    for (new client = 1; client <= MaxClients; client++)
    {
        if(IsClientInGame(client) && IsFakeClient(client) && GetClientTeamEx(client) == L4D2Team_Survivor)
        {
            return client;
        }
    }
    return -1;
}

stock bool:IsSurvivor(client)                                                   
{                                                                               
    return IsHuman(client)
        && GetClientTeam(client) == 2; 
}

stock bool:IsInfected(client)                                                   
{                                                                               
    return IsHuman(client)
        && GetClientTeam(client) == 3; 
}

public bool IsHuman(client)
{
    return IsClientInGame(client) && !IsFakeClient(client);
}

public bool RunVoteChecks(int client)
{
	if (!IsInReady())
	{
		CPrintToChat(client, "{blue}<{green}Team Mix Voting{blue}>{default} Team mix voting is only available during ready up.");
		return false;
	}
	if (GetClientTeam(client) == 1)
	{
		CPrintToChat(client, "{blue}<{green}Team Mix Voting{blue}>{default} Team mix voting is not available for spectators.");
		return false;
	}
	return true;
}

public Action VoteMix(int client, int args)
{
	if (!RunVoteChecks(client)) return;
	
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
	
	// Check if a new vote is allowed to be called
	if (IsNewBuiltinVoteAllowed() && isMixAllowed)
	{
	    FakeClientCommandAll("sm_hide");
		Call_StartForward(mixStartedForward);
		Call_Finish();
		char bv_voteTitle[64];
		Format(bv_voteTitle, 64, "Do you want to mix teams using captain method?")
		
		// Start the vote!
		team_vote = CreateBuiltinVote(TeamMixVoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(team_vote, bv_voteTitle);
		SetBuiltinVoteInitiator(team_vote, client);
		SetBuiltinVoteResultCallback(team_vote, TeamMixVoteResultHandler);
		DisplayBuiltinVote(team_vote, iPlayers, iNumPlayers, 20);
		FakeClientCommand(client, "Vote Yes");
		return;
	}

	CPrintToChat(client, "{blue}<{green}BossVote{blue}>{default} Boss Vote cannot be called right now...");
}

public void TeamMixVoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			team_vote = INVALID_HANDLE;
			CloseHandle(vote);
			FakeClientCommandAll("sm_show");
			Call_StartForward(mixStoppedForward);
			Call_Finish();
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
			FakeClientCommandAll("sm_show");
			Call_StartForward(mixStoppedForward);
			Call_Finish();
		}
	}
}

public void TeamMixVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i=0; i<num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_clients / 2))
			{
				CreateTimer(3, MixVotePasses);
				DisplayBuiltinVotePass(vote, "Ok, starting mix");
				Call_StartForward(mixStartedForward);
				Call_Finish();
			}
		}
	}
	
	// Vote Failed
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return;
}


public Action MixVotePasses(Handle timer)
{
				currentState = STATE_FIRST_CAPT;
				StartMix();
				SwapAllPlayersToSpec();

				// Initialise values
				mixCallsCount = 0;
				hVoteResultsTrie.Clear();
				hSwapWhitelist.Clear();
				maxVoteCount = 0;
				strcopy(currentMaxVotedCaptAuthId, MAX_STR_LEN, " ");
				pickCount = 0;

				if (Menu_Initialise()) {
					Menu_AddAllSpectators();
					Menu_DisplayToAllSpecs();
				}

				captainVoteTimer = CreateTimer(11.0, Menu_StateHandler, _, TIMER_REPEAT); 
				isPickingCaptain = true;
				return;
}