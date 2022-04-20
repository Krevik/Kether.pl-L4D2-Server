#pragma semicolon 1

#include <sourcemod>
#include <left4dhooks>
#include <colors>

#undef REQUIRE_PLUGIN
#include "readyup"

// Ready-up
bool readyUpIsAvailable;
bool bLive;

int debuging = 0;

ArrayList spawnList;
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

public Plugin myinfo =
{
	name = "L4D2 Proper Sack Order",
	author = "Krevik, Sir",
	description = "Finally fix that Sir' plugin not being reliable",
	version = "1.5k",
	url = "https://github.com/Krevik/Kether.pl-L4D2-Server"
};

public void OnPluginStart()
{
	spawnList = new ArrayList(1);
	// Events
	HookEvent("round_start", CleanUp);
	HookEvent("round_end", CleanUp);
	HookEvent("map_transition", CleanUp);
	HookEvent("round_start_pre_entity", CleanUp);
	HookEvent("player_spawn", PlayerSpawn);
}

public void CleanUp(Handle event, const char[] name, bool dontBroadcast)
{
	spawnList.Clear();
	for(int x = 1; x <= 7; x++){
		spawnList.Push(x);
	}
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

public void PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	//player spawned, remove from our array
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(GetClientTeam(client) == 3){
		if(bLive){
			if(IsValidClient(client) && !IsFakeClient(client)){
				int SI_CLASS = GetEntProp(client, Prop_Send, "m_zombieClass");
				int index = spawnList.FindValue(SI_CLASS);
				if(index != -1){
					spawnList.Erase(index);
				}else{
					//something is wrong, there was an SI spawned that wasn't present in the array. Maybe after tank pass to bot or sth? 
					if(debuging == 1){
						CPrintToChatAll("[K Debug] There was an SI Spawed that wasn't present in the array. ");
					}
				}
			}
		}
	}
}

public void OnRoundIsLive(){
	//fill the array with all the possible spawns
	for(int x = 1; x <= 7; x++){
		spawnList.Push(x);
	}
	//delete existing spawns from the array
	for (int client = 1; client <= MaxClients; client++)
	{
		if(GetClientTeam(client) == 3){
			int class = GetEntProp(client, Prop_Send, "m_zombieClass");
			if(class != 0 && class != - 1){
				int index = spawnList.FindValue(class);
				if(index != -1){
					spawnList.Erase(index);
					if(debuging == 1){
						CPrintToChatAll("[K Debug] Removed %d class from the array as the round started.", class);
					}
				}
			}
		}
	}
}

public void L4D_OnEnterGhostState(int client)
{
	if(IsValidClient(client)){
		if(IsClientInGame(client)){
			if(!IsFakeClient(client)){
				if(GetClientTeam(client) == 3){
					int SI = GetNextSI(client);
					L4D_SetClass(client, SI);
				}
			}
		}
	}
}

int GetNextSI(int clientID)
{
	//firstly we need to check if array is not empty
	int arraySize = spawnList.Length;
	if(arraySize == 0){
		for(int x = 1; x <= 7; x++){
			spawnList.Push(x);
		}
		if(debuging == 1){
			CPrintToChatAll("[K Debug] Array got empty, refilled. ");
		}
	}
	//we need to detect tank to delete spitter from array
	if(IsTankInPlay()){
		int spitterIndex = spawnList.FindValue(5);
		if(spitterIndex != -1){
			spawnList.Erase(spitterIndex);
			if(debuging == 1){
				CPrintToChatAll("[K Debug] Tank is in play, spitter was in the array, removed him. ");
			}
		}
	}

	int indexShift = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsValidClient(client)){
			if(IsClientInGame(client)){
				if(!IsFakeClient(client)){
					if(GetClientTeam(client) == 3){
						if(client != clientID){
							int class = GetEntProp(client, Prop_Send, "m_zombieClass");
							if(class != 0 && class != - 1){
								indexShift++;
							}
						}
					}
				}
			}
		}
		/* old code - change to this if upper is not working
		if(GetClientTeam(client) == 3 && client != clientID){
			int class = GetEntProp(client, Prop_Send, "m_zombieClass");
			if(class != 0 && class != - 1){
				indexShift++;
			}
		}*/
	}

	int additor = 1;
	while(indexShift > arraySize){
		spawnList.Push(additor);
		additor++;
		arraySize = spawnList.Length;
	}
	int classID = spawnList.Get(indexShift);

	return classID;
}

bool IsTankInPlay() 
{
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i)
			&& GetClientTeam(i) == 3
			&& IsPlayerAlive(i)
			&& !IsFakeClient(i)
			&& IsTank(i))
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
    if (client <= 0 || client > MaxClients || !IsClientConnected(client))
		return false;

    return IsClientInGame(client);
}
