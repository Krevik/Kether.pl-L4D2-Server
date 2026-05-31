/*
 * DEPRECATED — use l4d2_si_materialize_cue.sp (hooks materialize, correct switch, channel cvars).
 *
 * Plugin: L4D2 Special Infected Spawn Alerts
 * Author: StarterX4, Gemini Code Assist
 * Version: 0.1
 * Description: Plays a sound when a Special Infected (Jockey, Hunter, Spitter, Boomer, Charger, Tank, Smoker) spawns.
 * License: GNU GPLv3
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define TEAM_INFECTED 3

// Zombie classes
#define ZC_SMOKER  1
#define ZC_BOOMER  2
#define ZC_HUNTER  3
#define ZC_SPITTER 4
#define ZC_JOCKEY  5
#define ZC_CHARGER 6
#define ZC_TANK    8

// --- Sound Definitions ---
stock const char g_sJockeySound[][] =
{
	"player/jockey/voice/alert/jockey_02.wav",
	"player/jockey/voice/alert/jockey_04.wav",
	"player/jockey/voice/idle/jockey_spotprey_01.wav",
	"player/jockey/voice/idle/jockey_spotprey_02.wav",
	"player/jockey/voice/idle/jockey_recognize02.wav",
	"player/jockey/voice/idle/jockey_recognize06.wav",
	"player/jockey/voice/idle/jockey_recognize07.wav",
	"player/jockey/voice/idle/jockey_recognize08.wav"
};

stock const char g_sHunterSound[][] =
{
	"player/hunter/voice/alert/hunter_alert_01.wav",
	"player/hunter/voice/alert/hunter_alert_02.wav",
	"player/hunter/voice/alert/hunter_alert_03.wav",
	"player/hunter/voice/alert/hunter_alert_04.wav",
	"player/hunter/voice/alert/hunter_alert_05.wav"
};

stock const char g_sSpitterSound[][] =
{
	"player/spitter/voice/alert/spitter_alert_01.wav",
	"player/spitter/voice/alert/spitter_alert_02.wav",
	"player/spitter/voice/idle/spitter_spotprey_03.wav",
	"player/spitter/voice/idle/spitter_spotprey_06.wav"
};

stock const char g_sBoomerSound[][] =
{
	"player/boomer/voice/idle/male_boomer_lurk_01.wav",
	"player/boomer/voice/idle/male_boomer_lurk_02.wav",
	"player/boomer/voice/idle/male_boomer_lurk_03.wav",
	"player/boomer/voice/idle/male_boomer_lurk_04.wav",
	"player/boomer/voice/idle/male_boomer_lurk_09.wav",
	"player/boomer/voice/idle/male_boomer_lurk_08.wav",
	"player/boomer/voice/idle/male_boomer_lurk_07.wav",
	"player/boomer/voice/idle/male_boomer_lurk_06.wav",
	"player/boomer/voice/idle/male_boomer_lurk_05.wav",
	"player/boomer/voice/idle/male_boomer_lurk_10.wav",
	"player/boomer/voice/idle/male_boomer_lurk_15.wav",
	"player/boomer/voice/idle/male_boomer_lurk_12.wav",
	"player/boomer/voice/idle/male_boomer_lurk_13.wav",
	"player/boomer/voice/idle/male_boomer_lurk_14.wav"
};

stock const char g_sChargerSound[][] =
{
	"player/charger/voice/alert/charger_alert_01.wav",
	"player/charger/voice/alert/charger_alert_02.wav",
	"player/charger/voice/idle/charger_lurk_16.wav",
	"player/charger/voice/idle/charger_lurk_06.wav"
};

stock const char g_sTankSound[][] =
{
	"npc/tank/voice/idle/tank_growl_01.wav", // Tanks often use NPC paths
	"npc/tank/voice/idle/tank_growl_02.wav",
	"npc/tank/voice/idle/tank_growl_03.wav",
	"npc/tank/voice/idle/tank_growl_09.wav"
};

stock const char g_sSmokerSound[][] =
{
	"player/smoker/voice/alert/smoker_alert_01.wav",
	"player/smoker/voice/alert/smoker_alert_02.wav",
	"player/smoker/voice/alert/smoker_alert_03.wav",
	"player/smoker/voice/alert/smoker_alert_04.wav",
	"player/smoker/voice/alert/smoker_alert_05.wav",
	"player/smoker/voice/alert/smoker_alert_06.wav"
};

public Plugin myinfo =
{
	name = "L4D2 Special Infected Spawn Alerts",
	author = "StarterX4, Gemini Code Assist",
	description = "Plays a sound when a Special Infected spawns.",
	version = "0.1",
	url = "https://github.com/Krevik/Kether.pl-L4D2-Server"
};

public void OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);
}

public void OnMapStart()
{
	PrecacheSoundArray(g_sJockeySound, sizeof(g_sJockeySound));
	PrecacheSoundArray(g_sHunterSound, sizeof(g_sHunterSound));
	PrecacheSoundArray(g_sSpitterSound, sizeof(g_sSpitterSound));
	PrecacheSoundArray(g_sBoomerSound, sizeof(g_sBoomerSound));
	PrecacheSoundArray(g_sChargerSound, sizeof(g_sChargerSound));
	PrecacheSoundArray(g_sTankSound, sizeof(g_sTankSound));
	PrecacheSoundArray(g_sSmokerSound, sizeof(g_sSmokerSound));
}

stock void PrecacheSoundArray(const char[][] sounds, int numSounds)
{
	for (int i = 0; i < numSounds; i++)
	{
		if (sounds[i][0] != '\0') // Ensure the sound string is not empty
		{
			PrecacheSound(sounds[i], true);
		}
	}
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client < 1 || !IsClientInGame(client) || GetClientTeam(client) != TEAM_INFECTED)
	{
		return;
	}

	// We only want to play a sound if the player is actually alive and spawning as an SI.
	// The player_spawn event can fire in various scenarios, including taking over bots.
	if (!IsPlayerAlive(client))
	{
		return;
	}

	int zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	char selectedSound[PLATFORM_MAX_PATH];
	selectedSound[0] = '\0'; // Initialize to empty string

	switch (zombieClass)
	{
		case ZC_JOCKEY:		if (sizeof(g_sJockeySound) > 0) strcopy(selectedSound, sizeof(selectedSound), g_sJockeySound[GetRandomInt(0, sizeof(g_sJockeySound) - 1)]);
		case ZC_HUNTER:		if (sizeof(g_sHunterSound) > 0) strcopy(selectedSound, sizeof(selectedSound), g_sHunterSound[GetRandomInt(0, sizeof(g_sHunterSound) - 1)]);
		case ZC_SPITTER:	if (sizeof(g_sSpitterSound) > 0) strcopy(selectedSound, sizeof(selectedSound), g_sSpitterSound[GetRandomInt(0, sizeof(g_sSpitterSound) - 1)]);
		case ZC_BOOMER:		if (sizeof(g_sBoomerSound) > 0) strcopy(selectedSound, sizeof(selectedSound), g_sBoomerSound[GetRandomInt(0, sizeof(g_sBoomerSound) - 1)]);
		case ZC_CHARGER:	if (sizeof(g_sChargerSound) > 0) strcopy(selectedSound, sizeof(selectedSound), g_sChargerSound[GetRandomInt(0, sizeof(g_sChargerSound) - 1)]);
		case ZC_TANK:		if (sizeof(g_sTankSound) > 0) strcopy(selectedSound, sizeof(selectedSound), g_sTankSound[GetRandomInt(0, sizeof(g_sTankSound) - 1)]);
		case ZC_SMOKER:		if (sizeof(g_sSmokerSound) > 0) strcopy(selectedSound, sizeof(selectedSound), g_sSmokerSound[GetRandomInt(0, sizeof(g_sSmokerSound) - 1)]);
	}

	if (selectedSound[0] != '\0')
	{
		EmitSoundToAll(selectedSound, client, SNDCHAN_VOICE, SNDLEVEL_SCREAMING); // SNDLVL_SCREAMING is 90dB
	}
}
