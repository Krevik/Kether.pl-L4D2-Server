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
// Config functions
//------------------------------------------------------------------------------
bool IsLanguageAllowedByConfig(const char[] code)
{
    return g_Cvar_AllowCustom.BoolValue || IsLanguageInConfig(code);
}

bool IsLanguageInConfig(const char[] code)
{
    return g_ConfigLanguages.ContainsKey(code);
}

bool IsSupportedLanguage(const char[] code)
{
    return g_SupportedLanguages.ContainsKey(code);
}

bool IsLanguageValidAndNotSupported(const char[] code)
{
    // NOTE: All valid country codes probably have a translation
    //
    // Additionally other code relies on this function implying that there
    // is a translation phrase matching the code. (See "Language not supported")

    if (TranslationPhraseExists(code))
        return !IsSupportedLanguage(code);
    return false;
}


//------------------------------------------------------------------------------
// LangSelect Config
//------------------------------------------------------------------------------
void ParseConfig()
{
    char buffer[PLATFORM_MAX_PATH];
    char path[PLATFORM_MAX_PATH];
    g_Cvar_ConfigPath.GetString(buffer, sizeof(buffer));
    BuildPath(Path_SM, path, sizeof(path), buffer);

    SMCParser p = new SMCParser();
    p.OnEnterSection = ParseConfig_EnterSection;
    p.OnKeyValue = ParseConfig_KeyValue;
    p.OnEnd = ParseConfig_OnEnd;

    SMCError res = p.ParseFile(path);
    if (res != SMCError_Okay)
    {
        char error[256];
        p.GetErrorString(res, error, sizeof(error));
        SetFailState("Failed to parse config file '%s'. Error: %s", path, error);
    }

    delete p;
}

SMCResult ParseConfig_EnterSection(
    SMCParser smc,
    const char[] name,
    bool opt_quotes)
{
    return SMCParse_Continue;
}

SMCResult ParseConfig_KeyValue(
    SMCParser smc,
    const char[] key,
    const char[] value,
    bool key_quotes,
    bool value_quotes)
{
    char keyLower[8];
    strcopy(keyLower, sizeof(keyLower), key);
    StrToLower(keyLower, sizeof(keyLower));

    AddLanguage(keyLower, value); // Translation is appended to name
    ++g_MenuLanguageCount;

    return SMCParse_Continue;
}

void ParseConfig_OnEnd(SMCParser smc, bool halted, bool failed)
{
    if (!halted && !failed)
        PrintToServer("%s %t", CHAT_TAG, "Loaded languages", g_MenuLanguageCount);
}


//------------------------------------------------------------------------------
// SourceMod Languages Config
//------------------------------------------------------------------------------
void ParseSourceModLanguages()
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/languages.cfg");

    SMCParser p = new SMCParser();
    p.OnEnterSection = ParseSMLangs_EnterSection;
    p.OnKeyValue = ParseSMLangs_KeyValue;

    SMCError res = p.ParseFile(path);
    if (res != SMCError_Okay)
    {
        char error[256];
        p.GetErrorString(res, error, sizeof(error));
        SetFailState("Failed to parse languages.cfg file. Error: %s", error);
    }

    delete p;
}

SMCResult ParseSMLangs_EnterSection(
    SMCParser smc,
    const char[] name,
    bool opt_quotes)
{
    return SMCParse_Continue;
}

SMCResult ParseSMLangs_KeyValue(
    SMCParser smc,
    const char[] key,
    const char[] value,
    bool key_quotes,
    bool value_quotes)
{
    g_SupportedLanguages.SetString(key, value);
    return SMCParse_Continue;
}
