#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <neon_beams>

ConVar g_hAllowed;
bool g_bAllowed, g_bLateLoad;
Handle g_Timers[MAXPLAYERS+1];
float g_Origins[MAXPLAYERS+1][3];
int g_Colors[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "[ANY] Neon Beams - Test Journey",
	author = "SilverShot",
	description = "Test plugin to create beams behind players which last until map change.",
	version = "1.1-tj",
	url = "https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
}

// Supports reloading this plugin or adding/removing the core plugin
public void LateLoad()
{
	for( int i = 1; i <= MaxClients; i++ ) StartJourney(i);
}

public void OnAllPluginsLoaded()
{
	if( LibraryExists("neon_beams") == false )
		SetFailState("Neon Beams plugin not been detected and is required.");

	// Turn this plugin on and off depending on the core plugins convar
	g_hAllowed = FindConVar("neon_allow");
	if( g_hAllowed != null )
	{
		g_hAllowed.AddChangeHook(ConVarChanged_Allowed);
		g_bAllowed = g_hAllowed.BoolValue;
	}

	if( g_bLateLoad )
		LateLoad();
}

public void ConVarChanged_Allowed(Handle convar, const char[] oldValue, const char[] newValue)
{
	g_bAllowed = g_hAllowed.BoolValue;
}

public void OnPluginStart()
{
	HookEvent("player_spawn", EventSpawn);
	HookEvent("player_death", EventDeath);
}

public void OnMapEnd()
{
	for( int i = 0; i <= MaxClients; i++ )
		delete g_Timers[i];
}

public void EventSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if( g_bAllowed )
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		StartJourney(client);
	}
}

public void EventDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if( client ) delete g_Timers[client];
}

void StartJourney(int client)
{
	if( client && IsClientInGame(client) )
	{
		// Reset position. Random color. Start timer to check position every 0.5 seconds
		g_Origins[client] = view_as<float>({0.0, 0.0, 0.0});
		g_Colors[client] = GetRandomInt(255, 16581375); // 16581375 = 255 * 255 * 255 (max RGB color code)
		g_Timers[client] = CreateTimer(0.5, TimerJourney, GetClientUserId(client), TIMER_REPEAT);
	}
}

public void OnClientDisconnect(int client)
{
	delete g_Timers[client];
}

public Action TimerJourney(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if( g_bAllowed && client && IsClientInGame(client) && IsPlayerAlive(client) )
	{
		float vPos[3];
		GetClientAbsOrigin(client, vPos);

		// Require them to move 50 units distance
		if( GetVectorDistance(vPos, g_Origins[client]) > 50 )
		{
			if( g_Origins[client][0] != 0.0 && g_Origins[client][1] != 0.0 && g_Origins[client][2] != 0.0 )
			{
				// Create a permanent beam from their current to their last.
				NeonBeams_TempMap(g_Colors[client], vPos, g_Origins[client]);
			}

			g_Origins[client] = vPos;
		}
	}
	else
	{
		g_Timers[client] = null;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}