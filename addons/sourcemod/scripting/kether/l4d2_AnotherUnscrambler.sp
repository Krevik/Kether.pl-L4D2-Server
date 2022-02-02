#include <sourcemod>
#include <sdktools>
#include <topmenus>
#include <adminmenu>
#include <clients>
#include "include/colors.inc"

#pragma newdecls required

#define PLUGIN_VERSION "1.2.1"
#define PLUGIN_NAME "Another Unscrambler"
#define MSG_TAG 	"{yellow}[Another Unscrambler]{default} "
#define MSG_TAG_ADM "{olive}[Another Unscrambler]{default} "

public Plugin myinfo = 
{
	name = "[L4D2] Another Unscrambler",
	author = "Merc1less",
	description = "Has an unscrambler and teambalancer and comes with team switching rules",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2730804"
}
//Global vars
bool g_GameModeEnabled 	    = false,
	 g_TeambalancingEnabled = false,
	 g_bLastTeamOrder 		= false;
int	 g_GameStatus = 0;
	 #define ROUND_STATUS_IN_ROUND            	  1
	 #define ROUND_STATUS_IN_FINALE           	  2
	 #define ROUND_STATUS_IN_RUNNING_VERSUS_GAME  4
	 #define ROUND_STATUS_WAITING_FOR_LOBBY_TEAMS 8
	
	 #define SetGameStatus(%0,%1) (g_GameStatus = ((g_GameStatus & ~(%1))|(%0)))
	 #define CheckGameStatus(%0) ((g_GameStatus & %0) == %0)
	 
ConVar cvar_tick_count_info,
	   cvar_change_team_adm_info_count,
	   cvar_show_announcement,
	   cvar_permissions,
       cvar_us_status,
 	   cvar_storage_time,
	   cvar_storage_filter;
	   
int g_Permissions = 0;
	#define PERM_BLOCK_TEAM_SWITCHING	            	 1
	#define PERM_BLOCKED_DURING_FINALES    				 2
	#define PERM_BLOCKED_TWO_PL_DIFF            		 4
	#define PERM_ALLOW_WINNING_TO_LOSING_TEAM_DIFF_1	 8
	#define PERM_ALLOW_POLLS							 16
	#define PERM_POLLS_ALLOWED_WHEN_TEAM_IS_FULL_ONLY	 32
	#define PERM_POLLS_ARE_ALLOWED_AT_THE_BEGINNING_ONLY 64 
	
Handle g_hUnscramblerTimer = INVALID_HANDLE,
	   g_fGetTeamScore	   = INVALID_HANDLE,
	   g_fSetHumanSpec	   = INVALID_HANDLE,
	   g_fTakeOverBot	   = INVALID_HANDLE;   

#define L4D_TEAM_LOBBY_CONNECT -1
#define L4D_TEAM_UNASSIGNED 	0
#define L4D_TEAM_SPECTATOR		1
#define L4D_TEAM_SURVIVORS		2
#define L4D_TEAM_INFECTED 		3

enum struct s_PLAYER_DATA
{
	int  iUserId;
	int  iTeam;
	int  iTeamchangeAttempts;
	bool bPollAllowed;
}
s_PLAYER_DATA[MAXPLAYERS+1] g_Players;

#define MAX_TEAMS 4
int g_LatelyJoined[MAX_TEAMS]; //just for the menu

#define STEAM_ID3_LEN 24
enum struct s_STORED_PLAYER
{	
	char sSteamID3[STEAM_ID3_LEN];
	int iDuration;
	int iLastTeam; //as internal Team id
}

ArrayList g_arrPlStorage;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "The plugin is written for Left 4 Dead 2 only.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
} 
public void OnPluginStart()
{
	//init	
	for (int i = 1;i <= MaxClients;i++)
	{
		g_Players[i].iUserId			 = 0;
		g_Players[i].iTeam   			 = L4D_TEAM_UNASSIGNED;
		g_Players[i].iTeamchangeAttempts = 0;
		g_Players[i].bPollAllowed 		 = false;		
    }
	
	LoadTranslations("common.phrases");
	LoadTranslations("l4d2_another_unscrambler.phrases");
	
	Handle hConf = LoadGameConfigFile("l4d_another_unscrambler_addresses");
	
	if (hConf == INVALID_HANDLE)
		SetFailState("Invalid file handle");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "SetHumanSpec");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	g_fSetHumanSpec = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "TakeOverBot");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_fTakeOverBot = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_GameRules);
    
	if (PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "GetTeamScore"))
    {
        PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
        PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
        PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
        g_fGetTeamScore = EndPrepSDKCall();
	}	
	
	if (g_fSetHumanSpec == INVALID_HANDLE
	||	g_fTakeOverBot  == INVALID_HANDLE
	||	g_fGetTeamScore == INVALID_HANDLE)
		SetFailState("Null Address found");
	
	CreateConVar("l4d2_aus_version",PLUGIN_VERSION,"Version of the plugin",FCVAR_DONTRECORD|FCVAR_NOTIFY);
	CreateConVar("l4d2_aus_gamemodes","","Enables all types of supported versus game modes. Empty string means all versus types."); //Just versus-based games are allowed. Plus mutation15 - versus survival
	CreateConVar("l4d2_aus_teambalancing","1","Enables teambalancing",0,true,0.0,true,1.0);
	CreateConVar("l4d2_aus_timeout","3","Defines a timeout in minutes after a still loading player will be kicked from server.");
	CreateConVar("l4d2_aus_newpl_execmdlist0","","Executes a list of commands as a server command when a new player joins the game.\nCommands with userid can be used with a '%d'. i.e.: sm_cmd %d;");
	CreateConVar("l4d2_aus_newpl_execmdlist1","","Executes a list of commands to all players when a newplayer joins the game\nCommands with userid can be used with a '%d'. i.e.: sm_cmd %d;");
	CreateConVar("l4d2_aus_newpl_execmdlist2","","Executes a list of commands to all admins when a new player joins the game.\nCommands with userid can be used with a '%d'. i.e.: sm_cmd %d;");
	CreateConVar("l4d2_aus_newpl_execmdlist3","","Executes a list of commands to all survivor players when a new player joins the team.\nCommands with userid can be used with a '%d'. i.e.: sm_cmd %d;");
	CreateConVar("l4d2_aus_newpl_execmdlist4","","Executes a list of commands to all infected players when a new player joins the team.\nCommands with userid can be used with a '%d'. i.e.: sm_cmd %d;");
	
	cvar_permissions				= CreateConVar("l4d2_aus_permissions","14","Sets the permission for team switching rules.",0,true,0.0,true,127.0); //Changeable in the menu
	cvar_tick_count_info			= CreateConVar("l4d2_aus_tick_count","3","How often the info of still loading players would appear. (n * 3 sec)",0,true,3.0,true,10.0);
	cvar_show_announcement			= CreateConVar("l4d2_aus_show_announcement","1","Shows an info when a int player connects to server. 0 = Off");
	cvar_change_team_adm_info_count = CreateConVar("l4d2_aus_changeteam_admin_info_count","3","How many times per round admins will be informed when a player wanna change the team",0,true,1.0);
	cvar_us_status			 		= CreateConVar("l4d2_aus_players_loading","0","Determines the current unscrambling status. Can be used by other plugins",FCVAR_DONTRECORD,true,0.0,true,float(MAXPLAYERS)); //Unscrambler is running > 0 means n-Players are loading or it is not unscrambling = 0
	cvar_storage_time		 		= CreateConVar("l4d2_aus_storage_time","10","Sets the reserved time in minutes a player is stored in list",0,true,1.0);	
	cvar_storage_filter				= CreateConVar("l4d2_aus_storage_filter","Disconnect by user;no steam logon;timed out;Steam Auth Ticket Has Been Canceled","Just players with these disconnect reasons are stored/remembered. Separated by ';'. Example 'Disconnect by user;no steam logon;timed out;' Empty string means all kind of reasons.");
	
	AutoExecConfig(true,"l4d2_another_unscrambler");
	g_Permissions          = cvar_permissions.IntValue;
	g_TeambalancingEnabled = GetConVarBool(FindConVar("l4d2_aus_teambalancing"));	

	g_arrPlStorage = new ArrayList(sizeof(s_STORED_PLAYER));

	RegAdminCmd("sm_aus_switchpl",AdmCommand_SwitchPlayer,ADMFLAG_GENERIC|ADMFLAG_RESERVATION,"Switches a chosen player to another team");	
	RegAdminCmd("sm_aus_swapl",AdmCommand_SwapPlayers,ADMFLAG_GENERIC|ADMFLAG_RESERVATION,"Swaps two players");
	
	HookConVarChange(FindConVar("mp_gamemode"),ConVar_GamemodeChanged);
}

