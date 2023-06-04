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

#include <sourcemod>
#include <clientprefs>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0.1"

#if SOURCEMOD_V_MAJOR == 1 && SOURCEMOD_V_MINOR < 11
    #error "This plugin requires SourceMod 1.11 or higher. Some required features do not exist in older versions of SourceMod."
#endif

public Plugin myinfo =
{
    name = "Language Selector",
    author = "SirDigbot",
    description = "Set the language used for SourceMod translations.",
    version = PLUGIN_VERSION,
    url = "https://github.com/sirdigbot/sm-lang-selector"
};

#define CURRENT_LANG_PREFIX "▶ "
#define CHAT_TAG "[LangSelect]"

#define MAX_PROMPT_ATTEMPTS 10  // Attempts for connect prompt
#define MAX_LOAD_ATTEMPTS 3     // Attempts for loading cookies asynchronously

//#define _DEBUG

enum ShowPromptState
{
    State_None = 0,
    State_WaitingToDisplay,
    State_Skipped // See ClientHasPassedPrompt
}

bool g_IsLateLoad;
EngineVersion g_Engine;

ConVar g_Cvar_Version;
ConVar g_Cvar_UseConfig;
ConVar g_Cvar_ConfigPath;
ConVar g_Cvar_AllowCustom;
ConVar g_Cvar_AllowReset;
ConVar g_Cvar_Save;
ConVar g_Cvar_ShowPrompt;
ConVar g_Cvar_PromptOnce;

Cookie g_Cookie_ClientLang;
StringMap g_SupportedLanguages;     // Languages in SourceMod's languages.cfg
StringMap g_ConfigLanguages;        // Languages in langselect config
Menu g_Menu;
int g_MenuLanguageCount;
bool g_MenuWasFromShowPrompt[MAXPLAYERS + 1];

#if !defined GetClientOriginalLanguage
int g_ClientDefaultLang[MAXPLAYERS + 1];
#warning "This plugin was compiled with an older SourceMod version (<= 1.12) where GetClientOriginalLanguage() is not available. This will work fine, but very rare bugs may be possible."
#endif

ShowPromptState g_ClientPromptState[MAXPLAYERS + 1];     // Prompt client on spawn (if prompt enabled).
bool g_HasLanguageLoaded[MAXPLAYERS + 1];
bool g_IsLoadingLanguageAsync[MAXPLAYERS + 1];  // Should OnClientLanguageChanged load the client's language setting.

Handle g_Timer_RetryLoad[MAXPLAYERS + 1];
Handle g_Timer_RetryPrompt[MAXPLAYERS + 1];


#include "langselect/commands.sp"
#include "langselect/config.sp"
#include "langselect/count_timer.sp"
#include "langselect/menu.sp"
#include "langselect/prompt.sp"


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int size)
{
    g_IsLateLoad = late;
    g_Engine = GetEngineVersion();
    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations("common.phrases");
    LoadTranslations("langselect.phrases");

    g_Cvar_Version = CreateConVar("langselect_version", PLUGIN_VERSION, "Language Selector version. Don't touch.", FCVAR_NOTIFY | FCVAR_DONTRECORD);
    g_Cvar_UseConfig = CreateConVar("langselect_use_config", "1", "Should the config file be used to set the available languages.\nIf 0, this will use a built-in list of languages.", FCVAR_NONE, true, 0.0, true, 1.0);
    g_Cvar_ConfigPath = CreateConVar("langselect_config", "configs/langselect.cfg", "Location of the Language Selector config file (relative to the SourceMod directory).");
    g_Cvar_AllowCustom = CreateConVar("langselect_allow_custom", "0", "Allow custom language codes with \"sm_language <Code>\".\nIf 0, only codes available in the config (or the built-in list if config is disabled) are permitted.", FCVAR_NONE, true, 0.0, true, 1.0);
    g_Cvar_AllowReset = CreateConVar("langselect_allow_reset", "1", "Show a \"Reset Language\" option on the menu.", FCVAR_NONE, true, 0.0, true, 1.0);
    g_Cvar_Save = CreateConVar("langselect_save", "1", "Should a player's selected language be saved.", FCVAR_NONE, true, 0.0, true, 1.0);
    g_Cvar_ShowPrompt = CreateConVar("langselect_show_prompt", "0", "Ask new players to select a language when they spawn.", FCVAR_NONE, true, 0.0, true, 1.0);
    g_Cvar_PromptOnce = CreateConVar("langselect_prompt_once", "1", "How should the language selection prompt show to a new player.\n0 - On each respawn until a language is selected.\n1 - Only once per session.", FCVAR_NONE, true, 0.0, true, 1.0);

    g_Cvar_Version.AddChangeHook(OnCvarChanged);
    g_Cvar_UseConfig.AddChangeHook(OnCvarChanged);
    g_Cvar_ConfigPath.AddChangeHook(OnCvarChanged);

    RegConsoleCmd("sm_language", Command_Language, "Set your own SourceMod translation language.");
    RegConsoleCmd("sm_lang", Command_Language, "Set your own SourceMod translation language.");

    RegAdminCmd("sm_getlanguage", Command_GetLanguage, ADMFLAG_GENERIC, "Get a player's SourceMod translation language.");
    RegAdminCmd("sm_getlang", Command_GetLanguage, ADMFLAG_GENERIC, "Get a player's SourceMod translation language.");
    RegAdminCmd("sm_setlanguage", Command_SetLanguage, ADMFLAG_BAN, "Set a player's SourceMod translation language.");
    RegAdminCmd("sm_setlang", Command_SetLanguage, ADMFLAG_BAN, "Set a player's SourceMod translation language.");
    RegAdminCmd("sm_resetlanguage", Command_ResetLanguage, ADMFLAG_BAN, "Reset a player's SourceMod translation language.");
    RegAdminCmd("sm_resetlang", Command_ResetLanguage, ADMFLAG_BAN, "Reset a player's SourceMod translation language.");

    g_SupportedLanguages = new StringMap();
    g_ConfigLanguages = new StringMap();
    g_Cookie_ClientLang = new Cookie("langselect_language", "Client's selected language.", CookieAccess_Protected);

    CountTimer_Init();

    HookEvent("player_spawn", Event_PlayerSpawn);

    AutoExecConfig();
}


