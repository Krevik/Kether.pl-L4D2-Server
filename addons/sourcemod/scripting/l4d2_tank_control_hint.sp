#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2lib>
#include <colors>
#define PLUGIN_VERSION "1.0.0"


bool:shouldPrintHint;
enum L4D2SI 
{
	ZC_None,
	ZC_Smoker,
	ZC_Boomer,
	ZC_Hunter,
	ZC_Spitter,
	ZC_Jockey,
	ZC_Charger,
	ZC_Witch,
	ZC_Tank
};

public Plugin:myinfo =
{
	name = "L4D2 Tank Control Hint",
	author = "Krevik",
	description = "Prints tank control hint",
	version = PLUGIN_VERSION,
	url = "kether.pl"
}

public OnPluginStart()
{
	HookEvent("tank_spawn", Event_Tank_Spawn);
	HookEvent("tank_killed", Event_Tank_Killed);
	shouldPrintHint=false;
}

public Action:Event_Tank_Spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	shouldPrintHint=true;
	for (new i=0; i<MaxClients; i++)
	{
		if (IsValidPlayer(i))
		{
			CreateTimer(1.0, TryToPrintHint, i, TIMER_REPEAT);
		}
	}
	return Plugin_Continue;
}

public Action:TryToPrintHint(Handle:timer, any:client)
{
	if(shouldPrintHint){
		new tank = FindTank();
		if (tank == -1) {
			shouldPrintHint=false;
		}else{
			new controlGauge = (100 - GetEntProp(tank, Prop_Send, "m_frustration"));
			PrintHintText(client, "Tank Control: %d / 100", controlGauge);
		}
	}
	return Plugin_Continue;
}

FindTank() 
{
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsInfected(i) && GetInfectedClass(i) == ZC_Tank && IsPlayerAlive(i))
			return i;
	}

	return -1;
}

public Action:Event_Tank_Killed(Handle:event, const String:name[], bool:dontBroadcast)
{
	shouldPrintHint=false;
	
	return Plugin_Stop;
}

bool:IsValidPlayer(clientNumber){
	if (clientNumber <= 0 || clientNumber > MaxClients || !IsClientConnected(clientNumber)) return false;
	return 	clientNumber > 0 
				&& clientNumber<=MaxClients 
				&& !IsFakeClient(clientNumber)
				&& IsClientConnected(clientNumber)
				&& GetClientTeam(clientNumber) != 1
				&& GetClientTeam(clientNumber) != 2
				&& IsClientInGame(clientNumber);
}

bool:IsInfected(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3;
}

L4D2SI:GetInfectedClass(client)
{
	return IsInfected(client) ? (L4D2SI:GetEntProp(client, Prop_Send, "m_zombieClass")) : ZC_None;
}