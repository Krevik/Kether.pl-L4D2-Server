#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1
#pragma newdecls required
#define L4D2 Spitter Supergirl
#define PLUGIN_VERSION "1.5"

#define ZOMBIECLASS_SPITTER 4

// ===========================================
// Spitter Setup
// ===========================================

// =================================
// Acidic Bile
// =================================

//Bools
bool isAcidicBile = false;

//Handles
Handle cvarAcidicBile;
Handle cvarAcidicBileChance;

// =================================
// Acidic Slobber
// =================================

//Bools
bool isAcidicSlobber = false;

//Handles
Handle cvarAcidicSlobber;
Handle cvarAcidicSlobberChance;
Handle cvarAcidicSlobberDamage;
Handle cvarAcidicSlobberRange;
Handle cvarAcidicSlobberTimer[MAXPLAYERS+1];

// =================================
// Acidic Pool
// =================================

//Bools
bool isAcidicPool = false;
bool isAcidicPoolDrop[MAXPLAYERS+1] = false;

//Handles
Handle cvarAcidicPool;
Handle cvarAcidicPoolCooldown;
Handle cvarAcidicPoolTimer[MAXPLAYERS+1];

// =================================
// Acidic Splash
// =================================

//Bools
bool isAcidicSplash = false;

//Handles
Handle cvarAcidicSplash;
Handle cvarAcidicSplashChance;
Handle cvarAcidicSplashDamage;
Handle cvarAcidicSplashRange;

// =================================
// Acid Swipe
// =================================

//Bools
bool isAcidSwipe = false;

//Handles
Handle cvarAcidSwipe;
Handle cvarAcidSwipeChance;
Handle cvarAcidSwipeDamage;
Handle cvarAcidSwipeDuration;
Handle cvarAcidSwipeTimer[MAXPLAYERS + 1];
int acidswipe[MAXPLAYERS+1];

// =================================
// Hydra Strike
// =================================

//Bools
bool isHydraStrike = false;
bool isHydraStrikeActive[MAXPLAYERS+1] = false;

//Handles
Handle cvarHydraStrike;
Handle cvarHydraStrikeCooldown;
Handle cvarHydraStrikeTimer[MAXPLAYERS+1];

// =================================
// Sticky Goo
// =================================

//Bools
bool isStickyGoo = false;
bool isStickyGooJump = false;

//Handles
Handle cvarStickyGoo;
Handle cvarStickyGooDuration;
Handle cvarStickyGooSpeed;
Handle cvarStickyGooJump;
Handle cvarStickyGooTimer[MAXPLAYERS + 1];
Handle cvarAcidDelay[MAXPLAYERS+1];

int stickygoo[MAXPLAYERS+1];
int laggedMovementOffset = 0;

// =================================
// Supergirl
// =================================

//Bools
bool isSupergirl = false;
bool isSupergirlSpeed = false;

//Handles
Handle cvarSupergirl;
Handle cvarSupergirlSpeed;
Handle cvarSupergirlDuration;
Handle cvarSupergirlSpeedDuration;
Handle cvarSupergirlTimer[MAXPLAYERS +1];
Handle cvarSupergirlSpeedTimer[MAXPLAYERS +1];

bool aciddelay[MAXPLAYERS+1] = false;


// ===========================================
// Generic Setup
// ===========================================

char GAMEDATA_FILENAME[] = "l4d2_viciousplugins";

//Handles
Handle PluginStartTimer;
Handle sdkCallDetonateAcid;
Handle sdkCallFling;
Handle sdkCallVomitOnPlayer;
Handle ConfigFile;
int g_iAbilityO = -1;
int g_iNextActO = -1;

// ===========================================
// Plugin Info
// ===========================================

public Plugin myinfo = 
{
    name = "[L4D2] Spitter Supergirl",
    author = "Mortiegama",
    description = "Adds a host of abilities to the Spitter to add Supergirl like powers.",
    version = PLUGIN_VERSION,
    url = "https://forums.alliedmods.net/showthread.php?t=122802"
}

// ===========================================
// Plugin Start
// ===========================================

