#pragma semicolon 1

#include <multicolors>
#include <sourcemod>
#include "sdktools_functions.inc"

public Plugin myinfo = 
{
    name = "only bot command",
    author = "Krevik",
    description = "only bot game",
    version = "1.0.0",
    url = ""
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
    MarkNativeAsOptional("GetUserMessageType");
    return APLRes_Success;
} 

public void OnPluginStart()
{
	RegConsoleCmd("sm_onlybotgame", Ready_CMD, "Let's get ready!");
}

public Action:Ready_CMD(client, args)
{
	new onlyBotsGame = 1;
	new String:sArg[32];
	GetCmdArg(1, sArg, sizeof(sArg));
	onlyBotsGame = StringToInt(sArg);
	if(onlyBotsGame == 1){
		SetConVarInt(FindConVar("sb_all_bot_game"), 1);
		SetConVarInt(FindConVar("allow_all_bot_survivor_team"), 1);
	}else{
		SetConVarInt(FindConVar("sb_all_bot_game"), 0);
		SetConVarInt(FindConVar("allow_all_bot_survivor_team"), 0);
	}
	
	CPrintToChatAll("Changed only bot game to %d", onlyBotsGame);
	return Plugin_Handled;
}