//------------------------------------------------------------------------------
// Events
//------------------------------------------------------------------------------
void OnCvarChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
    if (cvar == g_Cvar_Version)
        g_Cvar_Version.SetString(PLUGIN_VERSION);
    else if (cvar == g_Cvar_UseConfig || cvar == g_Cvar_ConfigPath)
        LoadLanguages();
}

public void OnConfigsExecuted()
{
    LoadLanguages();

    if (!g_IsLateLoad)
        return;

    for (int i = 1; i <= MaxClients; ++i)
    {
        if (IsClientConnected(i) && !IsFakeClient(i))
            LateLoadClient(i);
    }
}


//------------------------------------------------------------------------------
// Client connect/loading events
//------------------------------------------------------------------------------
/**
 * Connect process explained
 *
 * Most games will set a CPlayer's language during connect, however some (CSGO
 * and Blade Symphony currently) must query it asynchronously.
 * We can't SetClientLanguage until that async callback is executed or it will
 * overwrite anything we set.
 *
 * This means that for most games we can call LoadPlayerLanguage immediately in
 * OnClientCookiesCached (since it's always after OnClientConnected).
 *
 * But for CSGO/Blade Symphony we can't use OnClientCookiesCached, and must wait
 * until that async callback triggers OnClientLanguageChanged (the first time it
 * calls after OnClientConnected) and then repeatedly check
 * AreClientCookiesCached before we can call LoadPlayerLanguage.
 *
 *
 * Connect 'decision tree' explained:
 *
 * New client connects
 * - Prompt enabled
 *     - Set/Select lang
 *         -- Leaving after this will store setting.
 *     - Ignore prompt and continue playing
 *         -- Optionally shown prompt again on each respawn.
 *     - Ignore prompt and leave
 *         -- Dont save setting. Next join will treat as new player again.
 *            This will work even if prompt is disabled before next connect.
 *
 * - No Prompt enabled
 *     - Set/Select lang.
 *     - Leave
 *         -- Always stores current lang setting even if it wasn't set
 *            so they aren't seen as a new player next connect.
 */

void LateLoadClient(int client)
{
#if defined _DEBUG
    PrintToServer("DEBUG: LateLoadClient fired");
#endif

    // Simulate a normal player connection
    OnClientConnected(client);

    if (EngineQueriesLangCvar(g_Engine))
        OnClientLanguageChanged(client, GetClientLanguage(client));

    // If this fails client probably just joined
    if (AreClientCookiesCached(client))
        OnClientCookiesCached(client);
}

public void OnClientConnected(int client)
{
#if defined _DEBUG
    PrintToServer("DEBUG: OnClientConnected fired (query lang: %i)", EngineQueriesLangCvar(g_Engine));
#endif

    g_HasLanguageLoaded[client] = false;

    // State_None by default because LoadPlayerLanguage will set it
    // with the correct timing (always after a valid load),
    // so prompt never displays erroneously.
    g_ClientPromptState[client] = State_None;

#if !defined GetClientOriginalLanguage
    g_ClientDefaultLang[client] = GetClientLanguage(client);
#endif

    if (!IsFakeClient(client))
        g_IsLoadingLanguageAsync[client] = EngineQueriesLangCvar(g_Engine);
    else
        g_IsLoadingLanguageAsync[client] = false;
}

