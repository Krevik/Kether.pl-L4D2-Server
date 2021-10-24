#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.4.1"
#define CVAR_FLAGS 				FCVAR_PLUGIN|FCVAR_NOTIFY

new Handle:TimerMessage			= INVALID_HANDLE;
new Handle:TimerRepeatMessage	= INVALID_HANDLE;
new Handle:CommandKill 			= INVALID_HANDLE;
new Handle:CommandSurvivors		= INVALID_HANDLE;
new Handle:CommandInfected		= INVALID_HANDLE;
new Handle:CommandSpectate 		= INVALID_HANDLE;

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
	
	AutoExecConfig(true, "l4d_nth");
}

/*======================== PLAYER COMMANDS =========================*/
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