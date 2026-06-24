#pragma semicolon 1
#pragma newdecls optional
#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <ripext>

#define BIND_SUGGESTION_API_URL "http://21370000.xyz/api/bind_suggestions/addBindSuggestion"

bool canAddNewBind[MAXPLAYERS + 1];
char pendingBindText[MAXPLAYERS + 1][384];

public Plugin myinfo =
{
	name = "[ANY] Proposed binds (REST API)",
	author = "Krevik, StarterX4, Cursor AI",
	description = "Lets players suggest new binds via the Kether website REST API (successor to the database plugin).",
	version = "2.0.0",
	url = "https://kether.pl"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_bind", CMD_Binds, "Let's add that bind");
}

public void OnClientPutInServer(int client)
{
	canAddNewBind[client] = true;
}

public Action CMD_Binds(int client, int args)
{
	if (!canAddNewBind[client])
	{
		CPrintToChat(client, "Cooldown for binds adding: 1 minute");
		return Plugin_Handled;
	}

	char content[512];
	GetCmdArgString(content, sizeof(content));
	TrimString(content);

	if (content[0] == '\0')
	{
		CPrintToChat(client, "Usage: !bind Author :  quote text");
		return Plugin_Handled;
	}

	char author[128];
	char text[384];
	ParseBindContent(content, author, sizeof(author), text, sizeof(text));

	if (text[0] == '\0')
	{
		CPrintToChat(client, "Usage: !bind Author :  quote text");
		return Plugin_Handled;
	}

	postBindSuggestionRequest(client, author, text);
	canAddNewBind[client] = false;
	delayAllowBind(client);

	return Plugin_Handled;
}

void ParseBindContent(const char[] content, char[] author, int authorLen, char[] text, int textLen)
{
	author[0] = '\0';

	int colonPos = StrContains(content, ":");
	if (colonPos != -1)
	{
		strcopy(author, authorLen, content);
		author[colonPos] = '\0';
		TrimString(author);

		strcopy(text, textLen, content[colonPos + 1]);
		TrimString(text);
	}
	else
	{
		strcopy(text, textLen, content);
		TrimString(text);
	}
}

void postBindSuggestionRequest(int clientID, const char[] author, const char[] text)
{
	if (clientID <= 0 || clientID > MaxClients)
	{
		return;
	}

	if (!IsClientAndInGame(clientID) || IsFakeClient(clientID))
	{
		return;
	}

	char proposedBy[MAX_NAME_LENGTH];
	GetClientName(clientID, proposedBy, sizeof(proposedBy));

	strcopy(pendingBindText[clientID], sizeof(pendingBindText[]), text);

	JSONObject payload = new JSONObject();
	payload.SetString("author", author);
	payload.SetString("text", text);
	payload.SetString("proposed_by", proposedBy);

	HTTPRequest request = new HTTPRequest(BIND_SUGGESTION_API_URL);
	request.Post(payload, OnBindSuggestionPosted, clientID);

	delete payload;
}

void OnBindSuggestionPosted(HTTPResponse response, int clientID)
{
	if (!IsClientAndInGame(clientID))
	{
		return;
	}

	if (response.Status == HTTPStatus_OK)
	{
		CPrintToChatAll(
			"{blue}%N{default} suggested a new bind: {green}%s{default}",
			clientID,
			pendingBindText[clientID]
		);
		return;
	}

	if (response.Status == HTTPStatus_Conflict)
	{
		CPrintToChat(clientID, "That bind was already suggested.");
		LogError(
			"Proposed bind HTTP request rejected (duplicate). Client: %N, Status: %s",
			clientID,
			response.Status
		);
		return;
	}

	CPrintToChat(clientID, "Failed to suggest bind.");
	LogError(
		"Proposed bind HTTP request failed! Client: %N, Status: %s",
		clientID,
		response.Status
	);
}

public void delayAllowBind(int client)
{
	DataPack pack;
	CreateDataTimer(60.0, AllowBind, pack);
	pack.WriteCell(client);
}

public Action AllowBind(Handle timer, DataPack pack)
{
	int client;
	pack.Reset();
	client = pack.ReadCell();
	canAddNewBind[client] = true;
	return Plugin_Continue;
}

bool IsClientAndInGame(int index)
{
	return (index > 0 && index <= MaxClients && IsClientInGame(index));
}
