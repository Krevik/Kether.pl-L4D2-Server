#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <sdktools_sound>

#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util>
#define ENTITY_MAX_NAME_LENGTH 64

#pragma semicolon 1
#pragma newdecls required

#define give "items/suitchargeok1.wav"

public Plugin myinfo = {
    name        = "[L4D|L4D2]items chat give",
    author      = "King_OXO, Krevik, StarterX4",
    description = "commands in chat give items for you",
    version     = "3.0.0",
    url         = "www.sourcemod.net"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_nexus_m16", M16, "m16");
}

public void OnMapStart()
{
    PrecacheSound(give, true);
}

public Action Ak(int client, int args)
{
    char sWeaponName[ENTITY_MAX_NAME_LENGTH];
	int secWeaponIndex = GetPlayerWeaponSlot(client, L4D2WeaponSlot_Primary);
	GetEdictClassname(secWeaponIndex, sWeaponName, sizeof(sWeaponName));
	
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        RemovePlayerItem(client, secWeaponIndex);
		RemoveEntity(secWeaponIndex);
        FakeClientCommand(client, "give rifle_ak47");
		FakeClientCommand(client, "upgrade_add LASER_SIGHT");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
    SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action M16(int client, int args)
{
    char sWeaponName[ENTITY_MAX_NAME_LENGTH];
	int secWeaponIndex = GetPlayerWeaponSlot(client, L4D2WeaponSlot_Primary);
	GetEdictClassname(secWeaponIndex, sWeaponName, sizeof(sWeaponName));
	
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        RemovePlayerItem(client, secWeaponIndex);
		RemoveEntity(secWeaponIndex);
        FakeClientCommand(client, "give rifle");
		FakeClientCommand(client, "upgrade_add LASER_SIGHT");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
    SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action Rifle_desert(int client, int args)
{
    char sWeaponName[ENTITY_MAX_NAME_LENGTH];
	int secWeaponIndex = GetPlayerWeaponSlot(client, L4D2WeaponSlot_Primary);
	GetEdictClassname(secWeaponIndex, sWeaponName, sizeof(sWeaponName));
	
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        RemovePlayerItem(client, secWeaponIndex);
		RemoveEntity(secWeaponIndex);
        FakeClientCommand(client, "give rifle_desert");
		FakeClientCommand(client, "upgrade_add LASER_SIGHT");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action Awp(int client, int args)
{
    char sWeaponName[ENTITY_MAX_NAME_LENGTH];
	int secWeaponIndex = GetPlayerWeaponSlot(client, L4D2WeaponSlot_Primary);
	GetEdictClassname(secWeaponIndex, sWeaponName, sizeof(sWeaponName));
	
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        RemovePlayerItem(client, secWeaponIndex);
		RemoveEntity(secWeaponIndex);
        FakeClientCommand(client, "give sniper_awp");
		FakeClientCommand(client, "upgrade_add LASER_SIGHT");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action M60(int client, int args)
{
    char sWeaponName[ENTITY_MAX_NAME_LENGTH];
	int secWeaponIndex = GetPlayerWeaponSlot(client, L4D2WeaponSlot_Primary);
	GetEdictClassname(secWeaponIndex, sWeaponName, sizeof(sWeaponName));
	
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        RemovePlayerItem(client, secWeaponIndex);
		RemoveEntity(secWeaponIndex);
        FakeClientCommand(client, "give rifle_m60");
		FakeClientCommand(client, "upgrade_add LASER_SIGHT");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action fire(int client, int args)
{
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        FakeClientCommand(client, "upgrade_add INCENDIARY_AMMO");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action Explosive(int client, int args)
{
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        FakeClientCommand(client, "upgrade_add EXPLOSIVE_AMMO");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action Explosive_pack(int client, int args)
{
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        FakeClientCommand(client, "give upgradepack_explosive");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action firepack(int client, int args)
{
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        FakeClientCommand(client, "give upgradepack_incendiary");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action Smg(int client, int args)
{
    char sWeaponName[ENTITY_MAX_NAME_LENGTH];
	int secWeaponIndex = GetPlayerWeaponSlot(client, L4D2WeaponSlot_Primary);
	GetEdictClassname(secWeaponIndex, sWeaponName, sizeof(sWeaponName));
	
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        RemovePlayerItem(client, secWeaponIndex);
		RemoveEntity(secWeaponIndex);
        FakeClientCommand(client, "give smg");
		FakeClientCommand(client, "upgrade_add LASER_SIGHT");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action Smg2(int client, int args)
{
    char sWeaponName[ENTITY_MAX_NAME_LENGTH];
	int secWeaponIndex = GetPlayerWeaponSlot(client, L4D2WeaponSlot_Primary);
	GetEdictClassname(secWeaponIndex, sWeaponName, sizeof(sWeaponName));
	
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        RemovePlayerItem(client, secWeaponIndex);
		RemoveEntity(secWeaponIndex);
        FakeClientCommand(client, "give smg_silenced");
		FakeClientCommand(client, "upgrade_add LASER_SIGHT");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action Smg3(int client, int args)
{
    char sWeaponName[ENTITY_MAX_NAME_LENGTH];
	int secWeaponIndex = GetPlayerWeaponSlot(client, L4D2WeaponSlot_Primary);
	GetEdictClassname(secWeaponIndex, sWeaponName, sizeof(sWeaponName));
	
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        RemovePlayerItem(client, secWeaponIndex);
		RemoveEntity(secWeaponIndex);
        FakeClientCommand(client, "give smg_mp5");
		FakeClientCommand(client, "upgrade_add LASER_SIGHT");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action Pistol(int client, int args)
{
    char sWeaponName[ENTITY_MAX_NAME_LENGTH];
	int secWeaponIndex = GetPlayerWeaponSlot(client, L4D2WeaponSlot_Secondary);
	GetEdictClassname(secWeaponIndex, sWeaponName, sizeof(sWeaponName));
	
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        RemovePlayerItem(client, secWeaponIndex);
		RemoveEntity(secWeaponIndex);
        FakeClientCommand(client, "give pistol");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action Deagle(int client, int args)
{
    char sWeaponName[ENTITY_MAX_NAME_LENGTH];
	int secWeaponIndex = GetPlayerWeaponSlot(client, L4D2WeaponSlot_Secondary);
	GetEdictClassname(secWeaponIndex, sWeaponName, sizeof(sWeaponName));
	
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        RemovePlayerItem(client, secWeaponIndex);
		RemoveEntity(secWeaponIndex);
        FakeClientCommand(client, "give pistol_magnum");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action Military(int client, int args)
{
    char sWeaponName[ENTITY_MAX_NAME_LENGTH];
	int secWeaponIndex = GetPlayerWeaponSlot(client, L4D2WeaponSlot_Primary);
	GetEdictClassname(secWeaponIndex, sWeaponName, sizeof(sWeaponName));
	
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        RemovePlayerItem(client, secWeaponIndex);
		RemoveEntity(secWeaponIndex);
        FakeClientCommand(client, "give sniper_military");
		FakeClientCommand(client, "upgrade_add LASER_SIGHT");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action hunting(int client, int args)
{
    char sWeaponName[ENTITY_MAX_NAME_LENGTH];
	int secWeaponIndex = GetPlayerWeaponSlot(client, L4D2WeaponSlot_Primary);
	GetEdictClassname(secWeaponIndex, sWeaponName, sizeof(sWeaponName));
	
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        RemovePlayerItem(client, secWeaponIndex);
		RemoveEntity(secWeaponIndex);
        FakeClientCommand(client, "give hunting_rifle");
		FakeClientCommand(client, "upgrade_add LASER_SIGHT");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action Spas(int client, int args)
{
    char sWeaponName[ENTITY_MAX_NAME_LENGTH];
	int secWeaponIndex = GetPlayerWeaponSlot(client, L4D2WeaponSlot_Primary);
	GetEdictClassname(secWeaponIndex, sWeaponName, sizeof(sWeaponName));
	
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        RemovePlayerItem(client, secWeaponIndex);
		RemoveEntity(secWeaponIndex);
        FakeClientCommand(client, "give shotgun_spas");
		FakeClientCommand(client, "upgrade_add LASER_SIGHT");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action Scout(int client, int args)
{
    char sWeaponName[ENTITY_MAX_NAME_LENGTH];
	int secWeaponIndex = GetPlayerWeaponSlot(client, L4D2WeaponSlot_Primary);
	GetEdictClassname(secWeaponIndex, sWeaponName, sizeof(sWeaponName));
	
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        RemovePlayerItem(client, secWeaponIndex);
		RemoveEntity(secWeaponIndex);
        FakeClientCommand(client, "give sniper_scout");
        FakeClientCommand(client, "upgrade_add LASER_SIGHT");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action chrome(int client, int args)
{
    char sWeaponName[ENTITY_MAX_NAME_LENGTH];
	int secWeaponIndex = GetPlayerWeaponSlot(client, L4D2WeaponSlot_Primary);
	GetEdictClassname(secWeaponIndex, sWeaponName, sizeof(sWeaponName));
	
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        RemovePlayerItem(client, secWeaponIndex);
		RemoveEntity(secWeaponIndex);
        FakeClientCommand(client, "give shotgun_chrome");
        FakeClientCommand(client, "upgrade_add LASER_SIGHT");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action Auto(int client, int args)
{
    char sWeaponName[ENTITY_MAX_NAME_LENGTH];
	int secWeaponIndex = GetPlayerWeaponSlot(client, L4D2WeaponSlot_Primary);
	GetEdictClassname(secWeaponIndex, sWeaponName, sizeof(sWeaponName));
	
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        RemovePlayerItem(client, secWeaponIndex);
		RemoveEntity(secWeaponIndex);
        FakeClientCommand(client, "give autoshotgun");
        FakeClientCommand(client, "upgrade_add LASER_SIGHT");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action pump(int client, int args)
{
    char sWeaponName[ENTITY_MAX_NAME_LENGTH];
	int secWeaponIndex = GetPlayerWeaponSlot(client, L4D2WeaponSlot_Primary);
	GetEdictClassname(secWeaponIndex, sWeaponName, sizeof(sWeaponName));
	
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        RemovePlayerItem(client, secWeaponIndex);
		RemoveEntity(secWeaponIndex);
        FakeClientCommand(client, "give pumpshotgun");
        FakeClientCommand(client, "upgrade_add LASER_SIGHT");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action molotov(int client, int args)
{
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        FakeClientCommand(client, "give molotov");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action blie(int client, int args)
{
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        FakeClientCommand(client, "give vomitjar");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action pipe(int client, int args)
{
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        FakeClientCommand(client, "give pipe_bomb");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action pill(int client, int args)
{
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        FakeClientCommand(client, "give pain_pills");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action kit(int client, int args)
{
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        FakeClientCommand(client, "give first_aid_kit");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
}

public Action adrenaline(int client, int args)
{
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        FakeClientCommand(client, "give adrenaline");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action knife(int client, int args)
{
    char sWeaponName[ENTITY_MAX_NAME_LENGTH];
	int secWeaponIndex = GetPlayerWeaponSlot(client, L4D2WeaponSlot_Secondary);
	GetEdictClassname(secWeaponIndex, sWeaponName, sizeof(sWeaponName));
	
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        RemovePlayerItem(client, secWeaponIndex);
		RemoveEntity(secWeaponIndex);
        FakeClientCommand(client, "give knife");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action guitar(int client, int args)
{
    char sWeaponName[ENTITY_MAX_NAME_LENGTH];
	int secWeaponIndex = GetPlayerWeaponSlot(client, L4D2WeaponSlot_Secondary);
	GetEdictClassname(secWeaponIndex, sWeaponName, sizeof(sWeaponName));
	
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        RemovePlayerItem(client, secWeaponIndex);
		RemoveEntity(secWeaponIndex);
        FakeClientCommand(client, "give eletric_guitar");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action machete(int client, int args)
{
    char sWeaponName[ENTITY_MAX_NAME_LENGTH];
	int secWeaponIndex = GetPlayerWeaponSlot(client, L4D2WeaponSlot_Secondary);
	GetEdictClassname(secWeaponIndex, sWeaponName, sizeof(sWeaponName));
	
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        RemovePlayerItem(client, secWeaponIndex);
		RemoveEntity(secWeaponIndex);
        FakeClientCommand(client, "give machete");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action katana(int client, int args)
{
    char sWeaponName[ENTITY_MAX_NAME_LENGTH];
	int secWeaponIndex = GetPlayerWeaponSlot(client, L4D2WeaponSlot_Secondary);
	GetEdictClassname(secWeaponIndex, sWeaponName, sizeof(sWeaponName));
	
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        RemovePlayerItem(client, secWeaponIndex);
		RemoveEntity(secWeaponIndex);
        FakeClientCommand(client, "give katana");
    }
    EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action launcher(int client, int args)
{
    char sWeaponName[ENTITY_MAX_NAME_LENGTH];
	int secWeaponIndex = GetPlayerWeaponSlot(client, L4D2WeaponSlot_Primary);
	GetEdictClassname(secWeaponIndex, sWeaponName, sizeof(sWeaponName));
	
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        RemovePlayerItem(client, secWeaponIndex);
		RemoveEntity(secWeaponIndex);
	    FakeClientCommand(client, "give grenade_launcher");
		FakeClientCommand(client, "upgrade_add LASER_SIGHT");
	}
	EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action cola(int client, int args)
{
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
	{
	    FakeClientCommand(client, "give cola_bottles");
	}
	EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action defib(int client, int args)
{
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
	{
	    FakeClientCommand(client, "give grenade_launcher");
		FakeClientCommand(client, "upgrade_add LASER_SIGHT");
	}
	EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

public Action chainsaw(int client, int args)
{
    char sWeaponName[ENTITY_MAX_NAME_LENGTH];
	int secWeaponIndex = GetPlayerWeaponSlot(client, L4D2WeaponSlot_Secondary);
	GetEdictClassname(secWeaponIndex, sWeaponName, sizeof(sWeaponName));
	
    int giveflags = GetCommandFlags("give");
    int upgradeflags = GetCommandFlags("upgrade_add");
    SetCommandFlags("give", giveflags & ~FCVAR_CHEAT);
    if (IsValidClient(client))
    {
        RemovePlayerItem(client, secWeaponIndex);
		RemoveEntity(secWeaponIndex);
	    FakeClientCommand(client, "give chainsaw");
		FakeClientCommand(client, "upgrade_add LASER_SIGHT");
	}
	EmitSoundToClient(client, give, SNDCHAN_WEAPON, SNDLEVEL_SCREAMING);
	SetCommandFlags("give", giveflags|FCVAR_CHEAT);
}

bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2)
	{
		return false;
	}
	
	return true;
}
