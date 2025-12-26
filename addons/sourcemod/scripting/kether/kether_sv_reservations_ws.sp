#include <websocket>
#include <colors>

#define PLUGIN_VERSION "1.1"
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
    
    CPrintToChatAll("{green}Server has been reserved for the Kether community starting in {red}%s{green}!", timeRemaining);
    CPrintToChatAll("{green}You are advised to finish your match and leave the server within {red}%s{green}.", timeRemaining);
    CPrintToChatAll("{green}A few minutes (3-5) before the reservation starts, a sudden restart may happen.");
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