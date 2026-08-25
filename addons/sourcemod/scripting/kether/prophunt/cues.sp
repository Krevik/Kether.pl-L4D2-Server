#if defined __ph_cues_included
	#endinput
#endif
#define __ph_cues_included

// Reused special-infected vocal lines - same idea as scripting/kether/l4d2_si_materialize_cue.sp,
// just repurposed as the "you can't hide silently forever" forced noise. Kept as symbolic string
// data (not hardcoded call sites) so the set is easy to retune without touching the round logic.
static const char g_sCueSounds[][] = {
	"player/hunter/voice/idle/hunter_lurk_01.wav",
	"player/hunter/voice/idle/hunter_lurk_02.wav",
	"player/hunter/voice/idle/hunter_lurk_03.wav",
	"player/hunter/voice/alert/hunter_alert_01.wav",
	"player/hunter/voice/alert/hunter_alert_02.wav",
	"player/boomer/voice/idle/male_boomer_lurk_01.wav",
	"player/boomer/voice/idle/male_boomer_lurk_02.wav",
	"player/smoker/voice/alert/smoker_alert_01.wav",
	"player/smoker/voice/alert/smoker_alert_02.wav",
	"player/spitter/voice/idle/spitter_spotprey_03.wav",
	"player/spitter/voice/idle/spitter_spotprey_04.wav",
	"player/jockey/voice/idle/jockey_spotprey_01.wav",
	"player/jockey/voice/idle/jockey_spotprey_02.wav",
	"player/charger/voice/idle/charger_lurk_06.wav"
};

bool g_bCueInFlight[MAXPLAYERS + 1];

void PH_Cues_Precache()
{
	for (int i = 0; i < sizeof(g_sCueSounds); i++)
		PrecacheSound(g_sCueSounds[i], true);
}

// Self-rescheduling timer alternating between "send the warning" and "play the cue", so a
// single ph_cue_interval also defines the warning lead time via ph_cue_warn_fraction - the
// same trick the CS:GO Prop Hunt port's whistle timer uses.
public Action PH_Timer_PeriodicCue(Handle timer, bool warnedAlready)
{
	if (!PH_IsModeActive() || g_ePhase != PHPhase_Seek || g_flCvarCueInterval <= 0.0)
	{
		g_hTimerPeriodicCue = null;
		return Plugin_Stop;
	}

	float delay;
	if (warnedAlready)
	{
		PH_FireCueForAllProps();
		delay = g_flCvarCueInterval * g_flCvarCueWarnFraction;
	}
	else
	{
		PH_Hud_WarnCueIncoming();
		delay = g_flCvarCueInterval * (1.0 - g_flCvarCueWarnFraction);
	}

	if (delay < 0.5)
		delay = 0.5;

	g_hTimerPeriodicCue = CreateTimer(delay, PH_Timer_PeriodicCue, !warnedAlready, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Stop;
}

void PH_FireCueForAllProps()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !PH_IsProp(i) || !IsPlayerAlive(i) || g_bPropEliminated[i])
			continue;

		PH_EmitCueSound(i);
	}
}

void PH_DoTaunt(int client)
{
	if (!IsPlayerAlive(client) || g_bPropEliminated[client])
		return;

	if (GetGameTime() < g_flNextTauntTime[client])
	{
		PrintHintText(client, "%t", "PropHunt_TauntCooldown");
		return;
	}

	g_flNextTauntTime[client] = GetGameTime() + g_flCvarTauntCooldown;
	PH_EmitCueSound(client);
}

void PH_EmitCueSound(int client)
{
	char sound[PLATFORM_MAX_PATH];
	strcopy(sound, sizeof(sound), g_sCueSounds[GetRandomInt(0, sizeof(g_sCueSounds) - 1)]);

	float origin[3];
	GetClientAbsOrigin(client, origin);

	g_bCueInFlight[client] = true;
	EmitSoundToAll(sound, client, SNDCHAN_STATIC, SNDLEVEL_GUNFIRE, _, 1.0, 100, -1, origin);
	g_bCueInFlight[client] = false;
}
