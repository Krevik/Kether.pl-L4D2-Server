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

#define MENU_ITEMS_PER_PAGE 6


void AddLanguage(const char[] code, const char[] display)
{
    g_Menu.AddItem(code, display);
    g_ConfigLanguages.SetValue(code, 1);
}

static void ResetAllLanguages()
{
    delete g_Menu;
    g_MenuLanguageCount = 0;
    g_ConfigLanguages.Clear();
    g_SupportedLanguages.Clear();
}

int AddDefaultLanguages()
{
    /**
     * Languages ripped from SourceMod's standard languages.cfg
     * These are mostly ISO 639-1 language codes.
     * 
     * Names with * have ISO 639-1 noncompliant language codes.
     */
    int start = __LINE__;
    AddLanguage("en", "English");
    AddLanguage("ar", "عربى");          // Arabic
    AddLanguage("pt", "Português");     // Brazilian Portuguese *
    AddLanguage("bg", "български");     // Bulgarian
    AddLanguage("cze", "čeština");      // Czech *
    AddLanguage("da", "Dansk");         // Danish
    AddLanguage("nl", "Nederlands");    // Dutch
    AddLanguage("fi", "Suomalainen");   // Finnish
    AddLanguage("fr", "Français");      // French
    AddLanguage("de", "Deutsch");       // German
    AddLanguage("el", "Ελληνικά");      // Greek
    AddLanguage("he", "עִברִית");         // Hebrew
    AddLanguage("hu", "Magyar");        // Hungarian
    AddLanguage("it", "Italiano");      // Italian
    AddLanguage("jp", "日本語");        // Japanese
    AddLanguage("ko", "한국어");        // Korean
    AddLanguage("lv", "Latviski");      // Latvian
    AddLanguage("lt", "Lietuvių");      // Lithuanian
    AddLanguage("no", "Norsk");         // Norwegian
    AddLanguage("pl", "Polski");        // Polish
    AddLanguage("pt_p", "Português");   // Portuguese *
    AddLanguage("ro", "Română");        // Romanian
    AddLanguage("ru", "Русский");       // Russian
    AddLanguage("chi", "简体中文");     // Simplified Chinese *
    AddLanguage("sk", "Slovenský");     // Slovak
    AddLanguage("es", "Español");       // Spanish
    AddLanguage("sv", "Svenska");       // Swedish
    AddLanguage("zho", "繁體中文");     // Traditional Chinese *
    AddLanguage("th", "ไทย");           // Thai
    AddLanguage("tr", "Türk");          // Turkish
    AddLanguage("ua", "українська");    // Ukrainian
    AddLanguage("vi", "Tiếng Việt");    // Vietnamese
    int end = __LINE__;

    return end - start - 1;
}

void LoadLanguages()
{
    ResetAllLanguages();

    g_Menu = new Menu(LangSelectHandler, MenuAction_Display | MenuAction_DisplayItem | MenuAction_DrawItem);
    g_Menu.Pagination = true;
    g_Menu.ExitButton = true;

    // Always add reset, hide it in the handler if it's disabled (g_Cvar_AllowReset)
    // Otherwise we have to rebuild the menu when it changes.
    g_Menu.AddItem("RESET", "Reset Language");

    // If you add more items, fix GetMenuItemPage

    ParseSourceModLanguages();

    if (g_Cvar_UseConfig.BoolValue)
        ParseConfig();
    else
    {
        g_MenuLanguageCount = AddDefaultLanguages();
        PrintToServer("%s %t", CHAT_TAG, "Loaded default languages", g_MenuLanguageCount);
    }
}

int LangSelectHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_End:
        {
            // Global menu, don't delete
            return 0;
        }

        case MenuAction_Cancel:
        {
            g_MenuWasFromShowPrompt[param1] = false;
        }

        case MenuAction_Display:
        {
            char title[256];
            FormatEx(title, sizeof(title), "%T", "Choose a language", param1);
            Panel panel = view_as<Panel>(param2);
            panel.SetTitle(title);
        }

        case MenuAction_DisplayItem:
        {
            char info[8];
            char display[128];
            menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));

            if (StrEqual(info, "RESET"))
            {
                FormatEx(display, sizeof(display), "%T", "Reset Language", param1);
                return RedrawMenuItem(display);
            }

            int lang = GetLanguageByCode(info);
            if (lang == -1)
            {
                FormatEx(display, sizeof(display), "%T", "Invalid language menu item", param1, info);
                return RedrawMenuItem(display);
            }

            char langName[64];
            TranslateLanguageName(param1, lang, info, langName, sizeof(langName));

            // If item display text is empty, use a translated name as default.
            int currentLang = GetClientLanguage(param1);
            if (!display[0])
            {
                if (lang == currentLang)
                    Format(langName, sizeof(langName), "%s%s", CURRENT_LANG_PREFIX, langName);
                return RedrawMenuItem(langName);
            }

            // If item already has display text (i.e. default menu, correctly configured cfg)
            // append the translation to the original display name.
            Format(
                display,
                sizeof(display),
                "%s%s (%s)",
                (lang == currentLang) ? CURRENT_LANG_PREFIX : "",
                display,
                langName);
            return RedrawMenuItem(display);
        }

        case MenuAction_DrawItem:
        {
            char info[8];
            menu.GetItem(param2, info, sizeof(info));

            if (StrEqual(info, "RESET"))
            {
                if (g_Cvar_AllowReset.BoolValue)
                    return ITEMDRAW_DEFAULT;
                else
                    return ITEMDRAW_IGNORE; // GetMenuItemPage relies on this being IGNORE
            }

            if (!AreClientCookiesCached(param1))
                return ITEMDRAW_DISABLED;

            if (!g_HasLanguageLoaded[param1])
                return ITEMDRAW_DISABLED;

            int lang = GetLanguageByCode(info);
            if (lang == -1)
                return ITEMDRAW_DISABLED;
            
            // Don't disable current language option for new players,
            // in case they dont want to change
            if (!g_MenuWasFromShowPrompt[param1] && lang == GetClientLanguage(param1))
                return ITEMDRAW_DISABLED;

            return ITEMDRAW_DEFAULT;
        }

        case MenuAction_Select:
        {
            char info[8];
            menu.GetItem(param2, info, sizeof(info));

            if (!AreClientCookiesCached(param1))
            {
                g_MenuWasFromShowPrompt[param1] = false;
                return 0;
            }

            if (!g_HasLanguageLoaded[param1])
            {
                g_MenuWasFromShowPrompt[param1] = false;
                return 0;
            }

            if (StrEqual(info, "RESET"))
            {
                if (!g_Cvar_AllowReset.BoolValue)
                {
                    // Redisplay menu to lessen confusion
                    g_Menu.Display(param1, MENU_TIME_FOREVER);
                    g_MenuWasFromShowPrompt[param1] = false;
                    return 0;
                }

                char code[8];
                char langName[64];
                GetLanguageInfo(g_ClientDefaultLang[param1], code, sizeof(code));
                TranslateLanguageName(
                    param1,
                    g_ClientDefaultLang[param1],
                    code,
                    langName,
                    sizeof(langName));

                ResetPlayerLanguage(param1);

                PrintToChat(param1, "%s %t", CHAT_TAG, "Reset language to default", langName);

                g_Menu.Display(param1, MENU_TIME_FOREVER);
                g_MenuWasFromShowPrompt[param1] = false;
                return 0;
            }

            int lang = GetLanguageByCode(info);
            if (lang == -1)
            {
                NotifyInvalidLanguage(param1, info, true); // true = PrintToChat
                g_MenuWasFromShowPrompt[param1] = false;
                return 0;
            }

            char langName[64];
            TranslateLanguageName(param1, lang, info, langName, sizeof(langName));

            ApplyPlayerLanguage(param1, lang);
            PrintToChat(param1, "%s %t", CHAT_TAG, "Set language", langName);

            // Redisplay on same page (if the menu was not prompted).
            if (!g_MenuWasFromShowPrompt[param1])
                g_Menu.DisplayAt(param1, GetMenuItemPage(param2), MENU_TIME_FOREVER);
            
            g_MenuWasFromShowPrompt[param1] = false;
        }
    }

    return 0;
}

static int GetMenuItemPage(int itemPosition)
{
    // If "RESET" is ITEMDRAW_IGNORE, offset the item positions
    // for page calculation
    bool useOffset = !g_Cvar_AllowReset.BoolValue;
    if (useOffset)
        --itemPosition;

    int firstOnPage = (itemPosition / MENU_ITEMS_PER_PAGE) * MENU_ITEMS_PER_PAGE;

    // Fix offset to DisplayAt correct item
    if (useOffset)
        return firstOnPage + 1;

    return firstOnPage;
}
