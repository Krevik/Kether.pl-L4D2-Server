#pragma semicolon 1

#include <multicolors>
#include <sourcemod>
#include "sdktools_functions.inc"
#include "console.inc"
#include <l4d2util>

public Plugin myinfo = 
{
    name = "Spit print dmg",
    author = "Krevik",
    description = "Shows dmg done by spit",
    version = "1.0.0",
    url = "kether.pl"
}

Handle playerSpitDmgTrie = INVALID_HANDLE;

public void OnPluginStart()
{
	playerSpitDmgTrie = CreateTrie();
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre); 
}

public Action Event_PlayerHurt(Handle event, const char[] name, bool dontBroadcast) {
    int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int dmg = GetEventInt(event, "dmg_health");
	int type = GetEventInt(event, "type");

	char steamUsername[64] = "NOT_FOUND";
	
	if(type != 263168){
		return Plugin_Continue;
	}

	if(GetClientTeam(victim) != L4D2Team_Survivor){
		return Plugin_Continue;
	}

	bool foundPlayer = GetClientAuthId(victim, AuthId_Steam2, steamUsername, sizeof(steamUsername));
	if(!foundPlayer){
		return Plugin_Continue;
	}
	
	int spitDamageCollector[MAXPLAYERS + 1];
	char spit_dmg_key[20];
    Format(spit_dmg_key, sizeof(spit_dmg_key), "%x_dmg", victim);
    GetTrieArray(playerSpitDmgTrie, spit_dmg_key, spitDamageCollector, sizeof(spitDamageCollector));
	
	spitDamageCollector[victim]+=dmg;
    SetTrieArray(playerSpitDmgTrie, spit_dmg_key, spitDamageCollector, sizeof(spitDamageCollector));
	
	//start timer?
	startTiming(victim, spitDamageCollector[victim]);
    return Plugin_Continue;
}

public void startTiming(int client, int damageDoneToThatClient){
	DataPack pack;
	CreateDataTimer(1.0, VerifySpitDmg, pack);
	pack.WriteCell(client);
	pack.WriteCell(damageDoneToThatClient);
}

public Action VerifySpitDmg(Handle timer, DataPack pack)
{
	int client;
	int damage;
	pack.Reset();
	client = pack.ReadCell();
	damage = pack.ReadCell();
	
	int spitDamageCollector[MAXPLAYERS + 1];
	char spit_dmg_key[20];
    Format(spit_dmg_key, sizeof(spit_dmg_key), "%x_dmg", client);
    GetTrieArray(playerSpitDmgTrie, spit_dmg_key, spitDamageCollector, sizeof(spitDamageCollector));

	if(spitDamageCollector[client] == damage){
		CPrintToChat(client, "You received {red}%d {olive}Spit Dmg {default}", damage);
		spitDamageCollector[client] = 0;
		SetTrieArray(playerSpitDmgTrie, spit_dmg_key, spitDamageCollector, sizeof(spitDamageCollector));
	}
	return Plugin_Continue;
}