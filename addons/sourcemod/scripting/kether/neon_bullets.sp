#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <neon_beams>

public Plugin myinfo =
{
	name = "[ANY] Neon Beams - Test Bullets",
	author = "SilverShot",
	description = "Test plugin to create temporary tracer rounds on weapon fire using beams.",
	version = "1.1-tb",
	url = "https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers"
}

int g_Colors[MAXPLAYERS+1];
bool g_bAllowed;
ConVar g_hAllowed;

public void OnAllPluginsLoaded()
{
	if( LibraryExists("neon_beams") == false )
		SetFailState("Neon Beams plugin not been detected and is required.");

	g_hAllowed = FindConVar("neon_allow");
	if( g_hAllowed != null )
	{
		g_hAllowed.AddChangeHook(ConVarChanged_Allowed);
		g_bAllowed = g_hAllowed.BoolValue;
	}

	// Give everyone random tracer colors
	for( int i = 0; i <= MAXPLAYERS; i++ )
		g_Colors[i] = GetRandomInt(255,16581375);
}

public void ConVarChanged_Allowed(Handle convar, const char[] oldValue, const char[] newValue)
{
	g_bAllowed = g_hAllowed.BoolValue;
}

public void OnPluginStart()
{
	HookEvent("bullet_impact", EventImpact);
}

public void EventImpact(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if( client && g_bAllowed )
	{
		float vPos[3], vEye[3];
		vPos[0] = GetEventFloat (event, "x");
		vPos[1] = GetEventFloat (event, "y");
		vPos[2] = GetEventFloat (event, "z");
		GetClientEyePosition(client, vEye);
		// vEye = start point for beam. vPos = end point for beam. 1.0 = duration of beam.
		vEye[2] -= 10; // Move down

		// Team Color bullets
		int color = 0xFF; // red
		if( GetClientTeam(client) == 3 )
			color = 0xFF0000; // blue

		NeonBeams_TempMap(color, vEye, vPos, 1.0);

		// Random color bullets
		// NeonBeams_TempMap(g_Colors[client], vEye, vPos, 1.0);
	}
}