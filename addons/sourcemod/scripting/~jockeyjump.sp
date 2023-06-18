#include <sourcemod>
#include <sdktools>
#pragma semicolon 1

#define CVAR_FLAGS FCVAR_PLUGIN|FCVAR_NOTIFY
#define PLUGIN_VERSION "1.0.3"
#define TEAM_INFECTED 3
#define SOUND_JOCKEY_DIR "./player/jockey/"

//plugin info
//#######################
public Plugin:myinfo =
{
	name = "Jockey jump",
	author = "Die Teetasse",
	description = "Adding the ability that the jockey can jump with a survivor",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=122213"
};

/*
//history
//#######################

v1.0.3:
- fixed tank bug

v1.0.2:
- added configfile
- added enable/disable cvar and logic
- added sound cvar
- added rechargebar cvar
- added jump notification

v1.0.1:
- added client checks
- added cvar for jump force
- added l4d2 check
- fixed flying survivor
- fixed press delay
- added jockey jump sound

v1.0.0:
- initial
*/

//global definitions
//#######################

new bool:injump[MAXPLAYERS];
new bool:pressdelay[MAXPLAYERS];

new Handle:cvar_enable;
new Handle:cvar_disabletime;
new Handle:cvar_rechargebar;
new Handle:cvar_soundfile;
new Handle:cvar_zforce;

new String:soundfilepath[PLATFORM_MAX_PATH];

//plugin start
//#######################
public OnPluginStart()
{
	//L4D2 check
	decl String:game[12];
	GetGameFolderName(game, sizeof(game));
	if (StrContains(game, "left4dead2") == -1) SetFailState("Jockey jump will only work with Left 4 Dead 2!");

	//cvars
	CreateConVar("l4d2_jockeyjump_version", PLUGIN_VERSION, "Jockey jump version", CVAR_FLAGS|FCVAR_DONTRECORD);
	
	cvar_enable = CreateConVar("l4d2_jockeyjump_enable", "1", "Jockey jump - enable/disable plugin", CVAR_FLAGS);
	cvar_disabletime = CreateConVar("l4d2_jockeyjump_delay", "3.0", "Jockey jump - recharge time for the jockey jump", CVAR_FLAGS);
	cvar_rechargebar = CreateConVar("l4d2_jockeyjump_rechargebar", "1", "Jockey jump - recharge bar enable/disable", CVAR_FLAGS);
	cvar_soundfile = CreateConVar("l4d2_jockeyjump_soundfile", "voice/attack/jockey_loudattack01_wet.wav", "Jockey jump - jockey sound file (relative to to sound/player/jockey/ - empty to disable)", CVAR_FLAGS);
	cvar_zforce = CreateConVar("l4d2_jockeyjump_force", "330.0", "Jockey jump - jump force (z-direction)", CVAR_FLAGS, true, 251.0); //gravity is 250
	
	//config file
	AutoExecConfig(true, "l4d2_jockey_jump");
	
	//hooking events
	HookEvent("round_start", Round_Event);
	HookEvent("jockey_ride", Ride_Event);
}

//map start
//#######################
public OnMapStart()
{
	//get string
	new String:cvarstring[256];
	GetConVarString(cvar_soundfile, cvarstring, sizeof(cvarstring));

	//trim string
	TrimString(cvarstring);
	
	//is string empty?
	if (strlen(cvarstring) == 0) soundfilepath = "";
	//building sound path
	else
	{
		PrintToServer("Building path...");
	
		//check for / at the beginning
		if (cvarstring[0] == '/')
		{
			new String:tempstring[256];
			strcopy(tempstring, sizeof(tempstring), cvarstring[1]);
			cvarstring = tempstring;
			
			PrintToServer("/ found! new String: %s", cvarstring);
		}
		
		//add strings
		Format(soundfilepath, sizeof(soundfilepath), "%s%s", SOUND_JOCKEY_DIR, cvarstring);
	
		PrintToServer("path: %s", soundfilepath);
	
		//precatching sound
		PrefetchSound(soundfilepath);
		PrecacheSound(soundfilepath);
	}
}

//events
//#######################
public Action:Round_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 0; i < MAXPLAYERS; i++)
	{
		injump[i] = false;
		pressdelay[i] = false;
	}
}

public Action:Ride_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	//enabled?
	if (!GetConVarBool(cvar_enable)) return Plugin_Continue;
	
	new client_jockey = GetClientOfUserId(GetEventInt(event, "userid"));
	new client_victim = GetClientOfUserId(GetEventInt(event, "victim"));
	
	//everybody still there?
	if (!IsClientInGame(client_jockey)) return Plugin_Continue;
	if (!IsClientInGame(client_victim)) return Plugin_Continue;
	
	//botjockey?
	if (IsFakeClient(client_jockey)) return Plugin_Continue;
	
	//add a new jockey + victim
	injump[client_jockey] = false;
	
	//delay jumping for a second (you can get on a survivor by jumping)
	pressdelay[client_jockey] = true;
	CreateTimer(1.0, ResetPressDelay, client_jockey, TIMER_FLAG_NO_MAPCHANGE);
	
	//send notification
	PrintHintText(client_jockey, "You can jump with the survivor by pressing JUMP!");
	
	return Plugin_Continue;
}

//playercmd
//#######################
public Action:OnPlayerRunCmd(client, &buttons)
{
	//enabled?
	if (!GetConVarBool(cvar_enable)) return;
	
	//pressing jump?
	if (!(buttons & IN_JUMP)) return;

	//delay?
	if (injump[client]) return;
	
	//pressdelay?
	if (pressdelay[client]) return;

	//human?
	if (IsFakeClient(client)) return;
	
	//infected?
	if (GetClientTeam(client) != TEAM_INFECTED) return;

	// Jockey? zombieClass 5 is Jockey.
	if (GetEntProp(client, Prop_Send, "m_zombieClass") != 5) return;
	
	new victim = GetEntPropEnt(client, Prop_Send, "m_jockeyVictim");

	// Is he riding someone?
	if (victim == -1) return;

	//activate press delay (half second) regardless of jumping result
	pressdelay[client] = true;
	CreateTimer(0.5, ResetPressDelay, client);
	
	//jump! (if survivor is falling return => no delay)
	if (!jump(victim)) return; 
	
	injump[client] = true;
	
	//setdelayreset
	new Float:delay = GetConVarFloat(cvar_disabletime);
	CreateTimer(delay, ResetJump, client);
	
	//is bar enabled?
	if (GetConVarBool(cvar_rechargebar))
	{
		//display progress bar
		SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
		SetEntPropFloat(client, Prop_Send, "m_flProgressBarDuration", delay);  
	
		PrintHintText(client, "Jockey jump recharge!");
	}
}

//timer
//#######################
public Action:ResetPressDelay(Handle:timer, any:index)
{
	//reset press delay
	pressdelay[index] = false;
}

public Action:ResetJump(Handle:timer, any:index)
{
	//reset jump
	injump[index] = false;
}

//private function
//#######################
bool:jump(client)
{
	//client still there?
	if (!IsClientInGame(client)) return false;

	//get velocity
	new Float:velo[3];
	velo[0] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
	velo[1] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");
	velo[2] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[2]");
	
	//falling or jumping?
	if (velo[2] != 0) return false;

	//add only velocity in z-direction
	new Float:vec[3];
	vec[0] = velo[0];
	vec[1] = velo[1];
	vec[2] = velo[2] + GetConVarFloat(cvar_zforce);
	
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vec);
	
	//play sound if set
	if (strlen(soundfilepath) > 0) EmitSoundToAll(soundfilepath, client);
	
	return true;
}
