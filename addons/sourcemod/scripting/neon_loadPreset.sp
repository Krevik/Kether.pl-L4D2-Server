#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <neon_beams>

#define PRESET "test"

public Plugin myinfo =
{
	name = "[ANY] Neon Beams - Test Presets",
	author = "SilverShot",
	description = "Test plugin to spawn presets by name.",
	version = "1.1-tp",
	url = "https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers"
}

bool g_bAllowed;
ConVar g_hAllowed;

public void OnPluginStart()
{
	RegAdminCmd("sm_neon_pre", sm_neon_pre, ADMFLAG_ROOT, "Neom Beams - Load preset 'test'.");
}

public void OnAllPluginsLoaded()
{
	if( LibraryExists("neon_beams") == false )
	{
		SetFailState("Neon Beams plugin not been detected and is required.");
	}

	g_hAllowed = FindConVar("neon_allow");

	if( g_hAllowed != null )
	{
		g_hAllowed.AddChangeHook(ConVarChanged_Allowed);
		g_bAllowed = g_hAllowed.BoolValue;
	}
}

public void ConVarChanged_Allowed(Handle convar, const char[] oldValue, const char[] newValue)
{
	g_bAllowed = g_hAllowed.BoolValue;
}

public Action sm_neon_pre(int client, int args)
{
	float vAng[3], vPos[3];

	if( g_bAllowed )
	{
		if( NeonBeams_SetupPos(GetClientUserId(client), vAng, vPos) )
		{
			if( NeonBeams_TempPre(PRESET, vAng, vPos) )
			{
				PrintToChat(client, "[Neon Beams] Spawned preset '\x05%s\x01'!", PRESET);
			} else {
				PrintToChat(client, "[Neon Beams] Cannot find preset '\x05%s\x01'.", PRESET);
			}
		} else {
			PrintToChat(client, "[Neon Beams] Bad position, try again.");
		}
	} else {
		PrintToChat(client, "[Neon Beams] Core plugin has been turned off.");
	}

	return Plugin_Handled;
}

public bool TraceFilter(int entity, int contentsMask, any client)
{
	if( entity == client )
		return false;
	return true;
}