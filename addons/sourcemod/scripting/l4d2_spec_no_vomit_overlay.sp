#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

#define OBS_MODE_IN_EYE 4

public Plugin myinfo =
{
    name = "L4D2 Spectator No Vomit Overlay",
    author = "Codex",
    description = "Removes boomer bile screen effect for first-person spectators",
    version = "1.0.0",
    url = ""
};

ConVar g_hEnable;
ConVar g_hInterval;
Handle g_hSweepTimer;

public void OnPluginStart()
{
    g_hEnable = CreateConVar(
        "l4d2_spec_no_vomit_overlay_enable",
        "1",
        "Enable removing vomit overlay for first-person spectators.",
        FCVAR_NOTIFY,
        true,
        0.0,
        true,
        1.0
    );

    g_hInterval = CreateConVar(
        "l4d2_spec_no_vomit_overlay_interval",
        "0.10",
        "How often (seconds) to sweep spectators and clear vomit overlay.",
        FCVAR_NOTIFY,
        true,
        0.05,
        true,
        1.0
    );

    g_hEnable.AddChangeHook(OnSettingsChanged);
    g_hInterval.AddChangeHook(OnSettingsChanged);

    AutoExecConfig(true, "l4d2_spec_no_vomit_overlay");
    RebuildSweepTimer();
}

public void OnMapEnd()
{
    delete g_hSweepTimer;
}

public void OnSettingsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    RebuildSweepTimer();
}

void RebuildSweepTimer()
{
    delete g_hSweepTimer;

    if (!g_hEnable.BoolValue)
    {
        return;
    }

    float interval = g_hInterval.FloatValue;
    if (interval < 0.05)
    {
        interval = 0.05;
    }

    g_hSweepTimer = CreateTimer(interval, Timer_ClearSpectatorOverlay, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ClearSpectatorOverlay(Handle timer)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || IsFakeClient(client))
        {
            continue;
        }

        if (GetClientTeam(client) != 1)
        {
            continue;
        }

        if (GetEntProp(client, Prop_Send, "m_iObserverMode") != OBS_MODE_IN_EYE)
        {
            continue;
        }

        int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
        if (target < 1 || target > MaxClients || !IsClientInGame(target))
        {
            continue;
        }

        // This native is the standard way in Left4DHooks to remove the IT/vomit effect.
        L4D_OnITExpired(client);
    }

    return Plugin_Continue;
}
