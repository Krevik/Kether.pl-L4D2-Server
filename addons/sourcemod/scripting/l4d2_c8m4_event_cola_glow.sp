#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_direct>
#include <l4d_stocks>
// #include <left4downtown> // Assuming this is compatible or not needed
#include <l4d2lib>

#define C8M4_EVENT_ID              	3
#define C8M4_COLA_BOTTLES			"cola_bottles"
#define C8M4_COLA_BOTTLES_GLOW_COLOR	{255, 153, 0}

StringMap g_hComplexEventMapTrie; // Use StringMap instead of Handle
int g_iComplexEventID = -1; // Use a global or cache locally in OnMapStart if preferred

public Plugin myinfo =
{
	name = "Confogl Sky Customization Plugin (Cola Glow)", // Adjusted name for clarity
	author = "Visor, JaneDoe, StarterX4",
	description = "Adds glow to dropped cola bottles on c8m4_interior (Kether version)", // Adjusted description
	version = "2.1", // Incremented version
	url = "https://github.com/Attano" // Or your specific repo
};

public void OnPluginStart()
{
	char sGame[12]; // Smaller buffer is sufficient
	GetGameFolderName(sGame, sizeof(sGame));
	if (!StrEqual(sGame, "left4dead2", false))
	{
		SetFailState("Plugin supports Left 4 Dead 2 only!");
	}

	HookEvent("weapon_drop", OnWeaponDrop, EventHookMode_Pre);

	// Initialize the StringMap directly
	g_hComplexEventMapTrie = new StringMap();
	g_hComplexEventMapTrie.SetValue("c8m4_interior", C8M4_EVENT_ID);
	// Add other maps here if needed in the future
	// g_hComplexEventMapTrie.SetValue("map_name", MAP_EVENT_ID);

	// No need to load translations if not using any translated strings
	// LoadTranslations("common.phrases");
	// LoadTranslations("plugin.basecommands");
}

// Optional: Clear map-specific data if needed
// public void OnPluginEnd()
// {
// 	if (g_hComplexEventMapTrie != null)
// 	{
// 		delete g_hComplexEventMapTrie;
// 	}
// }

public void OnMapStart()
{
	char sCurrentMap[128];
	GetCurrentMap(sCurrentMap, sizeof(sCurrentMap));

	// Get the event ID for the current map from the StringMap
	if (!g_hComplexEventMapTrie.GetValue(sCurrentMap, g_iComplexEventID))
	{
		// Map not found in our list, set ID to -1 or some other indicator
		g_iComplexEventID = -1;
		// PrintToServer("Map '%s' not configured for special events.", sCurrentMap); // Optional debug message
	}
	// else
	// {
	// 	PrintToServer("Map '%s' configured with Event ID: %d", sCurrentMap, g_iComplexEventID); // Optional debug message
	// }
}

public Action OnWeaponDrop(Event event, const char[] name, bool dontBroadcast)
{
	// Check if the current map has the specific event ID we care about
	if (g_iComplexEventID == C8M4_EVENT_ID)
	{
		char classname[64];
		event.GetString("item", classname, sizeof(classname)); // Use event handle directly

		// Setting up glow for cola bottles
		if (StrEqual(classname, C8M4_COLA_BOTTLES))
		{
			int propId = event.GetInt("propid"); // Use event handle directly
			if (IsValidEntity(propId)) // Good practice to check if the entity is valid
			{
				// L4D2_SetEntityGlow parameters: entity, type, range, minRange, color[3], flashing
				L4D2_SetEntityGlow(propId, L4D2Glow_Constant, 0, 22, C8M4_COLA_BOTTLES_GLOW_COLOR, true);
			}
		}
	}

	return Plugin_Continue;
}

// BuildComplexEventTrie function is no longer needed as the StringMap is populated in OnPluginStart
