#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <builtinvotes>
#include <l4d2_skill_detect>

#define PLUGIN_VERSION "1.0.0"
#define DB_NAME "kether_skill_rating"

#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

#define ZC_TANK 8
#define ZC_JOCKEY 5

#define MIX_MIN_TEAM_SIZE 1
#define MIX_MAX_TEAM_SIZE 4

stock float FloatMax(float a, float b)
{
	return (a > b) ? a : b;
}

Database g_Db = null;

ConVar g_CvarEnabled;
ConVar g_CvarRoundPool;
ConVar g_CvarWeightInfDamage;
ConVar g_CvarWeightSurvDamage;
ConVar g_CvarWeightTankDamage;
ConVar g_CvarWeightWitchDamage;
ConVar g_CvarWeightCommonKills;
ConVar g_CvarWeightSpecialClear;
ConVar g_CvarWeightSelfClear;
ConVar g_CvarWeightSkeet;
ConVar g_CvarWeightDeadstop;
ConVar g_CvarWeightBoomerPop;
ConVar g_CvarWeightRevive;
ConVar g_CvarWeightMedkitGive;
ConVar g_CvarWeightRescue;
ConVar g_CvarWeightJockeyBlock;
ConVar g_CvarWeightTankPlayAction;
ConVar g_CvarTopMinRounds;
ConVar g_CvarMixVotePct;
ConVar g_CvarMixVoteCooldown;

bool g_bRoundActive = false;
bool g_bRoundFinalized = false;
int g_iRoundNumber = 0;
char g_sMapName[64];

float g_fTotalPoints[MAXPLAYERS + 1];
int g_iRoundsPlayed[MAXPLAYERS + 1];

int g_iDamageAsInfected[MAXPLAYERS + 1];
int g_iDamageAsSurvivor[MAXPLAYERS + 1];
int g_iTankDamageAsSurvivor[MAXPLAYERS + 1];
int g_iWitchDamageAsSurvivor[MAXPLAYERS + 1];
int g_iCommonKillsAsSurvivor[MAXPLAYERS + 1];

int g_iSpecialClears[MAXPLAYERS + 1];
int g_iSmokerSelfClears[MAXPLAYERS + 1];
int g_iSkeets[MAXPLAYERS + 1];
int g_iDeadstops[MAXPLAYERS + 1];
int g_iBoomerPopsNoVomit[MAXPLAYERS + 1];
int g_iRevives[MAXPLAYERS + 1];
int g_iMedkitGives[MAXPLAYERS + 1];
int g_iRescuesFromSpecial[MAXPLAYERS + 1];
int g_iJockeyBlocks[MAXPLAYERS + 1];
int g_iTankPlayActions[MAXPLAYERS + 1];

bool g_bHealStartedToOther[MAXPLAYERS + 1];

bool g_bMixVoteInProgress = false;
Handle g_hMixVote = INVALID_HANDLE;
float g_fLastMixVoteTime = 0.0;

public Plugin myinfo =
{
	name = "Kether Skill Rating",
	author = "Kether + gpt-5.3-codex",
	description = "Round-normalized skill rating with local SQLite and skill mix vote",
	version = PLUGIN_VERSION,
	url = "kether.pl"
};