public void OnPluginStart()
{
	CreateConVar("l4d_ssg_version", PLUGIN_VERSION, "Spitter Supergirl Version", FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_NOTIFY);

	// ======================================
	// Spitter Ability: Acidic Bile
	// ======================================
	cvarAcidicBile = CreateConVar("l4d_ssg_acidicbile", "1", "Enables Acidic Bile ability: Survivors that have wandered into an acid pool have a chance of being splashed with bile and attracting common infected. (Def 1)");
	cvarAcidicBileChance = CreateConVar("l4d_ssg_acidicbilechance", "5", "Chance that the Survivor will be biled upon when standing in spit. (Def 5)");

	// ======================================
	// Spitter Ability: Acidic Pool
	// ======================================
	cvarAcidicPool = CreateConVar("l4d_ssg_acidicpool", "1", "Enables Acidic Pool ability: Due to the unstable nature of the Spitter's body, periodically a pool of Spit will leak out beneath her feet. (Def 1)");
	cvarAcidicPoolCooldown = CreateConVar("l4d_ssg_acidicpoolcooldown", "30.0", "Period of time between Acid Pool drops. (Def 30.0)");

	// ======================================
	// Spitter Ability: Acidic Slobber
	// ======================================
	cvarAcidicSlobber = CreateConVar("l4d_ssg_acidicslobber", "1", "Enables Acidic Slobber ability: The Spitter is constantly shaking her head which will occasionally cause some of the drooling acid to land on nearby Survivors. (Def 1)");
	cvarAcidicSlobberChance = CreateConVar("l4d_ssg_acidicslobberchance", "5", "Chance that a Survivor will be hit with Acid from the Spitter's slobber. (Def 5)(5 = 5%)");
	cvarAcidicSlobberDamage = CreateConVar("l4d_ssg_acidicslobberdamage", "15", "Amount of damage the Acidic Slobber will cause to a Survivor. (Def 15)");
	cvarAcidicSlobberRange = CreateConVar("l4d_ssg_acidicslobberrange", "500.0", "Distance the Acidic Slobber will travel. (Def 500.0)");

	// ======================================
	// Spitter Ability: Acidic Splash
	// ======================================	
	cvarAcidicSplash = CreateConVar("l4d_ssg_acidicsplash", "1", "Enables Acid Splash ability: When a Spitter takes damage, the fresh wounds have a chance of splashing acid on any nearby Survivors. (Def 1)");
	cvarAcidicSplashChance = CreateConVar("l4d_ssg_acidicsplashchance", "50", "Chance that a Survivor will be splashed by the Spitter's acid splash. (Def 50)(50 = 50%)");
	cvarAcidicSplashDamage = CreateConVar("l4d_ssg_acidicsplashdamage", "6", "Amount of damage the Acidic Splash will cause to a Survivor. (Def 6)");
	cvarAcidicSplashRange = CreateConVar("l4d_ssg_acidicsplashrange", "500.0", "Distance the Acidic Splash will travel from Spitter. (Def 500.0)");
	
	// ======================================
	// Spitter Ability: Acid Swipe
	// ======================================
	cvarAcidSwipe = CreateConVar("l4d_ssg_acidswipe", "1", "Enables Acid Swipe ability: The Spitter uses her acid coated fingers to swipe at a Survivor, causing damage over time as the wound burns. (Def 1)");
	cvarAcidSwipeChance = CreateConVar("l4d_ssg_acidswipechance", "100", "Chance that when a Spitter claws a Survivor they will take damage over time. (100 = 100%). (Def 100)");
	cvarAcidSwipeDuration = CreateConVar("l4d_ssg_acidswipeduration", "10", "For how many seconds does the Acid Swipe last. (Def 10)");
	cvarAcidSwipeDamage = CreateConVar("l4d_ssg_acidswipedamage", "1", "How much damage is inflicted by Acid Swipe each second. (Def 1)");
	
	// ======================================
	// Spitter Ability: Hydra Strike
	// ======================================
	cvarHydraStrike = CreateConVar("l4d_ssg_hydrastrike", "1", "Enables Hydra Strike ability: Allows the Spitter to fire off a second spit rapidly after the first. (Def 1)");
	cvarHydraStrikeCooldown = CreateConVar("l4d_ssg_hydrastrikecooldown", "0.0", "Additional recharge time before the Hydra Strike allows another spit. (Def 0.0)");

	// ======================================
	// Spitter Ability: Sticky Goo
	// ======================================
	cvarStickyGoo = CreateConVar("l4d_ssg_stickygoo", "1", "Enables Sticky Goo ability: Any Survivor standing inside a pool of Spit will be stuck in the goo and find it harder to move out quickly. (Def 1)");
	cvarStickyGooJump = CreateConVar("l4d_ssg_stickygoojump", "1", "Prevents the Survivor from jumping while speed is reduced. (Def 1)");
	cvarStickyGooDuration = CreateConVar("l4d_ssg_stickygooduration", "3", "For how long after exiting the Sticky Goo will a Survivor be slowed. (Def 3)");
	cvarStickyGooSpeed = CreateConVar("l4d_ssg_stickygoospeed", "0.5", "Speed reduction to Survivor caused by the Sticky Goo. (Def 0.5)");

	// ======================================
	// Spitter Ability: Super Girl
	// ======================================
	cvarSupergirl = CreateConVar("l4d_ssg_supergirl", "1", "Enables Super Girl ability: After launching a spit, the Spitter is coated in a protective layer that slowly drips off and reduces all damage until it is gone. (Def 1)");
	cvarSupergirlDuration = CreateConVar("l4d_ssg_supergirlduration", "4", "How long the Spitter is invulnerable. (Def 4)");
	
	// ======================================
	// Spitter Ability: Super Girl Speed
	// ======================================
	cvarSupergirlSpeed = CreateConVar("l4d_ssg_supergirlspeed", "1", "Enables Super Girl Speed ability: Works with the Supergirl ability, the spit also coats the Spitters feet increasing movement speed for a brief period after launching a spit. (Def 1)");
	cvarSupergirlSpeedDuration = CreateConVar("l4d_ssg_supergirlspeedduration", "4", "How long the Spitter is invulnerable. (Def 4)");
	
	// ======================================
	// Hook Events
	// ======================================
	HookEvent("spit_burst", Event_SpitBurst);
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	// ======================================
	// General Setup
	// ======================================
	laggedMovementOffset = FindSendPropInfo("CTerrorPlayer", "m_flLaggedMovementValue");
	g_iNextActO			=	FindSendPropInfo("CBaseAbility","m_nextActivationTimer");
	g_iAbilityO			=	FindSendPropInfo("CTerrorPlayer","m_customAbility");
	AutoExecConfig(true, "plugin.L4D2.Supergirl");
	PluginStartTimer = CreateTimer(3.0, OnPluginStart_Delayed);
	ConfigFile = LoadGameConfigFile(GAMEDATA_FILENAME);
	
	// ======================================
	// SDK Calls
	// ======================================
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "CSpitterProjectile_Detonate");
	sdkCallDetonateAcid = EndPrepSDKCall();
	if (sdkCallDetonateAcid == null)
	{
		LogError("Could not prep the Detonate Acid function");
	}
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "CTerrorPlayer_OnVomitedUpon");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	sdkCallVomitOnPlayer = EndPrepSDKCall();
	if (sdkCallVomitOnPlayer == null)
	{
		SetFailState("Cant initialize OnVomitedUpon SDKCall");
	}
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "CTerrorPlayer_Fling");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	sdkCallFling = EndPrepSDKCall();
	if (sdkCallFling == null)
	{
		SetFailState("Cant initialize Fling SDKCall");
	}
}

