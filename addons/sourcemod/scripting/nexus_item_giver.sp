#include <sourcemod>
#include <sdktools>

public Plugin:myinfo =
{
    name = "Give Weapon",
    author = "Assistant",
    description = "A simple plugin that allows the player to receive any weapon by name",
    version = "1.0",
    url = "https://www.example.com"
};

public OnPluginStart()
{
    RegConsoleCmd("!give", Command_Give, "Usage: !give <weapon_name> - Gives the player the specified weapon");
}

public Action:Command_Give(client, args)
{
    // Check if the command was issued by a player named Nexus
	new String:clientName[64];
	GetClientName(client, clientName, sizeof(clientName));
    if (!IsClientInGame(client) || strcmp(clientName, "Nexus") == 0)
    {
        return Plugin_Handled;
    }

    // Check if a weapon name was specified
    if (args < 1)
    {
        PrintToChat(client, "Usage: !give <weapon_name> - Gives the player the specified weapon");
        return Plugin_Handled;
    }

    // Get the specified weapon name
    new String:weaponName[64];
    GetCmdArg(1, weaponName, sizeof(weaponName));

    // Give the player the specified weapon
    GivePlayerItem(client, weaponName);

    return Plugin_Handled;
}