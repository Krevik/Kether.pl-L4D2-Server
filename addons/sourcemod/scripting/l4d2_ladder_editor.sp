#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define CONFIG_LADDERS           "data/l4d2_ladder_editor.cfg"
#define CHAT_TAG                 "\x04[Ladder]\x01 "
#define MAX_LADDERS              128
#define MAX_REMOVES              128
#define DEFAULT_POS_STEP         1.0
#define DEFAULT_ANG_STEP         15.0
#define DEFAULT_SIZE_STEP        4.0
#define ORIGIN_TOLERANCE         1.0
#define ANGLE_TOLERANCE          1.0

enum struct LadderData
{
    char model[128];
    float origin[3];
    float angles[3];
    float normal[3];
}

public Plugin myinfo =
{
    name = "L4D2 Ladder Editor (Menu)",
    author = "Kether",
    description = "Menu-based ladder editor with live save.",
    version = "1.0.0",
    url = ""
};

int g_iSelectedLadder[MAXPLAYERS + 1];
float g_fPosStep[MAXPLAYERS + 1];
float g_fAngStep[MAXPLAYERS + 1];
float g_fSizeStep[MAXPLAYERS + 1];
bool g_bMenuOpen[MAXPLAYERS + 1];
int g_iLastMenuAction[MAXPLAYERS + 1]; // 0=main, 1=nudge, 2=rotate, 3=size

LadderData g_AddData[MAX_LADDERS];
int g_iAddEntRef[MAX_LADDERS];
int g_iAddCount;

LadderData g_RemoveData[MAX_REMOVES];
int g_iRemoveCount;

bool g_bMapStarted;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    EngineVersion test = GetEngineVersion();
    if (test != Engine_Left4Dead2)
    {
        strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
        return APLRes_SilentFailure;
    }
    return APLRes_Success;
}

public void OnPluginStart()
{
    RegAdminCmd("sm_ladder_menu", Command_Menu, ADMFLAG_ROOT, "Open ladder editor menu.");

    for (int i = 1; i <= MaxClients; i++)
    {
        g_iSelectedLadder[i] = INVALID_ENT_REFERENCE;
        g_fPosStep[i] = DEFAULT_POS_STEP;
        g_fAngStep[i] = DEFAULT_ANG_STEP;
        g_fSizeStep[i] = DEFAULT_SIZE_STEP;
        g_bMenuOpen[i] = false;
        g_iLastMenuAction[i] = 0;
    }
}

static int g_iLastButtons[MAXPLAYERS + 1];

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    if (client <= 0 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client))
        return Plugin_Continue;

    if (!g_bMenuOpen[client] || GetSelectedEntity(client, false) == -1)
    {
        g_iLastButtons[client] = buttons;
        return Plugin_Continue;
    }
    int currentButtons = buttons;
    bool bShift = (buttons & IN_SPEED) != 0;

    if (!bShift)
    {
        g_iLastButtons[client] = currentButtons;
        return Plugin_Continue;
    }

    int lastButtons = g_iLastButtons[client];
    bool bPressed = false;
    float move[3];
    float rotDelta[3];

    int menuAction = g_iLastMenuAction[client];
    
    if (menuAction == 1 || menuAction == 0)
    {
        if ((currentButtons & IN_FORWARD) && !(lastButtons & IN_FORWARD))
        {
            move[1] = g_fPosStep[client];
            bPressed = true;
        }
        if ((currentButtons & IN_BACK) && !(lastButtons & IN_BACK))
        {
            move[1] = -g_fPosStep[client];
            bPressed = true;
        }
        if ((currentButtons & IN_MOVELEFT) && !(lastButtons & IN_MOVELEFT))
        {
            move[0] = -g_fPosStep[client];
            bPressed = true;
        }
        if ((currentButtons & IN_MOVERIGHT) && !(lastButtons & IN_MOVERIGHT))
        {
            move[0] = g_fPosStep[client];
            bPressed = true;
        }
        if ((currentButtons & IN_USE) && !(lastButtons & IN_USE))
        {
            move[2] = g_fPosStep[client];
            bPressed = true;
        }
        if ((currentButtons & IN_RELOAD) && !(lastButtons & IN_RELOAD))
        {
            move[2] = -g_fPosStep[client];
            bPressed = true;
        }
        if (bPressed && (move[0] != 0.0 || move[1] != 0.0 || move[2] != 0.0))
        {
            NudgeSelected(client, move[0], move[1], move[2]);
        }
    }
    else if (menuAction == 2)
    {
        if ((currentButtons & IN_FORWARD) && !(lastButtons & IN_FORWARD))
        {
            rotDelta[1] = g_fAngStep[client];
            bPressed = true;
        }
        if ((currentButtons & IN_BACK) && !(lastButtons & IN_BACK))
        {
            rotDelta[1] = -g_fAngStep[client];
            bPressed = true;
        }
        if ((currentButtons & IN_MOVELEFT) && !(lastButtons & IN_MOVELEFT))
        {
            rotDelta[2] = -g_fAngStep[client];
            bPressed = true;
        }
        if ((currentButtons & IN_MOVERIGHT) && !(lastButtons & IN_MOVERIGHT))
        {
            rotDelta[2] = g_fAngStep[client];
            bPressed = true;
        }
        if ((currentButtons & IN_USE) && !(lastButtons & IN_USE))
        {
            rotDelta[0] = g_fAngStep[client];
            bPressed = true;
        }
        if ((currentButtons & IN_RELOAD) && !(lastButtons & IN_RELOAD))
        {
            rotDelta[0] = -g_fAngStep[client];
            bPressed = true;
        }
        if (bPressed && (rotDelta[0] != 0.0 || rotDelta[1] != 0.0 || rotDelta[2] != 0.0))
        {
            RotateSelected(client, rotDelta);
        }
    }
    else if (menuAction == 3)
    {
        float heightDelta = 0.0;
        if ((currentButtons & IN_USE) && !(lastButtons & IN_USE))
        {
            heightDelta = g_fSizeStep[client];
            bPressed = true;
        }
        if ((currentButtons & IN_RELOAD) && !(lastButtons & IN_RELOAD))
        {
            heightDelta = -g_fSizeStep[client];
            bPressed = true;
        }
        if (bPressed && heightDelta != 0.0)
        {
            ResizeSelected(client, heightDelta);
        }
    }

    g_iLastButtons[client] = currentButtons;
    return Plugin_Continue;
}