// ===========================================
// Plugin Start Delayed
// ===========================================

public Action OnPluginStart_Delayed(Handle timer)
{
	if (GetConVarInt(cvarAcidicBile))
	{
		isAcidicBile = true;
	}
	if (GetConVarInt(cvarAcidicSlobber))
	{
		isAcidicSlobber = true;
	}
	if (GetConVarInt(cvarAcidicSplash))
	{
		isAcidicSplash = true;
	}
	if (GetConVarInt(cvarAcidicPool))
	{
		isAcidicPool = true;
	}
	if (GetConVarInt(cvarAcidSwipe))
	{
		isAcidSwipe = true;
	}
	if (GetConVarInt(cvarHydraStrike))
	{
		isHydraStrike = true;
	}
	if (GetConVarInt(cvarStickyGoo))
	{
		isStickyGoo = true;
	}
	if (GetConVarInt(cvarStickyGooJump))
	{
		isStickyGooJump = true;
	}
	if (GetConVarInt(cvarSupergirl))
	{
		isSupergirl = true;
	}
	if (GetConVarInt(cvarSupergirlSpeed))
	{
		isSupergirlSpeed = true;
	}
	if (PluginStartTimer != null)
	{
 		KillTimer(PluginStartTimer);
		PluginStartTimer = null;
	}
	return Plugin_Stop;
}
// ====================================================================================================================
// ===========================================                              =========================================== 
// ===========================================           SPITTER            =========================================== 
// ===========================================                              =========================================== 
// ====================================================================================================================

