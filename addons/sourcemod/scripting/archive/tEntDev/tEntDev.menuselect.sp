#pragma semicolon 1
#include <sourcemod>
#include <tentdev>
#include <colors>

public Plugin:myinfo =
{
	name 		= "tEntDev - Menu select",
	author 		= "Thrawn",
	description = "Selects an entity by choosing from a menu",
	version 	= VERSION,
};

new Handle:g_hEntityTree = INVALID_HANDLE;
new String:g_sNetClassSelect[MAXPLAYERS+1][32+1];
new String:g_sClassNameSelect[MAXPLAYERS+1][32+1];

public OnPluginStart() {
	CreateConVar("sm_tentdev_menuselect_version", VERSION, "", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	RegAdminCmd("sm_ted_menuselect", Command_ShowMenu, ADMFLAG_ROOT);
}

public Action:Command_ShowMenu(client,args) {
	ShowMenu_NetClassSelect(client);

	return Plugin_Handled;
}

public OnAllPluginsLoaded() {
	if (!LibraryExists("ted")) {
		SetFailState("tEntDev plugin not loaded!");
	}
}

public BuildTreeFromEntities() {
	ClearKeyValues(g_hEntityTree);

	g_hEntityTree = CreateKeyValues("Entities");

	for(new iEnt = 0; iEnt < GetMaxEntities(); iEnt++) {
		if(!IsValidEdict(iEnt))continue;
		if(!IsEntNetworkable(iEnt))continue;

		new String:sNetclass[64];
		if(GetEntityNetClass(iEnt, sNetclass, sizeof(sNetclass))) {
			new String:sName[128];
			if(iEnt > 0 && iEnt <= MaxClients && IsClientInGame(iEnt)) {
				Format(sName, sizeof(sName), "%N", iEnt);
			} else {
				GetEdictClassname(iEnt, sName, sizeof(sName));
			}

			new String:sEntity[6];
			Format(sEntity, sizeof(sEntity), "%i", iEnt);

			KvRewind(g_hEntityTree);
			if(KvJumpToKey(g_hEntityTree, sNetclass, true)) {
				if(KvJumpToKey(g_hEntityTree, sName, true)) {
					KvSetString(g_hEntityTree, sEntity, "1");
					KvGoBack(g_hEntityTree);
				}

				KvGoBack(g_hEntityTree);
			}
		}
	}

	KvRewind(g_hEntityTree);
	KeyValuesToFile(g_hEntityTree, "test.tree.txt");
}

public ShowMenu_NetClassSelect(client) {
	BuildTreeFromEntities();

	KvRewind(g_hEntityTree);
	if(KvGotoFirstSubKey(g_hEntityTree)) {
		new Handle:menu = CreateMenu(Handler_NetClassSelect);
		SetMenuTitle(menu, "Please select a NetClass");

		do { //Outer Loop, Netclasses
			new String:sNetclass[32];
			KvGetSectionName(g_hEntityTree, sNetclass, sizeof(sNetclass));
			AddMenuItem(menu, sNetclass, sNetclass);
		} while (KvGotoNextKey(g_hEntityTree));

		DisplayMenu(menu, client, 0);
	} else {
		CPrintToChat(client, "{red}There is no entity in the list. Something has gone wrong.");
	}
}

public Handler_NetClassSelect(Handle:menu, MenuAction:action, param1, param2) {
	//param1:: client
	//param2:: item

	if(action == MenuAction_Select) {
		new String:sNetclass[32];

		GetMenuItem(menu, param2, sNetclass, sizeof(sNetclass));

		strcopy(g_sNetClassSelect[param1], 32, sNetclass);
		ShowMenu_ClassNameSelect(param1, sNetclass);
		//CPrintToChat(param1, "You've chosen: {olive}%s", sNetclass);
	} else if (action == MenuAction_Cancel) {
	} else if (action == MenuAction_End) {
		CloseHandle(menu);
	}
}

public ShowMenu_ClassNameSelect(client, const String:sNetClass[]) {
	BuildTreeFromEntities();
	KvRewind(g_hEntityTree);
	if(KvJumpToKey(g_hEntityTree, sNetClass)) {
		new Handle:menu = CreateMenu(Handler_ClassNameSelect);
		new String:sTitle[128];
		Format(sTitle, sizeof(sTitle), "Please select a ClassName (%s)", sNetClass);
		SetMenuTitle(menu, sTitle);

		if(KvGotoFirstSubKey(g_hEntityTree)) {
			do {
				//Middle Loop, Class or Playernames
				new String:sClassName[32];
				KvGetSectionName(g_hEntityTree, sClassName, sizeof(sClassName));

				AddMenuItem(menu, sClassName, sClassName);
			} while (KvGotoNextKey(g_hEntityTree));

			KvGoBack(g_hEntityTree);
		}
		KvGoBack(g_hEntityTree);
		DisplayMenu(menu, client, 0);
	} else {
		CPrintToChat(client, "{red}There is no entity with NetClass {default}%s{red} anymore.");
	}
}

public Handler_ClassNameSelect(Handle:menu, MenuAction:action, param1, param2) {
	//param1:: client
	//param2:: item

	if(action == MenuAction_Select) {
		new String:sClassName[32];
		GetMenuItem(menu, param2, sClassName, sizeof(sClassName));

		strcopy(g_sClassNameSelect[param1], 32, sClassName);
		ShowMenu_EntitySelect(param1, g_sNetClassSelect[param1], sClassName);

		//CPrintToChat(param1, "You've chosen: {olive}%s{default}->{olive}%s", g_sNetClassSelect[param1], sClassName);
	} else if (action == MenuAction_Cancel) {
	} else if (action == MenuAction_End) {
		CloseHandle(menu);
	}
}

ShowMenu_EntitySelect(client, const String:sNetClass[], const String:sClassName[]) {
	KvRewind(g_hEntityTree);
	if(KvJumpToKey(g_hEntityTree, sNetClass)) {
		if(KvJumpToKey(g_hEntityTree, sClassName)) {
			if(KvGotoFirstSubKey(g_hEntityTree, false)) {
				new Handle:menu = CreateMenu(Handler_EntitySelect);
				new String:sTitle[128];
				Format(sTitle, sizeof(sTitle), "Please select an EntityID (%s)", sClassName);
				SetMenuTitle(menu, sTitle);

				new iCount = 0;
				new String:sEntityID[6];
				do {
					//Inner Loop, Entitiy IDs
					KvGetSectionName(g_hEntityTree, sEntityID, sizeof(sEntityID));
					AddMenuItem(menu, sEntityID, sEntityID);
					iCount++;
				} while (KvGotoNextKey(g_hEntityTree, false));
				KvGoBack(g_hEntityTree);

				if(iCount == 1) {
					CloseHandle(menu);
					//CPrintToChat(client, "Directly selecting: {olive}%s{default}->{olive}%s{default}->{olive}%s", sNetClass, sClassName, sEntityID);

					new iEnt = StringToInt(sEntityID);
					TED_SelectEntity(client, iEnt);
				} else {
					DisplayMenu(menu, client, 0);
				}
			}
		}
	}
}

public Handler_EntitySelect(Handle:menu, MenuAction:action, param1, param2) {
	//param1:: client
	//param2:: item

	if(action == MenuAction_Select) {
		new String:sEntityID[32];
		GetMenuItem(menu, param2, sEntityID, sizeof(sEntityID));

		new iEnt = StringToInt(sEntityID);

		//CPrintToChat(param1, "You've selected {olive}%s{default}->{olive}%s{default}->{olive}%s", g_sNetClassSelect[param1], g_sClassNameSelect[param1], sEntityID);
		TED_SelectEntity(param1, iEnt);
	} else if (action == MenuAction_Cancel) {
	} else if (action == MenuAction_End) {
		CloseHandle(menu);
	}
}

public ClearKeyValues(&Handle:hKV) {
	if(hKV != INVALID_HANDLE) {
		CloseHandle(hKV);
		hKV = INVALID_HANDLE;
	}
}