public void OnMapStart()
{
    g_bMapStarted = true;
    ResetState();
    CreateTimer(0.2, Timer_LoadConfig, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd()
{
    g_bMapStarted = false;
    ResetState();
}

public void OnClientDisconnect_Post(int client)
{
    g_iSelectedLadder[client] = INVALID_ENT_REFERENCE;
    g_fPosStep[client] = DEFAULT_POS_STEP;
    g_fAngStep[client] = DEFAULT_ANG_STEP;
    g_fSizeStep[client] = DEFAULT_SIZE_STEP;
    g_bMenuOpen[client] = false;
    g_iLastMenuAction[client] = 0;
}

Action Timer_LoadConfig(Handle timer)
{
    if (!g_bMapStarted)
        return Plugin_Stop;

    LoadConfig();
    return Plugin_Stop;
}

void ResetState()
{
    g_iAddCount = 0;
    g_iRemoveCount = 0;

    for (int i = 0; i < MAX_LADDERS; i++)
        g_iAddEntRef[i] = 0;
}

// ====================================================================================================
//                                     COMMANDS / MENUS
// ====================================================================================================
public Action Command_Menu(int client, int args)
{
    if (!client)
    {
        ReplyToCommand(client, "[Ladder] Command can only be used in game.");
        return Plugin_Handled;
    }

    ShowMainMenu(client);
    return Plugin_Handled;
}

void ShowMainMenu(int client)
{
    Menu menu = new Menu(MainMenuHandler);
    menu.SetTitle("Ladder Editor");
    menu.AddItem("select", "Select ladder (aim)");
    menu.AddItem("clone", "Clone ladder (aim) at crosshair");
    menu.AddItem("move", "Move selected to crosshair");
    menu.AddItem("nudge", "Nudge selected");
    menu.AddItem("rotate", "Rotate selected");
    menu.AddItem("size", "Resize height");
    menu.AddItem("delete", "Delete selected");
    menu.AddItem("list", "List saved ladders");
    menu.AddItem("tele", "Teleport to ladder");
    menu.AddItem("reload", "Reload from config");
    menu.ExitButton = true;
    menu.ExitBackButton = false;
    menu.Display(client, MENU_TIME_FOREVER);
    g_bMenuOpen[client] = true;
    g_iLastMenuAction[client] = 0;
}

int MainMenuHandler(Menu menu, MenuAction action, int client, int index)
{
    if (action == MenuAction_End)
    {
        delete menu;
        g_bMenuOpen[client] = false;
        return 0;
    }
    
    if (action != MenuAction_Select)
        return 0;

    char info[16];
    menu.GetItem(index, info, sizeof(info));

    if (StrEqual(info, "select"))
    {
        SelectLadder(client);
        ShowMainMenu(client);
    }
    else if (StrEqual(info, "clone"))
    {
        CloneFromAim(client);
        ShowMainMenu(client);
    }
    else if (StrEqual(info, "move"))
    {
        MoveSelectedToCrosshair(client);
        ShowMainMenu(client);
    }
    else if (StrEqual(info, "nudge"))
    {
        ShowNudgeMenu(client);
    }
    else if (StrEqual(info, "rotate"))
    {
        ShowRotateMenu(client);
    }
    else if (StrEqual(info, "size"))
    {
        ShowSizeMenu(client);
    }
    else if (StrEqual(info, "delete"))
    {
        DeleteSelected(client);
        ShowMainMenu(client);
    }
    else if (StrEqual(info, "list"))
    {
        PrintLadderList(client);
        ShowMainMenu(client);
    }
    else if (StrEqual(info, "tele"))
    {
        ShowTeleportMenu(client);
    }
    else if (StrEqual(info, "reload"))
    {
        ReloadFromConfig(client);
        ShowMainMenu(client);
    }

    return 0;
}

void ShowNudgeMenu(int client)
{
    Menu menu = new Menu(NudgeMenuHandler);
    char title[64];
    Format(title, sizeof(title), "Nudge (step %.2f)", g_fPosStep[client]);
    menu.SetTitle(title);
    menu.AddItem("x+", "X +");
    menu.AddItem("y+", "Y +");
    menu.AddItem("z+", "Z +");
    menu.AddItem("x-", "X -");
    menu.AddItem("y-", "Y -");
    menu.AddItem("z-", "Z -");
    menu.AddItem("step+", "Step +0.5");
    menu.AddItem("step-", "Step -0.5");
    menu.AddItem("back", "Back to main");
    menu.ExitButton = true;
    menu.ExitBackButton = false;
    menu.Display(client, MENU_TIME_FOREVER);
    g_iLastMenuAction[client] = 1;
}

int NudgeMenuHandler(Menu menu, MenuAction action, int client, int index)
{
    if (action == MenuAction_End)
    {
        delete menu;
        if (g_iLastMenuAction[client] == 1)
            g_bMenuOpen[client] = false;
        return 0;
    }
    
    if (action != MenuAction_Select)
        return 0;

    char info[16];
    menu.GetItem(index, info, sizeof(info));

    if (StrEqual(info, "back"))
    {
        ShowMainMenu(client);
        return 0;
    }

    if (StrEqual(info, "step+"))
    {
        g_fPosStep[client] += 0.5;
    }
    else if (StrEqual(info, "step-"))
    {
        g_fPosStep[client] = FloatMaxCustom(0.1, g_fPosStep[client] - 0.5);
    }
    else
    {
        float move[3];
        if (StrEqual(info, "x+")) move[0] = g_fPosStep[client];
        if (StrEqual(info, "y+")) move[1] = g_fPosStep[client];
        if (StrEqual(info, "z+")) move[2] = g_fPosStep[client];
        if (StrEqual(info, "x-")) move[0] = -g_fPosStep[client];
        if (StrEqual(info, "y-")) move[1] = -g_fPosStep[client];
        if (StrEqual(info, "z-")) move[2] = -g_fPosStep[client];

        NudgeSelected(client, move[0], move[1], move[2]);
    }

    ShowNudgeMenu(client);
    return 0;
}

void ShowRotateMenu(int client)
{
    Menu menu = new Menu(RotateMenuHandler);
    char title[64];
    Format(title, sizeof(title), "Rotate (step %.1f)", g_fAngStep[client]);
    menu.SetTitle(title);
    menu.AddItem("p+", "Pitch +");
    menu.AddItem("y+", "Yaw +");
    menu.AddItem("r+", "Roll +");
    menu.AddItem("p-", "Pitch -");
    menu.AddItem("y-", "Yaw -");
    menu.AddItem("r-", "Roll -");
    menu.AddItem("step+", "Step +5.0");
    menu.AddItem("step-", "Step -5.0");
    menu.AddItem("back", "Back to main");
    menu.ExitButton = true;
    menu.ExitBackButton = false;
    menu.Display(client, MENU_TIME_FOREVER);
    g_iLastMenuAction[client] = 2;
}

int RotateMenuHandler(Menu menu, MenuAction action, int client, int index)
{
    if (action == MenuAction_End)
    {
        delete menu;
        if (g_iLastMenuAction[client] == 2)
            g_bMenuOpen[client] = false;
        return 0;
    }
    
    if (action != MenuAction_Select)
        return 0;

    char info[16];
    menu.GetItem(index, info, sizeof(info));

    if (StrEqual(info, "back"))
    {
        ShowMainMenu(client);
        return 0;
    }

    if (StrEqual(info, "step+"))
    {
        g_fAngStep[client] += 5.0;
    }
    else if (StrEqual(info, "step-"))
    {
        g_fAngStep[client] = FloatMaxCustom(1.0, g_fAngStep[client] - 5.0);
    }
    else
    {
        float delta[3];
        if (StrEqual(info, "p+")) delta[0] = g_fAngStep[client];
        if (StrEqual(info, "y+")) delta[1] = g_fAngStep[client];
        if (StrEqual(info, "r+")) delta[2] = g_fAngStep[client];
        if (StrEqual(info, "p-")) delta[0] = -g_fAngStep[client];
        if (StrEqual(info, "y-")) delta[1] = -g_fAngStep[client];
        if (StrEqual(info, "r-")) delta[2] = -g_fAngStep[client];

        RotateSelected(client, delta);
    }

    ShowRotateMenu(client);
    return 0;
}

void ShowTeleportMenu(int client)
{
    Menu menu = new Menu(TeleportMenuHandler);
    menu.SetTitle("Teleport to ladder");

    char info[16];
    char label[128];
    float center[3];
    for (int i = 0; i < g_iAddCount; i++)
    {
        if (!IsValidEntRef(g_iAddEntRef[i]))
            continue;

        int entity = EntRefToEntIndex(g_iAddEntRef[i]);
        GetLadderCenter(entity, center);
        Format(info, sizeof(info), "%d", i);
        Format(label, sizeof(label), "#%d (%.1f %.1f %.1f)", i + 1, center[0], center[1], center[2]);
        menu.AddItem(info, label);
    }

    menu.AddItem("back", "Back to main");
    menu.ExitButton = true;
    menu.ExitBackButton = false;
    menu.Display(client, MENU_TIME_FOREVER);
}

int TeleportMenuHandler(Menu menu, MenuAction action, int client, int index)
{
    if (action == MenuAction_End)
    {
        delete menu;
        return 0;
    }
    
    if (action != MenuAction_Select)
        return 0;

    char info[16];
    menu.GetItem(index, info, sizeof(info));
    
    if (StrEqual(info, "back"))
    {
        ShowMainMenu(client);
        return 0;
    }
    
    int slot = StringToInt(info);
    if (slot < 0 || slot >= g_iAddCount)
    {
        ShowTeleportMenu(client);
        return 0;
    }

    if (!IsValidEntRef(g_iAddEntRef[slot]))
    {
        ShowTeleportMenu(client);
        return 0;
    }

    int entity = EntRefToEntIndex(g_iAddEntRef[slot]);
    float center[3];
    GetLadderCenter(entity, center);
    center[2] += 20.0;
    TeleportEntity(client, center, NULL_VECTOR, NULL_VECTOR);
    PrintToChat(client, "%sTeleported to ladder #%d.", CHAT_TAG, slot + 1);
    ShowTeleportMenu(client);
    return 0;
}

// ====================================================================================================
//                                     MENU ACTIONS
// ====================================================================================================
void SelectLadder(int client)
{
    int entity = GetClientAimTarget(client, false);
    if (!IsValidEntity(entity) || !IsLadder(entity))
    {
        g_iSelectedLadder[client] = INVALID_ENT_REFERENCE;
        PrintToChat(client, "%sNot looking at a ladder.", CHAT_TAG);
        return;
    }

    g_iSelectedLadder[client] = EntIndexToEntRef(entity);
    PrintLadderInfo(client, entity, "Selected");
}

void CloneFromAim(int client)
{
    int source = GetClientAimTarget(client, false);
    if (!IsValidEntity(source) || !IsLadder(source))
    {
        PrintToChat(client, "%sAim at a ladder to clone.", CHAT_TAG);
        return;
    }

    float targetCenter[3];
    if (!GetAimPosition(client, targetCenter))
    {
        PrintToChat(client, "%sCannot find target position.", CHAT_TAG);
        return;
    }

    LadderData data;
    float sourceCenter[3];
    GetLadderData(source, data, sourceCenter);

    float offset[3];
    offset[0] = sourceCenter[0] - data.origin[0];
    offset[1] = sourceCenter[1] - data.origin[1];
    offset[2] = sourceCenter[2] - data.origin[2];

    data.origin[0] = targetCenter[0] - offset[0];
    data.origin[1] = targetCenter[1] - offset[1];
    data.origin[2] = targetCenter[2] - offset[2];

    int entity = CreateLadderEntity(data);
    if (entity == -1)
    {
        PrintToChat(client, "%sFailed to create ladder.", CHAT_TAG);
        return;
    }

    int index = AddLadderConfig(data);
    if (index == -1)
    {
        RemoveEntity(entity);
        PrintToChat(client, "%sCannot save ladder (limit reached).", CHAT_TAG);
        return;
    }

    g_iAddEntRef[index] = EntIndexToEntRef(entity);
    g_iSelectedLadder[client] = EntIndexToEntRef(entity);
    PrintToChat(client, "%sLadder cloned and saved (#%d).", CHAT_TAG, index + 1);
}

void MoveSelectedToCrosshair(int client)
{
    int entity = GetSelectedEntity(client);
    if (entity == -1)
        return;

    if (!EnsureManagedLadder(client, entity))
        return;

    entity = GetSelectedEntity(client);
    if (entity == -1)
        return;

    float targetCenter[3];
    if (!GetAimPosition(client, targetCenter))
    {
        PrintToChat(client, "%sCannot find target position.", CHAT_TAG);
        return;
    }

    float center[3];
    float origin[3];
    GetLadderCenter(entity, center);
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);

    float offset[3];
    offset[0] = center[0] - origin[0];
    offset[1] = center[1] - origin[1];
    offset[2] = center[2] - origin[2];

    origin[0] = targetCenter[0] - offset[0];
    origin[1] = targetCenter[1] - offset[1];
    origin[2] = targetCenter[2] - offset[2];
    TeleportEntity(entity, origin, NULL_VECTOR, NULL_VECTOR);

    UpdateManagedLadder(entity);
    PrintToChat(client, "%sMoved ladder to target.", CHAT_TAG);
}

void NudgeSelected(int client, float x, float y, float z)
{
    int entity = GetSelectedEntity(client);
    if (entity == -1)
        return;

    if (!EnsureManagedLadder(client, entity))
        return;

    entity = GetSelectedEntity(client);
    if (entity == -1)
        return;

    float origin[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
    origin[0] += x;
    origin[1] += y;
    origin[2] += z;
    TeleportEntity(entity, origin, NULL_VECTOR, NULL_VECTOR);

    UpdateManagedLadder(entity);
}

void RotateSelected(int client, const float delta[3])
{
    int entity = GetSelectedEntity(client);
    if (entity == -1)
        return;

    if (!EnsureManagedLadder(client, entity))
        return;

    entity = GetSelectedEntity(client);
    if (entity == -1)
        return;

    float origin[3];
    float angles[3];
    float normal[3];
    float center[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
    GetEntPropVector(entity, Prop_Send, "m_angRotation", angles);
    GetEntPropVector(entity, Prop_Send, "m_climbableNormal", normal);
    GetLadderCenter(entity, center);

    angles[0] += delta[0];
    angles[1] += delta[1];
    angles[2] += delta[2];

    float newOrigin[3];
    ComputeOriginForCenter(entity, center, angles, newOrigin);
    TeleportEntity(entity, newOrigin, angles, NULL_VECTOR);

    float rotatedNormal[3];
    Math_RotateVector(normal, delta, rotatedNormal);
    SetEntPropVector(entity, Prop_Send, "m_climbableNormal", rotatedNormal);

    UpdateManagedLadder(entity);
}

void ShowSizeMenu(int client)
{
    Menu menu = new Menu(SizeMenuHandler);
    char title[64];
    Format(title, sizeof(title), "Resize Height (step %.1f)", g_fSizeStep[client]);
    menu.SetTitle(title);
    menu.AddItem("h+", "Height +");
    menu.AddItem("h-", "Height -");
    menu.AddItem("step+", "Step +2.0");
    menu.AddItem("step-", "Step -2.0");
    menu.AddItem("back", "Back to main");
    menu.ExitButton = true;
    menu.ExitBackButton = false;
    menu.Display(client, MENU_TIME_FOREVER);
    g_iLastMenuAction[client] = 3;
}

int SizeMenuHandler(Menu menu, MenuAction action, int client, int index)
{
    if (action == MenuAction_End)
    {
        delete menu;
        if (g_iLastMenuAction[client] == 3)
            g_bMenuOpen[client] = false;
        return 0;
    }
    
    if (action != MenuAction_Select)
        return 0;

    char info[16];
    menu.GetItem(index, info, sizeof(info));

    if (StrEqual(info, "back"))
    {
        ShowMainMenu(client);
        return 0;
    }

    if (StrEqual(info, "step+"))
    {
        g_fSizeStep[client] += 2.0;
    }
    else if (StrEqual(info, "step-"))
    {
        g_fSizeStep[client] = FloatMaxCustom(1.0, g_fSizeStep[client] - 2.0);
    }
    else
    {
        float heightDelta = 0.0;
        if (StrEqual(info, "h+")) heightDelta = g_fSizeStep[client];
        if (StrEqual(info, "h-")) heightDelta = -g_fSizeStep[client];

        if (heightDelta != 0.0)
        {
            ResizeSelected(client, heightDelta);
        }
    }

    ShowSizeMenu(client);
    return 0;
}

void ResizeSelected(int client, float heightDelta)
{
    int entity = GetSelectedEntity(client);
    if (entity == -1)
        return;

    if (!EnsureManagedLadder(client, entity))
        return;

    entity = GetSelectedEntity(client);
    if (entity == -1)
        return;

    float mins[3];
    float maxs[3];
    float center[3];
    float angles[3];
    GetEntPropVector(entity, Prop_Send, "m_vecMins", mins);
    GetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxs);
    GetLadderCenter(entity, center);
    GetEntPropVector(entity, Prop_Send, "m_angRotation", angles);

    // Zmieniamy tylko wysokość (Z axis)
    mins[2] += heightDelta * 0.5;
    maxs[2] += heightDelta * 0.5;

    if (mins[2] >= maxs[2])
    {
        PrintToChat(client, "%sCannot resize: height would be invalid.", CHAT_TAG);
        return;
    }

    // Ustawiamy mins/maxs w obu miejscach (Send i Data)
    SetEntPropVector(entity, Prop_Send, "m_vecMins", mins);
    SetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxs);
    SetEntPropVector(entity, Prop_Data, "m_vecMins", mins);
    SetEntPropVector(entity, Prop_Data, "m_vecMaxs", maxs);

    // Obliczamy nowy origin na podstawie zachowanego center i nowych mins/maxs
    float newOrigin[3];
    ComputeOriginForCenter(entity, center, angles, newOrigin);
    
    // Teleportujemy entity z nowym originem
    TeleportEntity(entity, newOrigin, NULL_VECTOR, NULL_VECTOR);
    
    // Aktualizujemy collision box
    SetEntPropVector(entity, Prop_Send, "m_vecMins", mins);
    SetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxs);
    SetEntPropVector(entity, Prop_Data, "m_vecMins", mins);
    SetEntPropVector(entity, Prop_Data, "m_vecMaxs", maxs);

    UpdateManagedLadder(entity);
}