// ===========================================
// Spitter Setup Events
// ===========================================
public void OnClientPostAdminCheck(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event,"userid"));
	if (IsValidSpitter(client))
	{
		// =================================
		// Spitter Ability: Acidic Pool
		// =================================
		if (isAcidicPool)
		{
		SpitterAbility_AcidicPool(client);
		}
		// =================================
		// Spitter Ability: Acidic Slobber
		// =================================
		if (isAcidicSlobber)
		{
			SpitterAbility_AcidicSlobber(client);
		}
	}
}

public Action Event_SpitBurst(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event,"userid"));
	// =================================
	// Spitter Ability: Hydra Strike
	// =================================
	if (isHydraStrike)
	{
		SpitterAbility_HydraStrike(client);
	}
	// =================================
	// Spitter Ability: Super Girl
	// =================================
	if (isSupergirl)
	{
		SpitterAbility_SuperGirl(client);
	}
	// =================================
	// Spitter Ability: Super Girl Speed
	// =================================
	if (isSupergirlSpeed)
	{
		SpitterAbility_SuperGirlSpeed(client);
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (IsValidEntity(inflictor) && IsValidClient(victim) && GetClientTeam(victim) == 2)
	{
		char classname[56];
		char weapon[64];
		GetEdictClassname(inflictor, classname, sizeof(classname));
		if (IsValidClient(attacker))
		{
			GetClientWeapon(attacker, weapon, sizeof(weapon));
		}
		if (StrEqual(classname, "insect_swarm"))
		{
			// =================================
			// Spitter Ability: Acidic Bile
			// =================================
			if (isAcidicBile)
			{
				SpitterAbility_AcidicBile(victim, attacker);
			}
			// =================================
			// Spitter Ability: Sticky Goo
			// =================================
			if (isStickyGoo)
			{
				SpitterAbility_StickyGoo(victim);
			}
			cvarAcidDelay[victim] = CreateTimer(1.0, Timer_AcidDelay, victim);
			aciddelay[victim] = true;
		}
		if (IsValidSpitter(attacker) && StrEqual(weapon, "weapon_spitter_claw"))
		{
			// =================================
			// Spitter Ability: Acid Swipe
			// =================================
			if (isAcidSwipe)
			{
				SpitterAbility_AcidSwipe(victim, attacker);
			}
		}
	}
	if (IsValidClient(attacker) && GetClientTeam(attacker) == 2 && IsValidSpitter(victim))
	{
		// =================================
		// Spitter Ability: Acidic Splash
		// =================================
		if (isAcidicSplash)
		{
			SpitterAbility_AcidicSplash(victim);
		}
	}
}

public Action Timer_AcidDelay(Handle timer, any victim)
{
	aciddelay[victim] = false;
	if (cvarAcidDelay[victim] != null)
	{
		KillTimer(cvarAcidDelay[victim]);
		cvarAcidDelay[victim] = null;
	}
	return Plugin_Stop;
}
// ===========================================
// Spitter Ability: Acidic Bile
// ===========================================
// Description: Enables the Acidic Bile ability, Survivors who enter a pool of spit will attract infected.
void SpitterAbility_AcidicBile(int victim, int attacker)
{
	int AcidicBileChance = GetRandomInt(0, 99);
	int AcidicBilePercent = (GetConVarInt(cvarAcidicBileChance));
	if (IsValidClient(victim) && GetClientTeam(victim) == 2 && AcidicBileChance < AcidicBilePercent)
	{
		SDKCall(sdkCallVomitOnPlayer, victim, attacker, true);
	}
}
// ===========================================
// Spitter Ability: Acidic Pool
// ===========================================
// Description: Enables the Acidic Pool ability, the Spitter randomly drops a pool of spit where she stands.
void SpitterAbility_AcidicPool(int client)			
{
	cvarAcidicPoolTimer[client] = CreateTimer(GetConVarFloat(cvarAcidicPoolCooldown), Timer_AcidicPool, client, TIMER_REPEAT);
}