public void OnClientCookiesCached(int client)
{
#if defined _DEBUG
    PrintToServer("DEBUG: OnClientCookiesCached fired");
#endif

    if (IsFakeClient(client))
        return;

    // Load synchronously for games not in EngineQueriesLangCvar
    if (!EngineQueriesLangCvar(g_Engine))
    {
#if defined _DEBUG
        PrintToServer("DEBUG: Loading Sync client:%i", client);
#endif
        LoadPlayerLanguage(client);
    }
}

public void OnClientLanguageChanged(int client, int language)
{
#if defined _DEBUG
    PrintToServer("DEBUG: OnClientLanguageChanged fired");
#endif

    // Reject client if they are not being loaded in via async language query
    if (!g_IsLoadingLanguageAsync[client] || !EngineQueriesLangCvar(g_Engine))
        return;

    g_IsLoadingLanguageAsync[client] = false;

    if (IsFakeClient(client))
        return;

#if defined _DEBUG
    PrintToServer("DEBUG: Loading Async client:%i", client);
#endif

    if (AreClientCookiesCached(client))
        LoadPlayerLanguage(client);
    else
    {
        // This timer is only needed if EngineQueriesLangCvar is true,
        // because OnClientCookiesCached is guaranteed to be called AFTER
        // client connects (meaning they can have their language set)
        // for non cvar-querying games.
        CloseCountTimer(g_Timer_RetryLoad[client]);

        g_Timer_RetryLoad[client] = CreateCountTimer(
            5.0,
            MAX_LOAD_ATTEMPTS,
            OnRetryAsyncLoad,
            OnFinishedAsyncLoad,
            GetClientUserId(client));

#if defined _DEBUG
        PrintToServer("DEBUG: Async Retry Timer client:%i", client);
#endif

    }
}

