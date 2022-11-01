#include <sourcemod>
#pragma semicolon 1
#pragma newdecls required
#define IG_VERSION "1.4"

public Plugin myinfo =
{
	name = "[L4D & L4D2] Item Giver",
	author = "Psyk0tik (Crasher_3637)",
	description = "Provides a command to give items to players.",
	version = IG_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=308268"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Item Giver only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	RegConsoleCmd("sm_give", cmdGive, "Let's give him some item");
	CreateConVar("ig_pluginversion", IG_VERSION, "Item Giver version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
}

public Action cmdGive(int client, int args)
{
	if (client == 0 || !IsClientInGame(client))
	{
		ReplyToCommand(client, "[IG] You must be in-game to use this command.");
		return Plugin_Handled;
	}
	if (GetClientTeam(client) != 2)
	{
		ReplyToCommand(client, "\x04[IG]\x01 You must be on the survivor team to use this command.");
		return Plugin_Handled;
	}
	char item[32];
	GetCmdArg(1, item, sizeof(item));
	if( StrContains(item, "pump", false) > -1 || StrContains(item, "shotgun", false) > -1 || StrContains(item, "chrom", false) > -1 || StrContains(item, "uzi", false) > -1 ||
	StrContains(item, "silenc", false) > -1 || StrContains(item, "smg", false) > -1 || StrContains(item, "scout", false) > -1){
		int iCmdFlags = GetCommandFlags("give");
		SetCommandFlags("give", iCmdFlags & ~FCVAR_CHEAT);
		FakeClientCommand(client, "give %s", item);
		SetCommandFlags("give", iCmdFlags);
	}
	return Plugin_Handled;
}