public void OnPluginStart()
{
	char error[256];
	g_Db = SQLite_UseDatabase(DB_NAME, error, sizeof(error));
	if (g_Db == null)
	{
		SetFailState("Failed to open SQLite DB '%s': %s", DB_NAME, error);
	}

	CreateTables();

	g_CvarEnabled = CreateConVar("sm_skill_rating_enabled", "1", "Enable/disable skill rating plugin", FCVAR_NONE, true, 0.0, true, 1.0);
	g_CvarRoundPool = CreateConVar("sm_skill_rating_round_pool", "100.0", "Points distributed per team per round", FCVAR_NONE, true, 1.0, false);
	g_CvarWeightInfDamage = CreateConVar("sm_skill_w_inf_damage", "0.020", "Infected damage weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSurvDamage = CreateConVar("sm_skill_w_surv_damage", "0.012", "Survivor damage weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTankDamage = CreateConVar("sm_skill_w_tank_damage", "0.018", "Tank damage weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightWitchDamage = CreateConVar("sm_skill_w_witch_damage", "0.020", "Witch damage weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightCommonKills = CreateConVar("sm_skill_w_common_kills", "0.250", "Common kills weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSpecialClear = CreateConVar("sm_skill_w_special_clear", "12.0", "Special clear weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSelfClear = CreateConVar("sm_skill_w_self_clear", "14.0", "Self clear weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightSkeet = CreateConVar("sm_skill_w_skeet", "15.0", "Skeet weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightDeadstop = CreateConVar("sm_skill_w_deadstop", "12.0", "Deadstop weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightBoomerPop = CreateConVar("sm_skill_w_boomer_pop", "8.0", "No-vomit boomer pop weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightRevive = CreateConVar("sm_skill_w_revive", "10.0", "Revive weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightMedkitGive = CreateConVar("sm_skill_w_medkit_give", "10.0", "Heal other with medkit weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightRescue = CreateConVar("sm_skill_w_rescue", "8.0", "Rescue from special pin weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightJockeyBlock = CreateConVar("sm_skill_w_jockey_block", "10.0", "Jockey block/shove-interrupt weight", FCVAR_NONE, true, 0.0, false);
	g_CvarWeightTankPlayAction = CreateConVar("sm_skill_w_tankplay_action", "4.0", "Bonus for high-skill actions performed while tank is in play", FCVAR_NONE, true, 0.0, false);
	g_CvarTopMinRounds = CreateConVar("sm_skill_top_min_rounds", "5", "Minimum rounds for top ranking", FCVAR_NONE, true, 0.0, false);
	g_CvarMixVotePct = CreateConVar("sm_skill_mix_vote_pct", "51", "Percent votes required for skill mix", FCVAR_NONE, true, 1.0, true, 100.0);
	g_CvarMixVoteCooldown = CreateConVar("sm_skill_mix_vote_cooldown", "120.0", "Cooldown between skill mix votes", FCVAR_NONE, true, 0.0, false);

	AutoExecConfig(true, "kether_skill_rating");

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	HookEvent("infected_hurt", Event_InfectedHurt, EventHookMode_Post);
	HookEvent("infected_death", Event_InfectedDeath, EventHookMode_Post);
	HookEvent("revive_success", Event_ReviveSuccess, EventHookMode_Post);
	HookEvent("heal_begin", Event_HealBegin, EventHookMode_Post);
	HookEvent("heal_success", Event_HealSuccess, EventHookMode_Post);

	RegConsoleCmd("sm_skill", Command_Skill, "Show your skill rating");
	RegConsoleCmd("sm_myskill", Command_Skill, "Show your skill rating");
	RegConsoleCmd("sm_skilltop", Command_SkillTop, "Show top skill players");
	RegConsoleCmd("sm_skillsim", Command_SkillSim, "Show players with a similar profile");
	RegConsoleCmd("sm_skillmix", Command_SkillMixVote, "Call vote to mix teams by skill");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidHuman(i))
		{
			LoadPlayerProfile(i);
		}
	}
}

public void OnMapStart()
{
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));
}

public void OnClientPostAdminCheck(int client)
{
	if (!IsValidHuman(client))
	{
		return;
	}

	ResetRoundStats(client);
	g_fTotalPoints[client] = 0.0;
	g_iRoundsPlayed[client] = 0;
	LoadPlayerProfile(client);
}

public void OnClientDisconnect(int client)
{
	ResetRoundStats(client);
	g_fTotalPoints[client] = 0.0;
	g_iRoundsPlayed[client] = 0;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_CvarEnabled.BoolValue)
	{
		return;
	}

	g_bRoundActive = true;
	g_bRoundFinalized = false;
	g_iRoundNumber++;
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));

	for (int i = 1; i <= MaxClients; i++)
	{
		ResetRoundStats(i);
	}
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	FinalizeRoundIfNeeded();
}

public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	FinalizeRoundIfNeeded();
	return Plugin_Continue;
}

void FinalizeRoundIfNeeded()
{
	if (!g_CvarEnabled.BoolValue || !g_bRoundActive || g_bRoundFinalized)
	{
		return;
	}

	g_bRoundFinalized = true;
	g_bRoundActive = false;

	float teamPool = g_CvarRoundPool.FloatValue;
	float teamRawSum[4];
	int teamCount[4];

	teamRawSum[TEAM_SURVIVOR] = 0.0;
	teamRawSum[TEAM_INFECTED] = 0.0;
	teamCount[TEAM_SURVIVOR] = 0;
	teamCount[TEAM_INFECTED] = 0;

	float rawScore[MAXPLAYERS + 1];

	for (int i = 1; i <= MaxClients; i++)
	{
		rawScore[i] = 0.0;

		if (!IsValidHuman(i))
		{
			continue;
		}

		int team = GetClientTeam(i);
		if (team != TEAM_SURVIVOR && team != TEAM_INFECTED)
		{
			continue;
		}

		rawScore[i] = ComputeRawRoundScore(i, team);
		teamRawSum[team] += rawScore[i];
		teamCount[team]++;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidHuman(i))
		{
			continue;
		}

		int team = GetClientTeam(i);
		if (team != TEAM_SURVIVOR && team != TEAM_INFECTED)
		{
			continue;
		}

		float awarded = 0.0;
		if (teamCount[team] > 0)
		{
			if (teamRawSum[team] > 0.0001)
			{
				awarded = teamPool * (rawScore[i] / teamRawSum[team]);
			}
			else
			{
				awarded = teamPool / float(teamCount[team]);
			}
		}

		SaveRoundAndUpdatePlayer(i, team, rawScore[i], awarded);
	}
}