void DeleteSelected(int client)
{
    int entity = GetSelectedEntity(client);
    if (entity == -1)
        return;

    int slot = GetManagedSlotByEntity(entity);
    if (slot != -1)
    {
        RemoveManagedLadder(slot);
        g_iSelectedLadder[client] = INVALID_ENT_REFERENCE;
        PrintToChat(client, "%sLadder deleted.", CHAT_TAG);
        return;
    }

    LadderData data;
    float center[3];
    GetLadderData(entity, data, center);
    if (AddRemoveConfig(data))
    {
        RemoveEntity(entity);
        g_iSelectedLadder[client] = INVALID_ENT_REFERENCE;
        PrintToChat(client, "%sOriginal ladder removed and saved.", CHAT_TAG);
    }
    else
    {
        PrintToChat(client, "%sFailed to save removal (limit reached).", CHAT_TAG);
    }
}

void ReloadFromConfig(int client)
{
    ResetState();
    LoadConfig();
    PrintToChat(client, "%sReloaded ladders from config.", CHAT_TAG);
}

void PrintLadderList(int client)
{
    int count = 0;
    float center[3];

    for (int i = 0; i < g_iAddCount; i++)
    {
        if (!IsValidEntRef(g_iAddEntRef[i]))
            continue;

        int entity = EntRefToEntIndex(g_iAddEntRef[i]);
        GetLadderCenter(entity, center);
        PrintToChat(client, "%s#%d: %.1f %.1f %.1f", CHAT_TAG, i + 1, center[0], center[1], center[2]);
        count++;
    }

    PrintToChat(client, "%sTotal ladders: %d.", CHAT_TAG, count);
}

