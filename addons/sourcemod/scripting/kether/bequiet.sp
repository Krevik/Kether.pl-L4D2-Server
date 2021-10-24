#pragma semicolon 1

#include <sourcemod>

public Plugin myinfo = 
{
    name = "BeQuiet",
    author = "Sir",
    description = "Please be Quiet!",
    version = "1.33.7",
    url = "https://github.com/SirPlease/SirCoding"
}

public void OnPluginStart()
{
    AddCommandListener(Say_Callback, "say");
    AddCommandListener(TeamSay_Callback, "say_team");
}


public Action Say_Callback(int client, char[] command, int args)
{
    char sayWord[MAX_NAME_LENGTH];
    GetCmdArg(1, sayWord, sizeof(sayWord));
    
    if(sayWord[0] == '!' || sayWord[0] == '/')
    {
        return Plugin_Handled;
    }
    return Plugin_Continue; 
}

public Action TeamSay_Callback(int client, char[] command, int args)
{
    char sayWord[MAX_NAME_LENGTH];
    GetCmdArg(1, sayWord, sizeof(sayWord));
    
    if(sayWord[0] == '!' || sayWord[0] == '/')
    {
        return Plugin_Handled;
    }
    return Plugin_Continue; 
}