float ComputeRawRoundScore(int client, int team)
{
	float score = 0.0;

	if (team == TEAM_INFECTED)
	{
		score += float(g_iDamageAsInfected[client]) * g_CvarWeightInfDamage.FloatValue;
		return score;
	}

	score += float(g_iDamageAsSurvivor[client]) * g_CvarWeightSurvDamage.FloatValue;
	score += float(g_iTankDamageAsSurvivor[client]) * g_CvarWeightTankDamage.FloatValue;
	score += float(g_iWitchDamageAsSurvivor[client]) * g_CvarWeightWitchDamage.FloatValue;
	score += float(g_iCommonKillsAsSurvivor[client]) * g_CvarWeightCommonKills.FloatValue;
	score += float(g_iSpecialClears[client]) * g_CvarWeightSpecialClear.FloatValue;
	score += float(g_iSmokerSelfClears[client]) * g_CvarWeightSelfClear.FloatValue;
	score += float(g_iSkeets[client]) * g_CvarWeightSkeet.FloatValue;
	score += float(g_iDeadstops[client]) * g_CvarWeightDeadstop.FloatValue;
	score += float(g_iBoomerPopsNoVomit[client]) * g_CvarWeightBoomerPop.FloatValue;
	score += float(g_iRevives[client]) * g_CvarWeightRevive.FloatValue;
	score += float(g_iMedkitGives[client]) * g_CvarWeightMedkitGive.FloatValue;
	score += float(g_iRescuesFromSpecial[client]) * g_CvarWeightRescue.FloatValue;
	score += float(g_iJockeyBlocks[client]) * g_CvarWeightJockeyBlock.FloatValue;
	score += float(g_iTankPlayActions[client]) * g_CvarWeightTankPlayAction.FloatValue;

	return score;
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bRoundActive || !g_CvarEnabled.BoolValue)
	{
		return;
	}

	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int damage = event.GetInt("dmg_health") + event.GetInt("dmg_armor");

	if (damage <= 0 || !IsValidHuman(attacker) || attacker == victim)
	{
		return;
	}

	int attackerTeam = GetClientTeam(attacker);
	if (attackerTeam == TEAM_INFECTED)
	{
		if (IsValidClient(victim) && GetClientTeam(victim) == TEAM_SURVIVOR)
		{
			g_iDamageAsInfected[attacker] += damage;
		}
		return;
	}

	if (attackerTeam != TEAM_SURVIVOR)
	{
		return;
	}

	if (IsValidClient(victim) && GetClientTeam(victim) == TEAM_INFECTED)
	{
		g_iDamageAsSurvivor[attacker] += damage;

		int zClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
		if (zClass == ZC_TANK)
		{
			g_iTankDamageAsSurvivor[attacker] += damage;
		}
	}
}

public void Event_InfectedHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bRoundActive || !g_CvarEnabled.BoolValue)
	{
		return;
	}

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!IsValidHuman(attacker) || GetClientTeam(attacker) != TEAM_SURVIVOR)
	{
		return;
	}

	int amount = event.GetInt("amount");
	if (amount > 0)
	{
		g_iWitchDamageAsSurvivor[attacker] += amount;
	}
}

public void Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bRoundActive || !g_CvarEnabled.BoolValue)
	{
		return;
	}

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (IsValidHuman(attacker) && GetClientTeam(attacker) == TEAM_SURVIVOR)
	{
		g_iCommonKillsAsSurvivor[attacker]++;
	}
}

public void Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bRoundActive || !g_CvarEnabled.BoolValue)
	{
		return;
	}

	int reviver = GetClientOfUserId(event.GetInt("userid"));
	int revived = GetClientOfUserId(event.GetInt("subject"));
	if (IsValidHuman(reviver) && IsValidClient(revived) && reviver != revived && GetClientTeam(reviver) == TEAM_SURVIVOR)
	{
		g_iRevives[reviver]++;
		if (IsTankInPlayActive())
		{
			g_iTankPlayActions[reviver]++;
		}
	}
}

public void Event_HealBegin(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bRoundActive || !g_CvarEnabled.BoolValue)
	{
		return;
	}

	int healer = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));
	if (!IsValidHuman(healer) || GetClientTeam(healer) != TEAM_SURVIVOR)
	{
		return;
	}

	g_bHealStartedToOther[healer] = (subject > 0 && subject != healer);
}

public void Event_HealSuccess(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bRoundActive || !g_CvarEnabled.BoolValue)
	{
		return;
	}

	int healer = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));
	if (!IsValidHuman(healer) || GetClientTeam(healer) != TEAM_SURVIVOR)
	{
		return;
	}

	if (subject > 0 && subject != healer && g_bHealStartedToOther[healer])
	{
		g_iMedkitGives[healer]++;
		if (IsTankInPlayActive())
		{
			g_iTankPlayActions[healer]++;
		}
	}
	g_bHealStartedToOther[healer] = false;
}

public void OnSpecialClear(int clearer, int pinner, int pinvictim, int zombieClass, float timeA, float timeB, bool withShove)
{
	if (!g_bRoundActive || !IsValidHuman(clearer))
	{
		return;
	}

	if (GetClientTeam(clearer) == TEAM_SURVIVOR)
	{
		g_iSpecialClears[clearer]++;
		g_iRescuesFromSpecial[clearer]++;
		if (zombieClass == ZC_JOCKEY)
		{
			g_iJockeyBlocks[clearer]++;
		}
		if (IsTankInPlayActive())
		{
			g_iTankPlayActions[clearer]++;
		}
	}
}

public void OnSmokerSelfClear(int survivor, int smoker, bool withShove)
{
	if (!g_bRoundActive || !IsValidHuman(survivor))
	{
		return;
	}

	if (GetClientTeam(survivor) == TEAM_SURVIVOR)
	{
		g_iSmokerSelfClears[survivor]++;
		if (IsTankInPlayActive())
		{
			g_iTankPlayActions[survivor]++;
		}
	}
}

public void OnSkeet(int survivor, int hunter)
{
	if (!g_bRoundActive || !IsValidHuman(survivor))
	{
		return;
	}

	if (GetClientTeam(survivor) == TEAM_SURVIVOR)
	{
		g_iSkeets[survivor]++;
		if (IsTankInPlayActive())
		{
			g_iTankPlayActions[survivor]++;
		}
	}
}

