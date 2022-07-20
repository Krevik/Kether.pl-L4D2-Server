#include <sourcemod>
#include <sdktools>

/* These class numbers are the same ones used internally in L4D2 SIClass enum*/
enum {
	SI_None=0,
	SI_Smoker=1,
	SI_Boomer,
	SI_Hunter,
	SI_Spitter,
	SI_Jockey,
	SI_Charger,
	SI_Witch,
	SI_Tank,
	
	SI_MAX_SIZE
};

public Plugin:myinfo = { 
	name        = "[L4D2] Headshot notification", 
	author        = "DeathChaos25, Krevik", 
	description    = "Players will see a notification when they perform a Headshot", 
	version        = "1.0", 
	url        = "https://forums.alliedmods.net/showthread.php?t=248751" 
}

public OnPluginStart()
{
	HookEvent("player_death", PlayerDeath_Event) 
}

public OnMapStart()
{
}

public PlayerDeath_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "attacker")) 
	new infected_id = GetClientOfUserId(GetEventInt(event, "userid")) 
	if(client > 0 && infected_id > 0){
		if(GetClientTeam(client) == 2 && GetClientTeam(infected_id) == 3){
			new SI_CLASS_ID = GetEntProp(infected_id, Prop_Send, "m_zombieClass");
			new bool:IsHeadshot = GetEventBool(event, "headshot") 
			if (IsSurvivor(client) && IsHeadshot == true && IsInfected(SI_CLASS_ID) ) {
				PrintCenterText(client, "HEADSHOT!");
				PrintCenterText(infected_id, "HEADSHOTTED!");
			}
		}
	}
}

stock bool:IsSurvivor(client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		return true;
	}
	return false;
}

stock bool:IsInfected(infected_ID){
	if(infected_ID == SI_Smoker || infected_ID == SI_Boomer || infected_ID == SI_Hunter || infected_ID == SI_Spitter || infected_ID == SI_Jockey || infected_ID == SI_Charger || infected_ID == SI_Witch){
		return true;
	}
	return false;
}