public Action Timer_AcidicPool(Handle timer, any client)
{
	if (!IsValidSpitter(client) || IsPlayerGhost(client))
	{
		if (cvarAcidicPoolTimer[client] != null)
		{
			KillTimer(cvarAcidicPoolTimer[client]);
			cvarAcidicPoolTimer[client] = null;
		}	
		return Plugin_Stop;
	}
	isAcidicPoolDrop[client] = true;
	Create_AcidicPool(client);
	return Plugin_Continue;
}

void Create_AcidicPool(int client)
{
	float vecPos[3];
	GetClientAbsOrigin(client, vecPos);
	vecPos[2]+=16.0;
	int iAcid = CreateEntityByName("spitter_projectile");
	if (IsValidEntity(iAcid))
	{
		DispatchSpawn(iAcid);
		SetEntPropFloat(iAcid, Prop_Send, "m_DmgRadius", 1024.0);
		SetEntProp(iAcid, Prop_Send, "m_bIsLive", 1 );
		SetEntPropEnt(iAcid, Prop_Send, "m_hThrower", client);
		TeleportEntity(iAcid, vecPos, NULL_VECTOR, NULL_VECTOR);
		SDKCall(sdkCallDetonateAcid, iAcid);
	}
	if (IsValidClient(client))
	{
		isAcidicPoolDrop[client] = false;
	}
}
// ===========================================
// Spitter Ability: Acid Slobber
// ===========================================
// Description: Enables the ability for the Spitter to slobber on Survivors causing them acidic damage.
void SpitterAbility_AcidicSlobber(int client)
{
	cvarAcidicSlobberTimer[client] = CreateTimer(0.5, Timer_AcidicSlobber, client, TIMER_REPEAT);
}
			
public Action Timer_AcidicSlobber(Handle timer, any client)
{
	if (!IsValidSpitter(client) || IsPlayerGhost(client))
	{
		if (cvarAcidicSlobberTimer[client] != null)
		{
			KillTimer(cvarAcidicSlobberTimer[client]);
			cvarAcidicSlobberTimer[client] = null;
		}
		return Plugin_Stop;
	}
	for (int victim=1; victim<=MaxClients; victim++)
	if (IsValidClient(victim) && IsValidClient(client) && GetClientTeam(victim) == 2)
	{
		int AcidicSlobberChance = GetRandomInt(0, 99);
		int AcidicSlobberPercent = (GetConVarInt(cvarAcidicSlobberChance));
		if (AcidicSlobberChance < AcidicSlobberPercent)
		{
			float v_pos[3];
			GetClientEyePosition(victim, v_pos);		
			float targetVector[3];
			float distance;
			float range = GetConVarFloat(cvarAcidicSlobberRange);
			GetClientEyePosition(client, targetVector);
			distance = GetVectorDistance(targetVector, v_pos);
			if (distance <= range)
			{
				int damage = GetConVarInt(cvarAcidicSlobberDamage);
				int attacker = client;
				DamageHook(victim, attacker, damage);
			}
		}
	}
	return Plugin_Continue;
}
// ===========================================
// Spitter Ability: Acidic Splash
// ===========================================
// Description: Enables the ability Acidic Splash, when hit, the Spitter's acid splashes out at nearby survivors.
void SpitterAbility_AcidicSplash(int victim)
{
	for (int survivor=1; survivor<=MaxClients; survivor++)
	
	if (IsValidClient(survivor) && GetClientTeam(survivor) == 2 && IsValidSpitter(victim))
	{
		int AcidicSplashChance = GetRandomInt(0, 99);
		int AcidicSplashPercent = (GetConVarInt(cvarAcidicSplashChance));	
		if (AcidicSplashChance < AcidicSplashPercent)
		{
			float v_pos[3];
			GetClientEyePosition(survivor, v_pos);		
			float targetVector[3];
			float distance;
			float range = GetConVarFloat(cvarAcidicSplashRange);
			GetClientEyePosition(victim, targetVector);
			distance = GetVectorDistance(targetVector, v_pos);
			if (distance <= range)
			{
				int damage = GetConVarInt(cvarAcidicSplashDamage);
				DamageHook(survivor, victim, damage);
			}
		}
	}
}
// ===========================================
// Spitter Ability: Acid Swipe
// ===========================================
// Description: Survivor takes damage over time after being Spitter clawed.
void SpitterAbility_AcidSwipe(int victim, int attacker)
{
	int AcidSwipeChance = GetRandomInt(0, 99);
	int AcidSwipePercent = (GetConVarInt(cvarAcidSwipeChance));
	if (IsValidClient(victim) && GetClientTeam(victim) == 2 && AcidSwipeChance < AcidSwipePercent)
	{
		PrintHintText(victim, "The Spitter has coated you with corrosive acid!");
		if (acidswipe[victim] <= 0)
		{
			acidswipe[victim] = (GetConVarInt(cvarAcidSwipeDuration));
			Handle dataPack = CreateDataPack();
			cvarAcidSwipeTimer[victim] = CreateDataTimer(1.0, Timer_AcidSwipe, dataPack, TIMER_REPEAT);
			WritePackCell(dataPack, victim);
			WritePackCell(dataPack, attacker);
		}
	}
}

