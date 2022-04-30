#pragma semicolon 1

#include <sourcemod>
#include <left4dhooks>
#include <colors>

#undef REQUIRE_PLUGIN
#include "readyup"

// Ready-up
bool readyUpIsAvailable;
bool bLive;

ArrayList spawnList;

enum {
	SI_None=0,
	SI_Smoker=1,
	SI_Boomer=2,
	SI_Hunter=3,
	SI_Spitter=4,
	SI_Jockey=5,
	SI_Charger=6,
	SI_Witch=7,
	SI_Tank=8
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
	HookEvent("map_transition", MapTransition_Event);
	HookEvent("round_start_pre_entity", CleanUp);
	HookEvent("player_death", PlayerDeath);
	HookEvent("round_end", RoundEnd_Event);
}

public void OnRoundIsLive(){
	RefreshSpawnList();
	bLive = true;
}

public void RoundEnd_Event(Handle event, const char[] name, bool dontBroadcast)
{
	CleanUp(event, name, dontBroadcast);
	bLive = false;
}

public void MapTransition_Event(Handle event, const char[] name, bool dontBroadcast)
{
	CleanUp(event, name, dontBroadcast);
	bLive = false;
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

public void CleanUp(Handle event, const char[] name, bool dontBroadcast)
{
	spawnList.Clear();
	for(int x = 1; x <= 6; x++){
		spawnList.Push(x);
	}
}

public void L4D_OnEnterGhostState(int client)
{
	if(bLive){
		if(IsValidClient(client)){
			if(GetClientTeam(client) == 3){
				int SI = GetNextSI(client);
				L4D_SetClass(client, SI);
			}
		}
	}
}

public void PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	//player dead, add SI_CLASS to end of array
	if(bLive){
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		if(IsValidClient(client)){
			if(GetClientTeam(client) == 3){
				int SI_CLASS = GetEntProp(client, Prop_Send, "m_zombieClass");
				int index = spawnList.FindValue(SI_CLASS);
				if(index != -1){
					if(IsTankInPlay() && index==5){
						// List spawns available on tank
						ArrayList tankSpawnsList = getSpawnListForTank();

						// Remove from tank list taken spawns
						for (int client = 1; client <= MaxClients; client++)
						{
							if(IsValidClient(client)){
								if(GetClientTeam(client) == 3){
									int class = GetEntProp(client, Prop_Send, "m_zombieClass");
									if(class != 0 && class != - 1){
										int index = tankSpawnsList.FindValue(class);
										if(index != -1){
											tankSpawnsList.Erase(index);
										}
									}
								}
							}
						}

						// Add one spawn to spawn list
						for(int x = 0; x < tankSpawnsList.Length; x++){ 
							int index = spawnList.FindValue(x);
							if(index != -1){
								spawnList.Push(index);
								break;
							}
						}
					}else{
						spawnList.Push(index);
					}
				}
			}
		}
	}

}

public RefreshSpawnList() { 
	//delete existing spawns from the array
	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsValidClient(client)){
			if(GetClientTeam(client) == 3){
				int class = GetEntProp(client, Prop_Send, "m_zombieClass");
				if(class != 0 && class != - 1){
					int index = spawnList.FindValue(class);
					if(index != -1){
						spawnList.Erase(index);
					}
				}
			}
		}
	}
}

int GetNextSI(int clientID)
{
	//we need to detect tank to delete spitter from array
	if(IsTankInPlay()){
		int spitterIndex = spawnList.FindValue(SI_Spitter);
		if(spitterIndex != -1){
			spawnList.Erase(spitterIndex);
		}
	}

	// if spawnList is < or == 0 (spec or disconnect)
	if(spawnList.Length == 0) {
		if(IsTankInPlay()) {
				// List spawns available on tank
				ArrayList tankSpawnsList = getSpawnListForTank();
		
				// Remove from tank list taken spawns
				for (int client = 1; client <= MaxClients; client++)
				{
					if(IsValidClient(client)){
						if(GetClientTeam(client) == 3){
							int class = GetEntProp(client, Prop_Send, "m_zombieClass");
							if(class != 0 && class != - 1){
								int index = tankSpawnsList.FindValue(class);
								if(index != -1){
									tankSpawnsList.Erase(index);
								}
							}
						}
					}
				}

				// Add one spawn to spawn list
				for(int x = 0; x < tankSpawnsList.Length; x++){ 
					int index = spawnList.FindValue(x);
					if(index != -1){
						spawnList.Push(index);
						break;
					}
				}
		}else {
			// List full spawn list
			ArrayList fullSpawnList = getFullSpawnList();
		
			// Remove from list taken spawns
			for (int client = 1; client <= MaxClients; client++)
			{
				if(IsValidClient(client)){
					if(GetClientTeam(client) == 3){
						int class = GetEntProp(client, Prop_Send, "m_zombieClass");
						if(class != 0 && class != - 1){
							int index = fullSpawnList.FindValue(class);
							if(index != -1){
								fullSpawnList.Erase(index);
							}
						}
					}
				}
			}

			// Add one spawn to spawn list
			for(int x = 0; x < fullSpawnList.Length; x++){ 
				int index = spawnList.FindValue(x);
				if(index != -1){
					spawnList.Push(index);
					break;
				}
			}
		}
	}

	// Get first spawn from list
	int classID = spawnList.Get(0);
	spawnList.Erase(0);
	return classID;
}