// ====================================================================================================
//                                     CONFIG HANDLING
// ====================================================================================================
void LoadConfig()
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), CONFIG_LADDERS);
    if (!FileExists(path))
        return;

    KeyValues kv = new KeyValues("ladders");
    if (!kv.ImportFromFile(path))
    {
        delete kv;
        return;
    }

    char map[64];
    GetCurrentMap(map, sizeof(map));
    if (!kv.JumpToKey(map))
    {
        delete kv;
        return;
    }

    g_iRemoveCount = LoadRemoveSection(kv, "remove");
    ApplyRemovals();

    g_iAddCount = LoadAddSection(kv, "add");
    for (int i = 0; i < g_iAddCount; i++)
    {
        int entity = CreateLadderEntity(g_AddData[i]);
        if (entity != -1)
            g_iAddEntRef[i] = EntIndexToEntRef(entity);
    }

    delete kv;
}

int LoadAddSection(KeyValues kv, const char[] section)
{
    if (!kv.JumpToKey(section))
        return 0;

    int count = kv.GetNum("num", 0);
    if (count > MAX_LADDERS)
        count = MAX_LADDERS;

    char indexStr[8];
    for (int i = 1; i <= count; i++)
    {
        IntToString(i, indexStr, sizeof(indexStr));
        if (!kv.JumpToKey(indexStr))
            continue;

        kv.GetString("model", g_AddData[i - 1].model, sizeof(g_AddData[i - 1].model));
        kv.GetVector("origin", g_AddData[i - 1].origin);
        kv.GetVector("angles", g_AddData[i - 1].angles);
        kv.GetVector("normal", g_AddData[i - 1].normal);
        kv.GoBack();
    }

    kv.GoBack();
    return count;
}

