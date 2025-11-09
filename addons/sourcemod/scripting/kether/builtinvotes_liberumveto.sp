#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <builtinvotes>

#define PLUGIN_VERSION "1.0.0"

const int TEAM_SPECTATE = 1;
const int TEAM_SURVIVOR = 2;
const int TEAM_INFECTED = 3;

bool g_bBuiltinVotesAvailable;
bool g_bBuiltinCancelAvailable;
bool g_bBuiltinVotePoolAvailable;
bool g_bGameVoteTeamAvailable;
bool g_bGameVoteStatusAvailable;

public Plugin myinfo =
{
	name		= "Native Votes Liberum Veto",
	author		= "StarterX4 & GPT-5 Codex",
	description = "Allows admins to instantly fail any ongoing vote via sm_liberumveto.",
	version		= PLUGIN_VERSION,
	url			= "kether.pl"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_liberumveto", Command_LiberumVeto, ADMFLAG_GENERIC, "Forces the current vote to fail.");

	HookConVarChange(CreateConVar("sm_liberumveto_version", PLUGIN_VERSION, "NativeVotes Liberum Veto version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD), ConVar_VersionChanged);

	UpdateFeatureAvailability();
}

public void OnAllPluginsLoaded()
{
	UpdateFeatureAvailability();
}

public void OnLibraryAdded(const char[] name)
{
	UpdateFeatureAvailability();
}

public void OnLibraryRemoved(const char[] name)
{
	UpdateFeatureAvailability();
}

public void ConVar_VersionChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	if (!StrEqual(newValue, PLUGIN_VERSION))
	{
		cvar.SetString(PLUGIN_VERSION);
	}
}

Action Command_LiberumVeto(int client, int args)
{
	UpdateFeatureAvailability();

	if (!IsAnyBuiltinVoteRunning())
	{
		ReplyToInvoker(client, "[LiberumVeto] No vote is currently in progress.");
		return Plugin_Handled;
	}

	bool voteCancelled = false;
	int fakeNoVotesIssued = 0;

	if (g_bBuiltinCancelAvailable)
	{
		CancelBuiltinVote();
		voteCancelled = true;
	}
	else
	{
		fakeNoVotesIssued = ForceBuiltinVoteNo();
	}

	ShowActivity2(client, "[LiberumVeto] ", "invoked Liberum Veto on the running vote.");

	if (voteCancelled)
	{
		ReplyToInvoker(client, "[LiberumVeto] Vote cancelled via native functionality.");
	}
	else if (fakeNoVotesIssued > 0)
	{
		ReplyToInvoker(client, "[LiberumVeto] Issued Vote No for %d eligible players.", fakeNoVotesIssued);
	}
	else
	{
		ReplyToInvoker(client, "[LiberumVeto] Attempted to veto vote, but no eligible voters were found.");
	}

	return Plugin_Handled;
}

void ReplyToInvoker(int client, const char[] fmt, any ...)
{
	char buffer[256];
	VFormat(buffer, sizeof(buffer), fmt, 3);

	if (client <= 0)
	{
		PrintToServer("%s", buffer);
	}
	else if (IsClientInGame(client))
	{
		PrintToChat(client, "%s", buffer);
	}
	else
	{
		ReplyToCommand(client, "%s", buffer);
	}
}

int ForceBuiltinVoteNo()
{
	if (!IsAnyBuiltinVoteRunning())
	{
		return 0;
	}

	int forced = 0;
	int team = BUILTINVOTES_ALL_TEAMS;

	if (g_bGameVoteStatusAvailable && g_bGameVoteTeamAvailable && Game_IsVoteInProgress())
	{
		team = Game_GetVoteTeam();
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
		{
			continue;
		}

		if (g_bBuiltinVotePoolAvailable && !IsClientInBuiltinVotePool(i))
		{
			continue;
		}

		if (team >= TEAM_SPECTATE && team <= TEAM_INFECTED && GetClientTeam(i) != team)
		{
			continue;
		}

		FakeClientCommand(i, "Vote No");
		forced++;
	}

	return forced;
}

bool IsAnyBuiltinVoteRunning()
{
	if (g_bBuiltinVotesAvailable && IsBuiltinVoteInProgress())
	{
		return true;
	}

	if (g_bGameVoteStatusAvailable && Game_IsVoteInProgress())
	{
		return true;
	}

	return false;
}

void UpdateFeatureAvailability()
{
	g_bBuiltinVotesAvailable = GetFeatureStatus(FeatureType_Native, "IsBuiltinVoteInProgress") == FeatureStatus_Available;
	g_bBuiltinCancelAvailable = GetFeatureStatus(FeatureType_Native, "CancelBuiltinVote") == FeatureStatus_Available;
	g_bBuiltinVotePoolAvailable = GetFeatureStatus(FeatureType_Native, "IsClientInBuiltinVotePool") == FeatureStatus_Available;
	g_bGameVoteTeamAvailable = GetFeatureStatus(FeatureType_Native, "Game_GetVoteTeam") == FeatureStatus_Available;
	g_bGameVoteStatusAvailable = GetFeatureStatus(FeatureType_Native, "Game_IsVoteInProgress") == FeatureStatus_Available;
}


