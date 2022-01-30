//to do: add action: "copy" files with timedate stamp or overwrite. Create native bool for checking a file with X days at X path. accept multiple extensions, separated by semicolon. "Rename" action.
#pragma semicolon 1
#pragma dynamic 131072 //increase stack space to from 4 kB to 131072 cells (or 512KB, a cell is 4 bytes).*/

#include <sourcemod>
#include <autoexecconfig>	//https://github.com/Impact123/AutoExecConfig or http://www.togcoding.com/showthread.php?p=1862459

#define PLUGIN_VERSION "4.4.0"
//#define DEGUGMODE ""	//uncomment this define to compile with debugging. Be sure to switch back to a compilation without debugging after you have finished your debug.

#pragma newdecls required

Handle g_hLog = null;
bool g_bLog;					//Enable logs

Handle hKeyValues = null;

char g_sCleanPath[PLATFORM_MAX_PATH];		//deleted files log file path
#if defined DEGUGMODE
char g_sDebugPath[PLATFORM_MAX_PATH];		//debug file path
#endif

public Plugin myinfo =
{
	name = "TOGs File Cleaner",
	author = "That One Guy",
	description = "Performs file actions for logs of a desired extension, filenames, and age at specified paths",
	version = PLUGIN_VERSION,
	url = "http://www.togcoding.com"
}

