#include <ripext>
#include <regex>
#include <sourcemod>

public Plugin myinfo =
{
	name		= "L4D2 - Player Statistics Sync",
	author		= "Altair Sossai",
	description = "Sends the information generated by plugin l4d2_playstats.smx to the API of l4d2_playstats",
	version		= "1.0.0",
	url			= "https://github.com/altair-sossai/l4d2-zone-server"
};

ConVar cvar_playstats_endpoint;
ConVar cvar_playstats_server;
ConVar cvar_playstats_access_token;

public void OnPluginStart()
{
	cvar_playstats_endpoint = CreateConVar("playstats_endpoint", "https://l4d2-playstats-api.azurewebsites.net", "Play Stats endpoint", FCVAR_PROTECTED);
	cvar_playstats_server = CreateConVar("playstats_server", "", "vanilla4mod", FCVAR_PROTECTED);
	cvar_playstats_access_token = CreateConVar("playstats_access_token", "", "Play Stats Access Token", FCVAR_PROTECTED);

	RegAdminCmd("sm_syncstats", SyncStatsCmd, ADMFLAG_BAN);
	RegConsoleCmd("sm_ranking", ShowRankingCmd);
	RegConsoleCmd("sm_lastmatch", LastMatchCmd);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	CreateTimer(130.0, DisplayStatsUrlTick, _, TIMER_REPEAT);
}

public void Event_RoundStart(Event hEvent, const char[] eName, bool dontBroadcast)
{
	Sync();
}

public Action SyncStatsCmd(int client, int args)
{
	Sync();
	return Plugin_Handled;
}

public Action ShowRankingCmd(int client, int args)
{
	ShowRanking(client);
	return Plugin_Handled;
}

public Action LastMatchCmd(int client, int args)
{
	LastMatch(client);
	return Plugin_Handled;
}

public Action DisplayStatsUrlTick(Handle timer)
{
	new String:server[100];
	GetConVarString(cvar_playstats_server, server, sizeof(server));

	PrintToChatAll("Estatísticas/ranking disponível em:");
	PrintToChatAll("\x03https://l4d2-playstats.azurewebsites.net/server/%s", server);
	PrintToChatAll("\x01Use \x04!ranking \x01para consultar sua posição");

	return Plugin_Continue;
}

public void Sync()
{
	char logsPath[128] = "logs/";
	BuildPath(Path_SM, logsPath, PLATFORM_MAX_PATH, logsPath);

	Regex regex = new Regex("^\\w{4}-\\w{2}-\\w{2}_\\w{2}-\\w{2}_\\d{4}.*\\.txt$");
	DirectoryListing directoryListing = OpenDirectory(logsPath);

	char fileName[128];
	while (directoryListing.GetNext(fileName, sizeof(fileName))) 
	{
		if (!regex.Match(fileName))
			continue;

		SyncFile(fileName);
	}
}

public void SyncFile(String:fileName[])
{
	char filePath[128];
	FormatEx(filePath, sizeof(filePath), "%s%s", "logs/", fileName);
	BuildPath(Path_SM, filePath, PLATFORM_MAX_PATH, filePath);

	File file = OpenFile(filePath, "r");
	if (!file)
		return;

	char content[40000];
	file.ReadString(content, sizeof(content), -1);

	JSONObject command = new JSONObject();

	command.SetString("fileName", fileName);
	command.SetString("content", content);

	HTTPRequest request = BuildHTTPRequest("/api/statistics");
	request.Post(command, SyncFileResponse);
}

void SyncFileResponse(HTTPResponse httpResponse, any value)
{
	if (httpResponse.Status != HTTPStatus_OK)
		return;

	JSONObject response = view_as<JSONObject>(httpResponse.Data);

	bool mustBeDeleted = response.GetBool("mustBeDeleted");
	if (!mustBeDeleted)
		return;

	char fileName[128];
	response.GetString("fileName", fileName, sizeof(fileName));

	char filePath[128];
	FormatEx(filePath, sizeof(filePath), "%s%s", "logs/", fileName);
	BuildPath(Path_SM, filePath, PLATFORM_MAX_PATH, filePath);

	DeleteFile(filePath);
}

