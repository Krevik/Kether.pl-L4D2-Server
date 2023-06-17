#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <readyup>
#include <left4dhooks>

public Plugin myinfo =
{
	name = "Readyup_Scav",
	author = "Lechuga",
	description = "fix some bugs and allow to select the number of rounds",
	version = "1.0",
	url = "https://github.com/lechuga16/Readyup_Scav"
};

// Plugin Cvars
ConVar	l4d_ready_scavenge_rounds, cvarGameMode, cvarScavRestart;

public void OnPluginStart()
{
CreateConVar("l4d_ready_scavenge_restart", "1", "Mark the first raund for a double reset.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
l4d_ready_scavenge_rounds	= CreateConVar("l4d_ready_scavenge_rounds", "5", "Set the number of rounds", FCVAR_NOTIFY, true, 1.0, true, 5.0);

cvarScavRestart = FindConVar("l4d_ready_scavenge_restart");
cvarGameMode 	= FindConVar("mp_gamemode");
}

/* Called when the round goes live (Requires Ready Up Plugin)
 * If the Ready Up plugin is available, we use this.
 * It will print boss percents after all players are ready and the round goes live.
*/
public void OnRoundIsLive()
{
	if(ShouldResetRoundTwiceToGoLive())
	{
		PrintHintTextToAll("Match will be live\nafter 2 round restarts.");
		RestartCampaignAny();
	}
}

stock bool IsScavengeMode()
{
	char sGameMode[32];
	GetConVarString(cvarGameMode, sGameMode, sizeof(sGameMode));
	if (StrContains(sGameMode, "scavenge") > -1)
	{
		return true;
	}
	else
	{
		return false;
	}
}

stock int GetScavengeRoundNumber()
{
	return GameRules_GetProp("m_nRoundNumber");
}

bool ShouldResetRoundTwiceToGoLive()
{
	int round = GetScavengeRoundNumber();
	GameRules_SetProp("m_nRoundLimit", l4d_ready_scavenge_rounds.IntValue);
	char ScavRest[10];
	GetConVarString(cvarScavRestart, ScavRest, sizeof(ScavRest));
	if(IsScavengeMode() && StrEqual(ScavRest, "1", true) && round == 1) //scavenge pre-first round warmup
	return true;
	
	//do not reset the round for L4D2 versus or L4D2 scavenge reready
	return false;
}

void RestartCampaignAny()
{
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(LoadGameConfigFile("left4dhooks.l4d2"), SDKConf_Signature, "CTerrorGameRules_ResetRoundNumber");
	Handle func = EndPrepSDKCall();
	if (func == INVALID_HANDLE)
	{
		ThrowError("Failed to end prep sdk call");
	}
	SDKCall(func);
	CloseHandle(func);
	CreateTimer(2.0, RestartCampaignAny1, _);
}

public Action RestartCampaignAny1(Handle timer)
{
	char currentmap[128];
	GetCurrentMap(currentmap, sizeof(currentmap));
	
	Call_StartForward(CreateGlobalForward("OnReadyRoundRestarted", ET_Event));
	Call_Finish();
	
	L4D_RestartScenarioFromVote(currentmap);
	CreateTimer(2.0, RestartCampaignAny2, _);
}

public Action RestartCampaignAny2(Handle timer)
{
	char currentmap[128];
	GetCurrentMap(currentmap, sizeof(currentmap));
	
	Call_StartForward(CreateGlobalForward("OnReadyRoundRestarted", ET_Event));
	Call_Finish();
	
	L4D_RestartScenarioFromVote(currentmap);
	ServerCommand("l4d_ready_scavenge_restart 0");
}