public void OnPluginStart()
{
	AutoExecConfig_SetFile("togfilecleaner");
	AutoExecConfig_CreateConVar("tfc_version", PLUGIN_VERSION, "TOGs File Cleaner: Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	g_hLog = AutoExecConfig_CreateConVar("tfc_log", "0", "Enables logging of files that actions are taken on.", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hLog, OnCVarChange);
	g_bLog = GetConVarBool(g_hLog);
	
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	//path builds
#if defined DEGUGMODE
	BuildPath(Path_SM, g_sDebugPath, sizeof(g_sDebugPath), "logs/togsfilecleanerdebug.log");
#endif
	BuildPath(Path_SM, g_sCleanPath, sizeof(g_sCleanPath), "logs/togsfilecleaner.log");
}

public void OnCVarChange(Handle hCVar, const char[] sOldValue, const char[] sNewValue)
{
	if(hCVar == g_hLog)
	{
		g_bLog = GetConVarBool(g_hLog);
	}
}

public void OnMapStart()
{
	RunSetups();
}

void RunSetups()
{
	char sCfgPath[256];
	BuildPath(Path_SM, sCfgPath, sizeof(sCfgPath), "configs/togfilecleaner.txt");
	
	if(!FileExists(sCfgPath))
	{
#if defined DEGUGMODE
		LogToFileEx(g_sDebugPath, "===================================================================================================================");
		LogToFileEx(g_sDebugPath, "==================================== File Not Found: %s ====================================", sCfgPath);
		LogToFileEx(g_sDebugPath, "===================================================================================================================");
#endif
		SetFailState("File Not Found: %s", sCfgPath);
		return;
	}
	
	hKeyValues = CreateKeyValues("Setups");
	
	if(!FileToKeyValues(hKeyValues, sCfgPath))
	{
		SetFailState("Improper structure for configuration file: %s", sCfgPath);
		CloseHandle(hKeyValues);
		return;
	}

#if defined DEGUGMODE
	LogToFileEx(g_sDebugPath, "File path for setups: %s", sCfgPath);
	LogToFileEx(g_sDebugPath, "------------------------------------------------------------------------------------------------------");
	LogToFileEx(g_sDebugPath, "Running setups.");
	LogToFileEx(g_sDebugPath, "");
#endif
	
	if(KvJumpToKey(hKeyValues, "SM Directory Setups"))
	{
		if(KvGotoFirstSubKey(hKeyValues))
		{
#if defined DEGUGMODE
			LogToFileEx(g_sDebugPath, "==============================================================================================================================");
			LogToFileEx(g_sDebugPath, "------------------------------------------------------------------------------------------------------------------------------");
			LogToFileEx(g_sDebugPath, "SM Setups config entered");
			LogToFileEx(g_sDebugPath, "------------------------------------------------------------------------------------------------------------------------------");
			LogToFileEx(g_sDebugPath, "==============================================================================================================================");
#endif
			
			do
			{
				char sSectionName[30];
				KvGetSectionName(hKeyValues, sSectionName, sizeof(sSectionName));
				if(!KvGetNum(hKeyValues, "enabled", 0))
				{
#if defined DEGUGMODE
					LogToFileEx(g_sDebugPath, "================================ Setup Ignored - enabled not set to 1: %s ================================", sSectionName);
					LogToFileEx(g_sDebugPath, "");
#endif
					continue;
				}
				
				char sBuffer[PLATFORM_MAX_PATH];
				Handle hDirectory = null;
				FileType type = FileType_Unknown;
				float fDaysOld;
				
				char sFolder[PLATFORM_MAX_PATH], sString[30], sExt[30], sExclude[30], sAction[30], sNewFilePath[PLATFORM_MAX_PATH];
				float fDays;
				int iCase;
				KvGetString(hKeyValues, "filepath", sFolder, sizeof(sFolder), "logs");
				fDays = KvGetFloat(hKeyValues, "days", 3.0);
				KvGetString(hKeyValues, "string", sString, sizeof(sString), "none");
				iCase = KvGetNum(hKeyValues, "case", 1);
				KvGetString(hKeyValues, "extension", sExt, sizeof(sExt), "any");
				KvGetString(hKeyValues, "exclude", sExclude, sizeof(sExclude), "");
				KvGetString(hKeyValues, "action", sAction, sizeof(sAction), "delete");
				KvGetString(hKeyValues, "newpath", sNewFilePath, sizeof(sNewFilePath), "none");
				
#if defined DEGUGMODE
				LogToFileEx(g_sDebugPath, "==============================================================================================================================");
				LogToFileEx(g_sDebugPath, "Setup: %s", sSectionName);
				LogToFileEx(g_sDebugPath, "==============================================================================================================================");
				LogToFileEx(g_sDebugPath, "Settings set as - filepath: %s, days: %f, string: %s, case: %i, extension: %s, exlude: %s", sFolder, fDays, sString, iCase, sExt, sExclude);
#endif

				BuildPath(Path_SM, sFolder, sizeof(sFolder), "%s", sFolder);

				if(DirExists(sFolder))
				{
#if defined DEGUGMODE
					LogToFileEx(g_sDebugPath, "Directory found for RunSetups(): %s", sFolder);
					LogToFileEx(g_sDebugPath, "");
					
					if(iCase)
					{
						LogToFileEx(g_sDebugPath, "Looking for files with string (case sensitive) and extensions, excluding files with string: '%s' and '%s', '%s'", sString, sExt, sExclude);
						LogToFileEx(g_sDebugPath, "");
					}
					else
					{
						LogToFileEx(g_sDebugPath, "Looking for files with string (case insensitive) and extensions, excluding files with string: '%s' and '%s', '%s'", sString, sExt, sExclude);
						LogToFileEx(g_sDebugPath, "");
					}
					LogToFileEx(g_sDebugPath, ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> File Search Beginning <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<");
#endif
					
					hDirectory = OpenDirectory(sFolder);
					if(hDirectory != null)
					{
						while(ReadDirEntry(hDirectory, sBuffer, sizeof(sBuffer), type))
						{
							if(type == FileType_File)
							{
								if(StrContains(sBuffer, sString, iCase ? true : false) != -1)
								{
#if defined DEGUGMODE
									LogToFileEx(g_sDebugPath, "File %s contains string %s (case sensitive = %i)", sBuffer, sString, iCase);
									LogToFileEx(g_sDebugPath, "");
#endif
									
									if((StrContains(sBuffer, sExt, false) != -1) || StrEqual(sExt, "any", false))
									{
#if defined DEGUGMODE
										LogToFileEx(g_sDebugPath, "File %s contains required extension: %s", sBuffer, sExt);
										LogToFileEx(g_sDebugPath, "");
#endif
										
										if((StrContains(sBuffer, sExclude, false) == -1) || StrEqual(sExclude, "", false))
										{
#if defined DEGUGMODE
											LogToFileEx(g_sDebugPath, "File %s excludes the string %s", sBuffer, sExclude);
											LogToFileEx(g_sDebugPath, "");
#endif
											
											char sDelFile[PLATFORM_MAX_PATH];
											Format(sDelFile, sizeof(sDelFile), "%s/%s", sFolder, sBuffer);
											fDaysOld = ((float(GetTime() - GetFileTime(sDelFile, FileTime_LastChange))/86400));
											
											if(GetFileTime(sDelFile, FileTime_LastChange) < (GetTime() - (86400 * RoundFloat(fDays)) + 30))
											{
												if(StrEqual(sAction, "delete", false))
												{
													DeleteFile(sDelFile);
													
#if defined DEGUGMODE
													LogToFileEx(g_sDebugPath, "File deleted: %s (%f days old)", sDelFile, fDaysOld);
													LogToFileEx(g_sDebugPath, "");
#endif
													
													if(g_bLog)
													{
														LogToFileEx(g_sCleanPath, "Cleared old file: %s (%f days old)", sDelFile, fDaysOld);
													}
												}
												else if(StrEqual(sAction, "move", false) && !StrEqual(sNewFilePath, "none", false))
												{
													char sMoveBuild[PLATFORM_MAX_PATH];
													BuildPath(Path_SM, sMoveBuild, sizeof(sMoveBuild), "%s",sNewFilePath);
													MoveFile(sFolder, sMoveBuild, sBuffer);
													
#if defined DEGUGMODE
													LogToFileEx(g_sDebugPath, "File moved: %s (%f days old) to %s", sDelFile, fDaysOld, sNewFilePath);
													LogToFileEx(g_sDebugPath, "");
#endif
													
													if(g_bLog)
													{
														LogToFileEx(g_sCleanPath, "Moved old file: %s (%f days old) to %s", sDelFile, fDaysOld, sNewFilePath);
													}
												}
												else if(StrEqual(sAction, "copy", false) && !StrEqual(sNewFilePath, "none", false))
												{
													char sMoveBuild[PLATFORM_MAX_PATH];
													BuildPath(Path_SM, sMoveBuild, sizeof(sMoveBuild), "%s",sNewFilePath);
													CopyFile_NotTxt_OverWriteExisting(sFolder, sMoveBuild, sBuffer);
													
#if defined DEGUGMODE
													LogToFileEx(g_sDebugPath, "File copied: %s (%f days old) to %s", sDelFile, fDaysOld, sNewFilePath);
													LogToFileEx(g_sDebugPath, "");
#endif
													
													if(g_bLog)
													{
														LogToFileEx(g_sCleanPath, "Copied old file: %s (%f days old) to %s", sDelFile, fDaysOld, sNewFilePath);
													}
												}
											}
											else
											{
#if defined DEGUGMODE
												LogToFileEx(g_sDebugPath, "File %s ignored - Not old enough: %f days old", sDelFile, fDaysOld);
												LogToFileEx(g_sDebugPath, "");
#endif
											}
										}
										else
										{
#if defined DEGUGMODE
											LogToFileEx(g_sDebugPath, "File %s ignored for containing string %s", sBuffer, sExclude);
											LogToFileEx(g_sDebugPath, "");
#endif
										}
									}
									else
									{
#if defined DEGUGMODE
										LogToFileEx(g_sDebugPath, "File %s ignored for not having required extension: %s", sBuffer, sExt);
										LogToFileEx(g_sDebugPath, "");
#endif
									}
								}
								else
								{
#if defined DEGUGMODE
									LogToFileEx(g_sDebugPath, "File %s ignored for not containing string %s (case sensitive = %i)", sBuffer, sString, iCase);
									LogToFileEx(g_sDebugPath, "");
#endif
								}
#if defined DEGUGMODE
								LogToFileEx(g_sDebugPath, "------------------------------------------------------ Next File -------------------------------------------------------------");
#endif
							}
						}
					}
					
#if defined DEGUGMODE
					LogToFileEx(g_sDebugPath, "---------------------------------------------------- File Search Complete ----------------------------------------------------");
#endif
				}
				
				if(hDirectory != null)
				{
					CloseHandle(hDirectory);
					hDirectory = null;
				}
			} while(KvGotoNextKey(hKeyValues, false));
			KvGoBack(hKeyValues);
		}
	}
	
	KvGoBack(hKeyValues);
	if(KvJumpToKey(hKeyValues, "Root Directory Setups"))
	{
		if(KvGotoFirstSubKey(hKeyValues))
		{
#if defined DEGUGMODE
			LogToFileEx(g_sDebugPath, "==============================================================================================================================");
			LogToFileEx(g_sDebugPath, "------------------------------------------------------------------------------------------------------------------------------");
			LogToFileEx(g_sDebugPath, "Root Setups config entered");
			LogToFileEx(g_sDebugPath, "------------------------------------------------------------------------------------------------------------------------------");
			LogToFileEx(g_sDebugPath, "==============================================================================================================================");
#endif
			
			do
			{
				char sSectionName[30];
				KvGetSectionName(hKeyValues, sSectionName, sizeof(sSectionName));
				if(!KvGetNum(hKeyValues, "enabled", 0))
				{
#if defined DEGUGMODE
					LogToFileEx(g_sDebugPath, "================================ Setup Ignored - enabled not set to 1: %s ================================", sSectionName);
					LogToFileEx(g_sDebugPath, "");
#endif
					continue;
				}
				
				char sBuffer[256];
				Handle hDirectory = null;
				FileType type = FileType_Unknown;
				float fDaysOld;
				
				char sRootFilePath[256], sString[30], sExt[30], sExclude[30], sRootAction[30], sNewRootFilePath[256];
				float fRootDays;
				int iRootCase;
				KvGetString(hKeyValues, "filepath", sRootFilePath, sizeof(sRootFilePath), "");
				fRootDays = KvGetFloat(hKeyValues, "days", 3.0);
				KvGetString(hKeyValues, "string", sString, sizeof(sString), "none");
				iRootCase = KvGetNum(hKeyValues, "case", 1);
				KvGetString(hKeyValues, "extension", sExt, sizeof(sExt), "any");
				KvGetString(hKeyValues, "exclude", sExclude, sizeof(sExclude), "");
				KvGetString(hKeyValues, "action", sRootAction, sizeof(sRootAction), "delete");
				KvGetString(hKeyValues, "newpath", sNewRootFilePath, sizeof(sNewRootFilePath), "none");

#if defined DEGUGMODE
				LogToFileEx(g_sDebugPath, "==============================================================================================================================");
				LogToFileEx(g_sDebugPath, "Setup: %s", sSectionName);
				LogToFileEx(g_sDebugPath, "==============================================================================================================================");
				LogToFileEx(g_sDebugPath, "Settings set as - filepath: %s, days: %f, string: %s, case: %i, extension: %s, exlude: %s", sRootFilePath, fRootDays, sString, iRootCase, sExt, sExclude);
#endif
				
				if(DirExists(sRootFilePath) || StrEqual(sRootFilePath, "", false))
				{
#if defined DEGUGMODE
					LogToFileEx(g_sDebugPath, "Directory found for RunSetups(): %s", sRootFilePath);
					LogToFileEx(g_sDebugPath, "");
					
					if(iRootCase)
					{
						LogToFileEx(g_sDebugPath, "Looking for files with string (case sensitive) and extensions, excluding files with string: '%s' and '%s', '%s'", sString, sExt, sExclude);
						LogToFileEx(g_sDebugPath, "");
					}
					else
					{
						LogToFileEx(g_sDebugPath, "Looking for files with string (case insensitive) and extensions, excluding files with string: '%s' and '%s', '%s'", sString, sExt, sExclude);
						LogToFileEx(g_sDebugPath, "");
					}
#endif

#if defined DEGUGMODE
					LogToFileEx(g_sDebugPath, ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> File Search Beginning <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<");
#endif
					hDirectory = OpenDirectory(sRootFilePath);
					if(hDirectory != null)
					{
						while(ReadDirEntry(hDirectory, sBuffer, sizeof(sBuffer), type))
						{
							if(type == FileType_File)
							{
								if(StrContains(sBuffer, sString, iRootCase ? true : false) != -1)
								{
#if defined DEGUGMODE
									LogToFileEx(g_sDebugPath, "File %s contains string %s (case sensitive = %i)", sBuffer, sString, iRootCase);
									LogToFileEx(g_sDebugPath, "");
#endif
									if((StrContains(sBuffer, sExt, false) != -1) || StrEqual(sExt, "any", false))
									{
#if defined DEGUGMODE
										LogToFileEx(g_sDebugPath, "File %s contains required extension: %s", sBuffer, sExt);
										LogToFileEx(g_sDebugPath, "");
#endif
										
										if((StrContains(sBuffer, sExclude, false) == -1) || StrEqual(sExclude, "", false))
										{
#if defined DEGUGMODE
											LogToFileEx(g_sDebugPath, "File %s excludes the string %s", sBuffer, sExclude);
											LogToFileEx(g_sDebugPath, "");
#endif
											
											char sDelFile[PLATFORM_MAX_PATH];
											Format(sDelFile, sizeof(sDelFile), "%s/%s", sRootFilePath, sBuffer);
											fDaysOld = ((float(GetTime() - GetFileTime(sDelFile, FileTime_LastChange)))/86400);
											if(GetFileTime(sDelFile, FileTime_LastChange) < (GetTime() - (86400 * RoundFloat(fRootDays)) + 30))
											{
												if(StrEqual(sRootAction, "delete", false))
												{
													DeleteFile(sDelFile);
													
#if defined DEGUGMODE
													LogToFileEx(g_sDebugPath, "File deleted: %s (%f days old)", sDelFile, fDaysOld);
													LogToFileEx(g_sDebugPath, "");
#endif
													
													if(g_bLog)
													{
														LogToFileEx(g_sCleanPath, "Cleared old file: %s (%f days old)", sDelFile, fDaysOld);
													}
												}
												else if(StrEqual(sRootAction, "move", false) && !StrEqual(sNewRootFilePath, "none", false))
												{
													MoveFile(sRootFilePath, sNewRootFilePath, sBuffer);

#if defined DEGUGMODE
													LogToFileEx(g_sDebugPath, "File moved: %s (%f days old) to %s", sDelFile, fDaysOld, sNewRootFilePath);
													LogToFileEx(g_sDebugPath, "");
#endif
													
													if(g_bLog)
													{
														LogToFileEx(g_sCleanPath, "Moved old file: %s (%f days old) to %s", sDelFile, fDaysOld, sNewRootFilePath);
													}
												}
												else if(StrEqual(sRootAction, "copy", false) && !StrEqual(sNewRootFilePath, "none", false))
												{
													CopyFile_NotTxt_OverWriteExisting(sRootFilePath, sNewRootFilePath, sBuffer);

#if defined DEGUGMODE
													LogToFileEx(g_sDebugPath, "File copied: %s (%f days old) to %s", sDelFile, fDaysOld, sNewRootFilePath);
													LogToFileEx(g_sDebugPath, "");
#endif
													
													if(g_bLog)
													{
														LogToFileEx(g_sCleanPath, "Copied old file: %s (%f days old) to %s", sDelFile, fDaysOld, sNewRootFilePath);
													}
												}
											}
											else
											{
#if defined DEGUGMODE
												LogToFileEx(g_sDebugPath, "File %s ignored - Not old enough: %f days old", sDelFile, fDaysOld);
												LogToFileEx(g_sDebugPath, "");
#endif
											}
										}
										else
										{
#if defined DEGUGMODE
											LogToFileEx(g_sDebugPath, "File %s ignored for containing string %s", sBuffer, sExclude);
											LogToFileEx(g_sDebugPath, "");
#endif
										}
									}
									else
									{
#if defined DEGUGMODE
										LogToFileEx(g_sDebugPath, "File %s ignored for not having required extension: %s", sBuffer, sExt);
										LogToFileEx(g_sDebugPath, "");
#endif
									}
								}
								else
								{
#if defined DEGUGMODE
									LogToFileEx(g_sDebugPath, "File %s ignored for not containing string %s (case sensitive = %i)", sBuffer, sString, iRootCase);
									LogToFileEx(g_sDebugPath, "");
#endif
								}
							}
#if defined DEGUGMODE
							LogToFileEx(g_sDebugPath, "------------------------------------------------------ Next File -------------------------------------------------------------");
#endif
						}
					}
					else
					{
#if defined DEGUGMODE
						LogToFileEx(g_sDebugPath, "Unable to open directory - bad handle for file path: %s", sRootFilePath);
						LogToFileEx(g_sDebugPath, "");
#endif
					}
						
#if defined DEGUGMODE
					LogToFileEx(g_sDebugPath, "---------------------------------------------------- File Search Complete ----------------------------------------------------");
#endif
				}
				else
				{
#if defined DEGUGMODE
					LogToFileEx(g_sDebugPath, "Directory does not exist: %s", sRootFilePath);
					LogToFileEx(g_sDebugPath, "");
#endif
				}
				
				if(hDirectory != null)
				{
					CloseHandle(hDirectory);
					hDirectory = null;
				}
			} while(KvGotoNextKey(hKeyValues, false));
			KvGoBack(hKeyValues);
		}
	}
	CloseHandle(hKeyValues);
}

bool CopyFile_NotTxt_OverWriteExisting(const char[] sStartPath, const char[] sEndPath, const char[] sFileName)
{
	char sFullFromPath[256], sFullToPath[256];
	Format(sFullFromPath, sizeof(sFullFromPath), "%s/%s", sStartPath, sFileName);
	Format(sFullToPath, sizeof(sFullToPath), "%s/%s", sEndPath, sFileName);
	
	if(!FileExists(sFullFromPath))
	{
		LogError("Could not find file '%s' for function CopyFile_NotTxt_OverWriteExisting()", sFullFromPath);
		return false;
	}

	int vBuffer[2][15000];
	
	Handle hFile = OpenFile(sFullFromPath, "r");
	Handle hFileTemp = OpenFile(sFullToPath, "w");
	
	if(hFile != null)
	{
		while(ReadFile(hFile, vBuffer[0], 1, 1))
		{
			WriteFile(hFileTemp, vBuffer[0], 1, 1);
		}
	}
	else
	{
		return false;
	}
	
	if(hFile != null)
	{
		CloseHandle(hFile);
	}
	if(hFileTemp != null)
	{
		CloseHandle(hFileTemp);
	}
	return true;
}

void MoveFile(const char[] sFromPath, const char[] sToPath, const char[] sFileName)
{
	char sFullFromPath[256];
	Format(sFullFromPath, sizeof(sFullFromPath), "%s/%s", sFromPath, sFileName);
	if(CopyFile_NotTxt_OverWriteExisting(sFromPath, sToPath, sFileName) == true)
	{
#if defined DEGUGMODE
		LogToFileEx(g_sDebugPath, "Deleting file after move: %s", sFullFromPath);
#endif
		DeleteFile(sFullFromPath);
	}
	else
	{
#if defined DEGUGMODE
		LogToFileEx(g_sDebugPath, "File move unsuccessful: %s", sFullFromPath);
#endif
	}
	return;
}

/*
///////////////////////////////////////////////////////////////////////////
//////////////////////////////// Changelog ////////////////////////////////
///////////////////////////////////////////////////////////////////////////

4.0:
	* Started Change log.
	* Coded in ability to move stuff, made days a float instead of an integer, gave option to accept "any" file extension
4.1:
	* Code updates.
4.2:
	* Code updated.
	* Changed debug mode to be upon compile only.
4.3
	* Cleanup.
4.4.0
	* Converted to new syntax. Did not convert to classes yet.
	* Fixed handling of setups with no/blank exclusion phrases.
*/
