#include <sourcescramble>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME "Custom ServerInfo Text"
#define PLUGIN_VERSION "1.0.0"

#define INFOTEXT_FILE "configs/infotext.txt"

public Plugin myinfo =
{
  name = PLUGIN_NAME,
  author = "ugng, Zabaniya001",
  description = "Replace the text sent to clients in CBaseClient::SendServerInfo",
  version = PLUGIN_VERSION,
  url = "https://osyu.sh/",
};

char g_sInfotext[2048];

public void OnPluginStart()
{
  CreateConVar("serverinfotext_version", PLUGIN_VERSION, PLUGIN_NAME ... " version", FCVAR_NOTIFY | FCVAR_DONTRECORD);

  char sPath[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, sPath, sizeof(sPath), INFOTEXT_FILE);

  File hFile = OpenFile(sPath, "r");
  if (hFile == INVALID_HANDLE)
    SetFailState("Infotext file not found");

  hFile.ReadString(g_sInfotext, sizeof(g_sInfotext));

  delete hFile;

  GameData hGameConf = new GameData("serverinfotext");

  MemoryPatch hPatchText = MemoryPatch.CreateFromConf(hGameConf, "CBaseClient::SendServerInfo::infotext");
  if (!hPatchText.Validate())
    SetFailState("Failed to validate CBaseClient::SendServerInfo::infotext");

  hPatchText.Enable();

  int iInstOffset = hGameConf.GetOffset("CBaseClient::SendServerInfo::infotext::inst");
  StoreToAddress(hPatchText.Address + view_as<Address>(iInstOffset), GetAddressOfString(g_sInfotext), NumberType_Int32);

  delete hGameConf;
}
