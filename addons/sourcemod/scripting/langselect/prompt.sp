/**
 * This file is a part of Lanugage Selector.
 *
 * Copyright (C) 2022 SirDigbot (GitHub username)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#pragma semicolon 1
#pragma newdecls required

/**
 * Has client passed the prompt that's shown to new players.
 */
bool ClientHasPassedPrompt(int client)
{
    if (!g_Cvar_ShowPrompt.BoolValue)
        return true;
    return g_ClientPromptState[client] == State_None;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool bDontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client == 0 || IsFakeClient(client))
        return;

    if (!g_Cvar_ShowPrompt.BoolValue)
        return;

    if (g_ClientPromptState[client] == State_WaitingToDisplay)
        ShowPrompt(client);
}

bool DisplayPrompt(int client)
{
    if (!g_HasLanguageLoaded[client]
        || !AreClientCookiesCached(client)
        || !IsClientInGame(client))
    {
        return false;
    }

    // Prevent re-prompting later
    if (g_Cvar_PromptOnce.BoolValue)
        g_ClientPromptState[client] = State_Skipped;

    g_MenuWasFromShowPrompt[client] = true;

    g_Menu.Display(client, MENU_TIME_FOREVER);
    return true;
}

void ShowPrompt(int client)
{
    if (!DisplayPrompt(client))
    {
        CloseCountTimer(g_Timer_RetryPrompt[client]);
        g_Timer_RetryPrompt[client] = CreateCountTimer(
            2.0,
            MAX_PROMPT_ATTEMPTS,
            OnRetryPrompt,
            OnFinishedRetryPrompt,
            GetClientUserId(client));
    }
}

Action OnRetryPrompt(int loopCount, any data)
{
    int client = GetClientOfUserId(data);
    if (client == 0)
        return Plugin_Stop;

    if (DisplayPrompt(client))
        return Plugin_Stop;

    return Plugin_Continue;
}

void OnFinishedRetryPrompt(any data, bool error, bool stoppedEarly)
{
    int client = GetClientOfUserId(data);
    if (client == 0)
        return; // g_Timer_RetryPrompt deleted on disconnect

    g_Timer_RetryPrompt[client] = null;

    // Prompt was displayed successfully
    if (stoppedEarly)
        return;

    if (!stoppedEarly || error)
    {
        if (IsClientInGame(client))
            PrintToChat(client, "%s %t", CHAT_TAG, "Could not show prompt");
    }
}
