#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Krevik"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#pragma newdecls required

public Plugin myinfo = 
{
	name = "Player Fall dmg printing",
	author = PLUGIN_AUTHOR,
	description = "Prints player fall dmg.",
	version = PLUGIN_VERSION,
	url = "kether.pl"
};

public void OnPluginStart()
{
	HookEvent("player_falldamage", FALL_DMG_PRINT);
}

public void FALL_DMG_PRINT(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	float dmg = GetEventFloat(event, "damage"); 
	int reason = GetClientOfUserId(GetEventInt(event, "causer"));
	float fallVelocitySend = GetEntPropFloat(client, Prop_Send, "m_flFallVelocity");
	//TODO calculate height
	
	CPrintToChat(client, "You received {red}%d {olive}Fall Dmg {default}|| {olive}Fall Velocity: {red}%d {default}|| {olive}Reason: {red}%N", RoundToNearest(dmg), fallVelocitySend, reason);
}