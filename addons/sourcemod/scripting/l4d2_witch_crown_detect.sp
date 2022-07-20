#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <l4d2util>


//Features::
// --detect crown
// --print damage done to witch by survs
// TODO --detect draw crown

int TEAM_SURVIVOR = 2;
int TEAM_INFECTED = 3;

Handle witchDamageTrie = INVALID_HANDLE;
Handle witchHarasserTrie = INVALID_HANDLE;
Handle witchUnharassedDamageTrie = INVALID_HANDLE;
Handle witchShotsTrie = INVALID_HANDLE;
Handle witchPrintedTrie = INVALID_HANDLE;

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

public void OnPluginStart(){
	witchDamageTrie = CreateTrie();
    witchHarasserTrie = CreateTrie();
    witchUnharassedDamageTrie = CreateTrie();
    witchShotsTrie = CreateTrie();
    witchPrintedTrie = CreateTrie();

    HookEvent("infected_hurt", WitchHurt_Event, EventHookMode_Post);
    HookEvent("witch_harasser_set", Event_WitchHarasserSet, EventHookMode_Post);
    HookEvent("witch_killed", WitchKilled_Event, EventHookMode_Post);
    HookEvent("player_death", PlayerDied_Event, EventHookMode_Post);

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
    char witch_harasser_key[20];
    Format(witch_harasser_key, sizeof(witch_harasser_key), "%x_harasser", witchID);
    delayedAddTrie(witch_harasser_key, harasser);
}

public void delayedAddTrie(char[] witch_harasser_key, int harasser){
	DataPack pack;
	CreateDataTimer(0.2, AddToTheTrie, pack);
    pack.WriteString(witch_harasser_key);
    pack.WriteCell(harasser);
}

public Action AddToTheTrie(Handle timer, DataPack pack)
{
    char witch_harasser_key[20];
    int harasser;
	pack.Reset();
    pack.ReadString(witch_harasser_key, sizeof(witch_harasser_key));
    harasser = pack.ReadCell();
    SetTrieValue(witchHarasserTrie, witch_harasser_key, harasser);
}

public void WitchHurt_Event(Event event, const char[] name, bool dontBroadcast)
{
    int entityID = GetEventInt(event, "entityid");
	if (IsWitch(entityID))
	{
        int witchDamageCollector[MAXPLAYERS + 1];
        int witchUnharassedDamageCollector[MAXPLAYERS + 1];
        int witchShotsCollector[MAXPLAYERS + 1];
        bool hasHarraser = false;
        int harraserClient = -1;
        int witchID = entityID;
        char witch_dmg_key[20];
        char witch_unharassed_dmg_key[20];
        char witch_harasser_key[20];
        char witch_shots_key[20];
        Format(witch_dmg_key, sizeof(witch_dmg_key), "%x_dmg", witchID);
        Format(witch_unharassed_dmg_key, sizeof(witch_unharassed_dmg_key), "%x_uh_dmg", witchID);
        Format(witch_harasser_key, sizeof(witch_harasser_key), "%x_harasser", witchID);
        Format(witch_shots_key, sizeof(witch_shots_key), "%x_shots", witchID);
        GetTrieArray(witchUnharassedDamageTrie, witch_unharassed_dmg_key, witchUnharassedDamageCollector, sizeof(witchUnharassedDamageCollector) );
        GetTrieArray(witchDamageTrie, witch_dmg_key, witchDamageCollector, sizeof(witchDamageCollector));
        GetTrieArray(witchShotsTrie, witch_shots_key, witchShotsCollector, sizeof(witchShotsCollector));
        hasHarraser = GetTrieValue(witchHarasserTrie, witch_harasser_key, harraserClient);

        int attackerId = GetEventInt(event, "attacker");
        int attacker = GetClientOfUserId(attackerId);
        //we only care about survivor attackers or if the attacker is tank
		if (IsValidClient(attacker))
		{
            int damageDone = GetEventInt(event, "amount");
            if(GetClientTeam(attacker) == TEAM_SURVIVOR){
                witchShotsCollector[attacker] += 1;
                witchDamageCollector[attacker] += damageDone;
                SetTrieArray(witchDamageTrie, witch_dmg_key, witchDamageCollector, sizeof(witchDamageCollector));
                SetTrieArray(witchShotsTrie, witch_shots_key, witchShotsCollector, sizeof(witchShotsCollector));
                //PrintToConsoleAll("[DEBUG] Actual Witch Damage for the client %d stored: %d", attacker, witchDamageCollector[attacker]);
                //PrintToConsoleAll("[DEBUG] Actual Witch Shots Count for the client stored: %d", witchShotsCollector[attacker]);

                if(!hasHarraser){
                    //here we can collect our non-harassed damage. Harraser will be set in a moment, so we can detect draw crown using the trie;
                    witchUnharassedDamageCollector[attacker] += damageDone;
                    SetTrieArray(witchUnharassedDamageTrie, witch_unharassed_dmg_key, witchUnharassedDamageCollector, sizeof(witchUnharassedDamageCollector) );
                    //PrintToConsoleAll("[DEBUG] Actual unharassed witch damage: %d", witchUnharassedDamageCollector[attacker]);
                }
            }
        }
	}
}

