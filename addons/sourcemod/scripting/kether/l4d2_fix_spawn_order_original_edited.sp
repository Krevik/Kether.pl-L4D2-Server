#pragma semicolon 1

#include <sourcemod>
#include <left4dhooks>
#include <colors>

#undef REQUIRE_PLUGIN
#include "readyup"


Handle spawnList;
int storedSILastAssignedSpawn[MAXPLAYERS + 1];

// Ready-up
bool readyUpIsAvailable;
bool bLive;

// cvars

/* These class numbers are the same ones used internally in L4D2 SIClass enum*/
enum {
	SI_None=0,
	SI_Smoker=1,
	SI_Boomer,
	SI_Hunter,
	SI_Spitter,
	SI_Jockey,
	SI_Charger,
	SI_Witch,
	SI_Tank,
	
	SI_MAX_SIZE
};

char g_sSIClassNames[SI_MAX_SIZE][] = {
	"",
	"Smoker",
	"Boomer",
	"Hunter",
	"Spitter",
	"Jockey",
	"Charger",
	"Witch",
	"Tank"
};

public Plugin myinfo =
{
	name = "L4D2 Proper Sack Order",
	author = "Sir",
	description = "Finally fix that pesky spawn rotation not being reliable",
	version = "1.4",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart()
{
	// Events
	HookEvent("round_end", RoundEndEvent);
	HookEvent("player_team", TeamChange_Event);
	HookEvent("player_death", PlayerDeathEvent);

	// Array
	spawnList = CreateArray(16);
}

// Ready-up Checks
public void OnAllPluginsLoaded()
{
	readyUpIsAvailable = LibraryExists("readyup");
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "readyup"))
		readyUpIsAvailable = false;
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "readyup"))
		readyUpIsAvailable = true;
}

public void OnTankDeath()
{
	if(bLive){
		if(FindValueInArray(spawnList, SI_Spitter) == -1){
			PushArrayCell(spawnList, SI_Spitter);
		}
	}
}

public void OnClientDisconnect(int client)
{
	int class = storedSILastAssignedSpawn[client];
	if(class >= SI_Smoker && class <= SI_Charger){
		if(FindValueInArray(spawnList, class) == -1){
			ShiftArrayUp(spawnList, 0);
			SetArrayCell(spawnList, 0, class);
		}
		storedSILastAssignedSpawn[client] = SI_None;
	}
}

public void RoundEndEvent(Handle event, const char[] name, bool dontBroadcast)
{
	bLive = false;
	RefillArray();
}


public void TeamChange_Event(Handle event, const char[] name, bool dontBroadcast)
{
	if(bLive){
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		if(IsValidClient(client)){
			int old_team = GetEventInt(event, "oldteam");
			if( (old_team == 3 && GetEntProp(client, Prop_Send, "m_isGhost") == 1) ){
				int class = storedSILastAssignedSpawn[client];
				if(class >= SI_Smoker && class <= SI_Charger){
					if(FindValueInArray(spawnList, class) == -1){
						ShiftArrayUp(spawnList, 0);
						SetArrayCell(spawnList, 0, class);
					}
				}
				storedSILastAssignedSpawn[client] = SI_None;
			}
		}
	}
}

public void PlayerDeathEvent(Handle event, const char[] name, bool dontBroadcast)
{
	if(bLive){
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		int class = storedSILastAssignedSpawn[client];
		if(GetClientTeam(client) == 3){
			if(class >= SI_Smoker && class <= SI_Charger){
				if(IsTankInPlay()){
					if(class != SI_Spitter){
						PushArrayCell(spawnList, class);
					}
				}else{
					PushArrayCell(spawnList, class);
				}
			}
		}
		storedSILastAssignedSpawn[client] = SI_None;
	}
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	if (readyUpIsAvailable && IsInReady()) {
		bLive = false;
	} else {
		bLive = true;
	}

	if(bLive){
		for (int x = 1; x <= MaxClients; x++) {
			if(IsValidClient(x)){
				if(GetClientTeam(x) == 3){
					int class = GetEntProp(x, Prop_Send, "m_zombieClass");
					if(class >= SI_Smoker && class <= SI_Charger){
						storedSILastAssignedSpawn[x] = class;
					}
				}
			}
		}
		RefillArray();
	}
	return Plugin_Continue;
}

public void L4D_OnEnterGhostState(int client)
{
	if(bLive){
		if(GetClientTeam(client) == 3){
			int SI_class = GetArrayCell(spawnList, 0);
			L4D_SetClass(client, SI_class);
			storedSILastAssignedSpawn[client] = SI_class;
			RemoveFromArray(spawnList, 0);
		}
	}
}

public RefillArray(){
	spawnList = CreateArray(16);
	ClearArray(spawnList);
	//fill the array with all the possible spawns
	for(int x = SI_Smoker; x <= SI_Charger; x++){
		PushArrayCell(spawnList, x);
	}
	//delete existing spawns from the array
	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsValidClient(client)){
			if(GetClientTeam(client) == 3){
				int class = GetEntProp(client, Prop_Send, "m_zombieClass");
				if(class >= SI_Smoker && class <= SI_Charger){
					int index = FindValueInArray(spawnList,class);
					if(index != -1){
						RemoveFromArray(spawnList, index);
					}
				}
			}
		}
	}
}

bool IsTankInPlay() 
{
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && !IsFakeClient(i) && IsTank(i))
		{
			return true;
		}
	}
	return false;
}

bool IsTank(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass") == SI_Tank;
}

bool IsValidClient(int client)
{
    if (client <= 0 || client > MaxClients || !IsClientConnected(client)){
		return false;
	}

    return IsClientInGame(client);
}