public void OnHunterDeadstop(int survivor, int hunter)
{
	if (!g_bRoundActive || !IsValidHuman(survivor))
	{
		return;
	}

	if (GetClientTeam(survivor) == TEAM_SURVIVOR)
	{
		g_iDeadstops[survivor]++;
		if (IsTankInPlayActive())
		{
			g_iTankPlayActions[survivor]++;
		}
	}
}

public void OnBoomerPop(int survivor, int boomer, int shoveCount, float timeAlive)
{
	if (!g_bRoundActive || !IsValidHuman(survivor))
	{
		return;
	}

	if (GetClientTeam(survivor) == TEAM_SURVIVOR)
	{
		g_iBoomerPopsNoVomit[survivor]++;
		if (IsTankInPlayActive())
		{
			g_iTankPlayActions[survivor]++;
		}
	}
}

public void OnSpecialShoved(int survivor, int infected, int zombieClass)
{
	if (!g_bRoundActive || !IsValidHuman(survivor))
	{
		return;
	}

	if (GetClientTeam(survivor) != TEAM_SURVIVOR)
	{
		return;
	}

	// Heuristic: jockey shove-interrupts are treated as "jockey blocks".
	if (zombieClass == ZC_JOCKEY)
	{
		g_iJockeyBlocks[survivor]++;
		if (IsTankInPlayActive())
		{
			g_iTankPlayActions[survivor]++;
		}
	}
}

public Action Command_Skill(int client, int args)
{
	if (!g_CvarEnabled.BoolValue)
	{
		ReplyToCommand(client, "[Skill] Plugin is disabled.");
		return Plugin_Handled;
	}

	if (!IsValidHuman(client))
	{
		ReplyToCommand(client, "[Skill] This command is in-game only.");
		return Plugin_Handled;
	}

	int target = client;
	if (args >= 1)
	{
		char arg[64];
		GetCmdArg(1, arg, sizeof(arg));
		target = FindTarget(client, arg, true, false);
		if (target <= 0)
		{
			return Plugin_Handled;
		}
	}

	float avg = GetAveragePoints(target);
	ReplyToCommand(client, "[Skill] %N | total: %.2f | rounds: %d | avg/round: %.2f", target, g_fTotalPoints[target], g_iRoundsPlayed[target], avg);

	return Plugin_Handled;
}

public Action Command_SkillTop(int client, int args)
{
	if (!g_CvarEnabled.BoolValue)
	{
		ReplyToCommand(client, "[Skill] Plugin is disabled.");
		return Plugin_Handled;
	}

	int limit = 10;
	if (args >= 1)
	{
		char arg[16];
		GetCmdArg(1, arg, sizeof(arg));
		limit = StringToInt(arg);
		if (limit < 1)
		{
			limit = 1;
		}
		if (limit > 20)
		{
			limit = 20;
		}
	}

	int minRounds = g_CvarTopMinRounds.IntValue;

	char query[512];
	Format(query, sizeof(query),
		"SELECT name, total_points, rounds_played, "
		... "CASE WHEN rounds_played > 0 THEN (total_points / rounds_played) ELSE 0 END AS avg_score "
		... "FROM players WHERE rounds_played >= %d ORDER BY avg_score DESC, total_points DESC LIMIT %d;",
		minRounds, limit);

	DataPack pack = new DataPack();
	pack.WriteCell(client);
	g_Db.Query(SQL_ShowTop, query, pack);

	return Plugin_Handled;
}

public Action Command_SkillSim(int client, int args)
{
	if (!g_CvarEnabled.BoolValue)
	{
		ReplyToCommand(client, "[Skill] Plugin is disabled.");
		return Plugin_Handled;
	}

	if (!IsValidHuman(client))
	{
		ReplyToCommand(client, "[Skill] This command is in-game only.");
		return Plugin_Handled;
	}

	int target = client;
	if (args >= 1)
	{
		char arg[64];
		GetCmdArg(1, arg, sizeof(arg));
		target = FindTarget(client, arg, true, false);
		if (target <= 0)
		{
			return Plugin_Handled;
		}
	}

	char steamid[32];
	GetClientAuthId(target, AuthId_Steam2, steamid, sizeof(steamid));

	char query[1024];
	Format(query, sizeof(query),
		"SELECT p.steamid, p.name, p.total_points, p.rounds_played, "
		... "COALESCE(SUM(r.dmg_survivor), 0), COALESCE(SUM(r.dmg_infected), 0), COALESCE(SUM(r.dmg_tank), 0), "
		... "COALESCE(SUM(r.special_clears + r.self_clears + r.skeets + r.deadstops + r.boomer_pops + r.revives + r.medkit_gives + r.special_rescues + r.jockey_blocks + r.tank_play_actions), 0) "
		... "FROM players p LEFT JOIN round_stats r ON p.steamid = r.steamid "
		... "WHERE p.steamid = '%s' GROUP BY p.steamid;",
		steamid);

	DataPack pack = new DataPack();
	pack.WriteCell(client);
	g_Db.Query(SQL_LoadSimilarityTarget, query, pack);

	return Plugin_Handled;
}

