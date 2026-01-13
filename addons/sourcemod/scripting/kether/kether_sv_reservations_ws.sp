/*  
*    Copyright (C) 2025  StarterX4		starterx4(at)gmail(dot)com
*    Copyright (C) 2025  Kether.pl
*
*    This program is free software: you can redistribute it and/or modify
*    it under the terms of the GNU General Public License as published by
*    the Free Software Foundation, either version 3 of the License, or
*    (at your option) any later version.
*
*    This program is distributed in the hope that it will be useful,
*    but WITHOUT ANY WARRANTY; without even the implied warranty of
*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*    GNU General Public License for more details.
*
*    You should have received a copy of the GNU General Public License
*    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#include <websocket>
#include <colors>

#define PLUGIN_VERSION "1.2"
#define PLUGIN_URL "https://kether.pl"

// Constants
#define REMINDER_INTERVAL 300.0
#define SECONDS_PER_DAY 86400
#define SECONDS_PER_HOUR 3600
#define SECONDS_PER_MINUTE 60
#define SET_COMMAND_PREFIX "SET "
#define SET_COMMAND_PREFIX_LEN 4

public Plugin myinfo =
{
    name = "Kether Server Reservations (WebSocket)",
    author = "StarterX4",
    description = "Manages server reservations via WebSocket connection",
    version = PLUGIN_VERSION,
    url = PLUGIN_URL
};

// Globals
WebSocket g_ws = null;

bool g_isReserved = false;
int g_reservedTimestamp = 0;

// Plugin Lifecycle
public void OnPluginStart()
{
    g_ws = new WebSocket("wss://21370000.xyz/api/ws/plan", WebSocket_STRING);

    g_ws.SetHeader("Origin", PLUGIN_URL);
    g_ws.SetOpenCallback(OnWSOpen);
    g_ws.SetMessageCallback(OnWSMessage);
    g_ws.SetCloseCallback(OnWSClose);
    g_ws.SetErrorCallback(OnWSError);

    g_ws.AutoReconnect = true;

    g_ws.Connect();

    CreateTimer(REMINDER_INTERVAL, Timer_Reminder, _, TIMER_REPEAT);
}

public void OnClientPutInServer(int client)
{
    // Check if this is the first human player joining an empty server
    if (!IsFakeClient(client) && IsClientInGame(client))
    {
        // Count other human players (excluding this one)
        int humanCount = 0;
        for (int i = 1; i <= MaxClients; i++)
        {
            if (i != client && IsClientInGame(i) && !IsFakeClient(i))
            {
                humanCount++;
            }
        }
        
        // If server was empty (0 other humans) and reservation is active, show reminder
        if (humanCount == 0 && g_isReserved)
        {
            // Delay slightly to ensure client is fully connected
            CreateTimer(1.0, Timer_ShowReminderOnJoin, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
        }
    }
}

public void OnPluginEnd()
{
    if (g_ws != null)
    {
        delete g_ws;
        g_ws = null;
    }
}

// WebSocket Callbacks
public void OnWSOpen(WebSocket ws)
{
    PrintToServer("[WS] Connected to backend");
}

public void OnWSMessage(WebSocket ws, const char[] message, int wireSize)
{
    if (StrContains(message, SET_COMMAND_PREFIX) == 0)
    {
        HandleSetReservation(message);
        return;
    }

    if (StrEqual(message, "CLEAR"))
    {
        HandleClearReservation();
        return;
    }
}

public void OnWSClose(WebSocket ws, int code, const char[] reason)
{
    PrintToServer("[WS] Closed (%d): %s", code, reason);
}

public void OnWSError(WebSocket ws, const char[] errMsg)
{
    PrintToServer("[WS] Error: %s", errMsg);
}

// Timer Callbacks
public Action Timer_Reminder(Handle timer)
{
    if (g_isReserved)
    {
        ShowReservationMessages();
    }

    return Plugin_Continue;
}

public Action Timer_ShowReminderOnJoin(Handle timer, int userId)
{
    int client = GetClientOfUserId(userId);
    
    // Only show if reservation is still active and client is still connected
    if (g_isReserved && client > 0 && IsClientInGame(client) && !IsFakeClient(client))
    {
        ShowReservationMessages();
    }
    
    return Plugin_Stop;
}

// Helper Functions
void HandleSetReservation(const char[] message)
{
    char timestampStr[64];
    int messageLen = strlen(message);
    
    // Extract timestamp string after "SET " prefix
    if (messageLen <= SET_COMMAND_PREFIX_LEN)
    {
        PrintToServer("[WS] Invalid SET command: missing timestamp");
        return;
    }
    
    strcopy(timestampStr, sizeof(timestampStr), message[SET_COMMAND_PREFIX_LEN]);
    
    // Validate and parse timestamp
    int timestamp = StringToInt(timestampStr);
    if (timestamp <= 0)
    {
        PrintToServer("[WS] Invalid SET command: invalid timestamp '%s'", timestampStr);
        return;
    }
    
    // Store raw timestamp
    g_reservedTimestamp = timestamp;
    g_isReserved = true;

    char timeStr[64];
    FormatTimestamp(timestamp, timeStr, sizeof(timeStr));
    PrintToServer("[WS] Reservation set off %s", timeStr);
    ShowReservationMessages();
}

void HandleClearReservation()
{
    if (g_isReserved == true) PrintToServer("[WS] Reservation cleared");
    g_isReserved = false;
    g_reservedTimestamp = 0;
}

void ShowReservationMessages()
{
    // Recalculate time remaining on each reminder
    char timeRemaining[64];
    FormatTimestamp(g_reservedTimestamp, timeRemaining, sizeof(timeRemaining));
    
    CPrintToChatAll("{green}Server has been reserved for Kether community game in {red}%s{green}.", timeRemaining);
    CPrintToChatAll("{green}Please finish your match and leave the server within {red}%s{green}.", timeRemaining);
    CPrintToChatAll("{green}Restart may occur 3-5 minutes before reservation.");
}

void FormatTimestamp(int timestamp, char[] buffer, int maxlen)
{
    int time = GetTime();
    int diff = timestamp - time;
    
    if (diff < 0)
    {
        Format(buffer, maxlen, "now (expired)");
        return;
    }
    
    int days = diff / SECONDS_PER_DAY;
    int hours = (diff % SECONDS_PER_DAY) / SECONDS_PER_HOUR;
    int minutes = (diff % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE;
    
    if (days > 0)
        Format(buffer, maxlen, "%d day(s) %d hour(s)", days, hours);
    else if (hours > 0)
        Format(buffer, maxlen, "%d hour(s) %d minute(s)", hours, minutes);
    else
        Format(buffer, maxlen, "%d minute(s)", minutes);
}