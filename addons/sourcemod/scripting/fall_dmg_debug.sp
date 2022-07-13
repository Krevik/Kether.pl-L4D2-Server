#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Krevik"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#pragma newdecls required

public Plugin myinfo = 
{
	name = "Player Fall dmg Logging",
	author = PLUGIN_AUTHOR,
	description = "Log player fall dmg.",
	version = PLUGIN_VERSION,
	url = "nah"
};

char g_sCmdLogPath[256];

public void OnPluginStart()
{
	BuildPath(Path_SM, g_sCmdLogPath, sizeof(g_sCmdLogPath), "logs/kether_fall_dmg.log");
	HookEvent("player_falldamage", FALL_DMG_LOG);
}

public void FALL_DMG_LOG(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	float dmg = GetEventFloat(event, "damage"); 
	int reason = GetClientOfUserId(GetEventInt(event, "causer"));
	float fallVelocitySend = GetEntPropFloat(client, Prop_Send, "m_flFallVelocity");
	float fallVelocityData = GetEntPropFloat(client, Prop_Data, "m_flFallVelocity");
	LogToFileEx(g_sCmdLogPath, "Client: %d || ClientName: %N || dmg: %f || reason: %d || fallVeloSend: %f || fallVeloData: %f", client, client, dmg, reason, fallVelocitySend, fallVelocityData);
}