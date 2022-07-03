#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <l4d2util>


int TEAM_SURVIVOR = 2;
Handle witchDamageTrie = INVALID_HANDLE;
Handle witchShotsTrie = INVALID_HANDLE;
Handle witchHarasserTrie = INVALID_HANDLE;
Handle crownForward = INVALID_HANDLE;
Handle drawCrownForward = INVALID_HANDLE;

public Plugin myinfo = 
{
	name = "Witch Damage Manager",
	author = "Krevik",
	description = "Manages witch damage",
	version = "1.0",
	url = "Kether.pl"
};

public void OnPluginStart()
{
	witchDamageTrie = CreateTrie();
	witchShotsTrie = CreateTrie();
	witchHarasserTrie = CreateTrie();
    HookEvent("infected_hurt", WitchHurt_Event, EventHookMode_Post);
    HookEvent("witch_harasser_set", Event_WitchHarasserSet, EventHookMode_Post);
    HookEvent("witch_killed", WitchKilled_Event, EventHookMode_Post);
    crownForward = CreateGlobalForward("Kether_OnWitchCrown", ET_Ignore, Param_Cell, Param_Cell );
    drawCrownForward = CreateGlobalForward("Kether_OnWitchDrawCrown", ET_Ignore, Param_Cell, Param_Cell );

}

//TODO: detect witch incaps - possibly by player death and player hurt events
//Provide native for crown - (one attacker && no incaps && (attacker has shotgun || shotsCount==1?) ) || oneShot
//Print info on chat about crown
//Calculate damage done to witch in percents and print to chat upon witch death OR when witch kills the player and runs succesfully
//clear player's done damage and shots if he changed teams
public void Event_WitchHarasserSet(Event event, const char[] name, bool dontBroadcast)
{
    int harasser = GetClientOfUserId(GetEventInt(event, "userid"));
    int witchID = GetEventInt(event, "witchid");
    char witch_harasser_key[10];
    Format(witch_harasser_key, sizeof(witch_harasser_key), "%x_harasser", witchID);
    SetTrieValue(witchHarasserTrie, witch_harasser_key, harasser);
    PrintToConsoleAll("[DEBUG] Witch was harrased");
}
public void WitchHurt_Event(Event event, const char[] name, bool dontBroadcast)
{
    int entityID = GetEventInt(event, "entityid");
	if (IsWitch(entityID))
	{
        int witchDamageCollector[MAXPLAYERS + 1];
        int witchShotsCollector[MAXPLAYERS + 1];
        int witchID = entityID;
        char witch_dmg_key[10];
        char witch_shots_key[10];
        Format(witch_dmg_key, sizeof(witch_dmg_key), "%x_dmg", witchID);
        Format(witch_shots_key, sizeof(witch_shots_key), "%x_shots", witchID);
        GetTrieArray(witchDamageTrie, witch_dmg_key, witchDamageCollector, sizeof(witchDamageCollector));
        GetTrieArray(witchShotsTrie, witch_shots_key, witchShotsCollector, sizeof(witchShotsCollector));

        int attackerId = GetEventInt(event, "attacker");
        int attacker = GetClientOfUserId(attackerId);
		if (IsValidClient(attacker))
		{
            int damageDone = GetEventInt(event, "amount");
            witchShotsCollector[attacker] += 1;
            witchDamageCollector[attacker] += damageDone;
            SetTrieArray(witchDamageTrie, witch_dmg_key, witchDamageCollector, sizeof(witchDamageCollector));
            SetTrieArray(witchShotsTrie, witch_shots_key, witchShotsCollector, sizeof(witchShotsCollector));
            //check for draw crown
            checkForDrawCrown(witchID, attacker, witchDamageCollector);
            PrintToConsoleAll("[DEBUG] Actual Witch Damage for the client %d stored: %d", attacker, witchDamageCollector[attacker]);
            PrintToConsoleAll("[DEBUG] Actual Witch Shots Count for the client stored: %d", witchShotsCollector[attacker]);
        }
	}
}

void checkForDrawCrown(int witchID, int attacker, int[] witchDamageCollector){

}

public void WitchKilled_Event(Event event, const char[] name, bool dontBroadcast)
{
    int attackeruserid = GetEventInt(event, "userid");
    int attacker = GetClientOfUserId(attackeruserid);
    int witchID = GetEventInt(event, "witchid");
    char witch_dmg_key[10];
    char witch_shots_key[10];
    Format(witch_dmg_key, sizeof(witch_dmg_key), "%x_dmg", witchID);
    Format(witch_shots_key, sizeof(witch_shots_key), "%x_shots", witchID);
    int witchDamageCollector[MAXPLAYERS + 1];
    GetTrieArray(witchDamageTrie, witch_dmg_key, witchDamageCollector, sizeof(witchDamageCollector));
    bool oneShot = GetEventBool(event, "oneshot");
    //crown
    if(oneShot){
        PrintToConsoleAll("[DEBUG] Witch oneshot was detected");
        HandleCrown(attacker, witchDamageCollector[attacker]);
    }else{
        //no crown but we can still have drawcrown
        //drawcrown is a situation where few conditions must be met:
        //1.witch attacker wears a shotgun
        //2.damage done to witch previously is less then 500 threshold so we should probably check that in WitchHurt_Event

    }
    RemoveFromTrie(witchDamageTrie, witch_dmg_key);
    RemoveFromTrie(witchShotsTrie, witch_shots_key);
    PrintToConsoleAll("[DEBUG] Witch was killed, tries are cleared.");
    CalculateAndPrintDamage(witchID);
}

void HandleCrown(int attacker, int damage){
    if ( IsValidClient(attacker) )
    {
		CPrintToChatAll( "{green}♔ {olive}%N {blue}crowned a witch {default}({green}%i {default}damage).", attacker, damage );
    }
    else {
		CPrintToChatAll( "{green}♔ {blue}A witch was crowned.");
    }
    
    Call_StartForward(crownForward);
    Call_PushCell(attacker);
    Call_PushCell(damage);
    Call_Finish();
}

public void CalculateAndPrintDamage(int witchID){
        int witchDamageCollector[MAXPLAYERS + 1];
        int witchShotsCollector[MAXPLAYERS + 1];
        char witch_dmg_key[10];
        char witch_shots_key[10];
        Format(witch_dmg_key, sizeof(witch_dmg_key), "%x_dmg", witchID);
        Format(witch_shots_key, sizeof(witch_shots_key), "%x_shots", witchID);
        GetTrieArray(witchDamageTrie, witch_dmg_key, witchDamageCollector, sizeof(witchDamageCollector));
        GetTrieArray(witchShotsTrie, witch_shots_key, witchShotsCollector, sizeof(witchShotsCollector));
}



bool IsWitch(int iEntity)
{
	if(iEntity > 0 && IsValidEntity(iEntity) && IsValidEdict(iEntity))
	{
		char strClassName[64];
		GetEdictClassname(iEntity, strClassName, sizeof(strClassName));
		return StrEqual(strClassName, "witch");
	}
	return false;
}

bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	return true;
}