public void ConVar_GamemodeChanged (Handle convar, const char[] oldValue, char[] newValue)
{
	int entInfo = CreateEntityByName("info_gamemode");
	DispatchSpawn(entInfo);
	HookSingleEntityOutput(entInfo,"OnSurvival",Hook_CheckGameMode,true);
	HookSingleEntityOutput(entInfo,"OnVersus",Hook_CheckGameMode,false);
	HookSingleEntityOutput(entInfo,"OnCoop",Hook_CheckGameMode,true);
	HookSingleEntityOutput(entInfo,"OnScavenge",Hook_CheckGameMode,true);
	ActivateEntity(entInfo);
	AcceptEntityInput(entInfo, "PostSpawnActivate");
	AcceptEntityInput(entInfo,"Kill");
}
public void Hook_CheckGameMode (const char[] output, int caller, int activator, float delay)
{
	char sSuppGameModes[511];
	char sGameMode[32];
	
	GetConVarString(FindConVar("l4d2_aus_gamemodes"),sSuppGameModes,sizeof(sSuppGameModes));
	GetConVarString(FindConVar("mp_gamemode"),sGameMode,sizeof(sGameMode));

	//is gamemode supported by config? Just versus based games are allowed and useful.
	if (((StrEqual(output,"OnVersus") || (StrEqual(output,"OnSurvival") && StrEqual(sGameMode,"mutation15")))
	&&  (strlen(sSuppGameModes) == 0  || view_as<bool>(StrContains(sSuppGameModes,sGameMode,false) > -1))))
	{
		if (g_GameModeEnabled)
			return;

		g_GameModeEnabled = true;	
		g_GameStatus = 0;
		
		Unscrambler_Init();
		g_arrPlStorage.Clear();
		
		//init player stuff. Gamemode was changed while players already on server?
		for (int i = 1;i <= MaxClients;i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i))
			{
				g_Players[i].iTeam   	  = GetClientTeam(i);
				g_Players[i].iUserId 	  = GetClientUserId(i);
				g_Players[i].bPollAllowed = true;
			}
			else
			{
				g_Players[i].iTeam        = L4D_TEAM_UNASSIGNED;
				g_Players[i].iUserId 	  = 0;
				g_Players[i].bPollAllowed = false;
			}
			g_Players[i].iTeamchangeAttempts = 0;
			g_bLastTeamOrder				 = L4D_TeamsAreFlipped();
		}
	}
	else
	{
		g_GameModeEnabled       = false;
		cvar_us_status.IntValue = 0;
	}	
	EnableMainMenuItem(g_GameModeEnabled);
	
	static bool bHooksEnabled = false;	
	if (g_GameModeEnabled)
	{		
		if (!bHooksEnabled)
		{			
			HookEvent("player_team",Event_JoiningTeam,EventHookMode_Pre);
			HookEvent("player_disconnect",Event_PlayerDisconnect,EventHookMode_Post);	
			HookEvent("round_start", Events_GameStatus,EventHookMode_Post);
			HookEvent("round_end", Events_GameStatus,EventHookMode_Post);
			HookEvent("game_init",Events_GameStatus,EventHookMode_Post);
			HookEvent("finale_start",Events_GameStatus,EventHookMode_Post);
			HookEvent("versus_round_start",Events_GameStatus,EventHookMode_Post);
			HookEvent("survival_round_start",Events_GameStatus,EventHookMode_Post);	
			
			AddCommandListener(Cmd_JoinTeam,"jointeam");	
		
			bHooksEnabled = true;
		}
	}
	else if (bHooksEnabled)
	{	
		UnhookEvent("player_team",Event_JoiningTeam,EventHookMode_Pre);
		UnhookEvent("player_disconnect",Event_PlayerDisconnect,EventHookMode_Post);	
		UnhookEvent("round_start", Events_GameStatus,EventHookMode_Post);
		UnhookEvent("round_end", Events_GameStatus,EventHookMode_Post);
		UnhookEvent("game_init",Events_GameStatus,EventHookMode_Post);
		UnhookEvent("finale_start",Events_GameStatus,EventHookMode_Post);
		UnhookEvent("versus_round_start",Events_GameStatus,EventHookMode_Post);
		UnhookEvent("survival_round_start",Events_GameStatus,EventHookMode_Post);
		
		RemoveCommandListener(Cmd_JoinTeam,"jointeam");
		
		bHooksEnabled = false;
	}
}
static const char SOUND_TEAMCHANGE_DENIED [] = "./ambient/alarms/klaxon1.wav"
public void OnMapStart()
{
	ConVar_GamemodeChanged(INVALID_HANDLE,"",""); //The plugin is newly installed and the hook for chaging the gamemode isn't fired

	if (g_GameModeEnabled)
	{
		PrefetchSound(SOUND_TEAMCHANGE_DENIED);
		PrecacheSound(SOUND_TEAMCHANGE_DENIED);
		cvar_permissions.IntValue = g_Permissions;
	}
}
#define ROUND_END		  	 			          5
#define ROUND_END__RETURN_TO_LOBBY 				  3
#define ROUND_END__VERSUS_SURVIVAL_MATCH_FINISHED 16
public Action Events_GameStatus (Event event, const char[] name, bool dontBroadcast)
{ 	 
	if (StrEqual(name,"round_start"))
    {	
		SetGameStatus(ROUND_STATUS_IN_ROUND,ROUND_STATUS_IN_FINALE|ROUND_STATUS_IN_RUNNING_VERSUS_GAME);
		
		g_hUnscramblerTimer = INVALID_HANDLE;
		if (!CheckGameStatus(ROUND_STATUS_WAITING_FOR_LOBBY_TEAMS))
			Unscrambler_Run();
		else
			CreateTimer(3.0,Timer_Unscrambling,TIMER_FLAG_NO_MAPCHANGE);
		
		SetGameStatus(0,ROUND_STATUS_WAITING_FOR_LOBBY_TEAMS);
    }
	else if (StrEqual(name,"round_end"))
	{     
		int iReason = event.GetInt("reason");
		if (iReason == ROUND_END || iReason == ROUND_END__VERSUS_SURVIVAL_MATCH_FINISHED)
		{			
			SetGameStatus(0,ROUND_STATUS_IN_ROUND|ROUND_STATUS_IN_RUNNING_VERSUS_GAME);	
			
			for (int p = 1;p <= MaxClients;p++)
				g_Players[p].bPollAllowed = view_as<bool>((g_Permissions & PERM_ALLOW_POLLS));
		}
		else if (iReason == ROUND_END__RETURN_TO_LOBBY)
		{
			Unscrambler_Stop();
			g_arrPlStorage.Clear();
		}
	}
	else if (StrEqual(name,"game_init"))
	{
		g_GameStatus = 0;
		Unscrambler_Init();
		g_arrPlStorage.Clear();
	}
	else if (StrEqual(name,"finale_start")) SetGameStatus(ROUND_STATUS_IN_FINALE,0);
	else  //versus_round_start, survival_round_start
	{
		SetGameStatus(ROUND_STATUS_IN_RUNNING_VERSUS_GAME,0);
		
		if (StrEqual(name,"versus_round_start"))
		{
			//We treat these map starts as a finale. Just emulate it here.
			char sMapName[6];
			GetCurrentMap(sMapName,sizeof(sMapName));
		
			if (StrContains(sMapName,"c5m5") == 0 || StrContains(sMapName,"c13m4") == 0)
				HookEntityOutput("trigger_finale","UseStart",Hook_FinaleTriggered);	
		}	
	}
}
//Triggered for the 'finale_start'-event,
public void Hook_FinaleTriggered(const char[] output, int caller, int activator, float delay)
{
	SetGameStatus(ROUND_STATUS_IN_FINALE,0);
	UnhookEntityOutput("trigger_finale","UseStart",Hook_FinaleTriggered);
}
public void OnMapEnd()
{
	Unscrambler_Stop();
	SetGameStatus(0,ROUND_STATUS_IN_ROUND);
}
public void OnClientConnected(int client)
{
	if (!g_GameModeEnabled || CheckGameStatus(ROUND_STATUS_WAITING_FOR_LOBBY_TEAMS))
		return;
		
	int clUserId = GetClientUserId(client);
	if (IsFakeClient(client)) //Bot replaces a regular player
	{
		if (g_Players[client].iUserId != 0)
		{
			UnloadPlayer(client);
			Unscrambler_IncreaseRages();
		}
		g_Players[client].iUserId = 0;
		return;
	}
		
	if (g_Players[client].iTeam == L4D_TEAM_UNASSIGNED)
	{	
		//To lobby connect: Wait until these players have been switched to the right team by engine. Every other connectors are treated as new joining players.
		//Sadly, it works better than user message "AllPlayersConnectedGameStarting" since the game engine could try to change a player (usually from infected to survivors team) after the message and even without success.
		//"player_team" is sent then, but nothing happens. 
		if (TeamArray_GetPlayersCountOfTeam(L4D_TEAM_INFECTED) + TeamArray_GetPlayersCountOfTeam(L4D_TEAM_SURVIVORS) > 0) 
		{
			if (cvar_show_announcement.BoolValue)
			{
				static char stLastIP [16];
				char sIP[16];
				GetClientIP(client,sIP,sizeof(sIP));
				
				if (strcmp(sIP,stLastIP) != 0) //Ignore the info when a player with the last same ip is retrying and retrying to connect
				{
					CPrintToChatAll ("%s %t",MSG_TAG,"NewPlayerIsConnecting",client);
					stLastIP = sIP;
				}
			}
		}
		else
			g_Players[client].iTeam = L4D_TEAM_LOBBY_CONNECT;
	}
	
	if 		(g_Players[client].iUserId == 0)
			 g_Players[client].iUserId  = clUserId;
	else if (g_Players[client].iUserId != clUserId) //a player left the server (during mapchanges) and a new one connected and got the same client Id
	{
		Unscrambler_IncreaseRages();
		UnloadPlayer(client);
		g_Players[client].iUserId = clUserId;
	}	
	g_Players[client].bPollAllowed 		  = true;
	g_Players[client].iTeamchangeAttempts = 0;
}
public Action Event_JoiningTeam (Event event, const char[] name, bool dontBroadcast)
{
	if (!g_GameModeEnabled)
		return Plugin_Continue;
	
	int NewPlayerUserId	  = event.GetInt("userid");
	int NewPlayerClientId = GetClientOfUserId (NewPlayerUserId);
	if (NewPlayerClientId == 0 || IsFakeClient (NewPlayerClientId) || !IsClientInGame (NewPlayerClientId))
		return Plugin_Continue;
		
	 //ignore spectator mode
	int NewTeamId  = event.GetInt("team");
	if (NewTeamId != L4D_TEAM_INFECTED
	&&  NewTeamId != L4D_TEAM_SURVIVORS) 
		return Plugin_Continue;
		
	int iTeam = NewTeamId;
	if (g_Players[NewPlayerClientId].iTeam == L4D_TEAM_UNASSIGNED)
	{	
		int iBalancingType = 0;		

		s_STORED_PLAYER s_StoredPl;		
		GetClientAuthId(NewPlayerClientId,AuthId_Steam3,s_StoredPl.sSteamID3,STEAM_ID3_LEN);
		
		//Do we remember the player and their latest team?
		if (!Storage_FetchPlayer(s_StoredPl))
		{			
			if(g_TeambalancingEnabled)
			{
				iBalancingType = 1;
				int InfectedPlCnt = TeamArray_GetPlayersCountOfTeam(L4D_TEAM_INFECTED);
				int SurvivorPlCnt = TeamArray_GetPlayersCountOfTeam(L4D_TEAM_SURVIVORS);
				
				if 		(SurvivorPlCnt  < InfectedPlCnt)  iTeam = L4D_TEAM_SURVIVORS;
				else if (InfectedPlCnt == SurvivorPlCnt) //Player count is equal? Try to move the player to the losing team by campaign scores.
				{	
					int DisTeam = L4D_Teams_GetDisadvantaged();
					if (DisTeam > 0 
					&&  DisTeam != NewTeamId)
					{
						iTeam          = DisTeam;
						iBalancingType = 2;
					}		
				}
				else 
					iTeam = L4D_TEAM_INFECTED;	
			}
			else 
			{
				if (TeamArray_IsFull(iTeam)) //Team is full, so don't let the new player in that team while other players are still loading.
					iTeam = (iTeam == L4D_TEAM_INFECTED ? L4D_TEAM_SURVIVORS : L4D_TEAM_INFECTED);	
			}
		}
		else //Was on server and the player had a crash, an unwantend disconnect (no steam logon or high ping). The game could run imba, but do you want to play with a different team after a crash?
		{		
			iTeam = L4D_Teams_InternalToCurrentId(s_StoredPl.iLastTeam);				
			if (TeamArray_IsFull(iTeam)) //sad but true : the team is alreay full
				iTeam = (iTeam == L4D_TEAM_SURVIVORS ? L4D_TEAM_INFECTED : L4D_TEAM_SURVIVORS);
			else
				CPrintToChatAllEx(NewPlayerClientId,"%s%t",MSG_TAG,"PlayerWasSwitched",NewPlayerClientId);	
		}
			
		g_Players[NewPlayerClientId].iTeam = iTeam;		
		if (NewTeamId != iTeam && g_hUnscramblerTimer == INVALID_HANDLE) //The unscrambler doesn't run and the new player should come into another team. Don't try to do this inside the event.It CAN have unwanted side effects.
		{			
			DataPack dpTimerData;				
			CreateDataTimer(0.1,Timer_DeferredTeamChange,dpTimerData,TIMER_FLAG_NO_MAPCHANGE);
			dpTimerData.WriteCell(NewPlayerUserId);
			dpTimerData.WriteCell(iTeam);
			dpTimerData.WriteCell(iBalancingType);				
			return Plugin_Handled;
		}			
		//Nothing to change, just the info a player joined a team
		char sNewTeamName[32];
		GetTeamName(iTeam,sNewTeamName,sizeof(sNewTeamName));	
		CPrintToChatAllEx(NewPlayerClientId,"%s%t",MSG_TAG,"PlayerJoinedTeam",NewPlayerClientId,sNewTeamName);
	}
	else if (g_Players[NewPlayerClientId].iTeam == L4D_TEAM_LOBBY_CONNECT)
	{
		g_Players[NewPlayerClientId].iTeam = iTeam; //save only the new team id. No teambalancing has to made.		
	}
	else 
		return Plugin_Continue;
		
	g_LatelyJoined[iTeam] = NewPlayerClientId;		
	CreateTimer(0.3,Timer_ExecutePlayerCommands,NewPlayerUserId,TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}
//Do the teamchange outside the event. It seems safer.
public Action Timer_DeferredTeamChange (Handle timer, DataPack dpData)
{	
	dpData.Reset();
	int PlayerUserId = dpData.ReadCell();
		
	int PlayerClientId = GetClientOfUserId(PlayerUserId);	
	if (PlayerClientId == 0 || !IsClientInGame(PlayerClientId))
		return Plugin_Stop;
		
	int TeamId = dpData.ReadCell();
	if (!SwitchPlayerToTeam(PlayerClientId,TeamId))
		return Plugin_Stop;		
	
	char sTeamName [32];
	GetTeamName(TeamId,sTeamName,sizeof(sTeamName));
	
	//Show the reason
	int 	 iBalanceType = dpData.ReadCell();
	if 		(iBalanceType == 1)	CPrintToChatAllEx(PlayerClientId,"%s%t",MSG_TAG,"Teambalancer_TeamWithLessPlayers",PlayerClientId,sTeamName); //a team have less players
	else if	(iBalanceType == 2)	CPrintToChatAllEx(PlayerClientId,"%s%t",MSG_TAG,"Teambalancer_TeamsAreEqual",PlayerClientId,sTeamName); 	  //change to the disadvantaged team

	g_LatelyJoined[TeamId] = PlayerClientId;
	
	//Executes player commands - if set in config
	CreateTimer(0.3,Timer_ExecutePlayerCommands,PlayerUserId,TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Stop;
}
public Action Event_PlayerDisconnect (Event event, const char[] name, bool dontBroadcast)
{	
	int userId = event.GetInt("userid");	
	s_STORED_PLAYER s_StoredPl;
	//Compare with user id. GetClientOfUserId() doesn't work often and returns 0. Seems like a race condition.
	for (int i = 1;i <= MaxClients;i++)
	{
		if (g_Players[i].iUserId == userId)
		{
			if (IsClientAuthorized(i))
			{
				GetClientAuthId(i,AuthId_Steam3,s_StoredPl.sSteamID3,STEAM_ID3_LEN);		

				char sReason[32],sReasonFilter[512];
				event.GetString("reason",sReason,sizeof(sReason),"");			
				sReason[strlen(sReason)-1] = '\0'; //Remove the last point which is usually added by engine. Makes the comparing much easier.
				
				cvar_storage_filter.GetString(sReasonFilter,sizeof(sReasonFilter));	
				if (strlen(sReasonFilter) == 0
				||  StrContains(sReasonFilter,sReason,false) > -1) 
				{				
					s_StoredPl.iDuration = GetTime() + cvar_storage_time.IntValue*60;
					s_StoredPl.iLastTeam = L4D_Teams_GetInternalId(g_Players[i].iTeam);					
					g_arrPlStorage.PushArray(s_StoredPl);
				}
			}
			UnloadPlayer(i);
			break;
		}
	}
}
void UnloadPlayer(int clientId)
{
	if 		(g_Players[clientId].iTeam == L4D_TEAM_INFECTED  && g_LatelyJoined[L4D_TEAM_INFECTED]  == clientId) g_LatelyJoined[L4D_TEAM_INFECTED]  = 0;
	else if (g_Players[clientId].iTeam == L4D_TEAM_SURVIVORS && g_LatelyJoined[L4D_TEAM_SURVIVORS] == clientId) g_LatelyJoined[L4D_TEAM_SURVIVORS] = 0;
		
	g_Players[clientId].iUserId				= 0;
	g_Players[clientId].iTeam  				= L4D_TEAM_UNASSIGNED; 
	g_Players[clientId].iTeamchangeAttempts = 0;
	g_Players[clientId].bPollAllowed		= false;
}
//Check team changing rules
public Action Cmd_JoinTeam (int client, const char[] command, int argc) 
{  	
	if (!g_GameModeEnabled || IsFakeClient(client))
		return Plugin_Continue;	
		
	if (!CheckGameStatus(ROUND_STATUS_IN_ROUND))
		return Plugin_Stop;	
		
	int iTargetTeam;
	char sNewTeam [32];
	GetCmdArg(1,sNewTeam,sizeof(sNewTeam));
	
	if ((iTargetTeam = CmdArg_GetTeamId(sNewTeam)) == 0)
		return Plugin_Stop;
	
	int iCurTeam =  GetClientTeam(client);	
	if (iCurTeam == iTargetTeam) //Already in the right team? Nothing to do
		return Plugin_Continue;
		
	//Team switching is not allowed as long as the unscrambler is working. It looks safer.
	if (cvar_us_status.IntValue > 0)
	{
		ShowBlockMessage(client,"TeamChangeDenied_UnscramblingProcess");
		return Plugin_Stop;
	}
	//Prevent team changes when the server would shutdown then. Trolls know what i'm meaning.
	if (iCurTeam != L4D_TEAM_SPECTATOR && !GetConVarBool(FindConVar("sb_all_bot_game")) && TeamArray_GetPlayersCountOfTeam(iCurTeam) == 1)
	{
		ShowBlockMessage(client,"TeamChangeDenied_ServerShutdown");
		return Plugin_Stop;
	}
	
	//Admins is it always allowed to change the team
	if (GetUserFlagBits(client) == 0)
	{
		if (g_Permissions & PERM_BLOCK_TEAM_SWITCHING) //Teams are locked. Just switchable by admin.         
		{
			ShowBlockMessage(client,"TeamChangeDenied_TeamsLocked");
			return Plugin_Stop;	 	
		}
		else if ((g_Permissions & PERM_BLOCKED_DURING_FINALES) && CheckGameStatus(ROUND_STATUS_IN_FINALE)) //Team switching is not allowed during a finale of a campaign. The finale must begun.
		{
			ShowBlockMessage(client,"TeamChangeDenied_Finale");
			return Plugin_Stop;
		}
		else 
		{			
			if (TeamArray_IsFull(iTargetTeam))
			{
				ShowBlockMessage(client,"TeamChangeDenied_TeamIsFull");
				StartSwapPoll(client);					
				return Plugin_Stop;
			}
			else if (g_Permissions & PERM_BLOCKED_TWO_PL_DIFF) //just means that teams should be balanced by +- 1 player. You cannot play 4 vs 2 or 4 vs 1 in that case. Players who want to change to the winning team have to wait for more players.
			{
				int InfPlayers  = TeamArray_GetPlayersCountOfTeam(L4D_TEAM_INFECTED);
				int SurvPlayers = TeamArray_GetPlayersCountOfTeam(L4D_TEAM_SURVIVORS);		
				int iPlDiff		= SurvPlayers > InfPlayers ? SurvPlayers - InfPlayers : InfPlayers - SurvPlayers;
				if (iPlDiff <= 1)
				{
					//A player from the winning team could switch to the losing team. But still: Difference is 1 player.
					if (iPlDiff == 1 && g_Permissions & PERM_ALLOW_WINNING_TO_LOSING_TEAM_DIFF_1
					&&  L4D_Teams_GetDisadvantaged() == iTargetTeam)
						CPrintToChatAllEx(client,"%s%t",MSG_TAG,"TeamChangeAllowed_ToLosingTeam",client);
					else
					{		
						ShowBlockMessage(client,"TeamChangeDenied_DiffTwo",SurvPlayers,InfPlayers);
						
						if (g_Permissions & PERM_ALLOW_POLLS && g_Permissions & ~PERM_POLLS_ALLOWED_WHEN_TEAM_IS_FULL_ONLY)
							StartSwapPoll(client);

						return Plugin_Stop;
					}
				}
			}
		}
	}
	//send out the information to all players
	if (g_Players[client].iTeam != iTargetTeam)
	{
		g_Players[client].iTeam = iTargetTeam;
		CPrintToChatAllEx(client,"%s%t",MSG_TAG,"PlayerJoinedTeam",client,sNewTeam);
	}
	return Plugin_Continue;
}
//Shows a message to the player who wants to change the team.
void ShowBlockMessage(int clientId, any ...)
{
	char sBlockMsg[128];
	SetGlobalTransTarget(clientId);
	VFormat(sBlockMsg,sizeof(sBlockMsg),"%t",2);
	CPrintToChat(clientId,"%s{olive}%s",MSG_TAG,sBlockMsg);

	if (g_Players[clientId].iTeamchangeAttempts < cvar_change_team_adm_info_count.IntValue)
	{		
		g_Players[clientId].iTeamchangeAttempts++;
		for (int a = 1;a <= MaxClients;a++)
		{
			if (IsClientInGame(a) && !IsFakeClient(a) && GetUserFlagBits(a) > 0)
			{		
				SetGlobalTransTarget(a);
				VFormat(sBlockMsg,sizeof(sBlockMsg),"%t",2);			
				CPrintToChatEx(a,clientId,"%s%t",MSG_TAG_ADM,"Info_TeamChangeBlocked",clientId,sBlockMsg);			
			}
		}
	}
	else //didn't read that? Happens often. Write it to the center screen + aweful sound and don't bother the admins again
	{
		PrintHintText(clientId,sBlockMsg);
		EmitSoundToClient(clientId,SOUND_TEAMCHANGE_DENIED);
	}
}
public Action AdmCommand_SwapPlayers (int client, int args)
{
	if (!g_GameModeEnabled)
		return Plugin_Handled;
		
	int iPlIOneId = CmdArg_TargetPlayer(1);	
	int iPlTwoId  = CmdArg_TargetPlayer(2);
	if (iPlTwoId > 0 && iPlIOneId > 0)
	{
		char sErr[64];
		if (!PerfomSwap(GetUserAdmin(client),iPlIOneId,iPlTwoId,sErr))
		{
			CFormat(sErr, sizeof(sErr));
			ReplyToCommand(client,"%t",sErr);			
		}
		return Plugin_Handled;
	}
	ReplyToCommand(client,"%t","No matching clients");
	return Plugin_Handled;
}

public Action AdmCommand_SwitchPlayer (int client, int args)
{
	if (!g_GameModeEnabled)
		return Plugin_Handled;
		
	int iTargetPlId = CmdArg_TargetPlayer(1);	
	if (iTargetPlId > 0)
	{
		char sTeamId[32];
		GetCmdArg(2,sTeamId,sizeof(sTeamId));
		
		int iTeamId;
		if ((iTeamId = CmdArg_GetTeamId(sTeamId)) > 0)
		{		
			char sErr[64];
			if (!PerformSwitch(client,iTargetPlId,iTeamId,sErr))
			{
				CFormat(sErr, sizeof(sErr));
				ReplyToCommand(client,"%t",sErr);
			}
			return Plugin_Handled;
		}
	}
	ReplyToCommand(client,"%t","No matching clients");
	return Plugin_Handled;
}
//Look for the right team id by name
int CmdArg_GetTeamId (char sTeamParam[32])
{
	int iTeamID = 0;
	int iTeamCount = GetTeamCount ();	
	if (strlen(sTeamParam) > 1)
	{
	    //Looking for Team ID
	    char sTeamName [32];
	    for (int i = 0;i < iTeamCount;i++)
		{
			GetTeamName(i,sTeamName,sizeof(sTeamName));
			if (StrEqual(sTeamName,sTeamParam,false))
			{
				iTeamID = i;
				sTeamParam = sTeamName;
				break;
			}
		}
	}
	else
	{
		iTeamID = StringToInt(sTeamParam);
		GetTeamName(iTeamID,sTeamParam,sizeof(sTeamParam));
	}
	
	if ((iTeamID+1) > iTeamCount)
		return 0;
		
	return iTeamID;
}
int CmdArg_TargetPlayer(int iArgNr)
{
	char sTargetPlArg[MAX_NAME_LENGTH+2];
	
	int iArgLen = GetCmdArg(iArgNr,sTargetPlArg,sizeof(sTargetPlArg));
	if (iArgLen == 0)
		return 0;
	
	bool bIsNumeric = true; //Is the entire string numeric?	
	for (int i = 0;i < iArgLen;i++)
	{
		if (!IsCharNumeric(sTargetPlArg[i]))
		{
			bIsNumeric = false;
			break;
		}	
	}
	
	if (bIsNumeric)
	{	
		int TargetId = StringToInt(sTargetPlArg);
		if (TargetId > MaxClients) //If it's above MaxClients it might be an user id - which is preferable cause it is the safest method
			TargetId = GetClientOfUserId(TargetId);
		
		if (TargetId > 0 && IsClientInGame(TargetId)) 
			return TargetId; //Otherwise the numeric string is part of a player name
	}
	
	char sClientName[MAX_NAME_LENGTH+1];
	for (int p = 1;p <= MaxClients;p++)
	{
		if (IsClientInGame(p) && !IsFakeClient(p))
		{
			GetClientName(p,sClientName,sizeof(sClientName));
			if (StrEqual(sTargetPlArg,sClientName))
				return p;				
		}				
	}		
	return 0;
}
#define EXE_CMDLIST_SERVER		 0
#define EXE_CMDLIST_TO_PUBLIC	 1
#define EXE_CMDLIST_TO_ADMINS	 2
#define EXE_CMDLIST_TO_SURVIVORS 3
#define EXE_CMDLIST_TO_INFECTED	 4

#define MAX_CMDLIST_COMMANDS 8
public Action Timer_ExecutePlayerCommands (Handle timer, int NewPlayerId)
{	
	char sConVar [64];
	char sCommand[64*MAX_CMDLIST_COMMANDS+MAX_CMDLIST_COMMANDS];
	char sExCmds[MAX_CMDLIST_COMMANDS][64]

	for (int i = view_as<int>(EXE_CMDLIST_SERVER);i <= view_as<int>(EXE_CMDLIST_TO_INFECTED);i++)
	{	
		Format(sConVar,sizeof(sConVar),"l4d2_aus_newpl_execmdlist%d",i);		
		GetConVarString(FindConVar(sConVar),sCommand,sizeof(sCommand));
		
		if (sCommand[0] != '\0')
		{
			int nCommands = ExplodeString(sCommand,";",sExCmds,MAX_CMDLIST_COMMANDS,64); //commands are seperated by ';'			
			for (int c = 0;c < nCommands;c++)
			{			
				if (i != EXE_CMDLIST_SERVER)
				{
					//Show admins the data from playercommands plugin
					for (int p = 1;p <= MaxClients;p++)
					{
						if (IsClientInGame(p) && !IsFakeClient(p))
						{
							switch (i)
							{
								case EXE_CMDLIST_TO_PUBLIC:
								{
									FakeClientCommand(p,sExCmds[c],NewPlayerId); 
								}
								case EXE_CMDLIST_TO_ADMINS: 
								{ 
									if (GetUserFlagBits(p) > 0)
										FakeClientCommand(p,sExCmds[c],NewPlayerId);
								}
								case EXE_CMDLIST_TO_SURVIVORS: 
								{
									if (GetClientTeam(p) == L4D_TEAM_SURVIVORS)
										FakeClientCommand(p,sExCmds[c],NewPlayerId);
								}
								case EXE_CMDLIST_TO_INFECTED: 
								{
									if (GetClientTeam(p) == L4D_TEAM_INFECTED)
										FakeClientCommand(p,sExCmds[c],NewPlayerId);										
								}
							}				
								
						}
					}
				}
				else
					ServerCommand (sExCmds[c],NewPlayerId);
			}
		}
	}
}
bool Storage_FetchPlayer (s_STORED_PLAYER s_Player)
{
	s_STORED_PLAYER s_StoredPl;	
	for (int i = 0;i < g_arrPlStorage.Length;i++)
	{		
		g_arrPlStorage.GetArray(i,s_StoredPl,sizeof(s_STORED_PLAYER));		
		if (s_StoredPl.iDuration > GetTime())
		{
			if (StrEqual(s_StoredPl.sSteamID3,s_Player.sSteamID3))
			{
				g_arrPlStorage.GetArray(i,s_Player,sizeof(s_STORED_PLAYER));
				g_arrPlStorage.Erase(i);				
				return true;
			}			
		}
		else //clean up in a row
		{
			g_arrPlStorage.Erase(i);
			i--;
		}
	}
	return false;
}

//Unscrambler Fx
void Unscrambler_Init()
{
	g_hUnscramblerTimer 	= INVALID_HANDLE;
	g_bLastTeamOrder 		= false;	
	cvar_us_status.IntValue = 0;
}
void Unscrambler_ChangeCVars (bool bEnable)
{
	static stStoredOldValues[3] = {-1,-1,-1};	
	if (bEnable)
	{
		stStoredOldValues[0] = SetConVariable("sv_hibernate_when_empty",0,bEnable);	
		stStoredOldValues[1] = SetConVariable("sv_hibernate_postgame_delay",999,bEnable);
		stStoredOldValues[2] = SetConVariable("sb_all_bot_game",1,bEnable);
	}
	else if (stStoredOldValues[0] > -1) //reset values
	{	
		SetConVariable("sv_hibernate_when_empty",stStoredOldValues[0],bEnable);	
		SetConVariable("sv_hibernate_postgame_delay",stStoredOldValues[1],bEnable);
		SetConVariable("sb_all_bot_game",stStoredOldValues[2],bEnable);
		stStoredOldValues[0] = -1;
	}
}
//Sets a new value and returns the old one
int SetConVariable(const char[] sConVar, int Val, bool bSet)
{
	Handle hConVar = FindConVar(sConVar);	
	if (hConVar == INVALID_HANDLE)
		return -1;
		
	int ReturnVal = -1;
	if (bSet)
	{
		ReturnVal = GetConVarInt(hConVar);
		SetConVarInt(hConVar,Val);
	}
	else
	{
		if (Val != -1)
			SetConVarInt(hConVar,Val);
		else		
			ResetConVar(hConVar);
	}
	return ReturnVal;
}
//Since we store the player in the spectator team.
bool Unscrambler_ChangeTeam (int clientId, int ToTeam)
{
	if (SwitchPlayerToTeam(clientId,ToTeam))
	{
		if (ToTeam != L4D_TEAM_SPECTATOR)
			CPrintToChatAllEx(clientId,"%s%t",MSG_TAG,"PlayerWasSwitched",clientId);	
		
		return true;
	}
	return false;	
}
//Happens during map changes
int Unscrambler_IncreaseRages(bool bResetStats = false)
{	
	static int nRages = 0;
	return (bResetStats ? (nRages = 0) : nRages++);
}
//starts the unscrambling process
void Unscrambler_Run()
{	
	//Looks like very first map / lobby-connection 
	if (TeamArray_GetPlayersCountOfTeam(L4D_TEAM_INFECTED) + TeamArray_GetPlayersCountOfTeam(L4D_TEAM_SURVIVORS) == 0)
		return;
	
	Unscrambler_Stop();
	
	if (L4D_IsFirstRound())
	{
		Unscrambler_IncreaseRages(true);
		Unscrambler_ChangeCVars(true);
		
		DataPack dpTimerData;
		g_hUnscramblerTimer = CreateDataTimer(3.0,Timer_Unscrambling,dpTimerData,TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		dpTimerData.WriteCell(0);

		int CurTime = GetTime();
		int TimeOut = GetConVarInt(FindConVar("l4d2_aus_timeout"));
		
		dpTimerData.WriteCell(CurTime+30); //every player should be connected to the server after 30 seconds
		dpTimerData.WriteCell((TimeOut > 0 ? (CurTime + (TimeOut * 60)) : 0)); //sets a timeout until ALL players MUST be fully loaded into game	
	}
	else
		CreateTimer(0.1,Timer_Unscrambling,TIMER_FLAG_NO_MAPCHANGE);
}
public Action Timer_Unscrambling (Handle timer, DataPack dpTimerData)
{
	//New Round has started and teams are flipped? (the var is often not changed inside the 'round_start' event. Looks like a race condition.)
	bool bTeamsAreFlipped  = L4D_TeamsAreFlipped();	
	if  (bTeamsAreFlipped != g_bLastTeamOrder)
	{
		TeamArray_SwapTeams();
		g_bLastTeamOrder = bTeamsAreFlipped;
	}
		
	if (!CheckGameStatus(ROUND_STATUS_IN_ROUND) || !L4D_IsFirstRound())
	{
		g_hUnscramblerTimer = INVALID_HANDLE;
		return Plugin_Stop;
	}
	//Read the package data
	dpTimerData.Reset();
	int nTicks 				= dpTimerData.ReadCell();
	int CurTime 			= GetTime();
	bool bConnectionTimeout =(dpTimerData.ReadCell() <= CurTime); //A player should be connected to the server after x-seconds after mapchanges (must not be fully loaded into game)
	int TimeoutLimit 	 	= dpTimerData.ReadCell();	  	      //The player is loading too long or is crashed or something else
	
	int nSurvLoading = 0,nInfLoading = 0;	
	for (int i = 1;i <= MaxClients && CheckGameStatus(ROUND_STATUS_IN_ROUND);i++)
	{	  	 		
		if (g_Players[i].iTeam == L4D_TEAM_UNASSIGNED)
			continue;		
	
		if (bConnectionTimeout && (!IsClientConnected(i) || GetClientUserId(i) != g_Players[i].iUserId)) //the player should be connected to server after 30 seconds (default). 
		{
			UnloadPlayer(i);
			Unscrambler_IncreaseRages();
		}
		else if (TimeoutLimit > 0 && TimeoutLimit <= CurTime) //Kick the long loading players
		{	
			bool bIsClientInGame = IsClientInGame(i);			
			if (!bIsClientInGame || GetClientTeam(i) != g_Players[i].iTeam) //Player is in team 'unassigned' for "hours". Happens not often today.
			{		
				UnloadPlayer(i);
				KickClient(i,"%t","Kick_TimeoutReached");
				
				if (bIsClientInGame)
					CPrintToAdminsEx(i,ADMFLAG_ROOT|ADMFLAG_GENERIC,"%s%t",MSG_TAG_ADM,"Info_Timeout",i);
			}
		}
		else //players who were in a team before / on last map
		{
			bool bInRightTeam = false;			
			if (IsClientInGame(i)) 
			{	 	
				int CurTeamId  = GetClientTeam(i);			
				if (CurTeamId != g_Players[i].iTeam)
				{				   
					if (CurTeamId != L4D_TEAM_UNASSIGNED) //don't try to move unassigned (loading) players
					{						
						if 		(!IsTeamFull(g_Players[i].iTeam)) bInRightTeam = Unscrambler_ChangeTeam(i,g_Players[i].iTeam); //target team is not full?
						else if (CurTeamId != L4D_TEAM_SPECTATOR) Unscrambler_ChangeTeam(i,L4D_TEAM_SPECTATOR);           //set player to spectator team and wait for the next iteration
					}
				}
				else //right team
					bInRightTeam = true;
			}
			
			if (!bInRightTeam)
			{
				//ignore spectators
				if 		(g_Players[i].iTeam == L4D_TEAM_SURVIVORS) nSurvLoading++;
				else if (g_Players[i].iTeam == L4D_TEAM_INFECTED)  nInfLoading++; 
			}
		}		
	}
	
	int playersloading = nSurvLoading + nInfLoading;	
	//Update cvar to nCount of loading players
	cvar_us_status.IntValue = playersloading;
	
	if (playersloading == 0 || !CheckGameStatus(ROUND_STATUS_IN_ROUND)) //All known players have been loaded
	{
		//Restore CVars
		Unscrambler_ChangeCVars(false);				
		CPrintToChatAll ("%s%t",MSG_TAG,"Info_AllPlayersLoaded"); 
		
		int nRages = Unscrambler_IncreaseRages();
		if (nRages > 0)
			CPrintToChatAll ("%s%t",MSG_TAG,"RagesDuringMapchange",nRages);
		
		g_hUnscramblerTimer = INVALID_HANDLE;
		return Plugin_Stop;		
	}
	else //Update Status 
	{
		int TickCount = cvar_tick_count_info.IntValue;
		if (TickCount == ++nTicks)
		{
			//Info for all admins. The long loading player will be kicked in x-seconds. Happens not often today.
			int LastSeconds = TimeoutLimit-GetTime ();			
			if (LastSeconds > 0 && LastSeconds <= TickCount)
				CPrintToAdmins(ADMFLAG_ROOT|ADMFLAG_GENERIC,"%s%t",MSG_TAG,"KickLoadingTooLong",LastSeconds);
						
			CPrintToChatAll("%s %t",MSG_TAG,"Info_PlayersLoading",nSurvLoading,nInfLoading);			
			nTicks = 0;
		}
		//update nTicks
		dpTimerData.Reset();
		dpTimerData.WriteCell(nTicks);
	}
	return Plugin_Continue;
}
void Unscrambler_Stop()
{	
	if (g_hUnscramblerTimer != INVALID_HANDLE)
	{
		KillTimer(g_hUnscramblerTimer);
		g_hUnscramblerTimer = INVALID_HANDLE;
	}
	Unscrambler_ChangeCVars(false);
}
//Menu stuff
void EnableMainMenuItem (bool bEnable) //is just avaiable with supported game types / versus games.
{          
	Handle hTopMenu;
	if (!LibraryExists("adminmenu") || ((hTopMenu = GetAdminTopMenu()) == INVALID_HANDLE))
		return;
		
	static TopMenuObject hAU_MenuItem = INVALID_TOPMENUOBJECT;	
	if (bEnable)
	{
		if (hAU_MenuItem == INVALID_TOPMENUOBJECT)
		{
			TopMenuObject hTopMenuCat = FindTopMenuCategory(hTopMenu, ADMINMENU_PLAYERCOMMANDS);	
			if (hTopMenuCat != INVALID_TOPMENUOBJECT)
				hAU_MenuItem = AddToTopMenu(hTopMenu,"AUS_AnotherUnscrambler",TopMenuObject_Item,AdminMenu_Handler,hTopMenuCat,"",ADMFLAG_GENERIC|ADMFLAG_ROOT);
		}
	}
	else if (hAU_MenuItem != INVALID_TOPMENUOBJECT) 
	{
		RemoveFromTopMenu(hTopMenu,hAU_MenuItem);
		hAU_MenuItem = INVALID_TOPMENUOBJECT;
	}
}
public int AdminMenu_Handler (Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayTitle
	||  action == TopMenuAction_DisplayOption)
	{
		strcopy(buffer,maxlength,PLUGIN_NAME);		
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayPluginMainMenu(param);
	}
	else if (action == TopMenuAction_RemoveObject && param > 0 && IsClientInGame(param))
	{
		DisplayTopMenu (GetAdminTopMenu(), param, TopMenuPosition_LastCategory); 
	}
	return 0;
}
enum e_MENU_PLAYER_ACTIONS
{
	MENUPL_ACTION_SWITCH_PL  = 1,
	MENUPL_ACTION_SWAP_PL,
	MENUPL_ACTION_SWITCH_TO,
	MENUPL_ACTION_CHOOSE_TEAM
}
void DisplayPluginMainMenu (int clientid)
{
	Menu MainMenu = new Menu(MainMenu_Handler,MENU_ACTIONS_ALL);	
	MainMenu.SetTitle(PLUGIN_NAME);
	MainMenu.ExitBackButton = true;
	MainMenu.AddItem("MainMenu_SwitchTo",""); 
		
	if (TeamArray_GetPlayersCountOfTeam(L4D_TEAM_INFECTED) + TeamArray_GetPlayersCountOfTeam(L4D_TEAM_SURVIVORS) + TeamArray_GetPlayersCountOfTeam(L4D_TEAM_SPECTATOR) > 1)
		MainMenu.AddItem("MainMenu_SwapWith","");
	
	MainMenu.AddItem("MainMenu_ChangeTeamPermissions","");	

	if (g_arrPlStorage.Length > 0)
		MainMenu.AddItem("MainMenu_StoredPlayers","");	

	MainMenu.Display(clientid,MENU_TIME_FOREVER);
}

public int MainMenu_Handler (Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		
		if 		(StrEqual(sInfo,"MainMenu_SwitchTo"))			   Menu_DisplayPlayers(param1,MENUPL_ACTION_SWITCH_TO,""); 
		else if (StrEqual(sInfo,"MainMenu_SwapWith"))			   Menu_DisplayPlayers(param1,MENUPL_ACTION_SWITCH_PL,"");
		else if (StrEqual(sInfo,"MainMenu_ChangeTeamPermissions")) MainMenu_DisplayPermissions(param1);
		else if (StrEqual(sInfo,"MainMenu_StoredPlayers"))
		{
			g_arrPlStorage.Clear();
			DisplayPluginMainMenu(param1);		
		}
	}
	else if (action == MenuAction_DisplayItem)
	{
		char sTransStr[32], sBuffer [255];
		menu.GetItem(param2,sTransStr,sizeof(sTransStr));

		if (StrEqual(sTransStr,"MainMenu_StoredPlayers"))
			Format(sBuffer, sizeof(sBuffer), "%T", sTransStr, param1, g_arrPlStorage.Length);
		else
			Format(sBuffer, sizeof(sBuffer), "%T", sTransStr, param1);

		return RedrawMenuItem(sBuffer);
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{		
		if (param2 == MenuCancel_ExitBack)
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory); 
	}
	return 0;
}

void Menu_DisplayTeams (int clientid_Menu, int TargetUserId)
{	
	Menu Menu_Teams = new Menu(MenuHandler_ChooseTeam);
	Menu_Teams.SetTitle("%T :","MenuTitle_ChooseTeamToSwitchTo",clientid_Menu);
	Menu_Teams.ExitBackButton = true;
	
	char sTeamName[32], sInfoStr [16];
	
	int clientId   = GetClientOfUserId(TargetUserId);
	int clientTeam = GetClientTeam(clientId);
	
	//Teams to choose
	for (int i = 3; i >= 1;i--)
 	{		 
		if (i != clientTeam //Filter the team of clientId
		&& !TeamArray_IsFull(i))
		{
			GetTeamName(i,sTeamName,MAX_NAME_LENGTH);			
			Format(sInfoStr,sizeof(sInfoStr),"%d:%d",TargetUserId,i);
			Menu_Teams.AddItem(sInfoStr,sTeamName);//MENU_SUB_CHOOSE_TEAM	
	    }
	}
	Menu_Teams.Display(clientid_Menu,MENU_TIME_FOREVER);
}
public int MenuHandler_ChooseTeam (Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32], sInfoStr[2][12];
		menu.GetItem(param2, info, sizeof(info));
		
		ExplodeString(info,":",sInfoStr,2,12);
		
		char sErr[64];
		if (!PerformSwitch(param1,GetClientOfUserId(StringToInt(sInfoStr[0])), StringToInt(sInfoStr[1]),sErr))
			CPrintToChat(param1,"%s %t",MSG_TAG_ADM,sErr);
			
		DisplayPluginMainMenu(param1);
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{		
		if (param2 == MenuCancel_ExitBack)
			DisplayPluginMainMenu(param1); 
	}
	return 0;
}
void MainMenu_DisplayPermissions (int clientId)
{
	Menu Menu_Perms = new Menu(MenuHandler_ChangePermissions,MENU_ACTIONS_ALL);
	
	Menu_Perms.SetTitle("%T :","MainMenu_ChangeTeamPermissions",clientId);
	Menu_Perms.ExitBackButton = true;	

	Menu_Perms.AddItem("TeamChangeOption_Teambalancing",g_TeambalancingEnabled						? "Menu_OptionEnabled" : "Menu_OptionDisabled");	
	Menu_Perms.AddItem("TeamChangeOption_BlockFinale",  g_Permissions & PERM_BLOCKED_DURING_FINALES	? "Menu_OptionEnabled" : "Menu_OptionDisabled");
		
	if (!(g_Permissions & PERM_BLOCK_TEAM_SWITCHING))
	{
		Menu_Perms.AddItem("TeamChangeOption_TeamsLocked","Menu_OptionDisabled");
		
		if (g_Permissions & PERM_BLOCKED_TWO_PL_DIFF)
		{
			Menu_Perms.AddItem("TeamChangeOption_BlockWithTwo","Menu_OptionEnabled");
			Menu_Perms.AddItem("TeamChangeOption_AllowToLosingTeam",g_Permissions & PERM_ALLOW_WINNING_TO_LOSING_TEAM_DIFF_1 ? "Menu_OptionEnabled" : "Menu_OptionDisabled");		
		}
		else
			Menu_Perms.AddItem("TeamChangeOption_BlockWithTwo","Menu_OptionDisabled");

		if (g_Permissions & PERM_ALLOW_POLLS)
		{
			Menu_Perms.AddItem("TeamChangeOption_Polls","Menu_OptionEnabled");	
			Menu_Perms.AddItem("TeamChangeOption_PollsIfFull", g_Permissions & PERM_POLLS_ALLOWED_WHEN_TEAM_IS_FULL_ONLY              ? "Menu_OptionEnabled" : "Menu_OptionDisabled");
			Menu_Perms.AddItem("TeamChangeOption_PollsJustAtBeginning", g_Permissions & PERM_POLLS_ARE_ALLOWED_AT_THE_BEGINNING_ONLY  ? "Menu_OptionEnabled" : "Menu_OptionDisabled");
		}
		else
			Menu_Perms.AddItem("TeamChangeOption_Polls","Menu_OptionDisabled");	
	}
	else
		Menu_Perms.AddItem("TeamChangeOption_TeamsLocked","Menu_OptionEnabled");
	
	
	Menu_Perms.Display(clientId,MENU_TIME_FOREVER);
}