public Action Timer_AcidSwipe(Handle timer, any dataPack) 
{
	ResetPack(dataPack);
	int victim = ReadPackCell(dataPack);
	int attacker = ReadPackCell(dataPack);
	if (IsValidClient(victim))
	{
		if (acidswipe[victim] <= 0)
		{
			if (cvarAcidSwipeTimer[victim] != null)
			{
				KillTimer(cvarAcidSwipeTimer[victim]);
				cvarAcidSwipeTimer[victim] = null;
			}	
			return Plugin_Stop;
		}
		int damage = GetConVarInt(cvarAcidSwipeDamage);
		DamageHook(victim, attacker, damage);
		if (acidswipe[victim] > 0) 
		{
			acidswipe[victim] -= 1;
		}
	}
	return Plugin_Continue;
}
// ===========================================
// Spitter Ability: Hydra Strike
// ===========================================
// Description: Allows the Spitter to fire off a second spit rapidly after the first.
public Action SpitterAbility_HydraStrike(int client)
{
	if (IsValidSpitter(client) && !isAcidicPoolDrop[client] && !isHydraStrikeActive[client])
	{
		cvarHydraStrikeTimer[client] = CreateTimer(1.0, Timer_HydraStrike, client);
	}
	else
	{
		isHydraStrikeActive[client] = false;
	}
	return Plugin_Handled;
}  

public Action Timer_HydraStrike(Handle timer, any client)
{
	if (IsValidSpitter(client))
	{
		int iEntid = GetEntDataEnt2(client,g_iAbilityO);
		float flTimeStamp_ret = GetEntDataFloat(iEntid,g_iNextActO+8);
		float flTimeStamp_calc = flTimeStamp_ret - (flTimeStamp_ret + 1.0) + (GetConVarFloat(cvarHydraStrikeCooldown));
		SetEntDataFloat(iEntid, g_iNextActO+8, flTimeStamp_calc, true);
		isHydraStrikeActive[client] = true;
	}
	if (cvarHydraStrikeTimer[client] != null)
	{
		KillTimer(cvarHydraStrikeTimer[client]);
		cvarHydraStrikeTimer[client] = null;
	}
	return Plugin_Stop;
}
// ===========================================
// Spitter Ability: Sticky Goo
// ===========================================
// Description: Any Survivor standing inside a pool of Spit will be stuck in the goo and find it harder to move out quickly.
void SpitterAbility_StickyGoo(int victim)
{
	if (stickygoo[victim] <= 0)
	{
		stickygoo[victim] = (GetConVarInt(cvarStickyGooDuration));
		cvarStickyGooTimer[victim] = CreateTimer(1.0, Timer_StickyGoo, victim, TIMER_REPEAT);
		SetEntDataFloat(victim, laggedMovementOffset, GetConVarFloat(cvarStickyGooSpeed), true);
		if (isStickyGooJump)
		{
			SetEntityGravity(victim, 5.0);
		}
		PrintHintText(victim, "Standing in the spit is slowing you down!");
	}	
	if (stickygoo[victim] > 0 && !aciddelay[victim])
	{
		stickygoo[victim]++;
	}
}

