#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <colors>
#undef REQUIRE_PLUGIN
#include <l4d_lib>
#define VICTIM_CHECK_INTERVAL 0.1

enum L4D2Team
{
	L4D2Team_None = 0,
	L4D2Team_Spectator,
	L4D2Team_Survivor,
	L4D2Team_Infected
}

Handle tankingCheck_Timer;
float tankPlayerPrevPos[3];
int tankPlayer;

public Plugin:myinfo =
{
	name = "Tank Pass Unteleport",
	author = "Krevik, larrybrains, StarterX4",
	description = "Teleports a tank back into the map if they are randomly teleported outside or inside of the map after tank pass.",
	version = "0.1",
	url = "kether.pl"
};

public OnPluginStart()
{
	HookEvent("tank_spawn", Event_TankSpawn);
	//Handle("g_fwdOnTankPass", Event_TankPass);
	HookEvent("entity_killed", Event_EntityKilled);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("round_end", Event_RoundEnd);
}

public void OnMapStart()
{
	tankingCheck_Timer = null;
	tankPlayerPrevPos[0] = 0.0;
	tankPlayerPrevPos[1] = 0.0;
	tankPlayerPrevPos[2] = 0.0;
	tankPlayer=-1;
}

public Action Event_RoundEnd(Event hEvent, const char[] s_Name, bool b_DontBroadcast)
{
	delete tankingCheck_Timer;
	tankPlayer = -1;
}

public Action Event_EntityKilled(Event hEvent, const char[] s_Name, bool b_DontBroadcast)
{
	int entity = hEvent.GetInt("entindex_killed");
	if (IsClient(entity) && IsPlayerTank(entity))
		RequestFrame(OnEntKilled, entity);
}

public void OnEntKilled(int client)
{
	if (!IsAliveTank(client))
	delete tankingCheck_Timer;
	tankPlayer = -1;
}

public Action Event_TankSpawn(Event hEvent, const char[] name, bool dontBroadcast)
{
	//CreateTimer(0.2); // waiting for the bot_player_replace being fired
	new victim = GetClientOfUserId(hEvent.GetInt("userid"));

	if (IsClientInGame(victim) && GetClientTeam(victim) == 2 && IsPlayerAlive(victim) && IsValidTank(victim))
	{
		tankPlayer = victim;
		GetClientAbsOrigin(victim, tankPlayerPrevPos);

		if(tankingCheck_Timer == null){
			tankingCheck_Timer = CreateTimer(VICTIM_CHECK_INTERVAL, CheckVictimPosition_Timer, victim, TIMER_REPEAT);
		}
	}
}

public void Event_PlayerDeath(Event hEvent, const char[] name, bool dontBroadcast)
{

	static int client;
	client = GetClientOfUserId(hEvent.GetInt("userid"));

	if (client != 0) {
		if (client == tankPlayer) {
			tankPlayer = -1;
			delete tankingCheck_Timer;
		}
	}
}

public void Event_PlayerDisconnect(Event hEvent, const char[] name, bool dontBroadcast)
{

	static int client;
	client = GetClientOfUserId(hEvent.GetInt("userid"));

	if (client != 0) {
		if (client == tankPlayer) {
			tankPlayer = -1;
			delete tankingCheck_Timer;
		}
	}
}

public Action CheckVictimPosition_Timer(Handle timer, any victim)
{
	static bool isOutsideWorld;
	static float newVictimPos[3];
	
	if (IsClientInGame(victim) && GetClientTeam(victim) == 2 && IsPlayerAlive(victim))
	{
		GetClientAbsOrigin(victim, newVictimPos);
		isOutsideWorld = TR_PointOutsideWorld(newVictimPos);
		
		if ( !isOutsideWorld && (isPrevPositionEmpty() || (!isPrevPositionEmpty() && planarDistance(tankPlayerPrevPos, newVictimPos) < 500.0 )) )
		{
			tankPlayerPrevPos = newVictimPos;
		}
	}
	
	if (IsClientInGame(victim) && GetClientTeam(victim) == 2 && IsPlayerAlive(victim))
	{
		GetClientAbsOrigin(victim, newVictimPos);
		isOutsideWorld = TR_PointOutsideWorld(newVictimPos);
		
		if(isOutsideWorld || (!isPrevPositionEmpty() && planarDistance(tankPlayerPrevPos, newVictimPos) > 500.0 )){
			TeleportToPreviousPosition(victim);
		}
	}
	return Plugin_Continue;
}

float planarDistance(float pos1[3], float pos2[3]){
	float pos1X = pos1[0];
	float pos1Z = pos1[1];
	float pos2X = pos2[0];
	float pos2Z = pos2[1];
	float distance = GetVectorDistance(pos2,pos1,false);
	//SquareRoot(Pow((FloatAbs(pos2X-pos1X)),2)+Pow((FloatAbs(pos2Z-pos1Z)),2));
	return distance;
}

bool isPrevPositionEmpty(){
	if(tankPlayerPrevPos[0] == 0 && tankPlayerPrevPos[1] == 0 && tankPlayerPrevPos[2] == 0){
		return true;
	}else{
		return false;
	}
}

void TeleportToPreviousPosition(int victim){
	TeleportEntity(victim, tankPlayerPrevPos, NULL_VECTOR, NULL_VECTOR);
	CPrintToChatAll("{blue}[Tank Pass UnTeleport]{default} Tank Pass teleported the tank, teleporting him to previous position.");
}

bool IsValid(int client)
{
	return IsInfectedAndInGame(client) && !IsFakeClient(client);
}

bool IsTank(int tank)
{
	return IsPlayerTank(tank) && !IsIncaped(tank);
}

bool IsAliveTank(int tank)
{
	return IsTank(tank) && IsPlayerAlive(tank);
}

bool IsValidTank(int tank)
{
	return IsValid(tank) && IsAliveTank(tank);
}