public int MenuHandler_ChangePermissions (Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char sAction[64];
		menu.GetItem(param2, sAction, sizeof(sAction));
		
		int bResult;

		if 		(StrEqual(sAction,"TeamChangeOption_TeamsLocked")) 	 	 	bResult = TogglePermissionFlag(PERM_BLOCK_TEAM_SWITCHING);
		else if (StrEqual(sAction,"TeamChangeOption_BlockWithTwo")) 		bResult = TogglePermissionFlag(PERM_BLOCKED_TWO_PL_DIFF);
		else if (StrEqual(sAction,"TeamChangeOption_AllowToLosingTeam"))	bResult = TogglePermissionFlag(PERM_ALLOW_WINNING_TO_LOSING_TEAM_DIFF_1);		
		else if (StrEqual(sAction,"TeamChangeOption_BlockFinale")) 		 	bResult = TogglePermissionFlag(PERM_BLOCKED_DURING_FINALES);
		else if (StrEqual(sAction,"TeamChangeOption_Polls")) 			 	bResult = TogglePermissionFlag(PERM_ALLOW_POLLS);	
		else if (StrEqual(sAction,"TeamChangeOption_PollsIfFull")) 	 	 	bResult = TogglePermissionFlag(PERM_POLLS_ALLOWED_WHEN_TEAM_IS_FULL_ONLY);
		else if (StrEqual(sAction,"TeamChangeOption_PollsJustAtBeginning")) bResult = TogglePermissionFlag(PERM_POLLS_ARE_ALLOWED_AT_THE_BEGINNING_ONLY);
		else //TeamChangeOption_Teambalancing
		{
			bResult = g_TeambalancingEnabled = !g_TeambalancingEnabled;			
			SetConVarBool(FindConVar("l4d2_aus_teambalancing"),g_TeambalancingEnabled);			
		}
		
		char sBuff[255];
		Format(sBuff,sizeof(sBuff),"%T",sAction,param1);		
		CPrintToAdmins(ADMFLAG_ROOT|ADMFLAG_GENERIC,"%s%t",MSG_TAG,bResult ? "Info_OptionEnabled" : "Info_OptionDisabled",sBuff);
		
		MainMenu_DisplayPermissions (param1);
	}
	else if (action == MenuAction_DisplayItem)
	{	
		int val = 0;
		char buffer[255],sTransStr[64],sOnOffStr[32];
		menu.GetItem(param2,sTransStr,sizeof(sTransStr),val,sOnOffStr,sizeof(sOnOffStr));
		
		SetGlobalTransTarget(param1);
		Format(buffer, sizeof(buffer),"%t",sTransStr);
		Format(buffer, sizeof(buffer),"%t",sOnOffStr,buffer);		
		return RedrawMenuItem(buffer);
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{		
		if (param2 == MenuCancel_ExitBack)
			DisplayPluginMainMenu(param1); 
	}
	return 0;
}
//Enable / Disable flag and update the convar (sets itself in the hook again)
bool TogglePermissionFlag (int Flag)
{
	bool bAdded = true;	
		
	if (g_Permissions & Flag)
	{
		g_Permissions &= ~Flag;
		bAdded = false;
	}
	else
		g_Permissions |= Flag;
	
	cvar_permissions.IntValue = g_Permissions;	
	return bAdded;
}