public Action Command_SkillMixVote(int client, int args)
{
	if (!g_CvarEnabled.BoolValue)
	{
		ReplyToCommand(client, "[SkillMix] Plugin is disabled.");
		return Plugin_Handled;
	}

	if (!IsValidHuman(client))
	{
		ReplyToCommand(client, "[SkillMix] This command is in-game only.");
		return Plugin_Handled;
	}

	if (GetClientTeam(client) == TEAM_SPECTATOR)
	{
		ReplyToCommand(client, "[SkillMix] Spectators cannot call this vote.");
		return Plugin_Handled;
	}

	if (g_bMixVoteInProgress || IsBuiltinVoteInProgress())
	{
		ReplyToCommand(client, "[SkillMix] A vote is already in progress.");
		return Plugin_Handled;
	}

	int survCount = 0;
	int infCount = 0;
	int voters[MAXPLAYERS + 1];
	int voterCount = CollectEligibleVoters(voters, survCount, infCount);

	if (!IsValidMixSetup(survCount, infCount))
	{
		ReplyToCommand(client, "[SkillMix] Mix requires equal teams with 1v1 up to 4v4.");
		return Plugin_Handled;
	}

	float now = GetEngineTime();
	float cooldown = g_CvarMixVoteCooldown.FloatValue;
	if ((now - g_fLastMixVoteTime) < cooldown)
	{
		ReplyToCommand(client, "[SkillMix] Vote cooldown active.");
		return Plugin_Handled;
	}

	g_hMixVote = CreateBuiltinVote(Handle_MixVoteAction, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
	SetBuiltinVoteArgument(g_hMixVote, "Mix teams by skill rating?");
	SetBuiltinVoteInitiator(g_hMixVote, client);
	SetBuiltinVoteResultCallback(g_hMixVote, Handle_MixVoteResult);
	DisplayBuiltinVote(g_hMixVote, voters, voterCount, 15);
	FakeClientCommand(client, "Vote Yes");

	g_bMixVoteInProgress = true;
	g_fLastMixVoteTime = now;

	return Plugin_Handled;
}

public void Handle_MixVoteAction(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			g_hMixVote = INVALID_HANDLE;
			g_bMixVoteInProgress = false;
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
			g_bMixVoteInProgress = false;
		}
	}
}

public void Handle_MixVoteResult(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	int yesVotes = 0;
	for (int i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			yesVotes = item_info[i][BUILTINVOTEINFO_ITEM_VOTES];
			break;
		}
	}

	float yesPct = 0.0;
	if (num_votes > 0)
	{
		yesPct = (float(yesVotes) / float(num_votes)) * 100.0;
	}

	if (yesPct < g_CvarMixVotePct.FloatValue)
	{
		DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
		return;
	}

	DisplayBuiltinVotePass(vote, "Applying skill mix...");
	PerformSkillMix();
}

void PerformSkillMix()
{
	int players[MAXPLAYERS + 1];
	float rating[MAXPLAYERS + 1];
	int count = 0;
	int survCount = 0;
	int infCount = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidHuman(i))
		{
			continue;
		}

		int team = GetClientTeam(i);
		if (team != TEAM_SURVIVOR && team != TEAM_INFECTED)
		{
			continue;
		}

		players[count] = i;
		rating[count] = GetAveragePoints(i);
		count++;

		if (team == TEAM_SURVIVOR)
		{
			survCount++;
		}
		else if (team == TEAM_INFECTED)
		{
			infCount++;
		}
	}

	if (!IsValidMixSetup(survCount, infCount))
	{
		PrintToChatAll("[SkillMix] Mix aborted: teams are no longer valid.");
		return;
	}

	SortByRatingDesc(players, rating, count);

	int teamSize = count / 2;
	int teamSurv[MAXPLAYERS + 1];
	int teamInf[MAXPLAYERS + 1];
	int survIdx = 0;
	int infIdx = 0;
	float sumSurv = 0.0;
	float sumInf = 0.0;

	for (int i = 0; i < count; i++)
	{
		if (survIdx >= teamSize)
		{
			teamInf[infIdx++] = players[i];
			sumInf += rating[i];
			continue;
		}
		if (infIdx >= teamSize)
		{
			teamSurv[survIdx++] = players[i];
			sumSurv += rating[i];
			continue;
		}

		if (sumSurv <= sumInf)
		{
			teamSurv[survIdx++] = players[i];
			sumSurv += rating[i];
		}
		else
		{
			teamInf[infIdx++] = players[i];
			sumInf += rating[i];
		}
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidHuman(i) && GetClientTeam(i) != TEAM_SPECTATOR)
		{
			ChangeClientTeam(i, TEAM_SPECTATOR);
		}
	}

	for (int i = 0; i < survIdx; i++)
	{
		MoveHumanToTeam(teamSurv[i], TEAM_SURVIVOR);
	}
	for (int i = 0; i < infIdx; i++)
	{
		MoveHumanToTeam(teamInf[i], TEAM_INFECTED);
	}

	PrintToChatAll("[SkillMix] Teams mixed by current skill rating.");
}

void SortByRatingDesc(int players[MAXPLAYERS + 1], float rating[MAXPLAYERS + 1], int count)
{
	for (int i = 0; i < count; i++)
	{
		for (int j = i + 1; j < count; j++)
		{
			if (rating[j] > rating[i])
			{
				int tmpPlayer = players[i];
				players[i] = players[j];
				players[j] = tmpPlayer;

				float tmpRating = rating[i];
				rating[i] = rating[j];
				rating[j] = tmpRating;
			}
		}
	}
}

int CollectEligibleVoters(int voters[MAXPLAYERS + 1], int &survCount, int &infCount)
{
	int count = 0;
	survCount = 0;
	infCount = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidHuman(i))
		{
			continue;
		}

		int team = GetClientTeam(i);
		if (team == TEAM_SURVIVOR || team == TEAM_INFECTED)
		{
			voters[count++] = i;
			if (team == TEAM_SURVIVOR)
			{
				survCount++;
			}
			else
			{
				infCount++;
			}
		}
	}

	return count;
}