ArrayList getSpawnListForTank() {
	ArrayList spawnListForTank = new ArrayList(1);
	spawnListForTank.Push(SI_Smoker);
	spawnListForTank.Push(SI_Boomer);
	spawnListForTank.Push(SI_Hunter);
	spawnListForTank.Push(SI_Jockey);
	spawnListForTank.Push(SI_Charger);
	return spawnListForTank;
}

ArrayList getFullSpawnList() {
	ArrayList spawnListForTank = new ArrayList(1);
	spawnListForTank.Push(SI_Smoker);
	spawnListForTank.Push(SI_Boomer);
	spawnListForTank.Push(SI_Hunter);
	spawnListForTank.Push(SI_Spitter);
	spawnListForTank.Push(SI_Jockey);
	spawnListForTank.Push(SI_Charger);
	return spawnListForTank;
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

// public void PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
// {
// 	//player spawned, remove from our array
// 	if(bLive){
// 		int client = GetClientOfUserId(GetEventInt(event, "userid"));
// 		if(IsValidClient(client)){
// 			if(GetClientTeam(client) == 3){
// 				int SI_CLASS = GetEntProp(client, Prop_Send, "m_zombieClass");
// 				int index = spawnList.FindValue(SI_CLASS);
// 				if(index != -1){
// 					spawnList.Erase(index);
// 				}
// 			}
// 		}
// 	}
// }

// public RefillArray(){
// 	//fill the array with all the possible spawns
// 	for(int x = 1; x <= 6; x++){
// 		spawnList.Push(x);
// 	}
// 	//delete existing spawns from the array
// 	for (int client = 1; client <= MaxClients; client++)
// 	{
// 		if(IsValidClient(client)){
// 			if(GetClientTeam(client) == 3){
// 				int class = GetEntProp(client, Prop_Send, "m_zombieClass");
// 				if(class != 0 && class != - 1){
// 					int index = spawnList.FindValue(class);
// 					if(index != -1){
// 						spawnList.Erase(index);
// 					}
// 				}
// 			}
// 		}
// 	}

// 	//we need to detect tank to delete spitter from array
// 	if(IsTankInPlay()){
// 		int spitterIndex = spawnList.FindValue(SI_Spitter);
// 		if(spitterIndex != -1){
// 			spawnList.Erase(spitterIndex);
// 		}
// 	}
// }

// int GetNextSI(int clientID)
// {

	// //if we have other GHOST players that were assigned from the spawnList, and the classes they have are present in spawnList yet (as they are not spawned yet), we need to count them
	// int indexShift = 0;
	// for (int client = 1; client <= MaxClients; client++)
	// {
	// 	if(IsValidClient(client)){
	// 		if(GetClientTeam(client) == 3 && client != clientID){
	// 			int class = GetEntProp(client, Prop_Send, "m_zombieClass");
	// 			if(class != 0 && class != -1){
	// 				indexShift++;
	// 			}
	// 		}
	// 	}
	// }

	// //we need to detect tank to delete spitter from array
	// if(IsTankInPlay()){
	// 	int spitterIndex = spawnList.FindValue(5);
	// 	if(spitterIndex != -1){
	// 		spawnList.Erase(spitterIndex);
	// 	}
	// }

	// //we need to check if array is not empty
	// int arraySize = spawnList.Length;
	// if(arraySize == 0 || indexShift > arraySize){
	// 	RefillArray();
	// }

	// int classID = spawnList.Get(indexShift);
	// return classID;
// }