public Action Timer_StickyGoo(Handle timer, any victim) 
{
	if (IsValidClient(victim))
	{
		if (stickygoo[victim] <= 0)
		{
			SetEntDataFloat(victim, laggedMovementOffset, 1.0, true); //sets the survivors speed back to normal
			SetEntityGravity(victim, 1.0);
			PrintHintText(victim, "The spit is wearing off!");
			if (cvarStickyGooTimer[victim] != null)
			{
				KillTimer(cvarStickyGooTimer[victim]);
				cvarStickyGooTimer[victim] = null;
			}
			return Plugin_Stop;
		}
		if (stickygoo[victim] > 0) 
		{
			stickygoo[victim] -= 1;
		}
	}
	return Plugin_Continue;
}
// ===========================================
// Spitter Ability: Supergirl
// ===========================================
// Description: After launching a spit, the Spitter is coated in a protective layer that slowly drips off and reduces all damage until it is gone.
void SpitterAbility_SuperGirl(int client)
{
	if (IsValidSpitter(client) && !isAcidicPoolDrop[client])
	{
		PrintHintText(client, "You are temporarily invulnerable!");
		cvarSupergirlTimer[client] = CreateTimer(GetConVarFloat(cvarSupergirlDuration), Timer_Supergirl, client);	
		SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
	}
}

public Action Timer_Supergirl(Handle timer, any client)
{
	if (IsValidClient(client))
	{
		SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
		PrintHintText(client, "You are no longer invulnerable!");
	}
	if (cvarSupergirlTimer[client] != null)
	{
		KillTimer(cvarSupergirlTimer[client]);
		cvarSupergirlTimer[client] = null;
	}
	return Plugin_Stop;
}
// ===========================================
// Spitter Ability: Supergirl Speed
// ===========================================
// Description: Works with the Supergirl ability, the spit also coats the Spitters feet increasing movement speed for a brief period after launching a spit.
void SpitterAbility_SuperGirlSpeed(int client)
{
	if (IsValidSpitter(client) && !isAcidicPoolDrop[client])
	{
		cvarSupergirlSpeedTimer[client] = CreateTimer(GetConVarFloat(cvarSupergirlSpeedDuration), Timer_SupergirlSpeed, client);	
		SetEntDataFloat(client, laggedMovementOffset, 1.6, true);
	}
}

public Action Timer_SupergirlSpeed(Handle timer, any client)
{
	if (IsValidClient(client))
	{
		SetEntDataFloat(client, laggedMovementOffset, 1.0, true);
	}
	if (cvarSupergirlSpeedTimer[client] != null)
	{
		KillTimer(cvarSupergirlSpeedTimer[client]);
		cvarSupergirlSpeedTimer[client] = null;
	}
	return Plugin_Stop;
}
// ====================================================================================================================
// ===========================================                              =========================================== 
// ===========================================        GENERIC CALLS         =========================================== 
// ===========================================                              =========================================== 
// ====================================================================================================================
public Action DamageHook(int victim, int attacker, int damage)
{
	float victimPos[3];
	char strDamage[16];
	char strDamageTarget[16];
	GetClientEyePosition(victim, victimPos);
	IntToString(damage, strDamage, sizeof(strDamage));
	Format(strDamageTarget, sizeof(strDamageTarget), "hurtme%d", victim);
	int entPointHurt = CreateEntityByName("point_hurt");
	if (!IsValidEntity(entPointHurt) || !IsValidEdict(entPointHurt))
	{
		return;
	}
	DispatchKeyValue(victim, "targetname", strDamageTarget);
	DispatchKeyValue(entPointHurt, "DamageTarget", strDamageTarget);
	DispatchKeyValue(entPointHurt, "Damage", strDamage);
	DispatchKeyValue(entPointHurt, "DamageType", "0");
	DispatchSpawn(entPointHurt);
	TeleportEntity(entPointHurt, victimPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entPointHurt, "Hurt", (attacker && attacker < MaxClients && IsClientInGame(attacker)) ? attacker : -1);
	DispatchKeyValue(entPointHurt, "classname", "point_hurt");
	DispatchKeyValue(victim, "targetname", "null");
	AcceptEntityInput(entPointHurt, "kill");
}
// ====================================================================================================================
// ===========================================                              =========================================== 
// ===========================================          BOOL CALLS          =========================================== 
// ===========================================                              =========================================== 
// ====================================================================================================================
bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client));
}

bool IsValidSpitter(int client)
{
	if (IsValidClient(client) && GetClientTeam(client) == 3)
	{
		int class = GetEntProp(client, Prop_Send, "m_zombieClass");
		if (class == ZOMBIECLASS_SPITTER)
		{
			return true;
		}
	}
	return false;
}

bool IsPlayerGhost(int client)
{
	if (IsValidClient(client))
	{
		if (GetEntProp(client, Prop_Send, "m_isGhost"))
		{
			return true;
		}
	}
	return false;
}