bool IsValidMixSetup(int survCount, int infCount)
{
	if (survCount != infCount)
	{
		return false;
	}

	if (survCount < MIX_MIN_TEAM_SIZE || survCount > MIX_MAX_TEAM_SIZE)
	{
		return false;
	}

	return true;
}

bool MoveHumanToTeam(int client, int team)
{
	if (!IsValidHuman(client))
	{
		return false;
	}

	if (GetClientTeam(client) == team)
	{
		return true;
	}

	if (team != TEAM_SURVIVOR)
	{
		ChangeClientTeam(client, team);
		return true;
	}

	int bot = FindSurvivorBot();
	if (bot > 0)
	{
		int flags = GetCommandFlags("sb_takecontrol");
		SetCommandFlags("sb_takecontrol", flags & ~FCVAR_CHEAT);
		FakeClientCommand(client, "sb_takecontrol");
		SetCommandFlags("sb_takecontrol", flags);
		return true;
	}

	ChangeClientTeam(client, TEAM_SURVIVOR);
	return true;
}

int FindSurvivorBot()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR)
		{
			return i;
		}
	}
	return -1;
}

public void SQL_ShowTop(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	delete pack;

	if (!IsValidClient(client))
	{
		return;
	}

	if (results == null)
	{
		ReplyToCommand(client, "[Skill] Top query failed: %s", error);
		return;
	}

	int rank = 1;
	ReplyToCommand(client, "[Skill] Top players:");
	while (results.FetchRow())
	{
		char name[MAX_NAME_LENGTH];
		results.FetchString(0, name, sizeof(name));
		float total = results.FetchFloat(1);
		int rounds = results.FetchInt(2);
		float avg = results.FetchFloat(3);

		ReplyToCommand(client, "[Skill] #%d %s | avg: %.2f | total: %.1f | rounds: %d", rank, name, avg, total, rounds);
		rank++;
	}
}

public void SQL_LoadSimilarityTarget(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	delete pack;

	if (!IsValidClient(client))
	{
		return;
	}

	if (results == null || !results.FetchRow())
	{
		ReplyToCommand(client, "[Skill] No data available for similarity.");
		return;
	}

	char targetSteamid[32];
	results.FetchString(0, targetSteamid, sizeof(targetSteamid));
	float targetTotal = results.FetchFloat(2);
	int targetRounds = results.FetchInt(3);
	float targetDmgSurv = results.FetchFloat(4);
	float targetDmgInf = results.FetchFloat(5);
	float targetDmgTank = results.FetchFloat(6);
	float targetActions = results.FetchFloat(7);

	float r = float(targetRounds > 0 ? targetRounds : 1);
	float targetAvgPts = targetTotal / r;
	float targetAvgSurv = targetDmgSurv / r;
	float targetAvgInf = targetDmgInf / r;
	float targetAvgTank = targetDmgTank / r;
	float targetAvgActions = targetActions / r;

	char query[1024];
	Format(query, sizeof(query),
		"SELECT p.steamid, p.name, p.total_points, p.rounds_played, "
		... "COALESCE(SUM(r.dmg_survivor), 0), COALESCE(SUM(r.dmg_infected), 0), COALESCE(SUM(r.dmg_tank), 0), "
		... "COALESCE(SUM(r.special_clears + r.self_clears + r.skeets + r.deadstops + r.boomer_pops + r.revives + r.medkit_gives + r.special_rescues + r.jockey_blocks + r.tank_play_actions), 0) "
		... "FROM players p LEFT JOIN round_stats r ON p.steamid = r.steamid "
		... "WHERE p.steamid != '%s' GROUP BY p.steamid;",
		targetSteamid);

	DataPack pack2 = new DataPack();
	pack2.WriteCell(client);
	pack2.WriteFloat(targetAvgPts);
	pack2.WriteFloat(targetAvgSurv);
	pack2.WriteFloat(targetAvgInf);
	pack2.WriteFloat(targetAvgTank);
	pack2.WriteFloat(targetAvgActions);
	g_Db.Query(SQL_ShowSimilarity, query, pack2);
}

