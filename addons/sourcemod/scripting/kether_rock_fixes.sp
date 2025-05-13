/**
 * Tank Rock Fix + Glow (v1.1)
 * — Ensures all tank rocks become shootable immediately
 * — Adds a bright glow overlay visible only to survivors
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <l4d_stocks>
#include <l4d2lib>
#include <l4d2_direct>

#define COLLISION_GROUP_NORMAL 0
#define MAX_ENTITIES          2048

// rock ent index → glow‐overlay entref
static int g_RockGlowRef[MAX_ENTITIES];

public Plugin myinfo =
{
    name        = "Tank Rock Fix + Glow",
    author      = "Krevik",
    description = "Makes tank rocks immediately shootable and glow for survivors",
    version     = "1.1",
    url         = ""
};

public void OnPluginStart()
{
    // clear refs
    for (int i = 0; i < MAX_ENTITIES; i++)
        g_RockGlowRef[i] = INVALID_ENT_REFERENCE;
}

// sdkhooks will call this for every entity created
public void OnEntityCreated(int ent, const char[] classname)
{
    // catch all physics props (vanilla, override, multiplayer, etc)
    if (!StrContains(classname, "prop_physics", false))
        return;

    if (IsTankRock(ent))
    {
        // wait a tick, then fix collision + glow
        SDKHook(ent, SDKHook_PostThink, Hook_FixRockCollision);
    }
}

// sdkhooks will call this when any entity is destroyed
public void OnEntityDestroyed(int ent)
{
    if (ent < 0 || ent >= MAX_ENTITIES)
        return;

    int glowRef = g_RockGlowRef[ent];
    if (glowRef != INVALID_ENT_REFERENCE)
    {
        int glowEnt = EntRefToEntIndex(glowRef);
        if (IsValidEntity(glowEnt))
            RemoveEntity(glowEnt);
        g_RockGlowRef[ent] = INVALID_ENT_REFERENCE;
    }
}

// run once, right after the rock is spawned
public Action Hook_FixRockCollision(int rock)
{
    // unhook so it only runs once
    SDKUnhook(rock, SDKHook_PostThink, Hook_FixRockCollision);

    // make it bullet‐solid immediately
    SetEntProp(rock, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_NORMAL);
    AcceptEntityInput(rock, "Wake");

    // spawn the glow overlay
    CreateRockGlow(rock);

    return Plugin_Continue;
}

// check model path for both "rock" and "tank"
bool IsTankRock(int ent)
{
    static char model[PLATFORM_MAX_PATH];
    GetEntPropString(ent, Prop_Data, "m_ModelName", model, sizeof(model));
    return (StrContains(model, "rock", false) != -1
         && StrContains(model, "tank", false)  != -1);
}

// attach a prop_dynamic_override that glows
void CreateRockGlow(int target)
{
	L4D2_SetEntityGlow(target, L4D2Glow_Constant, 0, 22, {255, 255, 255}, true);
}

// only survivors see the glow overlay
public Action Hook_GlowTransmit(int glowEnt, int client)
{
    return (GetClientTeam(client) == 2)
         ? Plugin_Continue
         : Plugin_Handled;
}
