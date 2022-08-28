#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <l4d2_direct>

public Plugin:myinfo = {
	name        = "L4D2 Boss Flow Announce",
	author      = "ProdigySim",
	version     = "1.0",
	description = "Announce boss flow percents!"
};

new Handle:g_hVSBossBuffer;

public OnPluginStart() {
	g_hVSBossBuffer = FindConVar("versus_boss_buffer");
	RegConsoleCmd("sm_tank", TankCmd);
	HookEvent("player_left_start_area", EventHook:LeftStartAreaEvent, EventHookMode_PostNoCopy);
}

public LeftStartAreaEvent( ) {
	new roundNumber = GameRules_GetProp("m_bInSecondHalfOfRound") ? 1 : 0;
	if(L4D2Direct_GetVSTankToSpawnThisRound(roundNumber))
	{
		PrintToChatAll("Tank Spawn: %d%%", RoundToNearest(GetTankFlow(roundNumber)*100));
	}
	if(L4D2Direct_GetVSWitchToSpawnThisRound(roundNumber))
	{
		PrintToChatAll("Witch Spawn: %d%%", RoundToNearest(GetWitchFlow(roundNumber)*100));
	}
}


public Action:TankCmd(client, args) {
	new roundNumber = GameRules_GetProp("m_bInSecondHalfOfRound") ? 1 : 0;
	if(L4D2Direct_GetVSTankToSpawnThisRound(roundNumber))
	{
		ReplyToCommand(client, "Tank Spawn: %d%%", RoundToNearest(GetTankFlow(roundNumber)*100));
	}
	if(L4D2Direct_GetVSWitchToSpawnThisRound(roundNumber))
	{
		ReplyToCommand(client, "Witch Spawn: %d%%", RoundToNearest(GetWitchFlow(roundNumber)*100));
	}
}

Float:GetTankFlow(round)
{
	return L4D2Direct_GetVSTankFlowPercent(round) - 
		( GetConVarInt(g_hVSBossBuffer) / L4D2Direct_GetMapMaxFlowDistance() );
}

Float:GetWitchFlow(round)
{
	return L4D2Direct_GetVSWitchFlowPercent(round) - 
		( GetConVarInt(g_hVSBossBuffer) / L4D2Direct_GetMapMaxFlowDistance() );
}