public void SQL_ShowSimilarity(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	float targetAvgPts = pack.ReadFloat();
	float targetAvgSurv = pack.ReadFloat();
	float targetAvgInf = pack.ReadFloat();
	float targetAvgTank = pack.ReadFloat();
	float targetAvgActions = pack.ReadFloat();
	delete pack;

	if (!IsValidClient(client))
	{
		return;
	}

	if (results == null)
	{
		ReplyToCommand(client, "[Skill] Similarity query failed: %s", error);
		return;
	}

	char topName[5][MAX_NAME_LENGTH];
	float topDist[5];
	float topAvg[5];
	int topRounds[5];

	for (int i = 0; i < 5; i++)
	{
		topDist[i] = 999999.0;
		topAvg[i] = 0.0;
		topRounds[i] = 0;
		topName[i][0] = '\0';
	}

	while (results.FetchRow())
	{
		char name[MAX_NAME_LENGTH];
		float total = results.FetchFloat(2);
		int rounds = results.FetchInt(3);
		float dmgSurv = results.FetchFloat(4);
		float dmgInf = results.FetchFloat(5);
		float dmgTank = results.FetchFloat(6);
		float actions = results.FetchFloat(7);
		results.FetchString(1, name, sizeof(name));

		if (rounds <= 0)
		{
			continue;
		}

		float rr = float(rounds);
		float avgPts = total / rr;
		float avgSurv = dmgSurv / rr;
		float avgInf = dmgInf / rr;
		float avgTank = dmgTank / rr;
		float avgActions = actions / rr;

		float dist = 0.0;
		dist += FloatAbs(avgPts - targetAvgPts) / FloatMax(1.0, targetAvgPts);
		dist += FloatAbs(avgSurv - targetAvgSurv) / FloatMax(1.0, targetAvgSurv);
		dist += FloatAbs(avgInf - targetAvgInf) / FloatMax(1.0, targetAvgInf);
		dist += FloatAbs(avgTank - targetAvgTank) / FloatMax(1.0, targetAvgTank);
		dist += FloatAbs(avgActions - targetAvgActions) / FloatMax(1.0, targetAvgActions);

		int worst = 0;
		for (int i = 1; i < 5; i++)
		{
			if (topDist[i] > topDist[worst])
			{
				worst = i;
			}
		}

		if (dist < topDist[worst])
		{
			topDist[worst] = dist;
			topAvg[worst] = avgPts;
			topRounds[worst] = rounds;
			strcopy(topName[worst], sizeof(topName[]), name);
		}
	}

	ReplyToCommand(client, "[Skill] Most similar players:");
	for (int n = 0; n < 5; n++)
	{
		int best = -1;
		for (int i = 0; i < 5; i++)
		{
			if (topName[i][0] == '\0')
			{
				continue;
			}
			if (best == -1 || topDist[i] < topDist[best])
			{
				best = i;
			}
		}

		if (best == -1)
		{
			break;
		}

		ReplyToCommand(client, "[Skill] %s | avg: %.2f | rounds: %d", topName[best], topAvg[best], topRounds[best]);
		topName[best][0] = '\0';
	}
}

void LoadPlayerProfile(int client)
{
	if (!IsValidHuman(client))
	{
		return;
	}

	char steamid[32];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));

	char escName[MAX_NAME_LENGTH * 2 + 1];
	g_Db.Escape(name, escName, sizeof(escName));

	char qEnsure[512];
	Format(qEnsure, sizeof(qEnsure),
		"INSERT OR IGNORE INTO players (steamid, name, total_points, rounds_played, last_seen) "
		... "VALUES ('%s', '%s', 0.0, 0, strftime('%%s', 'now')); "
		... "UPDATE players SET name='%s', last_seen=strftime('%%s', 'now') WHERE steamid='%s';",
		steamid, escName, escName, steamid);
	g_Db.Query(SQL_ErrorOnly, qEnsure);

	char qLoad[256];
	Format(qLoad, sizeof(qLoad), "SELECT total_points, rounds_played FROM players WHERE steamid='%s';", steamid);
	DataPack pack = new DataPack();
	pack.WriteCell(client);
	g_Db.Query(SQL_LoadPlayerProfile, qLoad, pack);
}

public void SQL_LoadPlayerProfile(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	delete pack;

	if (!IsValidClient(client))
	{
		return;
	}

	if (results == null || !results.FetchRow())
	{
		return;
	}

	g_fTotalPoints[client] = results.FetchFloat(0);
	g_iRoundsPlayed[client] = results.FetchInt(1);
}

void SaveRoundAndUpdatePlayer(int client, int team, float rawScore, float awarded)
{
	char steamid[32];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	char escName[MAX_NAME_LENGTH * 2 + 1];
	g_Db.Escape(name, escName, sizeof(escName));

	char qPlayer[1024];
	Format(qPlayer, sizeof(qPlayer),
		"INSERT OR IGNORE INTO players (steamid, name, total_points, rounds_played, last_seen) "
		... "VALUES ('%s', '%s', 0.0, 0, strftime('%%s', 'now')); "
		... "UPDATE players SET name='%s', total_points=total_points+%.4f, rounds_played=rounds_played+1, last_seen=strftime('%%s', 'now') WHERE steamid='%s';",
		steamid, escName, escName, awarded, steamid);
	g_Db.Query(SQL_ErrorOnly, qPlayer);

	char escMap[128];
	g_Db.Escape(g_sMapName, escMap, sizeof(escMap));

	char qRound[2048];
	Format(qRound, sizeof(qRound),
		"INSERT INTO round_stats (steamid, name, round_index, map_name, team, raw_points, awarded_points, "
		... "dmg_infected, dmg_survivor, dmg_tank, dmg_witch, common_kills, special_clears, self_clears, skeets, deadstops, boomer_pops, revives, medkit_gives, special_rescues, jockey_blocks, tank_play_actions, ts) "
		... "VALUES ('%s', '%s', %d, '%s', %d, %.4f, %.4f, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, strftime('%%s', 'now'));",
		steamid, escName, g_iRoundNumber, escMap, team, rawScore, awarded,
		g_iDamageAsInfected[client],
		g_iDamageAsSurvivor[client],
		g_iTankDamageAsSurvivor[client],
		g_iWitchDamageAsSurvivor[client],
		g_iCommonKillsAsSurvivor[client],
		g_iSpecialClears[client],
		g_iSmokerSelfClears[client],
		g_iSkeets[client],
		g_iDeadstops[client],
		g_iBoomerPopsNoVomit[client],
		g_iRevives[client],
		g_iMedkitGives[client],
		g_iRescuesFromSpecial[client],
		g_iJockeyBlocks[client],
		g_iTankPlayActions[client]);
	g_Db.Query(SQL_ErrorOnly, qRound);

	g_fTotalPoints[client] += awarded;
	g_iRoundsPlayed[client]++;
}

