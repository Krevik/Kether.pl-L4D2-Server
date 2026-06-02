/*
 * L4D2 SI Materialize Cue (Kether)
 *
 * One spawn-in vocal per materialize when Valve does not already play one.
 * Never blocks Valve. Hunter excluded via classes bitmask (default 59).
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "1.5.0"

#define TEAM_INFECTED 3
#define MAX_GHOST_WAIT_FRAMES 30
#define SPAWN_CUE_COOLDOWN    2.5

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
ConVar g_CvarChannel;
ConVar g_CvarLevel;
ConVar g_CvarClasses;
ConVar g_CvarDelay;

bool g_bCuePending[MAXPLAYERS + 1];
bool g_bCuePlayedThisSpawn[MAXPLAYERS + 1];
bool g_bVanillaSpawnVocal[MAXPLAYERS + 1];
int g_iGhostWaitFrames[MAXPLAYERS + 1];
float g_flLastSpawnCueAt[MAXPLAYERS + 1];

stock const char g_sJockeyCue[][] = {
	"player/jockey/voice/alert/jockey_02.wav",
	"player/jockey/voice/alert/jockey_04.wav",
	"player/jockey/voice/idle/jockey_spotprey_01.wav",
	"player/jockey/voice/idle/jockey_spotprey_02.wav",
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

public Plugin myinfo = {
	name        = "L4D2 SI Materialize Cue",
	author      = "Kether.pl",
	description = "One spawn-in vocal per materialize when Valve is silent.",
	version     = PLUGIN_VERSION,
	url         = "https://github.com/Krevik/Kether.pl-L4D2-Server",
};

public void OnPluginStart() {
	g_CvarEnable  = CreateConVar("sm_si_materialize_cue", "1",
		"Enable SI materialize spawn-in vocals (0=off, 1=on).", _, true, 0.0, true, 1.0);
	g_CvarChannel = CreateConVar("sm_si_materialize_cue_channel", "0",
		"Sound channel: 0=AUTO (recommended), 2=VOICE.", _, true, 0.0, true, 7.0);
	g_CvarLevel   = CreateConVar("sm_si_materialize_cue_level", "110",
		"Sound level (dB) for the plugin cue.", _, true, 60.0, true, 120.0);
	g_CvarClasses = CreateConVar("sm_si_materialize_cue_classes", "59",
		"Bitmask: 1=Smoker, 2=Boomer, 4=Hunter, 8=Spitter, 16=Jockey, 32=Charger, 64=Tank.", _, true, 0.0, true, 127.0);
	g_CvarDelay   = CreateConVar("sm_si_materialize_cue_delay", "0.18",
		"Seconds after !ghost to wait for Valve spawn vocals before plugin cue.", _, true, 0.0, true, 1.0);

	CreateConVar("sm_si_materialize_cue_mode", "0", "Deprecated. Ignored since 1.4.", FCVAR_NOTIFY);

	AddNormalSoundHook(SoundHook_DetectVanillaSpawnVocal);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_PostNoCopy);

	AutoExecConfig(true, "l4d2_si_materialize_cue", "sourcemod");
}

public void OnClientDisconnect(int client) {
	ResetClientCueState(client);
}

public void OnMapStart() {
	PrecacheCueArray(g_sJockeyCue, sizeof(g_sJockeyCue));
	PrecacheCueArray(g_sSpitterCue, sizeof(g_sSpitterCue));
	PrecacheCueArray(g_sBoomerCue, sizeof(g_sBoomerCue));
	PrecacheCueArray(g_sChargerCue, sizeof(g_sChargerCue));
	PrecacheCueArray(g_sSmokerCue, sizeof(g_sSmokerCue));
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0) {
		ResetClientCueState(client);
	}
}

public void L4D_OnMaterializeFromGhost(int client) {
	if (!g_CvarEnable.BoolValue || !IsClientInGame(client) || GetClientTeam(client) != TEAM_INFECTED) {
		return;
	}

	// One materialize = one decision. Never reset after a cue was already handled.
	if (g_bCuePlayedThisSpawn[client] || g_bCuePending[client]) {
		return;
	}

	if (IsOnSpawnCueCooldown(client)) {
		return;
	}

	g_bVanillaSpawnVocal[client] = false;
	BeginCueAttempt(client);
}

bool IsOnSpawnCueCooldown(int client) {
	return g_flLastSpawnCueAt[client] > 0.0
		&& (GetGameTime() - g_flLastSpawnCueAt[client]) < SPAWN_CUE_COOLDOWN;
}

void BeginCueAttempt(int client) {
	g_bCuePending[client] = true;
	g_iGhostWaitFrames[client] = 0;
	RequestFrame(OnCueAttemptFrame, GetClientUserId(client));
}

void OnCueAttemptFrame(any userid) {
	AttemptMaterializeCue(GetClientOfUserId(userid));
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

	if (g_bCuePlayedThisSpawn[client]) {
		g_bCuePending[client] = false;
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

	float delay = g_CvarDelay.FloatValue;
	if (delay > 0.0) {
		CreateTimer(delay, Timer_FinalizeCue, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	} else {
		FinalizeMaterializeCue(client);
	}
}

Action Timer_FinalizeCue(Handle timer, int userid) {
	FinalizeMaterializeCue(GetClientOfUserId(userid));
	return Plugin_Stop;
}

void FinalizeMaterializeCue(int client) {
	g_bCuePending[client] = false;

	if (!IsValidLiveSI(client) || g_bCuePlayedThisSpawn[client]) {
		return;
	}

	int zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (!IsClassEnabled(zombieClass)) {
		return;
	}

	MarkSpawnCueHandled(client);

	if (g_bVanillaSpawnVocal[client]) {
		return;
	}

	char sound[PLATFORM_MAX_PATH];
	if (!PickCueSound(zombieClass, sound, sizeof(sound))) {
		return;
	}

	int sndChannel = g_CvarChannel.IntValue;
	if (sndChannel < 0) {
		sndChannel = SNDCHAN_AUTO;
	}

	float origin[3];
	GetClientAbsOrigin(client, origin);

	EmitSoundToAll(sound, client, sndChannel, g_CvarLevel.IntValue, SND_NOFLAGS, 1.0, 100, -1, origin);
}

void MarkSpawnCueHandled(int client) {
	g_bCuePlayedThisSpawn[client] = true;
	g_flLastSpawnCueAt[client] = GetGameTime();
}

Action SoundHook_DetectVanillaSpawnVocal(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],
	int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,
	char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (entity < 1 || entity > MaxClients || !g_bCuePending[entity]) {
		return Plugin_Continue;
	}

	if (!IsClientInGame(entity) || GetClientTeam(entity) != TEAM_INFECTED) {
		return Plugin_Continue;
	}

	if (IsSpawnInVocalSample(sample)) {
		g_bVanillaSpawnVocal[entity] = true;
	}

	return Plugin_Continue;
}

bool IsValidLiveSI(int client) {
	return client > 0
		&& client <= MaxClients
		&& IsClientInGame(client)
		&& IsPlayerAlive(client)
		&& GetClientTeam(client) == TEAM_INFECTED
		&& !GetEntProp(client, Prop_Send, "m_isGhost");
}

void ResetClientCueState(int client) {
	g_bCuePending[client] = false;
	g_bCuePlayedThisSpawn[client] = false;
	g_bVanillaSpawnVocal[client] = false;
	g_iGhostWaitFrames[client] = 0;
	g_flLastSpawnCueAt[client] = 0.0;
}

bool IsSpawnInVocalSample(const char[] sample) {
	if (StrContains(sample, "/voice/", false) == -1) {
		return false;
	}

	return StrContains(sample, "/alert/", false) != -1
		|| StrContains(sample, "/warn", false) != -1
		|| StrContains(sample, "lurk", false) != -1
		|| StrContains(sample, "spotprey", false) != -1
		|| StrContains(sample, "recognize", false) != -1;
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
		case ZC_SPITTER: return PickFromArray(g_sSpitterCue, sizeof(g_sSpitterCue), buffer, maxlen);
		case ZC_BOOMER:  return PickFromArray(g_sBoomerCue, sizeof(g_sBoomerCue), buffer, maxlen);
		case ZC_CHARGER: return PickFromArray(g_sChargerCue, sizeof(g_sChargerCue), buffer, maxlen);
		case ZC_SMOKER:  return PickFromArray(g_sSmokerCue, sizeof(g_sSmokerCue), buffer, maxlen);
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