bool Menu_DisplayPlayers (int clientId, e_MENU_PLAYER_ACTIONS e_MenuAction, const char[] sParam, int filterid = 0)
{
	char sInfoStr[32];
	char sInsert [MAX_NAME_LENGTH+32];
	
	Menu Menu_Players = new Menu(MenuHandler_ChoosePlayer);
	
	int filterteam = filterid > 0 ? GetClientTeam(filterid) : 0;
	for (int p = 1;p <= MaxClients;p++)
	{
		if (p != filterid && IsClientInGame(p) && !IsFakeClient(p))
		{
			if (p != clientId && GetUserFlagBits(p) > 0) //Skip other admins, they can switch themself.
				continue; 
			
			int playersTeam = GetClientTeam(p);			
			if (playersTeam != filterteam)
			{			
				char sLastPlayerInfo [64];
				if (g_LatelyJoined[playersTeam] == p)
					Format(sLastPlayerInfo,sizeof(sLastPlayerInfo),"%T","MenuText_LatelyPlayer",clientId);				
				else
					sLastPlayerInfo[0] = '\0';
					
				Format(sInsert,sizeof(sInsert),"%N%s",p,sLastPlayerInfo);	
				Format(sInfoStr,sizeof(sInfoStr),"%d:%d:%s",e_MenuAction,GetClientUserId(p),sParam);
				Menu_Players.AddItem(sInfoStr,sInsert);
			}
		}
	}
	
	if (Menu_Players.ItemCount == 0 || (e_MenuAction == MENUPL_ACTION_SWITCH_PL && Menu_Players.ItemCount < 2))
    {	
		delete Menu_Players;
		DisplayPluginMainMenu(clientId);
		return false;
	}
	
	switch (e_MenuAction)
	{	    
	    case MENUPL_ACTION_SWITCH_TO:  { Menu_Players.SetTitle("%T :","MenuTitle_ChoosePlayerToSwitchTo",clientId); }
	    case MENUPL_ACTION_SWITCH_PL:  { Menu_Players.SetTitle("%T :","MenuTitle_SwapPlayer",clientId);             }
		case MENUPL_ACTION_SWAP_PL:    { Menu_Players.SetTitle("%T :","MainMenu_SwapWith",clientId);                }		
	}   	
	Menu_Players.ExitBackButton = true;
	Menu_Players.Display(clientId,MENU_TIME_FOREVER);
	return true;
}
public int MenuHandler_ChoosePlayer (Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char sInfoStr[32];
		menu.GetItem(param2, sInfoStr, sizeof(sInfoStr));	
		
		char sMenuInfo[3][12];
		ExplodeString(sInfoStr,":",sMenuInfo,3,12);
		
		int plUserId = StringToInt(sMenuInfo[1]);		
		int clientId = GetClientOfUserId(plUserId);		
		if (clientId == 0 || !IsClientInGame(clientId))
		{
			DisplayPluginMainMenu(param1);
			CPrintToChat (param1,"%s%t",MSG_TAG,"No matching client");
			return 0;
		}
        
		switch (StringToInt(sMenuInfo[0]))
		{		  	
			case MENUPL_ACTION_SWITCH_TO: 
			{ 
				Menu_DisplayTeams(param1,plUserId);
			}
		    case MENUPL_ACTION_SWITCH_PL:
			{					
				if (!Menu_DisplayPlayers(param1,MENUPL_ACTION_SWAP_PL,sMenuInfo[1],clientId))
				{					
					DisplayPluginMainMenu(param1);
					CPrintToChat (param1,"%s%t",MSG_TAG,"No matching clients");
				}
			}
            case MENUPL_ACTION_SWAP_PL:
			{
				int PlayerOneId = GetClientOfUserId(StringToInt(sMenuInfo[2])); 
				
				char sErr [64];
				if (!PerfomSwap (GetUserAdmin(param1),PlayerOneId,clientId,sErr))
					CPrintToChat(param1,"%s%t",MSG_TAG,sErr);
	
 				DisplayPluginMainMenu(param1);
			}
		}
    }		 
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{		
		if (param2 == MenuCancel_ExitBack)
		{		
			if (GetAdminTopMenu() != INVALID_HANDLE)
				DisplayPluginMainMenu(param1);
		}
	}
	return 0;
}
//Swap Team Polls
bool StartSwapPoll (int client)
{
	if (!(g_Permissions & PERM_ALLOW_POLLS) || g_Players[client].bPollAllowed == false)
		return false;
	
	if ((g_Permissions & PERM_POLLS_ARE_ALLOWED_AT_THE_BEGINNING_ONLY) && CheckGameStatus(ROUND_STATUS_IN_RUNNING_VERSUS_GAME))
		return false;
	
	int CurTeam   	  = GetClientTeam(client);
	int iClientUserId = GetClientUserId(client);
	int TeamToAsk 	  = (CurTeam == L4D_TEAM_SURVIVORS ? L4D_TEAM_INFECTED : L4D_TEAM_SURVIVORS);
	
	for (int p = 1;p < MaxClients;p++)
	{
		if (IsClientInGame(p) && !IsFakeClient(p) && GetUserAdmin(p) == INVALID_ADMIN_ID && GetClientTeam(p) == TeamToAsk)
		{			
			CPrintToChat(client,"%s%t",MSG_TAG,"Poll_Info");
			Menu Menu_Poll = new Menu(MenuHandler_SwapTeam_Poll,MENU_ACTIONS_DEFAULT|MenuAction_DisplayItem);
			Menu_Poll.SetTitle("%T","Poll_Question",p,client,client);
	
			char sNumbers [16];
			Format(sNumbers,sizeof(sNumbers),"%d:%d:%d",iClientUserId,GetClientUserId (p),TeamToAsk);			
			Menu_Poll.AddItem("","No");
			Menu_Poll.AddItem(sNumbers,"Yes");
			Menu_Poll.Display(p,20);
		}
	}
	g_Players[client].bPollAllowed = false;
	return true;
}