int LoadRemoveSection(KeyValues kv, const char[] section)
{
    if (!kv.JumpToKey(section))
        return 0;

    int count = kv.GetNum("num", 0);
    if (count > MAX_REMOVES)
        count = MAX_REMOVES;

    char indexStr[8];
    for (int i = 1; i <= count; i++)
    {
        IntToString(i, indexStr, sizeof(indexStr));
        if (!kv.JumpToKey(indexStr))
            continue;

        kv.GetString("model", g_RemoveData[i - 1].model, sizeof(g_RemoveData[i - 1].model));
        kv.GetVector("origin", g_RemoveData[i - 1].origin);
        kv.GetVector("angles", g_RemoveData[i - 1].angles);
        kv.GetVector("normal", g_RemoveData[i - 1].normal);
        kv.GoBack();
    }

    kv.GoBack();
    return count;
}

int AddLadderConfig(const LadderData data)
{
    if (g_iAddCount >= MAX_LADDERS)
        return -1;

    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), CONFIG_LADDERS);
    EnsureConfigFile(path);

    KeyValues kv = new KeyValues("ladders");
    kv.ImportFromFile(path);

    char map[64];
    GetCurrentMap(map, sizeof(map));
    kv.JumpToKey(map, true);
    kv.JumpToKey("add", true);

    int count = kv.GetNum("num", 0);
    count++;
    kv.SetNum("num", count);

    char indexStr[8];
    IntToString(count, indexStr, sizeof(indexStr));
    kv.JumpToKey(indexStr, true);
    WriteLadderData(kv, data);

    kv.Rewind();
    kv.ExportToFile(path);
    delete kv;

    g_AddData[g_iAddCount] = data;
    g_iAddEntRef[g_iAddCount] = 0;
    g_iAddCount++;

    return count - 1;
}

