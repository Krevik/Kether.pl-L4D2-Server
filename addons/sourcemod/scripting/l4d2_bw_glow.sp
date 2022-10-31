#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

#define PLUGIN_VERSION "1.0.6"

public Plugin myinfo =
{
	name = "thirdstrike_glow",
	author = "little_froy",
	description = "game play",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=340159"
};

ConVar C_color;
ConVar C_range;

int O_color;
int O_range;

bool Added[MAXPLAYERS+1];

bool is_on_thirdstrike(int client)
{
	return GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike") != 0;
}

void set_glow(int client)
{
    if(!Added[client])
    {
        SetEntProp(client, Prop_Send, "m_iGlowType", 3);
        SetEntProp(client, Prop_Send, "m_glowColorOverride", O_color);
        SetEntProp(client, Prop_Send, "m_nGlowRange", O_range);
        Added[client] = true;
    }
}

void reset_glow(int client)
{
    if(Added[client])
    {
        SetEntProp(client, Prop_Send, "m_iGlowType", 0);
        SetEntProp(client, Prop_Send, "m_glowColorOverride", 0);
        SetEntProp(client, Prop_Send, "m_nGlowRange", 0, 1);
        SetEntProp(client, Prop_Send, "m_bFlashing", 0, 1);
        Added[client] = false;
    }
}

public void OnGameFrame()
{
    for(int client = 1; client <= MaxClients; client++)
    {
        if(IsClientInGame(client))
        {
            if(GetClientTeam(client) == 2)
            {
                if(IsPlayerAlive(client))
                {
                    if(is_on_thirdstrike(client))
                    {
                        set_glow(client);
                    }
                    else
                    {
                        reset_glow(client);
                    }
                }
            }
            else
            {
                reset_glow(client);
            }
        }
        else
        {
            Added[client] = false;
        }
    }
}

public void Event_round_start(Event event, const char[] name, bool dontBroadcast)
{
    for(int client = 1; client <= MaxClients; client++)
    {
        if(IsClientInGame(client))
        {
            reset_glow(client);
        }
        Added[client] = false;
    }
}

public void Event_player_death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
    if(client >= 1 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && !IsPlayerAlive(client))
    {
        reset_glow(client);
    }
}

int get_color()
{
    char cvar_colors[13];
    C_color.GetString(cvar_colors, sizeof(cvar_colors));
	char colors_get[3][4];
	ExplodeString(cvar_colors, ";", colors_get, 3, 4);
	return StringToInt(colors_get[0]) + StringToInt(colors_get[1]) * 256 + StringToInt(colors_get[2]) * 65536;
}

void internal_changed()
{
    O_color = get_color();
    O_range = C_range.IntValue;
}

public void convar_changed(ConVar convar, const char[] oldValue, const char[] newValue)
{
	internal_changed();
}

public void OnConfigsExecuted()
{
	internal_changed();
}

public void OnPluginStart()
{
    HookEvent("round_start", Event_round_start);
    HookEvent("player_death", Event_player_death);

    C_color = CreateConVar("thirdstrike_glow_color", "255;255;255", "color of glow, split up with \";\"");
    C_range = CreateConVar("thirdstrike_glow_range", "1600", "max visible range of glow", _, true, 1.0);

    CreateConVar("thirdstrike_glow_version", PLUGIN_VERSION, "version of \"thirdstrike_glow\"", FCVAR_DONTRECORD);

    C_color.AddChangeHook(convar_changed);
    C_range.AddChangeHook(convar_changed);

    AutoExecConfig(true, "thirdstrike_glow");
}