public int MenuHandler_SwapTeam_Poll (Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_DisplayItem)
	{
		char buffer[255];
		Format(buffer, sizeof(buffer),"%T",param2 == 0 ? "No" : "Yes",param1);
		return RedrawMenuItem(buffer);
	}	
	else if (action == MenuAction_Select)
	{
		if (param2 == 1) //voted yes
		{
			char sNumbers[16];
			GetMenuItem(menu, param2, sNumbers, sizeof(sNumbers));	
			
			Menu Menu_AreUSure = new Menu(MenuHandler_SwapTeam_Poll_AreYouSure,MENU_ACTIONS_DEFAULT|MenuAction_DisplayItem);
			Menu_AreUSure.SetTitle("%t","Poll_AreYouSure");
			
			Menu_AreUSure.AddItem(sNumbers,"Yes");
			Menu_AreUSure.AddItem("","No");			
			Menu_AreUSure.Display(param1,20);
		}
    }		 
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	return 0;
}
public int MenuHandler_SwapTeam_Poll_AreYouSure (Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_DisplayItem)
	{
		char buffer[255];
		Format(buffer, sizeof(buffer), "%T", param2 == 1 ? "No" : "Yes",param1); //Swap Yes/No
		return RedrawMenuItem(buffer);
	}	
	else if (action == MenuAction_Select)
	{
		if (param2 == 0) //voted yes
		{
			char sNumbers[16];
			menu.GetItem(param2, sNumbers, sizeof(sNumbers));				
			
			char sExplodedStr[3][8];
			ExplodeString(sNumbers,":",sExplodedStr,3,8);
			
			int SourceId = GetClientOfUserId(StringToInt(sExplodedStr[0]));		
			int TargetId = GetClientOfUserId(StringToInt(sExplodedStr[1]));
			
			if (SourceId > 0 && IsClientInGame(SourceId) 
			&&  TargetId > 0 && IsClientInGame(TargetId))
			{	
				int TargetTeam = StringToInt(sExplodedStr[2]);			
				int SourceTeam = GetClientTeam(SourceId);
		
				if (SourceTeam != TargetTeam && GetClientTeam(TargetId) != SourceTeam)
				{				
					//Much safer than in the initial release
					if (ChangeClientTeam (SourceId,L4D_TEAM_SPECTATOR) && ChangeClientTeam(TargetId,L4D_TEAM_SPECTATOR) //needed when both teams are full
					&& 	SwitchPlayerToTeam(SourceId,TargetTeam) 	   && SwitchPlayerToTeam(TargetId,SourceTeam)) 			
					{
						g_Players[SourceId].iTeam = TargetTeam;
						g_Players[TargetId].iTeam = SourceTeam;
						
						CPrintToChatAll("%s%t",MSG_TAG,"Poll_ResultInfo",TargetId,SourceId);
					}
					else //set back if something went wrong
					{
						SwitchPlayerToTeam(SourceId,SourceTeam)
						SwitchPlayerToTeam(TargetId,TargetTeam)
					}
				}
			}
		}
    }		 
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	return 0;
}
//Fx
bool PerformSwitch(int clientId, int clientToSwitch, int ToTeam, char sErr[64]) 
{	
	if 		(ToTeam < L4D_TEAM_SPECTATOR || ToTeam > L4D_TEAM_INFECTED || clientToSwitch == 0 || !IsClientInGame(clientToSwitch))	sErr = "No matching client";
	else if (g_hUnscramblerTimer != INVALID_HANDLE)																					sErr = "Err_UnscramblingProcess";
	else if (ToTeam == GetClientTeam(clientToSwitch))																				sErr = "SwitchErr_AlreayInThatTeam";
	else if (TeamArray_IsFull(ToTeam))																								sErr = "TeamChangeDenied_TeamIsFull";
	else
	{
		if (SwitchPlayerToTeam(clientToSwitch,ToTeam))
		{
			g_Players[clientToSwitch].iTeam = ToTeam;
			
			char sClTeam [32];
			GetTeamName(ToTeam,sClTeam,sizeof(sClTeam));
			
			char sAdmName [64];
			AdminId AdmId = GetUserAdmin(clientId);
			GetAdminUsername(AdmId,sAdmName,sizeof(sAdmName));			
			
			CPrintToAdminsEx(clientToSwitch,ADMFLAG_ROOT|ADMFLAG_GENERIC,"%s%t",MSG_TAG_ADM,"Info_PerformedSwitch",clientToSwitch,sClTeam,sAdmName);		 
			return true;
		}
		else
			sErr = "Err_Any";	
	}
	return false;
}

