#pragma semicolon 1
#include <sourcemod>
#include <tentdev>

public Plugin:myinfo =
{
	name 		= "tEntDev - List select",
	author 		= "Thrawn",
	description = "Selects an entity by choosing from a list",
	version 	= VERSION,
};

public OnPluginStart() {
	CreateConVar("sm_tentdev_listselect_version", VERSION, "", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	RegAdminCmd("sm_ted_listselect", Command_ListEntities, ADMFLAG_ROOT);
	RegAdminCmd("sm_ted_selectid", Command_SelectEntityByID, ADMFLAG_ROOT);
}

public OnAllPluginsLoaded() {
	if (!LibraryExists("ted")) {
		SetFailState("tEntDev plugin not loaded!");
	}
}

public Action:Command_SelectEntityByID(client,args) {
	if(args == 1) {
		new String:sEnt[32];
		GetCmdArg(1, sEnt, sizeof(sEnt));

		new iEnt = StringToInt(sEnt);
		if(IsValidEdict(iEnt)) {
			TED_SelectEntity(client, iEnt);
		} else {
			ReplyToCommand(client, "Entity with id %i is not valid", iEnt);
		}
	} else {
		ReplyToCommand(client, "Usage: sm_ted_selectid <entity-id>");
	}

	return Plugin_Handled;
}

public Action:Command_ListEntities(client,args) {
	for(new iEnt = 0; iEnt < GetMaxEntities(); iEnt++) {
		if(!IsValidEdict(iEnt))continue;

		new String:sNetclass[64];
		if(GetEntityNetClass(iEnt, sNetclass, sizeof(sNetclass))) {
			new String:sResult[256];

			new String:sName[128];
			if(iEnt > 0 && iEnt <= MaxClients && IsClientInGame(iEnt)) {
				Format(sName, sizeof(sName), "%N", iEnt);
			} else {
				GetEdictClassname(iEnt, sName, sizeof(sName));
			}

			Format(sResult, sizeof(sResult), "%5i %30s %s", iEnt, sNetclass, sName);
			ReplyToCommand(client, sResult);
		}

	}

	return Plugin_Handled;
}