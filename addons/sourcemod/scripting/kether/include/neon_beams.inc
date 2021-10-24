#if defined _neon_beams_included
  #endinput
#endif
#define _neon_beams_included


/**
 * Returns the surface vPos and vAng of where the provided client is looking.
 *
 * @param userid		client userid to use their crosshair position
 * @param vAng			Angle float vector in radians
 * @param vPos			Position float vector
 *
 * @return				True on success, false if invalid position
 */
native bool NeonBeams_SetupPos(int userid, float vAng[3], float vPos[3]);


/**
 * Loads an ArrayList of formatted data at the specified angle and position.
 * Array format is the same as the preset configs format.
 *
 * Format:
 * "<int RGB color> <float vPos[0]> <float vPos[1]> <float vPos[2]> <float vPos2[0]> <float vPos2[1]> <float vPos2[2]>"
 * Example:
 * PushArrayString(aHand, "255 -0.002937 180.852661 -66.920837 0.017084 133.275146 -63.721679");
 *
 * @param ArrayList		Array list handle to load from
 * @param vAng			Angle float vector in radians
 * @param vPos			Position float vector
 *
 * @return				True on success, false if something went wrong, or plugin turned off.
 */
native bool NeonBeams_LoadArray(ArrayList aHand, float vAng[3], float vPos[3]);


/**
 * Load a temporary preset by name at specified position.
 *
 * @param name[64]		Name of preset to load
 * @param vAng			Angle float vector in radians
 * @param vPos			Position float vector
 *
 * @return				True on success, false if no preset was found, or plugin turned off.
 */
native bool NeonBeams_TempPre(char name[64], float vAng[3], float vPos[3]);


/**
 * Display a temporary beam between specified positions.
 *
 * @param color			RGB Hex color code (e.g 0x0000FF is blue)
 * @param vPos1			Starting vector position
 * @param vPos2			Ending vector position
 *
 * @return				True on success, false if plugin turned off.
 */
native bool NeonBeams_TempMap(int color, float vPos1[3], float vPos2[3], float time = 0.0);


/**
 * Display and save a beam to the map between specified positions.
 *
 * @param color			RGB Hex color code (e.g. 0x0000FF is blue)
 * @param vPos1			Starting vector position
 * @param vPos2			Ending vector position
 *
 * @return				True on success, false if plugin turned off.
 */
native bool NeonBeams_SaveMap(int color, float vPos1[3], float vPos2[3]);