bool UpdateLadderConfig(int slot, const LadderData data)
{
    if (slot < 0 || slot >= g_iAddCount)
        return false;

    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), CONFIG_LADDERS);
    EnsureConfigFile(path);

    KeyValues kv = new KeyValues("ladders");
    kv.ImportFromFile(path);

    char map[64];
    GetCurrentMap(map, sizeof(map));
    if (!kv.JumpToKey(map))
    {
        delete kv;
        return false;
    }

    if (!kv.JumpToKey("add"))
    {
        delete kv;
        return false;
    }

    char indexStr[8];
    IntToString(slot + 1, indexStr, sizeof(indexStr));
    if (!kv.JumpToKey(indexStr))
    {
        delete kv;
        return false;
    }

    WriteLadderData(kv, data);
    kv.Rewind();
    kv.ExportToFile(path);
    delete kv;

    g_AddData[slot] = data;
    return true;
}

bool RemoveLadderConfig(int slot)
{
    if (slot < 0 || slot >= g_iAddCount)
        return false;

    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), CONFIG_LADDERS);
    if (!FileExists(path))
        return false;

    KeyValues kv = new KeyValues("ladders");
    if (!kv.ImportFromFile(path))
    {
        delete kv;
        return false;
    }

    char map[64];
    GetCurrentMap(map, sizeof(map));
    if (!kv.JumpToKey(map) || !kv.JumpToKey("add"))
    {
        delete kv;
        return false;
    }

    int count = kv.GetNum("num", 0);
    if (count <= 0)
    {
        delete kv;
        return false;
    }

    char indexStr[8];
    bool moved = false;
    for (int i = slot + 1; i <= count; i++)
    {
        IntToString(i, indexStr, sizeof(indexStr));
        if (!kv.JumpToKey(indexStr))
        {
            kv.Rewind();
            kv.JumpToKey(map);
            kv.JumpToKey("add");
            continue;
        }

        if (!moved)
        {
            moved = true;
            kv.DeleteThis();
        }
        else
        {
            IntToString(i - 1, indexStr, sizeof(indexStr));
            kv.SetSectionName(indexStr);
        }

        kv.Rewind();
        kv.JumpToKey(map);
        kv.JumpToKey("add");
    }

    if (moved)
    {
        count--;
        kv.SetNum("num", count);
        kv.Rewind();
        kv.ExportToFile(path);
    }

    delete kv;
    return moved;
}

bool AddRemoveConfig(const LadderData data)
{
    if (g_iRemoveCount >= MAX_REMOVES)
        return false;

    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), CONFIG_LADDERS);
    EnsureConfigFile(path);

    KeyValues kv = new KeyValues("ladders");
    kv.ImportFromFile(path);

    char map[64];
    GetCurrentMap(map, sizeof(map));
    kv.JumpToKey(map, true);
    kv.JumpToKey("remove", true);

    int count = kv.GetNum("num", 0);
    count++;
    kv.SetNum("num", count);

    char indexStr[8];
    IntToString(count, indexStr, sizeof(indexStr));
    kv.JumpToKey(indexStr, true);
    WriteLadderData(kv, data);

    kv.Rewind();
    kv.ExportToFile(path);
    delete kv;

    g_RemoveData[g_iRemoveCount] = data;
    g_iRemoveCount++;
    return true;
}

