#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Krevik"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <l4d2util>
#pragma newdecls required

int dmgReason[MAXPLAYERS+1];
int healthBeforeFall[MAXPLAYERS+1];
int dmgFromEvent[MAXPLAYERS+1];
float fallVelocity[MAXPLAYERS+1];

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
	HookEvent("player_falldamage", FallDamage_Event, EventHookMode_Pre);
}

public void FallDamage_Event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int dmg = RoundToNearest(GetEventFloat(event, "damage")); 
	int reason = GetClientOfUserId(GetEventInt(event, "causer"));
	float fallVelocitySend = GetEntPropFloat(client, Prop_Send, "m_flFallVelocity");

	dmgReason[client] = reason;
	dmgFromEvent[client] = dmg;
	fallVelocity[client] = fallVelocitySend;
	healthBeforeFall[client] = GetSurvivorPermanentHealth(client) + GetSurvivorTemporaryHealth(client);

	// //TODO calculate height
	// if(dmg > 0){
	// 	CPrintToChat(client, "You received {red}%d {olive}Fall Dmg {default}| {olive}Fall Velocity: {red}%d {default}| {olive}Reason: {red}%s", dmg, RoundToNearest(fallVelocitySend), reasonName);
	// }
}

public void delayedGuardedPrint(int client){
	DataPack pack;
	CreateDataTimer(0.5, CheckAndPrintDamage, pack);
	pack.WriteCell(client);
}

public Action CheckAndPrintDamage(Handle timer, DataPack pack)
{
	//gather data
	int client;
	pack.Reset();
	client = pack.ReadCell();

	//check
	char reasonName[128];
	char hostnameString[128]="";
	int actualHealth = GetSurvivorPermanentHealth(client) + GetSurvivorTemporaryHealth(client);
	int realReceivedDamage = 0;
	GetConVarString(FindConVar("hostname"), hostnameString, sizeof(hostnameString));
	if((client < 1 || client > MAXPLAYERS) || (dmgReason[client] < 1 || dmgReason[client] > MAXPLAYERS)){
		reasonName = "Generic";
	}else{
		GetClientName(dmgReason[client], reasonName, sizeof(reasonName));
		if(StrEqual(hostnameString, reasonName, false)){
			reasonName = "Generic";
		}
	}

	if(actualHealth < healthBeforeFall[client] && healthBeforeFall[client] > 0 && dmgFromEvent[client] > 0 && healthBeforeFall[client]-dmgFromEvent[client] <= actualHealth){
		realReceivedDamage = healthBeforeFall[client] - actualHealth;
	}
	//print
	if(realReceivedDamage > 0){
		CPrintToChat(client, "You received {red}%d {olive}Fall Dmg {default}| {olive}Fall Velocity: {red}%d {default}| {olive}Reason: {red}%s", dmgFromEvent[client], RoundToNearest(fallVelocity[client]), reasonName);
	}
	return Plugin_Continue;
}