bool PerfomSwap (AdminId Admin, int IdPlayerOne, int IdPlayerTwo, char sErr[64])
{
	if (IdPlayerOne == 0 || IdPlayerTwo == 0 || !IsClientInGame(IdPlayerOne) || !IsClientInGame(IdPlayerTwo))
	{
		sErr = "No matching client";
		return false;
	}
	else if (IdPlayerOne == IdPlayerTwo)
	{   
		sErr = "SwapErr_SamePlayer";
		return false;
	}	
	else if (g_hUnscramblerTimer != INVALID_HANDLE)
	{
		sErr = "Err_UnscramblingProcess";
		return false;
	} 

	int IdTeamOne = GetClientTeam(IdPlayerOne);
	int IdTeamTwo = GetClientTeam(IdPlayerTwo);
	if (IdTeamOne == IdTeamTwo)
	{	
		sErr = "SwapErr_SameTeam";	
		return false;
	}	
	//to first, change both players to spectator (it should always work)
	ChangeClientTeam(IdPlayerOne,L4D_TEAM_SPECTATOR);
	ChangeClientTeam(IdPlayerTwo,L4D_TEAM_SPECTATOR);	 
	
	//Could be a problem if it doesn't work. The admin has to move the players manually to a team. But never happened in many years.
	if (SwitchPlayerToTeam(IdPlayerOne,IdTeamTwo)
	&&  SwitchPlayerToTeam(IdPlayerTwo,IdTeamOne))
	{ 	  	  
		g_Players[IdPlayerOne].iTeam = IdTeamTwo;
		g_Players[IdPlayerTwo].iTeam = IdTeamOne;
		
		char sAdmName [MAX_NAME_LENGTH+1];
		GetAdminUsername(Admin,sAdmName,sizeof(sAdmName));	
			
		CPrintToAdmins(ADMFLAG_ROOT|ADMFLAG_GENERIC,"%s%t",MSG_TAG,"Info_PerformedSwap",IdPlayerOne,IdPlayerTwo,sAdmName);
		return true;
	}
	else
	{	//Switch back, if needed
		SwitchPlayerToTeam(IdPlayerOne,IdTeamOne)
		SwitchPlayerToTeam(IdPlayerTwo,IdTeamTwo)
		sErr = "Err_Any";
	}	
	return false;
}
bool SwitchPlayerToTeam (int clientToSwitch, int ToTeam)
{
	if (!IsClientInGame(clientToSwitch) || IsFakeClient(clientToSwitch) || GetClientTeam(clientToSwitch) == ToTeam || IsTeamFull(ToTeam))
		return false;
	
	if (ToTeam == L4D_TEAM_SURVIVORS)
	{			 
	 	//Looking for a (living) bot to replace. Otherwise take a dead bot. 
		int BotPlayer = -1;		
	 	for (int i = 1;i <= MaxClients;i++)
	    {
			if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == ToTeam)
			{
				if (IsPlayerAlive(i))
				{
					BotPlayer = i;
					break;
				}
				else
					BotPlayer = i;
			}			
		}		
		if (BotPlayer > -1)
		{
			//Set Human Spec
			SDKCall(g_fSetHumanSpec, BotPlayer, clientToSwitch);			
			// force player to take over bot
			SDKCall(g_fTakeOverBot, clientToSwitch, true);
			return true;
		}
		return false;
	}
	else
		ChangeClientTeam(clientToSwitch,ToTeam);
	
	return true;
}

