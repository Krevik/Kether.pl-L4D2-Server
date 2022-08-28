#include <sourcemod>  

public OnMapStart()
{
	ServerCommand("sm_cvar sv_minrate 30000")
	ServerCommand("sm_cvar sv_maxrate 67000")
	ServerCommand("sm_cvar sv_mincmdrate 67")
	ServerCommand("sm_cvar sv_maxcmdrate 67")
	ServerCommand("sm_cvar sv_minupdaterate 67")
	ServerCommand("sm_cvar sv_maxupdaterate 67")
	ServerCommand("sm_cvar net_splitpacket_maxrate 33500")
	ServerCommand("sm_cvar fps_max 0")
}

public void OnPluginStart ( )
{
	ServerCommand("sm_cvar sv_minrate 30000")
	ServerCommand("sm_cvar sv_maxrate 67000")
	ServerCommand("sm_cvar sv_mincmdrate 67")
	ServerCommand("sm_cvar sv_maxcmdrate 67")
	ServerCommand("sm_cvar sv_minupdaterate 67")
	ServerCommand("sm_cvar sv_maxupdaterate 67")
	ServerCommand("sm_cvar net_splitpacket_maxrate 33500")
	ServerCommand("sm_cvar fps_max 0")
}

public Plugin myinfo = 
{
	name = "EXEC CVARS",
	author = "CryWolf",
	description = "find missinc cvars",
	version = "0.2",
	url = "www.dark-arena.com"
}