void WriteLadderData(KeyValues kv, const LadderData data)
{
    kv.SetString("model", data.model);
    kv.SetVector("origin", data.origin);
    kv.SetVector("angles", data.angles);
    kv.SetVector("normal", data.normal);
}

void EnsureConfigFile(const char[] path)
{
    if (FileExists(path))
        return;

    File cfg = OpenFile(path, "w");
    if (cfg != null)
    {
        cfg.WriteLine("");
        delete cfg;
    }
}

void ApplyRemovals()
{
    if (g_iRemoveCount == 0)
        return;

    int entity = -1;
    char classname[64];
    while ((entity = FindEntityByClassname(entity, "func_simpleladder")) != -1)
    {
        if (!IsValidEntity(entity))
            continue;

        GetEntityClassname(entity, classname, sizeof(classname));
        if (!StrEqual(classname, "func_simpleladder"))
            continue;

        LadderData data;
        float center[3];
        GetLadderData(entity, data, center);

        for (int i = 0; i < g_iRemoveCount; i++)
        {
            if (IsRemovalMatch(data, g_RemoveData[i]))
            {
                AcceptEntityInput(entity, "Kill");
                break;
            }
        }
    }
}

bool IsRemovalMatch(const LadderData a, const LadderData b)
{
    if (!StrEqual(a.model, b.model, false))
        return false;

    if (FloatAbs(a.origin[0] - b.origin[0]) > ORIGIN_TOLERANCE) return false;
    if (FloatAbs(a.origin[1] - b.origin[1]) > ORIGIN_TOLERANCE) return false;
    if (FloatAbs(a.origin[2] - b.origin[2]) > ORIGIN_TOLERANCE) return false;
    if (FloatAbs(a.angles[0] - b.angles[0]) > ANGLE_TOLERANCE) return false;
    if (FloatAbs(a.angles[1] - b.angles[1]) > ANGLE_TOLERANCE) return false;
    if (FloatAbs(a.angles[2] - b.angles[2]) > ANGLE_TOLERANCE) return false;

    return true;
}

// ====================================================================================================
//                                     LADDER HELPERS
// ====================================================================================================
bool IsLadder(int entity)
{
    char classname[64];
    GetEntityClassname(entity, classname, sizeof(classname));
    return StrEqual(classname, "func_simpleladder", false);
}

int GetSelectedEntity(int client, bool showMessage = true)
{
    int entity = EntRefToEntIndex(g_iSelectedLadder[client]);
    if (entity == INVALID_ENT_REFERENCE || entity <= 0 || !IsValidEntity(entity))
    {
        if (showMessage && g_bMenuOpen[client])
        {
            PrintToChat(client, "%sNo ladder selected.", CHAT_TAG);
        }
        g_iSelectedLadder[client] = INVALID_ENT_REFERENCE;
        return -1;
    }
    return entity;
}

int GetManagedSlotByEntity(int entity)
{
    for (int i = 0; i < g_iAddCount; i++)
    {
        if (IsValidEntRef(g_iAddEntRef[i]) && EntRefToEntIndex(g_iAddEntRef[i]) == entity)
            return i;
    }
    return -1;
}

bool EnsureManagedLadder(int client, int entity)
{
    if (GetManagedSlotByEntity(entity) != -1)
        return true;

    LadderData data;
    float center[3];
    GetLadderData(entity, data, center);

    int addIndex = AddLadderConfig(data);
    if (addIndex == -1)
    {
        PrintToChat(client, "%sCannot save ladder (limit reached).", CHAT_TAG);
        return false;
    }

    if (!AddRemoveConfig(data))
    {
        RemoveLadderConfig(addIndex);
        if (g_iAddCount > 0)
        {
            g_iAddCount--;
            g_iAddEntRef[g_iAddCount] = 0;
        }
        PrintToChat(client, "%sCannot save removal (limit reached).", CHAT_TAG);
        return false;
    }

    int newEntity = CreateLadderEntity(data);
    if (newEntity == -1)
    {
        PrintToChat(client, "%sFailed to create ladder.", CHAT_TAG);
        return false;
    }

    RemoveEntity(entity);
    g_iAddEntRef[addIndex] = EntIndexToEntRef(newEntity);
    g_iSelectedLadder[client] = EntIndexToEntRef(newEntity);
    PrintToChat(client, "%sOriginal ladder converted to custom.", CHAT_TAG);
    return true;
}

void UpdateManagedLadder(int entity)
{
    int slot = GetManagedSlotByEntity(entity);
    if (slot == -1)
        return;

    LadderData data;
    float center[3];
    GetLadderData(entity, data, center);
    UpdateLadderConfig(slot, data);
}

void RemoveManagedLadder(int slot)
{
    if (slot < 0 || slot >= g_iAddCount)
        return;

    int entity = EntRefToEntIndex(g_iAddEntRef[slot]);
    int entityRef = g_iAddEntRef[slot];
    
    if (IsValidEntity(entity))
        RemoveEntity(entity);

    if (!RemoveLadderConfig(slot))
        return;

    // Clear selected ladder for all clients if this entity was selected
    for (int i = 1; i <= MaxClients; i++)
    {
        if (g_iSelectedLadder[i] == entityRef)
        {
            g_iSelectedLadder[i] = INVALID_ENT_REFERENCE;
        }
    }

    for (int i = slot; i < g_iAddCount - 1; i++)
    {
        g_AddData[i] = g_AddData[i + 1];
        g_iAddEntRef[i] = g_iAddEntRef[i + 1];
    }

    g_iAddEntRef[g_iAddCount - 1] = 0;
    g_iAddCount--;
}

