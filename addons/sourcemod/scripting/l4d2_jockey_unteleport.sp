#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <colors>
#define VICTIM_CHECK_INTERVAL 0.1

enum L4D2Team
{
	L4D2Team_None = 0,
	L4D2Team_Spectator,
	L4D2Team_Survivor,
	L4D2Team_Infected
}

Handle jockeyRideCheck_Timer;
float victimPrevPos[3];
int jockeyVictim;

public Plugin:myinfo =
{
	name = "Jockey Unteleport",
	author = "Krevik, larrybrains",
	description = "Teleports a survivor back into the map if they are randomly teleported outside or inside of the map while jockeyed.",
	version = "2.0",
	url = "kether.pl"
};

public OnPluginStart()
{
	HookEvent("jockey_ride", Event_JockeyRide);
	HookEvent("jockey_ride_end", Event_JockeyRideEnd);
	HookEvent("jockey_killed", Event_JockeyDeath);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("round_end", Event_RoundEnd);
}

public void OnMapStart()
{
	jockeyRideCheck_Timer = null;
	victimPrevPos[0] = 0.0;
	victimPrevPos[1] = 0.0;
	victimPrevPos[2] = 0.0;
	jockeyVictim=-1;
}

public Action Event_RoundEnd(Event h_Event, const char[] s_Name, bool b_DontBroadcast)
{
	delete jockeyRideCheck_Timer;
	jockeyVictim = -1;
}

public Action Event_JockeyDeath(Event h_Event, const char[] s_Name, bool b_DontBroadcast)
{
	delete jockeyRideCheck_Timer;
	jockeyVictim = -1;
}

public Action Event_JockeyRideEnd(Event hEvent, const char[] s_Name, bool b_DontBroadcast)
{
	delete jockeyRideCheck_Timer;
	jockeyVictim = -1;
}

public Action Event_JockeyRide(Event event, const char[] name, bool dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));

	if (IsClientInGame(victim) && GetClientTeam(victim) == 2 && IsPlayerAlive(victim))
	{
		jockeyVictim = victim;
		GetClientAbsOrigin(victim, victimPrevPos);

		if(jockeyRideCheck_Timer == null){
			jockeyRideCheck_Timer = CreateTimer(VICTIM_CHECK_INTERVAL, CheckVictimPosition_Timer, victim, TIMER_REPEAT);
		}
	}
}

public void Event_PlayerDeath(Event hEvent, const char[] name, bool dontBroadcast)
{

	static int client;
	client = GetClientOfUserId(hEvent.GetInt("userid"));

	if (client != 0) {
		if (client == jockeyVictim) {
			jockeyVictim = -1;
			delete jockeyRideCheck_Timer;
		}
	}
}

public void Event_PlayerDisconnect(Event hEvent, const char[] name, bool dontBroadcast)
{

	static int client;
	client = GetClientOfUserId(hEvent.GetInt("userid"));

	if (client != 0) {
		if (client == jockeyVictim) {
			jockeyVictim = -1;
			delete jockeyRideCheck_Timer;
		}
	}
}

public Action CheckVictimPosition_Timer(Handle timer, any victim)
{
	static bool isOutsideWorld;
	static float distanceToNearestSurv = 1000.0;
	static float newVictimPos[3];
	
	if (IsClientInGame(victim) && GetClientTeam(victim) == 2 && IsPlayerAlive(victim))
	{
		GetClientAbsOrigin(victim, newVictimPos);
		isOutsideWorld = TR_PointOutsideWorld(newVictimPos);
		
		if ( !isOutsideWorld && (isPrevPositionEmpty() || (!isPrevPositionEmpty() && planarDistance(victimPrevPos, newVictimPos) < 500.0 )) )
		{
			victimPrevPos = newVictimPos;
		}
	}
	
	if (IsClientInGame(victim) && GetClientTeam(victim) == 2 && IsPlayerAlive(victim))
	{
		GetClientAbsOrigin(victim, newVictimPos);
		isOutsideWorld = TR_PointOutsideWorld(newVictimPos);
		
		if(isOutsideWorld || (!isPrevPositionEmpty() && planarDistance(victimPrevPos, newVictimPos) > 500.0 )){
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
	if(victimPrevPos[0] == 0 && victimPrevPos[1] == 0 && victimPrevPos[2] == 0){
		return true;
	}else{
		return false;
	}
}

void TeleportToPreviousPosition(int victim){
	TeleportEntity(victim, victimPrevPos, NULL_VECTOR, NULL_VECTOR);
	CPrintToChatAll("{blue}[Jockey UnTeleport]{default} Jockey teleported a survivor, teleporting him to previous position.");
}

void TeleportToNearestSurvivor(int victim)
{
	float distanceToNearestSurv = 1000.0;
	int resultClientIndex = 1;
	for (new i = 1; i <= MaxClients; i++)
	{
			if (IsSurvivor(i) && !IsIncapped(i) && !IsPlayerLedged(i) && i!=victim)
			{
				if (IsPlayerAlive(i))
				{
					float actualSurvivorPosition[3];
					GetClientAbsOrigin(i, actualSurvivorPosition);
					float newDistance = GetVectorDistance(actualSurvivorPosition, victimPrevPos);
					if(newDistance < distanceToNearestSurv){
						distanceToNearestSurv = newDistance;
						resultClientIndex=i;
					}
				}
			}
	}
	
	float destinationPos[3];
	GetClientAbsOrigin(resultClientIndex, destinationPos);
		
	if (IsClientInGame(resultClientIndex) && IsPlayerAlive(resultClientIndex))
	{
		TeleportEntity(victim, destinationPos, NULL_VECTOR, NULL_VECTOR);
	}
}

bool:IsSurvivor(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

bool:IsIncapped(client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

bool:IsPlayerLedged(client)
{
	return bool:(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") | GetEntProp(client, Prop_Send, "m_isFallingFromLedge"));
}