public void WitchKilled_Event(Event event, const char[] name, bool dontBroadcast)
{
    int attackeruserid = GetEventInt(event, "userid");
    int attacker = GetClientOfUserId(attackeruserid);
    int witchID = GetEventInt(event, "witchid");
    int witchUnharassedDamageCollector[MAXPLAYERS + 1];
    char witch_dmg_key[20];
    char witch_shots_key[20];
    char witch_unharassed_dmg_key[20];
    Format(witch_dmg_key, sizeof(witch_dmg_key), "%x_dmg", witchID);
    Format(witch_unharassed_dmg_key, sizeof(witch_unharassed_dmg_key), "%x_uh_dmg", witchID);
    Format(witch_shots_key, sizeof(witch_shots_key), "%x_shots", witchID);
    int witchDamageCollector[MAXPLAYERS + 1];
    int witchShotsCollector[MAXPLAYERS + 1];
    GetTrieArray(witchDamageTrie, witch_dmg_key, witchDamageCollector, sizeof(witchDamageCollector) );
    GetTrieArray(witchShotsTrie, witch_shots_key, witchShotsCollector, sizeof(witchShotsCollector) );
    bool unharassedDmg = GetTrieArray(witchUnharassedDamageTrie, witch_unharassed_dmg_key, witchUnharassedDamageCollector, sizeof(witchUnharassedDamageCollector) );
    int witchUnharassedDamageByTheClient = witchUnharassedDamageCollector[attacker];
    bool oneShot = GetEventBool(event, "oneshot");
    //check if attacker was a tank
    if(IsTank(attacker)){
        CPrintToChatAll("{default}[{green}!{default}] {red}Tank {default}({olive}%N{default}) killed the {red}Witch", attacker);
        return;
    }
    //crown
    if(oneShot || (witchShotsCollector[attacker] < 9 && getTotalDamageDoneToWitchBySurvivors(witchID) == witchDamageCollector[attacker] && !unharassedDmg) ){
        //PrintToConsoleAll("[DEBUG] Witch oneshot was detected");
        HandleCrown(attacker, witchDamageCollector[attacker]);
    }else{
        //potential draw crown?
        //conditions:
        //harasser is the killer *
        //damage before harassing less than 500 *
        //killer wears a shotgun *
        //witch didn't incap any player - we don't need to check for incaps? because it is kinda contained in harraser check
        //killer has done 100% damage of done to witch AMONG survivors *
        if( unharassedDmg ){
            //soo we have some unharassed damage. We need to check how much and if the damage comes from the harasser
            if( (witchUnharassedDamageByTheClient > 0 && witchUnharassedDamageByTheClient < 501) || getTotalDamageDoneToWitchBySurvivors(witchID) == witchDamageCollector[attacker] ){
                //harasser is the killer
                //damage before harassing is less than 500
                char weaponNameBuffer[128];
                GetClientWeapon(attacker, weaponNameBuffer, sizeof(weaponNameBuffer));
                if(StrContains(weaponNameBuffer, "shotgun", false) != -1){
                    //attacker wears a shotgun
                    int totalWitchDamage = getTotalDamageDoneToWitchBySurvivors(witchID) - witchUnharassedDamageCollector[attacker];
                    if(witchDamageCollector[attacker] >= totalWitchDamage){
                        //well, finally seems like we have draw crown - report
                        //PrintToConsoleAll("[DEBUG] Witch draw-crown was detected");
                        HandleDrawCrown(attacker, witchDamageCollector[attacker]);
                    }
                }
            }
        }
    }

    CalculateAndPrintDamage(witchID);
    //PrintToConsoleAll("[DEBUG] Witch was killed, tries are cleared.");
}

