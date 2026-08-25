#if defined __ph_convars_included
	#endinput
#endif
#define __ph_convars_included

ConVar g_hCvarHunters;
ConVar g_hCvarHideTime;
ConVar g_hCvarRoundTime;
ConVar g_hCvarRoundEndDelay;
ConVar g_hCvarGuaranteedHunterTurns;

ConVar g_hCvarPropMinSize;
ConVar g_hCvarPropMaxSize;
ConVar g_hCvarPropSelectDistance;
ConVar g_hCvarPropChangeLimit;
ConVar g_hCvarProplockEnabled;
ConVar g_hCvarAutoFreezeTime;
ConVar g_hCvarThirdperson;

ConVar g_hCvarCueInterval;
ConVar g_hCvarCueWarnFraction;
ConVar g_hCvarTauntEnabled;
ConVar g_hCvarTauntCooldown;

ConVar g_hCvarHpHunterDec;
ConVar g_hCvarHpHunterIncHit;
ConVar g_hCvarHpHunterBonus;
ConVar g_hCvarHideBlood;

ConVar g_hCvarAnticheatKick;

int g_iCvarHunters;
float g_flCvarHideTime;
float g_flCvarRoundTime;
float g_flCvarRoundEndDelay;
int g_iCvarGuaranteedHunterTurns;

float g_flCvarPropMinSize;
float g_flCvarPropMaxSize;
float g_flCvarPropSelectDistance;
int g_iCvarPropChangeLimit;
bool g_bCvarProplockEnabled;
float g_flCvarAutoFreezeTime;
bool g_bCvarThirdperson;

float g_flCvarCueInterval;
float g_flCvarCueWarnFraction;
bool g_bCvarTauntEnabled;
float g_flCvarTauntCooldown;

int g_iCvarHpHunterDec;
int g_iCvarHpHunterIncHit;
int g_iCvarHpHunterBonus;
bool g_bCvarHideBlood;

bool g_bCvarAnticheatKick;

void PH_Convars_Init()
{
	g_hCvarHunters              = CreateConVar("ph_hunters", "4", "Number of Hunters (survivor slots) selected each round. The rest of the connected players are Props.", _, true, 1.0, true, 8.0);
	g_hCvarHideTime              = CreateConVar("ph_hide_time", "45.0", "Seconds Hunters are frozen and blinded at the start of a round while Props hide.", _, true, 0.0);
	g_hCvarRoundTime              = CreateConVar("ph_round_time", "240.0", "Seconds a round lasts once the seek phase starts. Props still alive when it expires win the round.", _, true, 30.0);
	g_hCvarRoundEndDelay          = CreateConVar("ph_round_end_delay", "8.0", "Seconds to show the round-end scoreline before starting the next round.", _, true, 2.0);
	g_hCvarGuaranteedHunterTurns  = CreateConVar("ph_guaranteed_hunter_turns", "3", "Rounds a client is guaranteed to stay a Prop after having been a Hunter, before being eligible again.", _, true, 0.0);

	g_hCvarPropMinSize           = CreateConVar("ph_prop_min_size", "20.0", "Minimum prop bounding-box diagonal (Hammer units) a Prop is allowed to disguise as.", _, true, 0.0);
	g_hCvarPropMaxSize           = CreateConVar("ph_prop_max_size", "260.0", "Maximum prop bounding-box diagonal (Hammer units) a Prop is allowed to disguise as.", _, true, 0.0);
	g_hCvarPropSelectDistance     = CreateConVar("ph_prop_select_distance", "180.0", "Maximum distance (Hammer units) to a prop for +use to select it.", _, true, 32.0);
	g_hCvarPropChangeLimit        = CreateConVar("ph_prop_change_limit", "0", "Times a Prop may re-pick a disguise per round. 0 = unlimited.", _, true, 0.0);
	g_hCvarProplockEnabled        = CreateConVar("ph_proplock_enabled", "1", "1 = Props may lock their rotation/position in place (bound to +reload).");
	g_hCvarAutoFreezeTime         = CreateConVar("ph_auto_freeze_time", "5.0", "Seconds a disguised Prop must stand still before being auto-locked in place. 0 = disabled.", _, true, 0.0);
	g_hCvarThirdperson            = CreateConVar("ph_thirdperson", "1", "1 = Props automatically get a third-person camera while disguised.");

	g_hCvarCueInterval            = CreateConVar("ph_cue_interval", "45.0", "Seconds between forced special-infected sound cues, so Props can't camp silently forever. 0 = disabled.", _, true, 0.0);
	g_hCvarCueWarnFraction        = CreateConVar("ph_cue_warn_fraction", "0.5", "Fraction of ph_cue_interval at which a chat warning is sent before the forced cue plays.", _, true, 0.0, true, 1.0);
	g_hCvarTauntEnabled           = CreateConVar("ph_taunt_enabled", "1", "1 = Props may voluntarily taunt (play a special infected sound) with the taunt command.");
	g_hCvarTauntCooldown          = CreateConVar("ph_taunt_cooldown", "10.0", "Seconds between voluntary taunts from the same Prop.", _, true, 0.0);

	g_hCvarHpHunterDec            = CreateConVar("ph_hp_hunter_dec", "5", "HP a Hunter loses for every shot fired.", _, true, 0.0);
	g_hCvarHpHunterIncHit         = CreateConVar("ph_hp_hunter_inc", "15", "HP a Hunter regains for landing a hit on a Prop.", _, true, 0.0);
	g_hCvarHpHunterBonus          = CreateConVar("ph_hp_hunter_bonus", "40", "Bonus HP a Hunter regains for eliminating a Prop.", _, true, 0.0);
	g_hCvarHideBlood              = CreateConVar("ph_hide_blood", "1", "1 = Suppress blood decals/particles when a Hunter hits a Prop.");

	g_hCvarAnticheatKick          = CreateConVar("ph_anticheat_kick", "1", "1 = Kick Hunters found with r_staticpropinfo enabled (reveals static prop names/bounds client-side).");

	AutoExecConfig(true, "kether_prophunt");

	HookConVarChange(g_hCvarHunters, PH_CvarChanged);
	HookConVarChange(g_hCvarHideTime, PH_CvarChanged);
	HookConVarChange(g_hCvarRoundTime, PH_CvarChanged);
	HookConVarChange(g_hCvarRoundEndDelay, PH_CvarChanged);
	HookConVarChange(g_hCvarGuaranteedHunterTurns, PH_CvarChanged);
	HookConVarChange(g_hCvarPropMinSize, PH_CvarChanged);
	HookConVarChange(g_hCvarPropMaxSize, PH_CvarChanged);
	HookConVarChange(g_hCvarPropSelectDistance, PH_CvarChanged);
	HookConVarChange(g_hCvarPropChangeLimit, PH_CvarChanged);
	HookConVarChange(g_hCvarProplockEnabled, PH_CvarChanged);
	HookConVarChange(g_hCvarAutoFreezeTime, PH_CvarChanged);
	HookConVarChange(g_hCvarThirdperson, PH_CvarChanged);
	HookConVarChange(g_hCvarCueInterval, PH_CvarChanged);
	HookConVarChange(g_hCvarCueWarnFraction, PH_CvarChanged);
	HookConVarChange(g_hCvarTauntEnabled, PH_CvarChanged);
	HookConVarChange(g_hCvarTauntCooldown, PH_CvarChanged);
	HookConVarChange(g_hCvarHpHunterDec, PH_CvarChanged);
	HookConVarChange(g_hCvarHpHunterIncHit, PH_CvarChanged);
	HookConVarChange(g_hCvarHpHunterBonus, PH_CvarChanged);
	HookConVarChange(g_hCvarHideBlood, PH_CvarChanged);
	HookConVarChange(g_hCvarAnticheatKick, PH_CvarChanged);

	PH_Convars_Cache();
}