public void ShowRanking(int client)
{
	new String:server[100];
	GetConVarString(cvar_playstats_server, server, sizeof(server));

	new String:communityId[25];
	GetClientAuthId(client, AuthId_SteamID64, communityId, sizeof(communityId));

	char path[128];
	FormatEx(path, sizeof(path), "/api/ranking/%s/place/%s", server, communityId);

	HTTPRequest request = BuildHTTPRequest(path);
	request.Get(ShowRankingResponse, client);
}

void ShowRankingResponse(HTTPResponse httpResponse, int client)
{
	if (httpResponse.Status != HTTPStatus_OK)
		return;

	JSONObject response = view_as<JSONObject>(httpResponse.Data);
	JSONArray top3 = view_as<JSONArray>(response.Get("top3"));
	JSONObject me = view_as<JSONObject>(response.Get("me"));

	for (int i = 0; i < top3.Length; i++)
	{
		JSONObject player = view_as<JSONObject>(top3.Get(i));
		PrintPlayerInfo(player, client);
	}

	if (me.GetInt("position") >= 4)
		PrintPlayerInfo(me, client);

	PrintToChatAll("\x01Use \x04!lastmatch \x01para visualizar os resultados do último jogo");
}

void PrintPlayerInfo(JSONObject player, int client)
{
	int position = player.GetInt("position");
	float points = player.GetFloat("points");
	float lastMatchPoints = player.GetFloat("lastMatchPoints");

	char name[256];
	player.GetString("name", name, sizeof(name));

	if (lastMatchPoints == 0)
		PrintToChat(client, "\x04%dº \x01%s \x03%.0f pts", position, name, points);
	else
		PrintToChat(client, "\x04%dº \x01%s \x03%.0f pts \x04(+%.0f)", position, name, points, lastMatchPoints);
}

public void LastMatch(int client)
{
	new String:server[100];
	GetConVarString(cvar_playstats_server, server, sizeof(server));

	char path[128];
	FormatEx(path, sizeof(path), "/api/ranking/%s/last-match", server);

	HTTPRequest request = BuildHTTPRequest(path);
	request.Get(LastMatchResponse, client);
}

void LastMatchResponse(HTTPResponse httpResponse, int client)
{
	if (httpResponse.Status != HTTPStatus_OK)
		return;

	JSONObject response = view_as<JSONObject>(httpResponse.Data);
	JSONObject match = view_as<JSONObject>(response.Get("match"));
	JSONArray players = view_as<JSONArray>(response.Get("players"));

	char campaign[128];
	match.GetString("campaign", campaign, sizeof(campaign));

	char matchElapsed[16];
	match.GetString("matchElapsed", matchElapsed, sizeof(matchElapsed));

	PrintToChat(client, "\x01Campanha: \x04%s", campaign);
	PrintToChat(client, "\x01Duração: \x04%s", matchElapsed);

	for (int i = 0; i < players.Length; i++)
	{
		JSONObject player = view_as<JSONObject>(players.Get(i));

		int position = player.GetInt("position");
		float lastMatchPoints = player.GetFloat("lastMatchPoints");

		char name[256];
		player.GetString("name", name, sizeof(name));

		PrintToChat(client, "\x04%dº \x01%s \x03+%.0f pts", position, name, lastMatchPoints);
	}
}

HTTPRequest BuildHTTPRequest(char[] path)
{
	new String:endpoint[255];
	GetConVarString(cvar_playstats_endpoint, endpoint, sizeof(endpoint));
	StrCat(endpoint, sizeof(endpoint), path);

	new String:access_token[100];
	GetConVarString(cvar_playstats_access_token, access_token, sizeof(access_token));

	HTTPRequest request = new HTTPRequest(endpoint);
	request.SetHeader("Authorization", access_token);

	return request;
}