void cleanUp(int witchID){
    char witch_dmg_key[20];
    char witch_unharassed_dmg_key[20];
    char witch_harasser_key[20];
    char witch_shots_key[20];
    char witch_printed_key[20];

    Format(witch_dmg_key, sizeof(witch_dmg_key), "%x_dmg", witchID);
    Format(witch_unharassed_dmg_key, sizeof(witch_unharassed_dmg_key), "%x_uh_dmg", witchID);
    Format(witch_harasser_key, sizeof(witch_harasser_key), "%x_harasser", witchID);
    Format(witch_shots_key, sizeof(witch_shots_key), "%x_shots", witchID);
    Format(witch_printed_key, sizeof(witch_printed_key), "%x_print", witchID);

    RemoveFromTrie(witchDamageTrie, witch_dmg_key);
    RemoveFromTrie(witchUnharassedDamageTrie, witch_unharassed_dmg_key);
    RemoveFromTrie(witchHarasserTrie, witch_harasser_key);
    RemoveFromTrie(witchShotsTrie, witch_shots_key);
    RemoveFromTrie(witchPrintedTrie, witch_printed_key);

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

void HandleDrawCrown(int attacker, int damage){
    if ( IsValidClient(attacker) )
    {
		CPrintToChatAll( "{green}♔ {olive}%N {blue}draw-crowned a witch {default}({green}%i {default}damage).", attacker, damage );
    }
    else {
		CPrintToChatAll( "{green}♔ {blue}A witch was draw-crowned.");
    }
    
    Call_StartForward(drawCrownForward);
    Call_PushCell(attacker);
    Call_PushCell(damage);
    Call_Finish();
}


public void PlayerDied_Event(Handle event, const char[] name, bool dontBroadcast)
{
	int userId = GetEventInt(event, "userid");
	int victim = GetClientOfUserId(userId);
	int attacker = GetEventInt(event, "attackerentid");

	if (IsValidClient(victim) && GetClientTeam(victim) == TEAM_SURVIVOR && IsWitch(attacker) )
	{
		//Delayed Timer in case Witch gets killed while she's running off.
        delayedPrint(attacker);
	}
}

public void delayedPrint(int witchID){
	DataPack pack;
	CreateDataTimer(3.0, PrintAnyway, pack);
	pack.WriteCell(witchID);
}

public Action PrintAnyway(Handle timer, DataPack pack)
{
    int printed = 0;
    char witch_printed_key[20];
    int witchMaxHealth = GetConVarInt(FindConVar("z_witch_health"));
    int maxSurvivors = GetConVarInt(FindConVar("survivor_limit"));
    int witchID;
    pack.Reset();
    witchID = pack.ReadCell();
    Format(witch_printed_key, sizeof(witch_printed_key), "%x_print", witchID);
    GetTrieValue(witchPrintedTrie, witch_printed_key, printed);

    if(printed == 0){
        int OneHundredPercentDamageValue = getTotalDamageDoneToWitchBySurvivors(witchID);
        int witchRemainingHealth = witchMaxHealth - OneHundredPercentDamageValue;
        if(witchRemainingHealth > 1){
            CPrintToChatAll("{default}[{green}!{default}] {blue}Witch {default}had {olive}%d {default}health remaining", witchRemainingHealth);
        }
        CalculateAndPrintDamage(witchID);
    }
    return Plugin_Continue;
}

public int getTotalDamageDoneToWitchBySurvivors(int witchID){
    int maxSurvivors = GetConVarInt(FindConVar("survivor_limit"));
    int witchDamageCollector[MAXPLAYERS + 1];
    char witch_dmg_key[20];
    Format(witch_dmg_key, sizeof(witch_dmg_key), "%x_dmg", witchID);
    GetTrieArray(witchDamageTrie, witch_dmg_key, witchDamageCollector, sizeof(witchDamageCollector));
    int OneHundredPercentDamageValue = 0;
    int survivorsTMP = 0;
    for(int client = 1; client <= MAXPLAYERS; client++){
        if(IsValidClient(client)){
            OneHundredPercentDamageValue += witchDamageCollector[client];
            //optimization
            if(GetClientTeam(client) == TEAM_SURVIVOR){
                survivorsTMP++;
            }
            if(survivorsTMP >= maxSurvivors){
                break;
            }
        }
    }
    return OneHundredPercentDamageValue;
}


public void CalculateAndPrintDamage(int witchID){
    int maxSurvivors = GetConVarInt(FindConVar("survivor_limit"));
    int damagersPercents[MAXPLAYERS + 1];
    int witchDamageCollector[MAXPLAYERS + 1];
    int witchShotsCollector[MAXPLAYERS + 1];
    int printed = 0;
    char witch_dmg_key[20];
    char witch_printed_key[20];
    Format(witch_dmg_key, sizeof(witch_dmg_key), "%x_dmg", witchID);
    Format(witch_printed_key, sizeof(witch_printed_key), "%x_print", witchID);
    GetTrieArray(witchDamageTrie, witch_dmg_key, witchDamageCollector, sizeof(witchDamageCollector));
    GetTrieValue(witchPrintedTrie, witch_printed_key, printed);
    int OneHundredPercentDamageValue = getTotalDamageDoneToWitchBySurvivors(witchID);

    //now we can successfully calculate percent of damage done to witch by survivors
    int survivorsTMP = 0;
    for(int client = 1; client <= MAXPLAYERS; client++){
        if(IsValidClient(client)){
            damagersPercents[client] = getPercentDamageDone(witchDamageCollector[client], OneHundredPercentDamageValue);
            //optimization
            if(GetClientTeam(client) == TEAM_SURVIVOR){
                survivorsTMP++;
            }
            if(survivorsTMP >= maxSurvivors){
                break;
            }
        }
    }

    //sort???? do we need sorting actually? let's leave it unsorted now

    if(OneHundredPercentDamageValue > 1){
	    CPrintToChatAll("{default}[{green}!{default}] {blue}Damage {default}dealt to {blue}Witch:");
        survivorsTMP = 0;
        int printedDamage = 0;
        for (int client = 1; client <= MAXPLAYERS; client++)
        {
            if(IsValidClient(client)){
                if(witchDamageCollector[client] > 0){
                    CPrintToChatAll("{blue}[{default}%d{blue}] ({default}%i%%{blue}) {olive}%N", witchDamageCollector[client], getPercentDamageDone(witchDamageCollector[client], OneHundredPercentDamageValue), client);
                    printedDamage += witchDamageCollector[client];
                }
                //optimization
                if(GetClientTeam(client) == TEAM_SURVIVOR){
                    survivorsTMP++;
                }
                if(survivorsTMP >= maxSurvivors || printedDamage >= OneHundredPercentDamageValue){
                    break;
                }
            }
        }
    }
    printed = 1;
    SetTrieValue(witchPrintedTrie, witch_printed_key, printed, true);
    cleanUp(witchID);
}

int getPercentDamageDone(int damageDone, int OneHundredPercentDamageValue){
    int result = RoundToFloor( (float(damageDone)/float(OneHundredPercentDamageValue)) * 100.0);
    return result;
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