public void PH_CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	PH_Convars_Cache();
}

void PH_Convars_Cache()
{
	g_iCvarHunters              = g_hCvarHunters.IntValue;
	g_flCvarHideTime             = g_hCvarHideTime.FloatValue;
	g_flCvarRoundTime             = g_hCvarRoundTime.FloatValue;
	g_flCvarRoundEndDelay         = g_hCvarRoundEndDelay.FloatValue;
	g_iCvarGuaranteedHunterTurns = g_hCvarGuaranteedHunterTurns.IntValue;

	g_flCvarPropMinSize          = g_hCvarPropMinSize.FloatValue;
	g_flCvarPropMaxSize          = g_hCvarPropMaxSize.FloatValue;
	g_flCvarPropSelectDistance    = g_hCvarPropSelectDistance.FloatValue;
	g_iCvarPropChangeLimit        = g_hCvarPropChangeLimit.IntValue;
	g_bCvarProplockEnabled        = g_hCvarProplockEnabled.BoolValue;
	g_flCvarAutoFreezeTime        = g_hCvarAutoFreezeTime.FloatValue;
	g_bCvarThirdperson            = g_hCvarThirdperson.BoolValue;

	g_flCvarCueInterval           = g_hCvarCueInterval.FloatValue;
	g_flCvarCueWarnFraction       = g_hCvarCueWarnFraction.FloatValue;
	g_bCvarTauntEnabled           = g_hCvarTauntEnabled.BoolValue;
	g_flCvarTauntCooldown         = g_hCvarTauntCooldown.FloatValue;

	g_iCvarHpHunterDec            = g_hCvarHpHunterDec.IntValue;
	g_iCvarHpHunterIncHit         = g_hCvarHpHunterIncHit.IntValue;
	g_iCvarHpHunterBonus          = g_hCvarHpHunterBonus.IntValue;
	g_bCvarHideBlood              = g_hCvarHideBlood.BoolValue;

	g_bCvarAnticheatKick          = g_hCvarAnticheatKick.BoolValue;
}
