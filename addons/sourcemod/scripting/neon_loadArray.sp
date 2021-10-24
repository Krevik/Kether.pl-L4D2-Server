#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <neon_beams>

#define LEN_FULL			128			// Max string length to store data etc.

public Plugin myinfo =
{
	name = "[ANY] Neon Beams - Test Arrays",
	author = "SilverShot",
	description = "Test plugin to spawn beams using an ArrayList of data.",
	version = "1.1-ta",
	url = "https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers"
}

public void OnPluginStart()
{
	RegAdminCmd("sm_neon_arr", sm_neon_arr, ADMFLAG_ROOT, "Preset spawn test");
}

public void OnAllPluginsLoaded()
{
	if( LibraryExists("neon_beams") == false )
	{
		SetFailState("Neon Beams plugin not been detected and is required.");
	}
}

public Action sm_neon_arr(int client, int args)
{
	// Each line represents 2 points to create 1 beam. Format: <int: RGB color value> <pointA XYZ vector> <pointB XYZ vector>
	// This is the same format as created by presets. You could create a preset and copy the data into here, or create custom math based vectors such as fractals!
	char sPositionsArray[][LEN_FULL] =
	{
		// First 2 entries usually contain the file path and file name.
		"",
		"",
		"255 0.000000 0.000000 -43.475341 0.000000 0.000000 0.000000",
		"255 0.000000 27.663574 -48.201171 0.000000 22.737060 -2.468505",
		"255 0.000000 26.840576 -23.807006 0.000000 4.041015 -25.210632",
		"255 0.000000 43.481445 -47.085815 0.000000 40.958007 -0.901550",
		"255 0.000000 79.385742 -47.457458 0.000000 43.481445 -47.085815",
		"255 0.000000 75.739990 -25.198242 0.000000 43.481445 -24.149536",
		"255 0.000000 82.145019 -5.464660 0.000000 41.798095 -1.729370",
		"255 0.000000 93.413574 -49.472106 0.000000 90.559814 -2.083862",
		"255 0.000000 133.285888 -50.443664 0.000000 93.413574 -49.472106",
		"255 0.000000 140.322753 -52.221618 0.000000 138.973632 -3.978332",
		"255 0.000000 172.118164 -51.687866 0.000000 140.322753 -52.221618",
		"255 0.000000 178.271728 -55.447326 0.000000 172.586914 -2.648986",
		"255 0.000000 220.199951 -56.673461 0.000000 178.271728 -55.447326",
		"255 0.000000 211.975830 -0.211608 0.000000 220.199951 -56.673461",
		"255 0.000000 172.586914 -3.107849 0.000000 211.405029 -0.214416",
		"16711680 0.000000 241.343505 -58.787841 0.000000 227.429199 -1.731262",
		"16711680 0.000000 257.026123 -23.194641 0.000000 242.397705 -58.139648",
		"16711680 0.000000 270.038818 -58.509094 0.000000 257.026123 -22.664001",
		"16711680 0.000000 281.090087 2.472900 0.000000 270.038818 -58.509094",
		"16711680 0.000000 286.968505 -58.741027 0.000000 289.667724 -0.139221",
		"16711680 0.000000 326.071533 -58.081909 0.000000 286.968505 -58.741027",
		"16711680 0.000000 322.347412 -0.035034 0.000000 326.071533 -58.081909",
		"16711680 0.000000 286.430908 -2.788146 0.000000 322.347412 -0.035034",
		"16711680 0.000000 337.438232 -58.416259 0.000000 335.221435 -1.538574",
		"16711680 0.000000 368.289794 -16.112731 0.000000 335.775634 0.235961",
		"16711680 0.000000 336.884033 -27.842834 0.000000 368.864990 -17.830261",
		"16711680 0.000000 373.499755 -55.975830 0.000000 336.329833 -27.842468",
		"16711680 0.000000 381.760009 -54.996887 0.000000 379.971923 4.817260",
		"16711680 0.000000 421.937255 -56.228759 0.000000 381.760009 -54.996887",
		"16711680 0.000000 430.709716 8.440612 0.000000 432.970458 -57.328002",
		"16711680 0.000000 472.072998 -23.440795 0.000000 430.709716 8.440612",
		"16711680 0.000000 434.494384 -57.395751 0.000000 473.036865 -23.385070",
		"65280 0.000000 480.651123 -66.504455 0.000000 -6.545654 -66.378112",
		"16711935 0.000000 520.003662 7.748901 0.000000 487.133056 6.397521",
		"16711935 0.000000 504.317138 -36.576477 0.000000 520.003662 7.748901",
		"16711935 0.000000 487.836669 5.710571 0.000000 504.317138 -38.017639",
		"16711935 0.000000 492.079345 -60.842529 0.000000 504.317138 -52.622741",
		"16711935 0.000000 521.537353 -61.431335 0.000000 492.079345 -61.588623",
		"16711935 0.000000 504.317138 -49.669677 0.000000 521.537353 -61.431335"
	};

	float vAng[3], vPos[3];

	// Spawn where we're aiming
	if( NeonBeams_SetupPos(GetClientUserId(client), vAng, vPos) )
	{
		// Store data in array
		ArrayList aHand = new ArrayList(ByteCountToCells(LEN_FULL));
		for( int i = 0; i < sizeof(sPositionsArray); i++ )
		{
			aHand.PushString(sPositionsArray[i]);
		}

		// Send array to main plugin and check response
		if( NeonBeams_LoadArray(aHand, vAng, vPos) )
		{
			PrintToChat(client, "[Neon Beams] Spawned array.");
		} else {
			PrintToChat(client, "[Neon Beams] Core plugin is been turned off.");
		}

		delete aHand;
	}

	return Plugin_Handled;
}

public bool TraceFilter(int entity, int contentsMask, any client)
{
	if( entity == client )
		return false;
	return true;
}