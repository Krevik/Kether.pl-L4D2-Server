#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks> // Required for SDKHook_WeaponCanUse
#include <sdktools> // Required for InitSDKCall

#define PLUGIN_VERSION "0.1.0"

// L4D2 Sniper Rifle Classnames
#define L4D2_HUNTING_RIFLE_CLASSNAME	"weapon_sniper_scout"      // L4D2 Hunting Rifle (classname is weapon_sniper_scout)
#define L4D2_MILITARY_SNIPER_CLASSNAME	"weapon_sniper_military" // L4D2 Military Sniper Rifle
#define L4D2_AWP_CLASSNAME				"weapon_sniper_awp"                  // L4D2 AWP Sniper Rifle (less common, but exists)
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
Handle hSDKGiveDefaultAmmo;

public void OnPluginStart() {
	CreateConVar("sm_sniperban_version", PLUGIN_VERSION, "Player Sniper Ban Plugin Version", FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_REPLICATED);
	g_cvEnableMessages = CreateConVar("sm_sniperban_messages", "1", "Enable messages to players about sniper restrictions (0=off, 1=on).", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvMessageCooldown = CreateConVar("sm_sniperban_message_cooldown", "2.0", "Minimum time in seconds between sniper restriction messages to the same player.", FCVAR_NONE, true, 0.5);

	RegAdminCmd("sm_bansnipers", Command_BanSnipers, ADMFLAG_KICK, "sm_bansnipers <#userid|name> - Bans a player from using sniper rifles.");
	RegAdminCmd("sm_unbansnipers", Command_UnbanSnipers, ADMFLAG_KICK, "sm_unbansnipers <#userid|name> - Unbans a player from using sniper rifles.");

	// Initialize for players already in the server
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}
}

public void OnClientPutInServer(int client) {
	g_bIsSniperBanned[client] = false; // Reset ban status on connect
	g_iLastSniperDenyMessageTick[client] = 0; // Reset message cooldown tick
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

	g_bIsSniperBanned[targetClient] = true;
	LogAction(admin, targetClient, "\"%L\" banned sniper usage for \"%L\"", admin, targetClient);
	PrintToChat(admin, "[SM] %N is now BANNED from using sniper rifles.", targetClient);
	if (g_cvEnableMessages.BoolValue) {
		PrintToChat(targetClient, "[SM] An admin has BANNED you from using sniper rifles.");
	}
	return Plugin_Handled;
}

public Action Command_UnbanSnipers(int admin, int args) {
	if (args < 1) {
		ReplyToCommand(admin, "[SM] Usage: sm_unbansnipers <#userid|name>");
		return Plugin_Handled;
	}

	char sTarget[64];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	char sTargetName[MAX_TARGET_LENGTH];
	int[] iTargets = new int[MAXPLAYERS];
	int iNumTargets;
	bool bML = false;

	if ((iNumTargets = ProcessTargetString(
			sTarget,
			admin,
			iTargets,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED, // Target should be connected to unban session ban
			sTargetName,
			sizeof(sTargetName),
			bML)) <= 0) {
		ReplyToTargetError(admin, iNumTargets);
		return Plugin_Handled;
	}

	if (iNumTargets > 1) {
		 ReplyToCommand(admin, "[SM] Cannot unban snipers for multiple players at once. Matched: %s", sTargetName);
		 return Plugin_Handled;
	}

	int targetClient = iTargets[0];

	// targetClient is a valid client index due to ProcessTargetString
	g_bIsSniperBanned[targetClient] = false;
	LogAction(admin, targetClient, "\"%L\" UNBANNED sniper usage for \"%L\"", admin, targetClient);
	PrintToChat(admin, "[SM] %N is NO LONGER banned from using sniper rifles.", targetClient);
	if (IsClientInGame(targetClient) && g_cvEnableMessages.BoolValue) {
		PrintToChat(targetClient, "[SM] An admin has UNBANNED you from using sniper rifles.");
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
		if (g_cvEnableMessages.BoolValue) {
			// Message cooldown: Check if enough time has passed since the last message.
			// GetTickInterval() returns seconds per tick. Cooldown is in seconds.
			// Ticks to wait = cooldown_seconds / seconds_per_tick
			int ticksToWait = RoundFloat(g_cvMessageCooldown.FloatValue / GetTickInterval());
			if (GetGameTickCount() - g_iLastSniperDenyMessageTick[client] >= ticksToWait) {
				SDKCall(hSDKGiveDefaultAmmo, 0, client); // Give him ammo instead.
				PrintToChat(client, "[SM] You cannot use this sniper rifle (%s). Usage is restricted for you.", sWeaponClass);
				EmitSoundToClient(client, SOUND_NAME);
				g_iLastSniperDenyMessageTick[client] = GetGameTickCount();
			}
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
