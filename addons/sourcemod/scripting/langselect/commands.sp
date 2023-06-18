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


//------------------------------------------------------------------------------
// sm_language <Optional Country Code>
//------------------------------------------------------------------------------
public Action Command_Language(int client, int args)
{
    if (client == 0)
    {
        ReplyToCommand(client, "%s %t", CHAT_TAG, "Command is in-game only");
        return Plugin_Handled;
    }

    if (!g_HasLanguageLoaded[client])
    {
        ReplyToCommand(client, "%s %t", CHAT_TAG, "Client not yet loaded");
        return Plugin_Handled;
    }

    if (args == 0)
    {
        g_Menu.Display(client, MENU_TIME_FOREVER);
        return Plugin_Handled;
    }

    if (args != 1)
    {
        ReplyToCommand(client, "%s %t", CHAT_TAG, "sm_language usage");
        return Plugin_Handled;
    }

    char arg1[8];
    GetCmdArg(1, arg1, sizeof(arg1));
    StrToLower(arg1, sizeof(arg1));

    int lang = GetLanguageByCode(arg1);
    if (lang == -1)
    {
        NotifyInvalidLanguage(client, arg1, false);
        return Plugin_Handled;
    }

    if (!IsLanguageAllowedByConfig(arg1))
    {
        ReplyToCommand(client, "%s %t", CHAT_TAG, "Custom languages not allowed");
        return Plugin_Handled;
    }

    char langName[64];
    TranslateLanguageName(client, lang, arg1, langName, sizeof(langName));

    ApplyPlayerLanguage(client, lang);
    ReplyToCommand(client, "%s %t", CHAT_TAG, "Set language", langName);
    return Plugin_Handled;
}


//------------------------------------------------------------------------------
// sm_getlanguage <Target>
//------------------------------------------------------------------------------
public Action Command_GetLanguage(int client, int args)
{
    if (args != 1)
    {
        ReplyToCommand(client, "%s %t", CHAT_TAG, "sm_getlanguage usage");
        return Plugin_Handled;
    }

    char arg1[MAX_NAME_LENGTH];
    GetCmdArg(1, arg1, sizeof(arg1));

    int target = FindTarget(client, arg1, true); // No bots
    if (target == -1)
        return Plugin_Handled;

    if (!g_HasLanguageLoaded[target] || !IsClientInGame(target))
    {
        ReplyToCommand(client, "%s %t", CHAT_TAG, "Target not yet loaded");
        return Plugin_Handled;
    }
    
    int lang = GetClientLanguage(target);
    
    char code[8];
    GetLanguageInfo(lang, code, sizeof(code));

    GetClientName(target, arg1, sizeof(arg1));

    if (TranslationPhraseExists(code))
        ReplyToCommand(client, "%s %t", CHAT_TAG, "Get target language", arg1, code);
    else
    {
        char langName[64];
        GetLanguageInfo(lang, _, _, langName, sizeof(langName));
        ReplyToCommand(client, "%s %t", CHAT_TAG, "Get target language", arg1, "_s", langName);
    }

    return Plugin_Handled;
}


//------------------------------------------------------------------------------
// sm_setlanguage <Target> <Country Code>
//------------------------------------------------------------------------------
public Action Command_SetLanguage(int client, int args)
{
    if (args != 2)
    {
        ReplyToCommand(client, "%s %t", CHAT_TAG, "sm_setlanguage usage");
        return Plugin_Handled;
    }

    char arg1[MAX_NAME_LENGTH];
    char arg2[8];
    GetCmdArg(1, arg1, sizeof(arg1));
    GetCmdArg(2, arg2, sizeof(arg2));

    StrToLower(arg2, sizeof(arg2));

    int target = FindTarget(client, arg1, true); // No bots
    if (target == -1)
        return Plugin_Handled;

    if (!g_HasLanguageLoaded[target] || !IsClientInGame(target))
    {
        ReplyToCommand(client, "%s %t", CHAT_TAG, "Target not yet loaded");
        return Plugin_Handled;
    }

    int lang = GetLanguageByCode(arg2);
    if (lang == -1)
    {
        NotifyInvalidLanguage(client, arg2, false);
        return Plugin_Handled;
    }

    // Custom/Non-menu language codes are always allowed for admins
    // so dont check IsLanguageAllowedByConfig

    ApplyPlayerLanguage(client, lang);

    GetClientName(target, arg1, sizeof(arg1));

    if (TranslationPhraseExists(arg2))
        ShowActivity2(client, CHAT_TAG, " %t", "Set target language", arg1, arg2);
    else
    {
        char langName[64];
        GetLanguageInfo(lang, _, _, langName, sizeof(langName));
        ShowActivity2(client, CHAT_TAG, " %t", "Set target language", arg1, "_s", langName);
    }
    return Plugin_Handled;
}


//------------------------------------------------------------------------------
// sm_resetlanguage <Target>
//------------------------------------------------------------------------------
public Action Command_ResetLanguage(int client, int args)
{
    if (args != 1)
    {
        ReplyToCommand(client, "%s %t", CHAT_TAG, "sm_resetlanguage usage");
        return Plugin_Handled;
    }

    char arg1[MAX_NAME_LENGTH];
    GetCmdArg(1, arg1, sizeof(arg1));

    int target = FindTarget(client, arg1, true); // No bots
    if (target == -1)
        return Plugin_Handled;
    
    if (!g_HasLanguageLoaded[target] || !IsClientInGame(target))
    {
        ReplyToCommand(client, "%s %t", CHAT_TAG, "Target not yet loaded");
        return Plugin_Handled;
    }

    ResetPlayerLanguage(target);

    GetClientName(target, arg1, sizeof(arg1));
    ShowActivity2(client, CHAT_TAG, " %t", "Reset target language", arg1);
    return Plugin_Handled;
}
