/*
 * L4D2 SI Materialize Cue (Kether)
 *
 * Exactly one audible spawn sound per materialize, delivered reliably.
 *
 * What the game does (server_srv.so): a ghost that materializes gets no spawn sound for the
 * survivors. The class "Alert" vocal and the survivors' spawn music only play in
 * CTerrorPlayer::Spawn for non-ghost spawns (bots, tank). After materializing, the first
 * UpdateZombieSounds call usually plays the class idle vocal (*_lurk_*, 85 dB, CHAN_VOICE),
 * depending on the SI's class state; hunters and jockeys get nothing.
 * Every sound, the game's and SourceMod's alike, is sent unreliably: it rides in one snapshot
 * and is gone if that packet is lost.
 *
 * What this plugin does, per materialize (hunters never, they spawn silently on purpose):
 *  - the game's own spawn-time vocal is caught, blocked and re-emitted unchanged (same entity,
 *    channel, level, pitch, recipients) through Tickrate Enabler's te_reliable_sound, so it can't
 *    be lost; nothing is added, the spawn is heard once.
 *  - if the game stays silent for sm_si_materialize_cue_delay seconds, the plugin plays its own
 *    class cue instead (reliably when possible), and a late duplicate idle vocal from the game is
 *    blocked for sm_si_materialize_cue_guard seconds.
 *  - boomer: MaterializeFromGhost itself starts BoomerZombie.Gurgle (CHAN_VOICE), and the groan from
 *    the same tick's PostThink replaces it on that channel before anyone hears it. The relayed groan
 *    arrives one tick later, so the gurgle is dropped instead of playing alone for that tick.
 *  - a relay is dropped if the SI died, respawned or became a ghost again before it went out.
 * Without te_reliable_sound (Tickrate Enabler missing/old) the game's vocal is left alone and the
 * cue falls back to EmitSoundToAll (unreliable).
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "2.1.0"

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define SPAWN_CUE_COOLDOWN 2.5
#define RELIABLE_SOUND_COMMAND "te_reliable_sound"
#define MIN_VANILLA_WAIT 0.05
#define MATERIALIZE_WINDOW 0.1	// Pre forward -> gurgle: same usercmd, so effectively the same instant

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
ConVar g_CvarReliable;
ConVar g_CvarSource;
ConVar g_CvarGuard;
ConVar g_CvarDebug;

bool g_bWaitingForVanilla[MAXPLAYERS + 1];	// spawn decision still open
bool g_bOwnCuePlayed[MAXPLAYERS + 1];		// our cue played: block a late duplicate idle vocal
bool g_bMaterializing[MAXPLAYERS + 1];		// boomer inside MaterializeFromGhost: drop its gurgle
int g_iSpawnSerial[MAXPLAYERS + 1];			// invalidates timers and relays of an older spawn
float g_flMaterializedAt[MAXPLAYERS + 1];
float g_flMaterializingAt[MAXPLAYERS + 1];
float g_flLastSpawnCueAt[MAXPLAYERS + 1];

char g_sLogPath[PLATFORM_MAX_PATH];

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
	description = "Exactly one reliable spawn sound per SI materialize (hunters stay silent).",
	version     = PLUGIN_VERSION,
	url         = "https://github.com/Krevik/Kether.pl-L4D2-Server",
};

public void OnPluginStart() {
	g_CvarEnable   = CreateConVar("sm_si_materialize_cue", "1",
		"Enable SI materialize spawn sounds (0=off, 1=on).", _, true, 0.0, true, 1.0);
	g_CvarChannel  = CreateConVar("sm_si_materialize_cue_channel", "0",
		"Sound channel of the plugin's own cue: 0=AUTO (recommended), 2=VOICE, 6=STATIC.", _, true, 0.0, true, 7.0);
	g_CvarLevel    = CreateConVar("sm_si_materialize_cue_level", "110",
		"Sound level (dB) of the plugin's own cue. The game's vocals keep their own level.", _, true, 60.0, true, 120.0);
	g_CvarClasses  = CreateConVar("sm_si_materialize_cue_classes", "59",
		"Bitmask: 1=Smoker, 2=Boomer, 8=Spitter, 16=Jockey, 32=Charger (4=Hunter and 64=Tank are always ignored).", _, true, 0.0, true, 127.0);
	g_CvarDelay    = CreateConVar("sm_si_materialize_cue_delay", "0.18",
		"Seconds after materializing to wait for the game's own spawn vocal before playing the plugin's cue.", _, true, 0.0, true, 1.0);
	g_CvarReliable = CreateConVar("sm_si_materialize_cue_reliable", "1",
		"Send spawn sounds reliably through Tickrate Enabler's te_reliable_sound when it exists (0=never).", _, true, 0.0, true, 1.0);
	g_CvarSource   = CreateConVar("sm_si_materialize_cue_source", "0",
		"Source of the plugin's own cue: 0=the SI (moves with it), 1=the world at the SI's position.", _, true, 0.0, true, 1.0);
	g_CvarGuard    = CreateConVar("sm_si_materialize_cue_guard", "1.5",
		"After the plugin's own cue, block one late idle vocal from the game for this many seconds after materializing (no double spawn sound).", _, true, 0.0, true, 5.0);
	g_CvarDebug    = CreateConVar("sm_si_materialize_cue_debug", "0",
		"Log every spawn sound decision to logs/l4d2_si_materialize_cue.log (0=off, 1=on).", _, true, 0.0, true, 1.0);

	CreateConVar("sm_si_materialize_cue_mode", "0", "Deprecated. Ignored since 1.4.", FCVAR_NOTIFY);

	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/l4d2_si_materialize_cue.log");

	AddNormalSoundHook(SoundHook_SpawnVocal);
	HookEvent("player_death", Event_PlayerDeath);

	AutoExecConfig(true, "l4d2_si_materialize_cue", "sourcemod");
}

public void OnClientDisconnect(int client) {
	ResetClient(client);
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
	if (client > 0 && client <= MaxClients) {
		ResetClient(client);
	}
}

void ResetClient(int client) {
	g_bWaitingForVanilla[client] = false;
	g_bOwnCuePlayed[client] = false;
	g_bMaterializing[client] = false;
	g_iSpawnSerial[client]++;
	g_flMaterializedAt[client] = 0.0;
	g_flLastSpawnCueAt[client] = 0.0;
}

// Arms the gurgle drop: BoomerZombie.Gurgle is emitted inside MaterializeFromGhost, before the post forward.
public Action L4D_OnMaterializeFromGhostPre(int client) {
	if (client < 1 || client > MaxClients) {
		return Plugin_Continue;
	}
	g_bMaterializing[client] = g_CvarEnable.BoolValue && IsClientInGame(client)
		&& GetClientTeam(client) == TEAM_INFECTED
		&& GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_BOOMER && IsClassEnabled(ZC_BOOMER);
	g_flMaterializingAt[client] = GetGameTime();
	return Plugin_Continue;
}

// Another plugin blocked the materialize: the boomer stays a ghost, nothing to drop.
public void L4D_OnMaterializeFromGhost_PostHandled(int client) {
	if (client >= 1 && client <= MaxClients) {
		g_bMaterializing[client] = false;
	}
}

public void L4D_OnMaterializeFromGhost(int client) {
	if (client >= 1 && client <= MaxClients) {
		g_bMaterializing[client] = false;
	}
	if (!g_CvarEnable.BoolValue || client < 1 || client > MaxClients
		|| !IsClientInGame(client) || GetClientTeam(client) != TEAM_INFECTED) {
		return;
	}

	int zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	// Hunters spawn silently on purpose: nothing is added, relayed or blocked for them.
	if (zombieClass == ZC_HUNTER || !IsClassEnabled(zombieClass)) {
		return;
	}

	float now = GetGameTime();
	if (g_flLastSpawnCueAt[client] > 0.0 && now - g_flLastSpawnCueAt[client] < SPAWN_CUE_COOLDOWN) {
		return;
	}

	g_iSpawnSerial[client]++;
	g_bWaitingForVanilla[client] = true;
	g_bOwnCuePlayed[client] = false;
	g_flMaterializedAt[client] = now;
	g_flLastSpawnCueAt[client] = now;

	float delay = g_CvarDelay.FloatValue;
	if (delay < MIN_VANILLA_WAIT) {
		delay = MIN_VANILLA_WAIT; // the game vocalizes in PostThink right after materializing
	}

	DataPack pack;
	CreateDataTimer(delay, Timer_PlayOwnCue, pack, TIMER_FLAG_NO_MAPCHANGE);
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(g_iSpawnSerial[client]);
}

bool IsClassEnabled(int zombieClass) {
	int mask = g_CvarClasses.IntValue;

	switch (zombieClass) {
		case ZC_SMOKER:  return (mask & CUE_SMOKER) != 0;
		case ZC_BOOMER:  return (mask & CUE_BOOMER) != 0;
		case ZC_SPITTER: return (mask & CUE_SPITTER) != 0;
		case ZC_JOCKEY:  return (mask & CUE_JOCKEY) != 0;
		case ZC_CHARGER: return (mask & CUE_CHARGER) != 0;
	}

	return false;
}

bool ReliableSoundAvailable() {
	return g_CvarReliable.BoolValue && CommandExists(RELIABLE_SOUND_COMMAND);
}

// Arguments te_reliable_sound accepts.
bool IsRelayable(int channel, int level, float volume, int pitch, int flags) {
	return channel >= 0 && channel <= 7
		&& level >= 0 && level <= 255
		&& volume >= 0.0 && volume <= 1.0
		&& pitch >= 1 && pitch <= 255
		&& flags >= 0;
}

bool IsVoiceSample(const char[] sample) {
	return StrContains(sample, "/voice/", false) != -1;
}

bool IsIdleVocal(const char[] sample) {
	return StrContains(sample, "/voice/idle/", false) != -1
		|| StrContains(sample, "lurk", false) != -1
		|| StrContains(sample, "breath", false) != -1;
}

Action SoundHook_SpawnVocal(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],
	int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,
	char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (entity < 1 || entity > MaxClients) {
		return Plugin_Continue;
	}
	if (!g_bWaitingForVanilla[entity] && !g_bOwnCuePlayed[entity] && !g_bMaterializing[entity]) {
		return Plugin_Continue;
	}
	if (!IsClientInGame(entity) || GetClientTeam(entity) != TEAM_INFECTED || !IsVoiceSample(sample)) {
		return Plugin_Continue;
	}

	if (g_bMaterializing[entity] && StrContains(sample, "indigestion", false) != -1) {
		// BoomerZombie.Gurgle from MaterializeFromGhost. Vanilla replaces it with the groan in the same
		// snapshot; the groan is relayed a tick later, so drop the gurgle (it is not the spawn decision).
		// Without te_reliable_sound nothing is relayed and the game's sounds are left alone.
		g_bMaterializing[entity] = false;
		if (GetGameTime() - g_flMaterializingAt[entity] <= MATERIALIZE_WINDOW && ReliableSoundAvailable()) {
			LogDecision(entity, "dropped materialize gurgle", sample, numClients);
			return Plugin_Stop;
		}
		return Plugin_Continue;
	}

	if (g_bWaitingForVanilla[entity]) {
		// The game's own spawn-time vocal: this is the spawn sound, nothing else will be added.
		g_bWaitingForVanilla[entity] = false;

		if (numClients > 0 && ReliableSoundAvailable() && IsRelayable(channel, level, volume, pitch, flags)) {
			DataPack pack = new DataPack();
			pack.WriteCell(GetClientUserId(entity));
			pack.WriteCell(g_iSpawnSerial[entity]);
			pack.WriteCell(channel);
			pack.WriteCell(level);
			pack.WriteFloat(volume);
			pack.WriteCell(pitch);
			pack.WriteCell(flags);
			pack.WriteString(sample);
			pack.WriteCell(numClients);
			for (int i = 0; i < numClients; i++) {
				pack.WriteCell(clients[i]);
			}
			// Re-emit on the next frame, outside of SourceMod's sound hook.
			RequestFrame(Frame_RelayReliably, pack);
			LogDecision(entity, "relay (reliable)", sample, numClients);
			return Plugin_Stop;
		}

		LogDecision(entity, "vanilla (unreliable)", sample, numClients);
		return Plugin_Continue;
	}

	if (!g_bOwnCuePlayed[entity]) {
		return Plugin_Continue;
	}

	// Our own cue was the spawn sound: drop one late idle vocal so the spawn isn't heard twice.
	g_bOwnCuePlayed[entity] = false;
	if (GetGameTime() - g_flMaterializedAt[entity] <= g_CvarGuard.FloatValue && IsIdleVocal(sample)) {
		LogDecision(entity, "blocked late duplicate", sample, numClients);
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

void Frame_RelayReliably(any data) {
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	int serial = pack.ReadCell();
	int channel = pack.ReadCell();
	int level = pack.ReadCell();
	float volume = pack.ReadFloat();
	int pitch = pack.ReadCell();
	int flags = pack.ReadCell();
	char sample[PLATFORM_MAX_PATH];
	pack.ReadString(sample, sizeof(sample));
	int numClients = pack.ReadCell();
	int recipients[MAXPLAYERS];
	int count = 0;
	for (int i = 0; i < numClients; i++) {
		int recipient = pack.ReadCell();
		if (recipient >= 1 && recipient <= MaxClients && IsClientInGame(recipient) && count < MAXPLAYERS) {
			recipients[count++] = recipient;
		}
	}
	delete pack;

	// Same spawn, still a live, materialized SI: otherwise the vocal would play after its death or respawn.
	if (client < 1 || serial != g_iSpawnSerial[client] || count == 0 || !IsClientInGame(client)
		|| !IsPlayerAlive(client) || GetClientTeam(client) != TEAM_INFECTED || GetEntProp(client, Prop_Send, "m_isGhost")) {
		return;
	}

	if (ReliableSoundAvailable()) {
		char list[256];
		for (int i = 0; i < count; i++) {
			Format(list, sizeof(list), "%s%s%d", list, i > 0 ? "," : "", recipients[i]);
		}
		ServerCommand("%s %d %d %d %.3f %d %d - \"%s\" %s", RELIABLE_SOUND_COMMAND,
			client, channel, level, volume, pitch, flags, sample, list);
		ServerExecute();
	} else {
		// te_reliable_sound went away in the meantime: play it the normal way rather than lose it.
		EmitSound(recipients, count, sample, client, channel, level, flags, volume, pitch);
	}
}

Action Timer_PlayOwnCue(Handle timer, DataPack pack) {
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	int serial = pack.ReadCell();

	if (client < 1 || serial != g_iSpawnSerial[client] || !g_bWaitingForVanilla[client]) {
		return Plugin_Stop; // the game vocalized (relayed), or a newer spawn / death happened
	}
	g_bWaitingForVanilla[client] = false;

	if (!IsClientInGame(client) || !IsPlayerAlive(client) || GetClientTeam(client) != TEAM_INFECTED
		|| GetEntProp(client, Prop_Send, "m_isGhost")) {
		return Plugin_Stop;
	}

	int zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (zombieClass == ZC_HUNTER || !IsClassEnabled(zombieClass)) {
		return Plugin_Stop;
	}

	char sound[PLATFORM_MAX_PATH];
	if (!PickCueSound(zombieClass, sound, sizeof(sound))) {
		return Plugin_Stop;
	}

	int channel = g_CvarChannel.IntValue;
	int level = g_CvarLevel.IntValue;
	float origin[3];
	GetClientAbsOrigin(client, origin);
	bool fromWorld = g_CvarSource.IntValue == 1;

	if (ReliableSoundAvailable()) {
		if (fromWorld) {
			ServerCommand("%s 0 %d %d 1.0 100 0 %.1f,%.1f,%.1f \"%s\"", RELIABLE_SOUND_COMMAND,
				channel, level, origin[0], origin[1], origin[2], sound);
		} else {
			ServerCommand("%s %d %d %d 1.0 100 0 - \"%s\"", RELIABLE_SOUND_COMMAND, client, channel, level, sound);
		}
		ServerExecute();
		LogDecision(client, fromWorld ? "own cue (reliable, world)" : "own cue (reliable)", sound, -1);
	} else {
		EmitSoundToAll(sound, fromWorld ? SOUND_FROM_WORLD : client, channel, level, SND_NOFLAGS, 1.0, 100, -1, origin);
		LogDecision(client, "own cue (unreliable)", sound, -1);
	}

	// Set after emitting: our own cue passes through the sound hook while it is played.
	g_bOwnCuePlayed[client] = g_CvarGuard.FloatValue > 0.0;
	return Plugin_Stop;
}

void LogDecision(int client, const char[] decision, const char[] sample, int numClients) {
	if (!g_CvarDebug.BoolValue) {
		return;
	}

	float origin[3];
	GetClientAbsOrigin(client, origin);
	int survivors = 0;
	float nearest = -1.0;
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i)) {
			continue;
		}
		float pos[3];
		GetClientAbsOrigin(i, pos);
		float distance = GetVectorDistance(origin, pos);
		if (nearest < 0.0 || distance < nearest) {
			nearest = distance;
		}
		survivors++;
	}

	LogToFileEx(g_sLogPath, "%N class %d: %s %s (+%.3f s after materialize, recipients %d, survivors %d, nearest %.0f u)",
		client, GetEntProp(client, Prop_Send, "m_zombieClass"), decision, sample,
		GetGameTime() - g_flMaterializedAt[client], numClients, survivors, nearest);
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