void ResetRoundStats(int client)
{
	if (client < 1 || client > MaxClients)
	{
		return;
	}

	g_iDamageAsInfected[client] = 0;
	g_iDamageAsSurvivor[client] = 0;
	g_iTankDamageAsSurvivor[client] = 0;
	g_iWitchDamageAsSurvivor[client] = 0;
	g_iCommonKillsAsSurvivor[client] = 0;

	g_iSpecialClears[client] = 0;
	g_iSmokerSelfClears[client] = 0;
	g_iSkeets[client] = 0;
	g_iDeadstops[client] = 0;
	g_iBoomerPopsNoVomit[client] = 0;
	g_iRevives[client] = 0;
	g_iMedkitGives[client] = 0;
	g_iRescuesFromSpecial[client] = 0;
	g_iJockeyBlocks[client] = 0;
	g_iTankPlayActions[client] = 0;

	g_bHealStartedToOther[client] = false;
}

float GetAveragePoints(int client)
{
	if (g_iRoundsPlayed[client] <= 0)
	{
		return 0.0;
	}
	return g_fTotalPoints[client] / float(g_iRoundsPlayed[client]);
}

bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client));
}

bool IsValidHuman(int client)
{
	return IsValidClient(client) && !IsFakeClient(client);
}

bool IsTankInPlayActive()
{
	return L4D2_IsTankInPlay();
}

void CreateTables()
{
	char query[4096];

	Format(query, sizeof(query),
		"CREATE TABLE IF NOT EXISTS players ("
		... "steamid TEXT PRIMARY KEY, "
		... "name TEXT NOT NULL DEFAULT '', "
		... "total_points REAL NOT NULL DEFAULT 0.0, "
		... "rounds_played INTEGER NOT NULL DEFAULT 0, "
		... "last_seen INTEGER NOT NULL DEFAULT (strftime('%%s', 'now'))"
		... ");");
	g_Db.Query(SQL_ErrorOnly, query);

	Format(query, sizeof(query),
		"CREATE TABLE IF NOT EXISTS round_stats ("
		... "id INTEGER PRIMARY KEY AUTOINCREMENT, "
		... "steamid TEXT NOT NULL, "
		... "name TEXT NOT NULL DEFAULT '', "
		... "round_index INTEGER NOT NULL, "
		... "map_name TEXT NOT NULL DEFAULT '', "
		... "team INTEGER NOT NULL DEFAULT 0, "
		... "raw_points REAL NOT NULL DEFAULT 0.0, "
		... "awarded_points REAL NOT NULL DEFAULT 0.0, "
		... "dmg_infected INTEGER NOT NULL DEFAULT 0, "
		... "dmg_survivor INTEGER NOT NULL DEFAULT 0, "
		... "dmg_tank INTEGER NOT NULL DEFAULT 0, "
		... "dmg_witch INTEGER NOT NULL DEFAULT 0, "
		... "common_kills INTEGER NOT NULL DEFAULT 0, "
		... "special_clears INTEGER NOT NULL DEFAULT 0, "
		... "self_clears INTEGER NOT NULL DEFAULT 0, "
		... "skeets INTEGER NOT NULL DEFAULT 0, "
		... "deadstops INTEGER NOT NULL DEFAULT 0, "
		... "boomer_pops INTEGER NOT NULL DEFAULT 0, "
		... "revives INTEGER NOT NULL DEFAULT 0, "
		... "medkit_gives INTEGER NOT NULL DEFAULT 0, "
		... "special_rescues INTEGER NOT NULL DEFAULT 0, "
		... "jockey_blocks INTEGER NOT NULL DEFAULT 0, "
		... "tank_play_actions INTEGER NOT NULL DEFAULT 0, "
		... "ts INTEGER NOT NULL DEFAULT (strftime('%%s', 'now'))"
		... ");");
	g_Db.Query(SQL_ErrorOnly, query);

	EnsureColumn("round_stats", "jockey_blocks", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "tank_play_actions", "INTEGER NOT NULL DEFAULT 0");
}

void EnsureColumn(const char[] table, const char[] column, const char[] definition)
{
	char query[256];
	Format(query, sizeof(query), "PRAGMA table_info(%s);", table);

	DataPack pack = new DataPack();
	pack.WriteString(table);
	pack.WriteString(column);
	pack.WriteString(definition);
	g_Db.Query(SQL_CheckColumn, query, pack);
}

public void SQL_CheckColumn(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	char table[64];
	char column[64];
	char definition[128];

	pack.Reset();
	pack.ReadString(table, sizeof(table));
	pack.ReadString(column, sizeof(column));
	pack.ReadString(definition, sizeof(definition));
	delete pack;

	if (results == null)
	{
		LogError("[SkillRating] PRAGMA table_info failed: %s", error);
		return;
	}

	bool found = false;
	while (results.FetchRow())
	{
		char colName[64];
		results.FetchString(1, colName, sizeof(colName));
		if (StrEqual(colName, column, false))
		{
			found = true;
			break;
		}
	}

	if (!found)
	{
		char alter[256];
		Format(alter, sizeof(alter), "ALTER TABLE %s ADD COLUMN %s %s;", table, column, definition);
		g_Db.Query(SQL_ErrorOnly, alter);
	}
}

public void SQL_ErrorOnly(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("[SkillRating] SQL error: %s", error);
	}
}
