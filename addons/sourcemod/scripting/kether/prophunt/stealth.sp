#if defined __ph_stealth_included
	#endinput
#endif
#define __ph_stealth_included

// Strip the movement-attack buttons every tick for Props, on top of the SDKHook_OnTakeDamage
// zeroing in hunters.sp - belt and suspenders so a Hunter never even sees the claw/pounce
// swing animation play out on a disguised Prop.
void PH_Stealth_BlockPropButtons(int &buttons)
{
	buttons &= ~(IN_ATTACK | IN_ATTACK2 | IN_ATTACK3);
}

// A human Hunter/Prop model constantly plays idle vocalizations and footstep voice lines that
// would broadcast a disguised Prop's location for free - none of the TF2/CS:GO ports need this
// (their idle characters are silent), so it's L4D2-specific hardening. Our own scheduled cues
// (cues.sp) set g_bCueInFlight right before EmitSoundToAll so they pass straight through.
public Action PH_NormalSoundHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],
	int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,
	char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (!PH_IsModeActive())
		return Plugin_Continue;

	if (entity < 1 || entity > MaxClients || !PH_IsProp(entity))
		return Plugin_Continue;

	if (g_bCueInFlight[entity])
		return Plugin_Continue;

	if (StrContains(sample, "voice/", false) != -1 || StrContains(sample, "footstep", false) != -1)
		return Plugin_Stop;

	return Plugin_Continue;
}

// Infected-team glow/outline must never leak through to a disguised Prop.
void PH_Stealth_ClearGlow(int client)
{
	if (!HasEntProp(client, Prop_Send, "m_iGlowType"))
		return;

	SetEntProp(client, Prop_Send, "m_iGlowType", 0);
	SetEntProp(client, Prop_Send, "m_glowColorOverride", 0);
	SetEntProp(client, Prop_Send, "m_nGlowRange", 0);
}

// Blanks the nav-mesh place name shown in the death/damage feed and voice-command call-outs,
// same idea as the CS:GO Prop Hunt port's per-think location scrub.
public void PH_Stealth_PostThinkPost(int client)
{
	if (!PH_IsModeActive() || !PH_IsProp(client))
		return;

	if (HasEntProp(client, Prop_Send, "m_szLastPlaceName"))
		SetEntPropString(client, Prop_Send, "m_szLastPlaceName", "");
}

// PropHunt Neu's r_staticpropinfo check ported verbatim - it reveals static prop names and
// bounds client-side, i.e. it would hand a Hunter exactly the data selection.sp is trying to
// approximate blind. Matters far more here than in a generic mod since static props are
// actually selectable.
void PH_Stealth_StartAnticheatScan()
{
	if (g_hTimerAntiCheatScan == null)
		g_hTimerAntiCheatScan = CreateTimer(5.0, PH_Timer_AnticheatScan, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

void PH_Stealth_StopAnticheatScan()
{
	delete g_hTimerAntiCheatScan;
}

public Action PH_Timer_AnticheatScan(Handle timer)
{
	if (!PH_IsModeActive())
		return Plugin_Continue;

	if (!g_bCvarAnticheatKick)
		return Plugin_Continue;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && PH_IsHunter(i))
			QueryClientConVar(i, "r_staticpropinfo", PH_OnAnticheatConVarQueried);
	}

	return Plugin_Continue;
}

public void PH_OnAnticheatConVarQueried(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] value)
{
	if (!g_bCvarAnticheatKick || result != ConVarQuery_Okay || !IsClientInGame(client))
		return;

	if (!StrEqual(value, "0"))
		KickClient(client, "%T", "PropHunt_AnticheatKickReason", client);
}

// Blocks re-materializing a Prop that was already eliminated this round - without this, L4D2's
// normal versus SI respawn queue would eventually try to bring dead Props back as ghosts again.
public Action L4D_OnMaterializeFromGhostPre(int client)
{
	if (PH_IsModeActive() && PH_IsProp(client) && g_bPropEliminated[client])
		return Plugin_Handled;

	return Plugin_Continue;
}
