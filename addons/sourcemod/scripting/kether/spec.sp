#include <sourcemod>
#include <sdktools>
#include <builtinvotes>

#define PLUGIN_VERSION "1.4.1"
#define CVAR_FLAGS 				FCVAR_PLUGIN|FCVAR_NOTIFY

new Handle:TimerMessage			= INVALID_HANDLE;
new Handle:TimerRepeatMessage	= INVALID_HANDLE;
new Handle:CommandKill 			= INVALID_HANDLE;
new Handle:CommandSurvivors		= INVALID_HANDLE;
new Handle:CommandInfected		= INVALID_HANDLE;
new Handle:CommandSpectate 		= INVALID_HANDLE;
new Handle:g_hVote				= INVALID_HANDLE;

public Plugin:myinfo = 
{
	name = "[L4D 1&2] NeedToHave",
	author = "Danny",
	description = "Chat Commands, Spectate, Join and Kill",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=128588"
}

public OnPluginStart()
{
	decl String:game[12];
	GetGameFolderName(game, sizeof(game));
	if (StrContains(game, "left4dead") == -1) SetFailState("NeedToHave will only work with Left 4 Dead 1 or 2!");

	LoadTranslations("l4d_nth.phrases");	
	
	CreateConVar("l4d_nth_version", PLUGIN_VERSION, "Plugin Version", CVAR_FLAGS|FCVAR_DONTRECORD);

	TimerMessage 		= 	CreateConVar("l4d_nth_message", 		"1", 		"Enables a hint message when a player connects", 				CVAR_FLAGS, true, 0.0, true, 1.0);
	TimerRepeatMessage 	= 	CreateConVar("l4d_nth_timerrepeat",		"9999", 		"Sets the timer to repeat the hint message", 					CVAR_FLAGS, true, 30.0, true, 600.0);	
	CommandKill 		=	CreateConVar("l4d_nth_kill",			"0", 		"0 = Disable, 1 = All, 2 = Survivor only, 3 = infected only", 	CVAR_FLAGS, true, 0.0, true, 3.0);
	CommandSurvivors	=	CreateConVar("l4d_nth_joinsurvivors",	"1", 		"Enables or disables joining the survivor team", 				CVAR_FLAGS, true, 0.0, true, 1.0);
	CommandInfected		=	CreateConVar("l4d_nth_joininfected",	"1", 		"Enables or disables joining the infected team", 				CVAR_FLAGS, true, 0.0, true, 1.0);
	CommandSpectate 	=	CreateConVar("l4d_nth_spectate",		"1", 		"Enables or disables spectate", 								CVAR_FLAGS, true, 0.0, true, 1.0);

	RegConsoleCmd("sm_kill", Kill_Me);

	RegConsoleCmd("sm_spec", Spectate);
	RegConsoleCmd("sm_s", Spectate);
	RegConsoleCmd("sm_spectate", Spectate);

	RegConsoleCmd("sm_afk", Spectate);
	
	RegConsoleCmd("sm_join", JoinTeam2);
	RegConsoleCmd("sm_infected", JoinTeam3);
	
	RegConsoleCmd("sm_kickspecs", KickSpecs_Cmd, "Let's vote to kick those Spectators!");
	AutoExecConfig(true, "l4d_nth");
}

/*======================== PLAYER COMMANDS =========================*/


public Action:KickSpecs_Cmd(client, args)
{
	if (IsClientInGame(client) && GetClientTeam(client) != 1)
	{
		if (IsNewBuiltinVoteAllowed())
		{
			new iNumPlayers;
			decl iPlayers[MaxClients];
			//list of non-spectators players
			for (new i=1; i<=MaxClients; i++)
			{
				if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) == 1))
				{
					continue;
				}
				iPlayers[iNumPlayers++] = i;
			}
			new String:sBuffer[64];
			g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
			Format(sBuffer, sizeof(sBuffer), "Kick Non-Admin & Non-Casting Spectators?");
			SetBuiltinVoteArgument(g_hVote, sBuffer);
			SetBuiltinVoteInitiator(g_hVote, client);
			SetBuiltinVoteResultCallback(g_hVote, SpecVoteResultHandler);
			DisplayBuiltinVote(g_hVote, iPlayers, iNumPlayers, 20);
			return;
		}
		PrintToChat(client, "Vote cannot be started now.");
	}
	return;
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
		}
	}
}

public void SpecVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (new i=0; i<num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				DisplayBuiltinVotePass(vote, "Ciao Spectators!");
				for (new c=1; c<=MaxClients; c++)
				{
					if (IsClientInGame(c) && (GetClientTeam(c) == 1) && GetUserAdmin(c) == INVALID_ADMIN_ID)
					{
						KickClient(c, "No Spectators, please!");
					}
				}
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public Action:Spectate(client, args)
{
	if(GetConVarInt(CommandSpectate))
	{
		ChangeClientTeam(client, 1);
	}
	return Plugin_Handled;
}

public Action:JoinTeam2(client, args)
{
	if(GetConVarInt(CommandSurvivors))
	{
		FakeClientCommand(client,"jointeam 2");
	}
	return Plugin_Handled;
}

public Action:JoinTeam3(client, args)
{
	if(GetConVarInt(CommandInfected))
	{
		FakeClientCommand(client,"jointeam 3");
	}
	return Plugin_Handled;
}

public Action:Kill_Me(client, args)
{
	new cvarValue = GetConVarInt(CommandKill);
	switch(cvarValue) 
	{
		case 3: 
		{
			if (GetClientTeam(client) == 3)
			{
				ForcePlayerSuicide(client);
			}
			else
			{
                PrintToChat(client, "%t", "MessageInfected");
			}
        }
        case 2: 
		{
            if (GetClientTeam(client) == 2)
			{
				ForcePlayerSuicide(client);
			}
			else
			{
				PrintToChat(client, "%t", "MessageSurvivors");
			}
        }
        case 1: 
		{
            ForcePlayerSuicide(client);
        }
        default: 
		{
            PrintToChat(client, "%t", "MessageNotAllowed");
        }
	}
	return Plugin_Continue;
}

/*============================= TIMER MESSAGE ====================================*/
public OnClientPutInServer(client)
{
	if(GetConVarInt(TimerMessage))
	{
		CreateTimer(GetConVarFloat(TimerRepeatMessage), WelcomePlayer, client, TIMER_REPEAT);
	}
}

public Action:WelcomePlayer(Handle:timer, any:client)
{
	if(IsClientInGame(client)) 
	{
		PrintHintText(client, "%t", "ShowHintMessage");
		return Plugin_Continue;
	}
	return Plugin_Stop;
}