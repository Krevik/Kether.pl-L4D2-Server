#pragma semicolon 1
#include <sourcemod>
#include <tentdev>

public Plugin:myinfo =
{
	name 		= "tEntDev - Ignore common netprops",
	author 		= "Thrawn",
	description = "Predefine filters for netprops that are not of interest most of the time",
	version 	= VERSION,
};

new Handle:g_hCvarPath = INVALID_HANDLE;
new String:g_sPath[PLATFORM_MAX_PATH];

public OnAllPluginsLoaded() {
	if (!LibraryExists("ted")) {
		SetFailState("tEntDev plugin not loaded!");
	}
}

public OnPluginStart() {
	CreateConVar("sm_tentdev_ignore_common_version", VERSION, "", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_hCvarPath = CreateConVar("sm_tentdev_ignorefiles_path", "configs/tEntDevIgnoreLists/", "Path to where the netprop ignore files reside", FCVAR_PLUGIN);
	HookConVarChange(g_hCvarPath, Cvar_Changed);

	RegAdminCmd("sm_ted_ignorefile", Command_IgnoreNetpropsByFile, ADMFLAG_ROOT);
	RegAdminCmd("sm_ted_unignorefile", Command_UnignoreNetpropsByFile, ADMFLAG_ROOT);
}

public OnConfigsExecuted() {
	GetConVarString(g_hCvarPath, g_sPath, sizeof(g_sPath));
}

public Cvar_Changed(Handle:convar, const String:oldValue[], const String:newValue[]) {
	OnConfigsExecuted();
}

public ParseFile(client, const String:sPath[], bool:bIgnore) {
	new iIgnoreCount = 0;
	new Handle:hFile = OpenFile(sPath, "r");
	new String:sLine[64];
	while(ReadFileLine(hFile, sLine, sizeof(sLine))) {
		TrimString(sLine);
		LogMessage("line: %s", sLine);
		if(strlen(sLine) == 0)continue;
		if(strncmp(sLine, "//", 2, false) == 0)continue;
		if(strncmp(sLine, ";", 1, false) == 0)continue;
		if(strncmp(sLine, "#", 1, false) == 0)continue;

		if(bIgnore) {
			TED_IgnoreNetprop(client, sLine);
		} else {
			TED_UnignoreNetprop(client, sLine);
		}
		iIgnoreCount++;
	}
	CloseHandle(hFile);

	return iIgnoreCount;
}

public Action:Command_IgnoreNetpropsByFile(client,args) {
	if(args == 1) {
		new String:sFile[PLATFORM_MAX_PATH];
		GetCmdArg(1, sFile, sizeof(sFile));

		new String:sPath[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sPath, sizeof(sPath), "%s%s", g_sPath, sFile);

		if(!FileExists(sPath)) {
			ReplyToCommand(client, "File does not exist");
			return Plugin_Handled;
		}

		new iIgnoreCount = ParseFile(client, sPath, true);

		ReplyToCommand(client, "Loaded file %s, ignored %i netprops", sPath, iIgnoreCount);
	} else {
		ReplyToCommand(client, "Usage: sm_ted_ignorefile <filename>.");
	}

	return Plugin_Handled;
}

public Action:Command_UnignoreNetpropsByFile(client,args) {
	if(args == 1) {
		new String:sFile[PLATFORM_MAX_PATH];
		GetCmdArg(1, sFile, sizeof(sFile));

		new String:sPath[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sPath, sizeof(sPath), "%s%s", g_sPath, sFile);

		if(!FileExists(sPath)) {
			ReplyToCommand(client, "File does not exist");
			return Plugin_Handled;
		}

		new iIgnoreCount = ParseFile(client, sPath, false);

		ReplyToCommand(client, "Loaded file %s, ignored %i netprops", sPath, iIgnoreCount);
	} else {
		ReplyToCommand(client, "Usage: sm_ted_ignorefile <filename>.");
	}

	return Plugin_Handled;
}