int CreateLadderEntity(const LadderData data)
{
    int entity = CreateEntityByName("func_simpleladder");
    if (entity == -1)
        return -1;

    DispatchKeyValue(entity, "model", data.model);
    DispatchKeyValue(entity, "team", "2");

    char buf[32];
    Format(buf, sizeof(buf), "%.6f", data.normal[2]);
    DispatchKeyValue(entity, "normal.z", buf);
    Format(buf, sizeof(buf), "%.6f", data.normal[1]);
    DispatchKeyValue(entity, "normal.y", buf);
    Format(buf, sizeof(buf), "%.6f", data.normal[0]);
    DispatchKeyValue(entity, "normal.x", buf);

    DispatchSpawn(entity);
    TeleportEntity(entity, data.origin, data.angles, NULL_VECTOR);
    SetEntPropVector(entity, Prop_Send, "m_climbableNormal", data.normal);
    return entity;
}

void GetLadderData(int entity, LadderData data, float center[3])
{
    GetEntPropString(entity, Prop_Data, "m_ModelName", data.model, sizeof(data.model));
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", data.origin);
    GetEntPropVector(entity, Prop_Send, "m_angRotation", data.angles);
    GetEntPropVector(entity, Prop_Send, "m_climbableNormal", data.normal);
    GetLadderCenter(entity, center);
}

void GetLadderCenter(int entity, float center[3])
{
    float origin[3];
    float mins[3];
    float maxs[3];
    float angles[3];
    float rotMins[3];
    float rotMaxs[3];

    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
    GetEntPropVector(entity, Prop_Send, "m_vecMins", mins);
    GetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxs);
    GetEntPropVector(entity, Prop_Send, "m_angRotation", angles);

    Math_RotateVector(mins, angles, rotMins);
    Math_RotateVector(maxs, angles, rotMaxs);

    center[0] = origin[0] + (rotMins[0] + rotMaxs[0]) * 0.5;
    center[1] = origin[1] + (rotMins[1] + rotMaxs[1]) * 0.5;
    center[2] = origin[2] + (rotMins[2] + rotMaxs[2]) * 0.5;
}

void ComputeOriginForCenter(int entity, const float center[3], const float angles[3], float origin[3])
{
    float mins[3];
    float maxs[3];
    float rotMins[3];
    float rotMaxs[3];

    GetEntPropVector(entity, Prop_Send, "m_vecMins", mins);
    GetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxs);

    Math_RotateVector(mins, angles, rotMins);
    Math_RotateVector(maxs, angles, rotMaxs);

    origin[0] = center[0] - (rotMins[0] + rotMaxs[0]) * 0.5;
    origin[1] = center[1] - (rotMins[1] + rotMaxs[1]) * 0.5;
    origin[2] = center[2] - (rotMins[2] + rotMaxs[2]) * 0.5;
}

void PrintLadderInfo(int client, int entity, const char[] prefix)
{
    LadderData data;
    float center[3];
    GetLadderData(entity, data, center);
    PrintToChat(client, "%s%s ladder: model=%s center=(%.1f %.1f %.1f) origin=(%.1f %.1f %.1f)",
        CHAT_TAG, prefix, data.model, center[0], center[1], center[2], data.origin[0], data.origin[1], data.origin[2]);
}

bool GetAimPosition(int client, float pos[3])
{
    float start[3];
    float angle[3];
    GetClientEyePosition(client, start);
    GetClientEyeAngles(client, angle);

    Handle trace = TR_TraceRayFilterEx(start, angle, MASK_SOLID, RayType_Infinite, TraceFilterPlayers);
    if (TR_DidHit(trace))
    {
        TR_GetEndPosition(pos, trace);
        delete trace;
        return true;
    }

    delete trace;
    return false;
}

bool TraceFilterPlayers(int entity, int contentsMask)
{
    return entity > MaxClients || !entity;
}

bool IsValidEntRef(int entRef)
{
    return entRef && EntRefToEntIndex(entRef) != INVALID_ENT_REFERENCE;
}

float FloatMaxCustom(float a, float b)
{
    return (a > b) ? a : b;
}

// ====================================================================================================
//                                     MATH
// ====================================================================================================
stock void Math_RotateVector(const float vec[3], const float angles[3], float result[3])
{
    float rad[3];
    rad[0] = DegToRad(angles[2]);
    rad[1] = DegToRad(angles[0]);
    rad[2] = DegToRad(angles[1]);

    float cosAlpha = Cosine(rad[0]);
    float sinAlpha = Sine(rad[0]);
    float cosBeta = Cosine(rad[1]);
    float sinBeta = Sine(rad[1]);
    float cosGamma = Cosine(rad[2]);
    float sinGamma = Sine(rad[2]);

    float x = vec[0];
    float y = vec[1];
    float z = vec[2];
    float newX;
    float newY;
    float newZ;
    newY = cosAlpha * y - sinAlpha * z;
    newZ = cosAlpha * z + sinAlpha * y;
    y = newY;
    z = newZ;

    newX = cosBeta * x + sinBeta * z;
    newZ = cosBeta * z - sinBeta * x;
    x = newX;
    z = newZ;

    newX = cosGamma * x - sinGamma * y;
    newY = cosGamma * y + sinGamma * x;
    x = newX;
    y = newY;

    result[0] = x;
    result[1] = y;
    result[2] = z;
}
