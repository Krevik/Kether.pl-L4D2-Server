//SPDX-License-Identifier: GPL-3.0-or-later
//Changelog:
/*
0.2.0: Save banned players' SteamIDs to disk.

*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define PLUGIN_VERSION "0.2.0"

// L4D2 Sniper Rifle Classnames
#define L4D2_HUNTING_RIFLE_CLASSNAME	"weapon_sniper_scout"      // L4D2 Hunting Rifle (classname is weapon_sniper_scout)
#define L4D2_MILITARY_SNIPER_CLASSNAME	"weapon_sniper_military" // L4D2 Military Sniper Rifle
#define L4D2_AWP_CLASSNAME				"weapon_sniper_awp"                  // L4D2 AWP Sniper Rifle (less common, but exists)

#define GAMEDATA_FILE					"l4d_wlimits"
#define BANNED_SNIPERS_FILE				"data/banned_snipers.txt"
#define SOUND_NAME						"player/suit_denydevice.wav"

public Plugin myinfo = {
	name = "Player Sniper Ban",
	author = "StarterX4, Gemini Code Assist",
	description = "Bans usage of L4D2 sniper rifles (Scout Rifle, Military Sniper, AWP) for selected players.",
	version = PLUGIN_VERSION,
	url = "https://kether.pl"
};

bool g_bIsSniperBanned[MAXPLAYERS + 1];
ConVar g_cvEnableMessages;
int g_iLastSniperDenyMessageTick[MAXPLAYERS + 1]; // For message cooldown
ConVar g_cvMessageCooldown;
Handle hSDKGiveDefaultAmmo; // For CWeaponAmmoSpawn_Use
char g_sBannedSnipersFilePath[PLATFORM_MAX_PATH];

public void OnPluginStart() {
	CreateConVar("sm_sniperban_version", PLUGIN_VERSION, "Player Sniper Ban Plugin Version", FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_REPLICATED);
	g_cvEnableMessages = CreateConVar("sm_sniperban_messages", "0", "Enable messages to players about sniper restrictions (0=off, 1=on).", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvMessageCooldown = CreateConVar("sm_sniperban_message_cooldown", "2.0", "Minimum time in seconds between sniper restriction messages to the same player.", FCVAR_NONE, true, 0.5);

	RegAdminCmd("sm_bansnipers", Command_BanSnipers, ADMFLAG_BAN, "sm_bansnipers <#userid|name> - Bans a player from using sniper rifles.");
	RegAdminCmd("sm_unbansnipers", Command_UnbanSnipers, ADMFLAG_BAN, "sm_unbansnipers <#userid|name|steamid> - Unbans a player or SteamID from using sniper rifles.");

	BuildPath(Path_SM, g_sBannedSnipersFilePath, sizeof(g_sBannedSnipersFilePath), BANNED_SNIPERS_FILE);

	// Ensure the ban file exists
	if (!FileExists(g_sBannedSnipersFilePath)) {
		OpenFile(g_sBannedSnipersFilePath, "w").Close();
	}

	// Initialize for players already in the server
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}

	InitSDKCall();
	PrecacheSound(SOUND_NAME, true);
}

void InitSDKCall() {
	Handle hConf = LoadGameConfigFile(GAMEDATA_FILE);
	if (hConf == null) {
		SetFailState("Gamedata file '%s.txt' missing or invalid.", GAMEDATA_FILE);
		return;
	}

	StartPrepSDKCall(SDKCall_Entity);
	if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CWeaponAmmoSpawn_Use")) {
		SetFailState("Failed to find signature 'CWeaponAmmoSpawn_Use' in gamedata file '%s.txt'.", GAMEDATA_FILE);
		CloseHandle(hConf);
		return;
	}
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer); // pPlayer
	hSDKGiveDefaultAmmo = EndPrepSDKCall();
	CloseHandle(hConf);

	if (hSDKGiveDefaultAmmo == null) {
		SetFailState("Failed to create SDKCall for CWeaponAmmoSpawn_Use.");
	}
}

public void OnClientPutInServer(int client) {
	g_bIsSniperBanned[client] = false; // Reset ban status on connect
	g_iLastSniperDenyMessageTick[client] = 0; // Reset message cooldown tick
	char steamId[64];
	if (GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId))) {
		if (IsSteamIdBannedInFile(steamId)) {
			g_bIsSniperBanned[client] = true;
			if (g_cvEnableMessages.BoolValue) {
				PrintToChat(client, "[SM] Your sniper rifle usage is currently restricted on this server.");
			}
		}
	}
	SDKHook(client, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
}

public void OnClientDisconnect(int client) {
	SDKUnhook(client, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
}

public Action Command_BanSnipers(int admin, int args) {
	if (args < 1) {
		ReplyToCommand(admin, "[SM] Usage: sm_bansnipers <#userid|name>");
		return Plugin_Handled;
	}

	char sTarget[64];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	char sTargetName[MAX_TARGET_LENGTH];
	int[] iTargets = new int[MAXPLAYERS];
	int iNumTargets;
	bool bML = false; // Not using multiple target logic here

	if ((iNumTargets = ProcessTargetString(
			sTarget,
			admin,
			iTargets,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED,
			sTargetName,
			sizeof(sTargetName),
			bML)) <= 0) {
		ReplyToTargetError(admin, iNumTargets);
		return Plugin_Handled;
	}

	if (iNumTargets > 1) {
		 ReplyToCommand(admin, "[SM] Cannot ban snipers for multiple players at once. Matched: %s", sTargetName);
		 return Plugin_Handled;
	}

	int targetClient = iTargets[0];

	if (!IsClientValidAndInGame(targetClient)) {
		ReplyToCommand(admin, "[SM] Target player (%s) not found or not fully in game.", sTargetName);
		return Plugin_Handled;
	}

	char steamId[64];
	if (GetClientAuthId(targetClient, AuthId_Steam2, steamId, sizeof(steamId))) {
		AddSteamIdToBanFile(steamId);
		g_bIsSniperBanned[targetClient] = true;
		LogAction(admin, targetClient, "\"%L\" banned sniper usage for \"%L\" (SteamID: %s)", admin, targetClient, steamId);
		PrintToChat(admin, "[SM] %N (SteamID: %s) is now BANNED from using sniper rifles.", targetClient, steamId);
		if (g_cvEnableMessages.BoolValue) {
			PrintToChat(targetClient, "[SM] An admin has BANNED you from using sniper rifles.");
		}
	}
	return Plugin_Handled;
}

public Action Command_UnbanSnipers(int admin, int args) {
	if (args < 1) {
		ReplyToCommand(admin, "[SM] Usage: sm_unbansnipers <#userid|name>");
		ReplyToCommand(admin, "[SM] Example: sm_unbansnipers STEAM_0:1:123456");
		return Plugin_Handled;
	}

	char sIdentifier[64];
	GetCmdArg(1, sIdentifier, sizeof(sIdentifier));

	char steamIdToUnban[64] = "";
	int targetClient = -1;

	// Check if the identifier is a SteamID
	if (StrContains(sIdentifier, "STEAM_", false) == 0 || StrContains(sIdentifier, "[U:", false) == 0) {
		strcopy(steamIdToUnban, sizeof(steamIdToUnban), sIdentifier);
		// Try to find if this SteamID belongs to an online player
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i)) {
				char currentSteamId[64];
				if (GetClientAuthId(i, AuthId_Steam2, currentSteamId, sizeof(currentSteamId)) && StrEqual(currentSteamId, steamIdToUnban)) {
					targetClient = i;
					break;
				}
			}
		}
	} else {
		// Treat as name or #userid
		char sTargetName[MAX_TARGET_LENGTH];
		int[] iTargets = new int[MAXPLAYERS];
		int iNumTargets;
		bool bML = false;

		if ((iNumTargets = ProcessTargetString(sIdentifier, admin, iTargets, MAXPLAYERS, COMMAND_FILTER_CONNECTED, sTargetName, sizeof(sTargetName), bML)) <= 0) {
			ReplyToTargetError(admin, iNumTargets);
			return Plugin_Handled;
		}
		if (iNumTargets > 1) {
			ReplyToCommand(admin, "[SM] Cannot unban snipers for multiple players at once. Matched: %s", sTargetName);
			return Plugin_Handled;
		}
		targetClient = iTargets[0];
		if (!GetClientAuthId(targetClient, AuthId_Steam2, steamIdToUnban, sizeof(steamIdToUnban))) {
			ReplyToCommand(admin, "[SM] Could not retrieve SteamID for %N.", targetClient);
			return Plugin_Handled;
		}
	}

	if (steamIdToUnban[0] == '\0') {
		ReplyToCommand(admin, "[SM] Invalid target or SteamID provided: %s", sIdentifier);
		return Plugin_Handled;
	}

	if (RemoveSteamIdFromBanFile(steamIdToUnban)) {
		if (targetClient != -1 && IsClientValidAndInGame(targetClient)) {
			g_bIsSniperBanned[targetClient] = false;
			LogAction(admin, targetClient, "\"%L\" UNBANNED sniper usage for \"%L\" (SteamID: %s)", admin, targetClient, steamIdToUnban);
			PrintToChat(admin, "[SM] %N (SteamID: %s) is NO LONGER banned from using sniper rifles.", targetClient, steamIdToUnban);
			if (g_cvEnableMessages.BoolValue) {
				PrintToChat(targetClient, "[SM] An admin has UNBANNED you from using sniper rifles.");
			}
		} else {
			// Player is offline or was specified by SteamID directly
			LogAction(admin, -1, "\"%L\" UNBANNED sniper usage for SteamID \"%s\"", admin, steamIdToUnban);
			PrintToChat(admin, "[SM] SteamID %s is NO LONGER banned from using sniper rifles.", steamIdToUnban);
		}
	} else {
		PrintToChat(admin, "[SM] SteamID %s was not found in the sniper ban list.", steamIdToUnban);
	}
	return Plugin_Handled;
}

bool IsBannedL4D2Sniper(const char[] weaponClass) {
	return StrEqual(weaponClass, L4D2_HUNTING_RIFLE_CLASSNAME, false) ||
	       StrEqual(weaponClass, L4D2_MILITARY_SNIPER_CLASSNAME, false) ||
	       StrEqual(weaponClass, L4D2_AWP_CLASSNAME, false);
}

public Action Hook_WeaponCanUse(int client, int weapon) {
	// If client is not valid, not in game, or not banned for snipers, let them use the weapon.
	if (!IsClientValidAndInGame(client) || !g_bIsSniperBanned[client]) {
		return Plugin_Continue;
	}

	// If the weapon entity is invalid, continue (should not happen often).
	if (!IsValidEntity(weapon) || !IsValidEdict(weapon)) {
		return Plugin_Continue;
	}

	char sWeaponClass[64];
	GetEdictClassname(weapon, sWeaponClass, sizeof(sWeaponClass));

	if (IsBannedL4D2Sniper(sWeaponClass)) {
		// if (g_cvEnableMessages.BoolValue) {
			// Message cooldown: Check if enough time has passed since the last message.
			// GetTickInterval() returns seconds per tick. Cooldown is in seconds.
			// Ticks to wait = cooldown_seconds / seconds_per_tick
			int ticksToWait = RoundFloat(g_cvMessageCooldown.FloatValue / GetTickInterval());
			if (GetGameTickCount() - g_iLastSniperDenyMessageTick[client] >= ticksToWait) {
				SDKCall(hSDKGiveDefaultAmmo, 0, client); // Give him ammo instead.
				PrintToChat(client, "[SM] You cannot use this sniper rifle (%s). Usage is restricted for you.", sWeaponClass);
				EmitSoundToClient(client, SOUND_NAME);
				g_iLastSniperDenyMessageTick[client] = GetGameTickCount();
			// }
		}
		return Plugin_Handled; // Deny usage/pickup
	}

	// If it's not a banned sniper, or the player isn't banned, let them use it.
		return Plugin_Continue;
}

// Helper: Checks if a client index is valid and the client is connected and in-game.
bool IsClientValidAndInGame(int client) {
	return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client);
}

bool IsSteamIdBannedInFile(const char[] steamId) {
	File file = OpenFile(g_sBannedSnipersFilePath, "r");
	if (file == null) {
		LogError("Could not open sniper ban file for reading: %s", g_sBannedSnipersFilePath);
		return false;
	}

	char line[64];
	bool found = false;
	while (file.ReadLine(line, sizeof(line))) {
		TrimString(line);
		if (StrEqual(line, steamId, false)) {
			found = true;
			break;
		}
	}
	file.Close();
	return found;
}

void AddSteamIdToBanFile(const char[] steamId) {
	if (IsSteamIdBannedInFile(steamId)) {
		return; // Already banned
	}

	File file = OpenFile(g_sBannedSnipersFilePath, "a"); // Append mode
	if (file == null) {
		LogError("Could not open sniper ban file for appending: %s", g_sBannedSnipersFilePath);
		return;
	}
	file.WriteLine("%s", steamId);
	file.Close();
}

bool RemoveSteamIdFromBanFile(const char[] steamId) {
	char tempFilePath[PLATFORM_MAX_PATH];
	FormatEx(tempFilePath, sizeof(tempFilePath), "%s.tmp", g_sBannedSnipersFilePath);

	File originalFile = OpenFile(g_sBannedSnipersFilePath, "r");
	if (originalFile == null) {
		LogError("Error opening original sniper ban file for reading: %s", g_sBannedSnipersFilePath);
		return false;
	}

	File tempFile = OpenFile(tempFilePath, "w");
	if (originalFile == null || tempFile == null) {
		LogError("Error opening files for sniper ban removal. Original: '%s', Temp: '%s'", g_sBannedSnipersFilePath, tempFilePath);
		if (originalFile != null) originalFile.Close();
		if (tempFile != null) tempFile.Close();
		return false;
	}

	char line[64];
	bool steamIdFound = false;
	while (originalFile.ReadLine(line, sizeof(line))) {
		TrimString(line);
		if (StrEqual(line, steamId, false)) {
			steamIdFound = true;
			// Skip writing this line to remove it
		} else {
			tempFile.WriteLine("%s", line);
		}
	}
	// It's crucial to close files before attempting to rename or delete them.
	originalFile.Close();
	tempFile.Close();

	if (steamIdFound) {
		// Attempt to replace the original file with the (modified) temporary file.
		// RenameFile(newPath, oldPath)
		if (!RenameFile(g_sBannedSnipersFilePath, tempFilePath)) {
			LogError("Failed to rename temporary ban file '%s' to '%s'. Ban removal for SteamID '%s' might not be permanent.", tempFilePath, g_sBannedSnipersFilePath, steamId);
			// Attempt to clean up the temporary file if rename failed
			if (!DeleteFile(tempFilePath)) {
				LogError("Additionally, failed to delete temporary ban file '%s' after rename failure.", tempFilePath);
			}
			return false; // Indicate that the file operation failed
		}
		// Rename was successful
		return true;
	} else {
		// SteamID was not found in the file, so no changes were made to the content.
		// Delete the temporary file as it's either empty or a copy of the original.
		if (!DeleteFile(tempFilePath)) {
			LogError("SteamID '%s' was not found in the ban list, and also failed to delete the temporary file '%s'.", steamId, tempFilePath);
		}
		return false; // SteamID not found, so it wasn't "removed".
	}
}
