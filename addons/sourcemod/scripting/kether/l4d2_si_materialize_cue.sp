/*
 * L4D2 SI Materialize Cue (Kether)
 *
 * One spawn-in vocal per SI when materializing from ghost.
 *
 * Mode 1 (replace): block Valve spawn alert/lurk vocals during the cue window,
 *   then play exactly one cue from vanilla asset pools.
 * Mode 0 (fill gaps): only play if Valve did not already play a spawn vocal.
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "1.3.0"

#define CUE_MODE_FILL_GAPS 0
#define CUE_MODE_REPLACE   1

#define TEAM_INFECTED 3
#define MAX_GHOST_WAIT_FRAMES 12

#define ZC_SMOKER  1
#define ZC_BOOMER  2
#define ZC_HUNTER  3
#define ZC_SPITTER 4
#define ZC_JOCKEY  5
#define ZC_CHARGER 6
#define ZC_TANK    8

#define CUE_SMOKER  (1 << 0)
#define CUE_BOOMER  (1 << 1)
#define CUE_HUNTER  (1 << 2)
#define CUE_SPITTER (1 << 3)
#define CUE_JOCKEY  (1 << 4)
#define CUE_CHARGER (1 << 5)
#define CUE_TANK    (1 << 6)

ConVar g_CvarEnable;
ConVar g_CvarMode;
ConVar g_CvarChannel;
ConVar g_CvarLevel;
ConVar g_CvarClasses;
ConVar g_CvarDelay;

float g_flMaterializeAt[MAXPLAYERS + 1];
bool g_bVanillaSpawnVocal[MAXPLAYERS + 1];
bool g_bPluginEmittingCue[MAXPLAYERS + 1];
bool g_bCuePending[MAXPLAYERS + 1];
bool g_bCuePlayedThisSpawn[MAXPLAYERS + 1];
int g_iGhostWaitFrames[MAXPLAYERS + 1];

stock const char g_sJockeyCue[][] = {
	"player/jockey/voice/alert/jockey_02.wav",
	"player/jockey/voice/alert/jockey_04.wav",
	"player/jockey/voice/idle/jockey_spotprey_01.wav",
	"player/jockey/voice/idle/jockey_spotprey_02.wav",
};

stock const char g_sHunterCue[][] = {
	"player/hunter/voice/alert/hunter_alert_01.wav",
	"player/hunter/voice/alert/hunter_alert_02.wav",
	"player/hunter/voice/alert/hunter_alert_03.wav",
	"player/hunter/voice/alert/hunter_alert_04.wav",
	"player/hunter/voice/alert/hunter_alert_05.wav",
};

stock const char g_sSpitterCue[][] = {
	"player/spitter/voice/alert/spitter_alert_01.wav",
	"player/spitter/voice/alert/spitter_alert_02.wav",
	"player/spitter/voice/idle/spitter_spotprey_03.wav",
	"player/spitter/voice/idle/spitter_spotprey_06.wav",
};

stock const char g_sBoomerCue[][] = {
	"player/boomer/voice/idle/male_boomer_lurk_01.wav",
	"player/boomer/voice/idle/male_boomer_lurk_02.wav",
	"player/boomer/voice/idle/male_boomer_lurk_03.wav",
	"player/boomer/voice/idle/male_boomer_lurk_04.wav",
	"player/boomer/voice/idle/male_boomer_lurk_05.wav",
};

stock const char g_sChargerCue[][] = {
	"player/charger/voice/alert/charger_alert_01.wav",
	"player/charger/voice/alert/charger_alert_02.wav",
	"player/charger/voice/idle/charger_lurk_16.wav",
	"player/charger/voice/idle/charger_lurk_06.wav",
};

stock const char g_sSmokerCue[][] = {
	"player/smoker/voice/alert/smoker_alert_01.wav",
	"player/smoker/voice/alert/smoker_alert_02.wav",
	"player/smoker/voice/alert/smoker_alert_03.wav",
	"player/smoker/voice/alert/smoker_alert_04.wav",
	"player/smoker/voice/alert/smoker_alert_05.wav",
	"player/smoker/voice/alert/smoker_alert_06.wav",
};

stock const char g_sTankCue[][] = {
	"npc/tank/voice/idle/tank_growl_01.wav",
	"npc/tank/voice/idle/tank_growl_02.wav",
	"npc/tank/voice/idle/tank_growl_03.wav",
};

public Plugin myinfo = {
	name        = "L4D2 SI Materialize Cue",
	author      = "Kether.pl",
	description = "Controlled spawn-in vocal per SI when materializing from ghost.",
	version     = PLUGIN_VERSION,
	url         = "https://github.com/Krevik/Kether.pl-L4D2-Server",
};

public void OnPluginStart() {
	g_CvarEnable  = CreateConVar("sm_si_materialize_cue", "1",
		"Enable SI materialize spawn-in vocals (0=off, 1=on).", _, true, 0.0, true, 1.0);
	g_CvarMode    = CreateConVar("sm_si_materialize_cue_mode", "1",
		"0=fill gaps only if Valve silent, 1=replace Valve spawn vocals (one cue, no doubles).", _, true, 0.0, true, 1.0);
	g_CvarChannel = CreateConVar("sm_si_materialize_cue_channel", "2",
		"Sound channel: 2=VOICE (vanilla-like), 0=AUTO (fallback if culled).", _, true, 0.0, true, 7.0);
	g_CvarLevel   = CreateConVar("sm_si_materialize_cue_level", "95",
		"Sound level (dB) for the cue.", _, true, 60.0, true, 110.0);
	g_CvarClasses = CreateConVar("sm_si_materialize_cue_classes", "63",
		"Bitmask: 1=Smoker, 2=Boomer, 4=Hunter, 8=Spitter, 16=Jockey, 32=Charger, 64=Tank.", _, true, 0.0, true, 127.0);
	g_CvarDelay   = CreateConVar("sm_si_materialize_cue_delay", "0.12",
		"Seconds after materialize/spawn before playing the cue.", _, true, 0.0, true, 1.0);

	AddNormalSoundHook(SoundHook_Materialize);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_PostNoCopy);

	AutoExecConfig(true, "l4d2_si_materialize_cue", "sourcemod");
}

public void OnClientDisconnect(int client) {
	ResetClientCueState(client);
}

public void OnMapStart() {
	PrecacheCueArray(g_sJockeyCue, sizeof(g_sJockeyCue));
	PrecacheCueArray(g_sHunterCue, sizeof(g_sHunterCue));
	PrecacheCueArray(g_sSpitterCue, sizeof(g_sSpitterCue));
	PrecacheCueArray(g_sBoomerCue, sizeof(g_sBoomerCue));
	PrecacheCueArray(g_sChargerCue, sizeof(g_sChargerCue));
	PrecacheCueArray(g_sSmokerCue, sizeof(g_sSmokerCue));
	PrecacheCueArray(g_sTankCue, sizeof(g_sTankCue));
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0) {
		ResetClientCueState(client);
	}
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	if (!g_CvarEnable.BoolValue) {
		return;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidLiveSI(client)) {
		return;
	}

	// Materialize forward usually schedules first; this catches late !ghost spawns.
	if (g_bCuePending[client] || g_bCuePlayedThisSpawn[client]) {
		return;
	}

	ScheduleMaterializeCue(client);
}

public void L4D_OnMaterializeFromGhost(int client) {
	if (!g_CvarEnable.BoolValue || !IsClientInGame(client) || GetClientTeam(client) != TEAM_INFECTED) {
		return;
	}

	g_bCuePlayedThisSpawn[client] = false;
	ScheduleMaterializeCue(client);
}

void ScheduleMaterializeCue(int client) {
	if (!IsClientInGame(client) || GetClientTeam(client) != TEAM_INFECTED) {
		return;
	}

	if (g_bCuePending[client]) {
		return;
	}

	g_bCuePending[client] = true;
	g_flMaterializeAt[client] = GetGameTime();
	g_bVanillaSpawnVocal[client] = false;
	g_iGhostWaitFrames[client] = 0;

	float delay = g_CvarDelay.FloatValue;
	if (delay <= 0.0) {
		RequestFrame(OnCueAttemptFrame, GetClientUserId(client));
	} else {
		CreateTimer(delay, Timer_CueAttempt, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

void OnCueAttemptFrame(any userid) {
	AttemptMaterializeCue(GetClientOfUserId(userid));
}

Action Timer_CueAttempt(Handle timer, int userid) {
	AttemptMaterializeCue(GetClientOfUserId(userid));
	return Plugin_Stop;
}

void AttemptMaterializeCue(int client) {
	if (client < 1 || !IsClientInGame(client)) {
		ResetClientCueState(client);
		return;
	}

	if (!IsPlayerAlive(client) || GetClientTeam(client) != TEAM_INFECTED) {
		ResetClientCueState(client);
		return;
	}

	if (GetEntProp(client, Prop_Send, "m_isGhost")) {
		g_iGhostWaitFrames[client]++;
		if (g_iGhostWaitFrames[client] <= MAX_GHOST_WAIT_FRAMES) {
			RequestFrame(OnCueAttemptFrame, GetClientUserId(client));
			return;
		}

		ResetClientCueState(client);
		return;
	}

	TryPlayMaterializeCue(client);
}

void TryPlayMaterializeCue(int client) {
	g_bCuePending[client] = false;

	if (!IsValidLiveSI(client)) {
		ClearMaterializeWatch(client);
		return;
	}

	int zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (!IsClassEnabled(zombieClass)) {
		ClearMaterializeWatch(client);
		return;
	}

	if (g_bCuePlayedThisSpawn[client]) {
		ClearMaterializeWatch(client);
		return;
	}

	if (g_CvarMode.IntValue == CUE_MODE_FILL_GAPS && g_bVanillaSpawnVocal[client]) {
		ClearMaterializeWatch(client);
		return;
	}

	char sound[PLATFORM_MAX_PATH];
	if (!PickCueSound(zombieClass, sound, sizeof(sound))) {
		ClearMaterializeWatch(client);
		return;
	}

	int sndChannel = g_CvarChannel.IntValue;
	if (sndChannel < 0) {
		sndChannel = SNDCHAN_AUTO;
	}

	float origin[3];
	GetClientAbsOrigin(client, origin);

	// End the block window before emitting so our cue cannot be stopped by the hook.
	ClearMaterializeWatch(client);

	g_bPluginEmittingCue[client] = true;
	EmitSoundToAll(sound, client, sndChannel, g_CvarLevel.IntValue, SND_NOFLAGS, 1.0, 100, -1, origin);
	g_bPluginEmittingCue[client] = false;

	g_bCuePlayedThisSpawn[client] = true;
}

bool IsValidLiveSI(int client) {
	return client > 0
		&& client <= MaxClients
		&& IsClientInGame(client)
		&& IsPlayerAlive(client)
		&& GetClientTeam(client) == TEAM_INFECTED
		&& !GetEntProp(client, Prop_Send, "m_isGhost");
}

Action SoundHook_Materialize(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],
	int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,
	char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (entity < 1 || entity > MaxClients || g_flMaterializeAt[entity] <= 0.0) {
		return Plugin_Continue;
	}

	if (g_bPluginEmittingCue[entity]) {
		return Plugin_Continue;
	}

	if (!IsClientInGame(entity) || GetClientTeam(entity) != TEAM_INFECTED) {
		return Plugin_Continue;
	}

	if (!IsSpawnInVocalSample(sample)) {
		return Plugin_Continue;
	}

	if (g_CvarMode.IntValue == CUE_MODE_REPLACE) {
		return Plugin_Stop;
	}

	g_bVanillaSpawnVocal[entity] = true;
	return Plugin_Continue;
}

void ClearMaterializeWatch(int client) {
	g_flMaterializeAt[client] = 0.0;
	g_bVanillaSpawnVocal[client] = false;
}

void ResetClientCueState(int client) {
	ClearMaterializeWatch(client);
	g_bPluginEmittingCue[client] = false;
	g_bCuePending[client] = false;
	g_bCuePlayedThisSpawn[client] = false;
	g_iGhostWaitFrames[client] = 0;
}

bool IsSpawnInVocalSample(const char[] sample) {
	if (StrContains(sample, "/voice/", false) == -1) {
		return false;
	}

	return StrContains(sample, "/alert/", false) != -1
		|| StrContains(sample, "lurk", false) != -1
		|| StrContains(sample, "spotprey", false) != -1
		|| StrContains(sample, "growl", false) != -1;
}

bool IsClassEnabled(int zombieClass) {
	int mask = g_CvarClasses.IntValue;

	switch (zombieClass) {
		case ZC_SMOKER:  return (mask & CUE_SMOKER) != 0;
		case ZC_BOOMER:  return (mask & CUE_BOOMER) != 0;
		case ZC_HUNTER:  return (mask & CUE_HUNTER) != 0;
		case ZC_SPITTER: return (mask & CUE_SPITTER) != 0;
		case ZC_JOCKEY:  return (mask & CUE_JOCKEY) != 0;
		case ZC_CHARGER: return (mask & CUE_CHARGER) != 0;
		case ZC_TANK:    return (mask & CUE_TANK) != 0;
	}

	return false;
}

bool PickCueSound(int zombieClass, char[] buffer, int maxlen) {
	switch (zombieClass) {
		case ZC_JOCKEY:  return PickFromArray(g_sJockeyCue, sizeof(g_sJockeyCue), buffer, maxlen);
		case ZC_HUNTER:  return PickFromArray(g_sHunterCue, sizeof(g_sHunterCue), buffer, maxlen);
		case ZC_SPITTER: return PickFromArray(g_sSpitterCue, sizeof(g_sSpitterCue), buffer, maxlen);
		case ZC_BOOMER:  return PickFromArray(g_sBoomerCue, sizeof(g_sBoomerCue), buffer, maxlen);
		case ZC_CHARGER: return PickFromArray(g_sChargerCue, sizeof(g_sChargerCue), buffer, maxlen);
		case ZC_SMOKER:  return PickFromArray(g_sSmokerCue, sizeof(g_sSmokerCue), buffer, maxlen);
		case ZC_TANK:    return PickFromArray(g_sTankCue, sizeof(g_sTankCue), buffer, maxlen);
	}

	return false;
}

bool PickFromArray(const char[][] sounds, int count, char[] buffer, int maxlen) {
	if (count <= 0) {
		return false;
	}

	strcopy(buffer, maxlen, sounds[GetRandomInt(0, count - 1)]);
	return buffer[0] != '\0';
}

void PrecacheCueArray(const char[][] sounds, int count) {
	for (int i = 0; i < count; i++) {
		if (sounds[i][0] != '\0') {
			PrecacheSound(sounds[i], true);
		}
	}
}