bool TeamArray_IsFull (int TeamId)
{
	if 		(TeamId == L4D_TEAM_SURVIVORS)	return (TeamArray_GetPlayersCountOfTeam(TeamId) == GetConVarInt(FindConVar("survivor_limit")));
	else if (TeamId == L4D_TEAM_INFECTED)	return (TeamArray_GetPlayersCountOfTeam(TeamId) == GetConVarInt(FindConVar("z_max_player_zombies")));	

	return false;
}
//Gets the count of the stored player ids in the internal array.
int TeamArray_GetPlayersCountOfTeam (int TeamId)
{
	int HumanCount = 0;	
	for (int i = 1;i <= MaxClients;i++)
	{
		if (g_Players[i].iTeam == TeamId)
			HumanCount++;
	}
	return HumanCount;	
}
void TeamArray_SwapTeams ()
{
	for (int i = 1;i <= MaxClients;i++)
	{
		if 		(g_Players[i].iTeam == L4D_TEAM_SURVIVORS) g_Players[i].iTeam = L4D_TEAM_INFECTED;
		else if (g_Players[i].iTeam == L4D_TEAM_INFECTED)	 g_Players[i].iTeam = L4D_TEAM_SURVIVORS;
	}	
}
int GetHumanPlayersCountFromTeam (int TeamId)
{
	int HumanCount = 0;
	for (int i = 1;i <= MaxClients;i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TeamId)
			HumanCount++;
	}
	return HumanCount;	
}
bool IsTeamFull (int TeamId) 
{
	if 		(TeamId == L4D_TEAM_SURVIVORS) return (GetHumanPlayersCountFromTeam(TeamId) == GetConVarInt(FindConVar("survivor_limit")));
	else if (TeamId == L4D_TEAM_INFECTED)  return (GetHumanPlayersCountFromTeam(TeamId) == GetConVarInt(FindConVar("z_max_player_zombies")));	
	
	return false;
}

