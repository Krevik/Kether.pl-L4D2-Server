#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <colors>

#define PLUGIN_VERSION "1.0"

//Timer
Handle TimerH = INVALID_HANDLE;
Handle cvarGameMode = INVALID_HANDLE;

public Plugin myinfo =
{
	name = "L4D2 No Mercy Rooftop Scavenge Fix",
	author = "Ratchet",
	description = "Fixes No Mercy 5 scavenge.",
	version = PLUGIN_VERSION,
	url = ""
}

public void OnMapStart()
{
	char mapname[128];
	GetCurrentMap(mapname, sizeof(mapname));
	
	if( TimerH != INVALID_HANDLE )
		KillTimer(TimerH);
		
	TimerH = INVALID_HANDLE;
		
	if (strcmp(mapname, "c8m5_rooftop") != 0)
		return;
		
	cvarGameMode = FindConVar("mp_gamemode");
	
	char sGameMode[32];
	GetConVarString(cvarGameMode, sGameMode, sizeof(sGameMode));
	if (strcmp(sGameMode, "scavenge") != 0)
		return;
		
	TimerH = CreateTimer(15.0, ScavTimerH, _, TIMER_REPEAT);
}

public Action ScavTimerH(Handle Timer, any Client)
{		
	FindMisplacedCans();
}

stock void FindMisplacedCans()
{
	int ent = -1;
	
	while ((ent = FindEntityByClassname(ent, "weapon_gascan")) != -1)
	{
		if (!IsValidEntity(ent)) 
			continue;

		float position[3];
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", position);
		
		if( position[2] <= 500.0 )
		if( position[0] > 0.0 && position[1] > 0.0 && position[2] )	//HACK HACK! Although it's impossible for can to go to 0 0 0 in NM5
			Ignite( ent );
	}
}


stock void Ignite(int entity)
{
	AcceptEntityInput(entity, "ignite");
	CPrintToChatAll("{blue}[{default}Scavogl{blue}]{default} {olive}Gascan{default} out of bounds! {green}Ignited!{default}");
}

stock void FindEntityByClassname2(int startEnt, const char[] classname)
{
	while (startEnt > -1 && !IsValidEntity(startEnt)) startEnt--;
	return FindEntityByClassname(startEnt, classname);
}
