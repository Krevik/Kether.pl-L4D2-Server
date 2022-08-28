

#pragma semicolon 1

#include <sourcemod>
#include <sdktools> 
#define MAX_BUTTONS 25
new g_LastButtons[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "Simple Button Detector",
	author = "Krevik",
	description = "Detects button presses on clients",
	version = "0.0.0.1a",
	url = "http://www.sourcemod.net/"
};

public void OnPluginStart()
{

}

public OnClientDisconnect_Post(client)
{
    g_LastButtons[client] = 0;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
    for (new i = 0; i < MAX_BUTTONS; i++)
    {
        new button = (1 << i);
        
        if ((buttons & button))
        {
            if (!(g_LastButtons[client] & button))
            {
                OnButtonPress(client, button);
            }
        }
        else if ((g_LastButtons[client] & button))
        {
            OnButtonRelease(client, button);
        }
    }
    
    g_LastButtons[client] = buttons;
    
    return Plugin_Continue;
}

OnButtonPress(client, button)
{
    PrintToConsole(client, "Button pressed: %i", button);
	//8192 - r
}

OnButtonRelease(client, button)
{
    // do stuff
}