bool L4D_IsFirstRound()
{
	return !view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound", 4, 0));
}
bool L4D_TeamsAreFlipped()
{
	return view_as<bool>(GameRules_GetProp("m_bAreTeamsFlipped", 4, 0));	
}

#define TEAM_A	1
#define TEAM_B	2

#define ROUND_SCORES    0
#define CAMPAIGN_SCORES 1
int L4D_Teams_GetDisadvantaged()
{
	int TeamSurvivor = L4D_Teams_GetInternalId(L4D_TEAM_SURVIVORS);
	int iSurvScores  = SDKCall(g_fGetTeamScore, TeamSurvivor, CAMPAIGN_SCORES);
	int iInfScores   = SDKCall(g_fGetTeamScore, TeamSurvivor == TEAM_A ? TEAM_B : TEAM_A, CAMPAIGN_SCORES);
	
	if (CheckGameStatus(ROUND_STATUS_IN_RUNNING_VERSUS_GAME) && !L4D_IsFirstRound())
		iSurvScores += SDKCall(g_fGetTeamScore, TeamSurvivor, ROUND_SCORES);

	if (iSurvScores == iInfScores)
		return 0;
		
	return iSurvScores > iInfScores ? L4D_TEAM_INFECTED : L4D_TEAM_SURVIVORS;	
}
int L4D_Teams_GetInternalId (int iTeamId)
{
	if (iTeamId == L4D_TEAM_SPECTATOR)
		return 0;
		
	bool bTeamsFlipped = L4D_TeamsAreFlipped();	
	return iTeamId == L4D_TEAM_SURVIVORS ? (bTeamsFlipped ? TEAM_B : TEAM_A) : (bTeamsFlipped ? TEAM_A : TEAM_B);
}
int L4D_Teams_InternalToCurrentId(int iInternalTeam)
{
	if (iInternalTeam == 0)
		return L4D_TEAM_SPECTATOR;
		
	bool bTeamsFlipped = L4D_TeamsAreFlipped();
	return iInternalTeam == TEAM_A ? (bTeamsFlipped ? L4D_TEAM_INFECTED : L4D_TEAM_SURVIVORS) : (bTeamsFlipped ? L4D_TEAM_SURVIVORS : L4D_TEAM_INFECTED);
}