Action OnRetryAsyncLoad(int loopCount, any data)
{
#if defined _DEBUG
    PrintToServer("DEBUG: OnRetryAsyncLoad fired");
#endif

    int client = GetClientOfUserId(data);
    if (client == 0)
        return Plugin_Stop;

    if (AreClientCookiesCached(client))
    {
        LoadPlayerLanguage(client);
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

void OnFinishedAsyncLoad(any data, bool error, bool stoppedEarly)
{
#if defined _DEBUG
    PrintToServer("DEBUG: OnFinishedAsyncLoad fired");
#endif

    int client = GetClientOfUserId(data);
    if (client == 0)
        return; // g_Timer_RetryLoad deleted on disconnect

    g_Timer_RetryLoad[client] = null;

    // Successfully loaded language
    if (stoppedEarly)
        return;

    else if (!stoppedEarly || error)
    {
        if (IsClientInGame(client))
            PrintToChat(client, "%s %t", CHAT_TAG, "Could not load language");
    }
}


//------------------------------------------------------------------------------
// Client disconnecting events
//------------------------------------------------------------------------------
public void OnClientDisconnect(int client)
{
#if defined _DEBUG
    PrintToServer("DEBUG: OnClientDisconnect fired");
#endif

    CloseCountTimer(g_Timer_RetryPrompt[client]);
    CloseCountTimer(g_Timer_RetryLoad[client]);

    // Save for every player even if their language didnt change
    // otherwise they will be seen as a new player.
    // But dont set if they haven't loaded in yet.
    if (g_HasLanguageLoaded[client]
        && IsClientConnected(client)
        && !IsFakeClient(client)
        && AreClientCookiesCached(client)
        && g_Cvar_Save.BoolValue)
    {
        // For new players, don't save if they ignored the prompt
        // (only if prompt is enabled)
        if (ClientHasPassedPrompt(client))
            SavePlayerLanguage(client);
    }

    g_HasLanguageLoaded[client] = false;
    g_IsLoadingLanguageAsync[client] = false;
    g_ClientPromptState[client] = State_None;

    g_MenuWasFromShowPrompt[client] = false;
    g_ClientDefaultLang[client] = 0;
}

public void OnPluginEnd()
{
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (!IsClientConnected(i) || IsFakeClient(i))
            continue;

        OnClientDisconnect(i);

        // Restore default language after saving
        ResetPlayerLanguage(i);
    }
}


//------------------------------------------------------------------------------
// Language Funcs
//------------------------------------------------------------------------------
void ApplyPlayerLanguage(int client, int lang)
{
    SetClientLanguage(client, lang);
    g_ClientPromptState[client] = State_None; // Prevent re-prompting later
}

void ResetPlayerLanguage(int client)
{
#if defined GetClientOriginalLanguage
    SetClientLanguage(client, GetClientOriginalLanguage(client));
#else
    SetClientLanguage(client, g_ClientDefaultLang[client]);
#endif

    // Prevent language prompt since resetting counts as setting your language
    g_ClientPromptState[client] = State_None;
}

void LoadPlayerLanguage(int client)
{
    if (!AreClientCookiesCached(client))
        ThrowError("Client cookies are not cached.");

    g_HasLanguageLoaded[client] = true;
    g_ClientPromptState[client] = State_None;

    // If saving/loading is disabled, we still need the globals to be set
    if (!g_Cvar_Save.BoolValue)
    {
#if defined _DEBUG
        PrintToServer("DEBUG: LoadPlayerLanguage Canceled (save=0) client:%i", client);
#endif
        return;
    }

    // Get language setting
    char code[8];
    g_Cookie_ClientLang.Get(client, code, sizeof(code));

    int lang = GetLanguageByCode(code);
    if (lang == -1)
    {
        // Client has unknown/no language setting, treat as new player
        if (g_Cvar_ShowPrompt.BoolValue)
            g_ClientPromptState[client] = State_WaitingToDisplay;
        return;
    }

    // Do not apply languages that were removed from the config
    if (!IsLanguageAllowedByConfig(code))
    {
        ResetPlayerLanguage(client);

#if defined _DEBUG
        PrintToServer("DEBUG: LoadPlayerLanguage Reset client:%i", client);
#endif

    }
    else
    {
        ApplyPlayerLanguage(client, lang);

#if defined _DEBUG
        PrintToServer("DEBUG: LoadPlayerLanguage Apply client:%i, lang:%i(%s)", client, lang, code);
#endif

    }
}

void SavePlayerLanguage(int client, int lang = -1)
{
#if defined _DEBUG
    PrintToServer("DEBUG: SavePlayerLanguage Called client:%i, lang:%i", client, lang);
#endif

    if (!g_HasLanguageLoaded[client])
        return;

    if (!AreClientCookiesCached(client))
        return;

    if (lang == -1)
        lang = GetClientLanguage(client);

    char code[8];
    GetLanguageInfo(lang, code, sizeof(code));
    if (!code[0])
        return;

#if defined _DEBUG
    PrintToServer("DEBUG: SavePlayerLanguage Saving client:%i, lang:%i(%s)", client, lang, code);
#endif

    g_Cookie_ClientLang.Set(client, code);
    return;
}

void NotifyInvalidLanguage(int client, const char[] code, bool printChat = false)
{
    char langName[64];

    if (IsLanguageValidAndNotSupported(code))
    {
        // IsLanguageValidAndNotSupported guarantees translation exists
        TranslateNoError(client, code, langName, sizeof(langName));

        if (printChat)
            PrintToChat(client, "%s %t", CHAT_TAG, "Language not supported", langName, code);
        else
            ReplyToCommand(client, "%s %t", CHAT_TAG, "Language not supported", langName, code);
    }
    else
    {
        if (printChat)
            PrintToChat(client, "%s %t", CHAT_TAG, "Invalid language code", code);
        else
            ReplyToCommand(client, "%s %t", CHAT_TAG, "Invalid language code", code);  
    }
}


bool TranslateLanguageName(
    int client,
    int lang,
    const char[] code,
    char[] output,
    int size)
{
    if (!TranslateNoError(client, code, output, size))
    {
        GetLanguageInfo(lang, _, _, output, size);
        return false;
    }
    return true;
}

bool TranslateNoError(int client, const char[] phrase, char[] output, int size)
{
    if (!TranslationPhraseExists(phrase))
        return false;

    FormatEx(output, size, "%T", phrase, client);
    return true;
}


//------------------------------------------------------------------------------
// Stocks
//------------------------------------------------------------------------------
stock void StrToLower(char[] str, int size)
{
    for (int i = 0; str[i] != '\0' && i < size; ++i)
        str[i] = CharToLower(str[i]);
}

/**
 * Does a given engine version use g_ConVarManager.QueryClientConVar()
 * to obtain the "cl_language" value.
 *
 * If it does, a client's language will be available on the next call to
 * OnClientLanguageChanged (after connecting) as opposed to immediately
 * during OnClientConnect.
 */
stock bool EngineQueriesLangCvar(EngineVersion engine)
{
    // See PlayerManager::HandleConVarQuery
    return engine == Engine_CSGO || engine == Engine_Blade;
}

stock bool QueryErrored(Database db, DBResultSet results, const char[] error)
{
    return db == null || results == null || !error[0];
}