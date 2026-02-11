#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

public Plugin myinfo = 
{
    name = "No Boomer Vomit Cooldown",
    author = "Perplexity, Krevik",
    description = "Deletes boomer vomit cooldown after spawn",
    version = "3.0",
    url = ""
};

#define BOOMER_CLASS "boomer"

Handle g_hBoomerTimers[MAXPLAYERS+1];
float g_fSpawnTime[MAXPLAYERS+1];

public void OnPluginStart()
{
    HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnPluginEnd()
{
    for(int i=1; i<=MaxClients; i++)
    {
        delete g_hBoomerTimers[i];
        g_fSpawnTime[i] = 0.0;
    }
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidInfected(client) || !IsBoomer(client) || IsFakeClient(client))
        return;

    // Jeśli z jakiegoś powodu mamy jeszcze stary timer, ubij go
    if (g_hBoomerTimers[client] != null)
    {
        delete g_hBoomerTimers[client];
        g_hBoomerTimers[client] = null;
    }

    g_fSpawnTime[client] = GetEngineTime();

    // Przekazujemy po prostu userid jako "any" do timera,
    // bez używania DataPack (który powodował wyjątki out of bounds).
    int userid = GetClientUserId(client);
    g_hBoomerTimers[client] = CreateTimer(0.0, Timer_FrameCheck, userid, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_FrameCheck(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client == 0 || !IsValidInfected(client) || !IsBoomer(client))
        return Plugin_Stop;
    
    // W L4D2 specjalne zdolności (w tym wymioty boomera) są podpięte jako "m_customAbility"
    if (!HasEntProp(client, Prop_Send, "m_customAbility"))
        return Plugin_Stop;

    int vomitAbility = GetEntPropEnt(client, Prop_Send, "m_customAbility");
    if (vomitAbility == -1)
        return Plugin_Continue;

    // Wystarczy zresetować cooldown na samym kliencie – ability_vomit nie ma m_flNextAttack.
    float currentTime = GetEngineTime();
    SetEntPropFloat(client, Prop_Send, "m_flNextAttack", 0.0);
    
    // Timing log do konsoli gracza
    float spawnDelta = currentTime - g_fSpawnTime[client];
    PrintToServer("[NoCD] Boomer %N: Vomit ready in %.3f seconds post-spawn", client, spawnDelta);
    PrintToConsole(client, "[NoCD] Your vomit ready in %.3f s (spawn at %.2f)", spawnDelta, g_fSpawnTime[client]);
    
    g_hBoomerTimers[client] = null;
    g_fSpawnTime[client] = 0.0;
    return Plugin_Stop;
}

bool IsValidInfected(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && 
            GetClientTeam(client) == 3 && IsPlayerAlive(client));
}

bool IsBoomer(int client)
{
    char model[64];
    GetEntPropString(client, Prop_Data, "m_ModelName", model, sizeof(model));
    return (StrContains(model, "boomer") != -1);
}