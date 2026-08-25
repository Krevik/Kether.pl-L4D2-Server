#if defined __ph_teams_included
	#endinput
#endif
#define __ph_teams_included

// Every connected human is a participant every round (Hunter or Prop) - there's no persistent
// "spectator" concept beyond a live caster_system registration, matching how the CS:GO Prop
// Hunt port treats its player pool.
bool PH_IsEligibleParticipant(int client)
{
	if (!IsClientInGame(client) || IsFakeClient(client))
		return false;

	if (GetFeatureStatus(FeatureType_Native, "IsClientCaster") == FeatureStatus_Available && IsClientCaster(client))
		return false;

	return true;
}

void PH_Teams_OnClientDisconnect(int client)
{
	g_iGuaranteedHunterTurns[client] = 0;
	g_bHunterVolunteer[client] = false;
	g_bWasHunterLastRound[client] = false;
}

void PH_Teams_ToggleVolunteer(int client)
{
	g_bHunterVolunteer[client] = !g_bHunterVolunteer[client];
	PrintHintText(client, "%t", g_bHunterVolunteer[client] ? "PropHunt_VolunteeredHunter" : "PropHunt_VolunteerCancelled");
}

// Fairness queue: volunteers whose guaranteed-Prop rounds have already expired go first, then
// whoever has waited the longest (lowest remaining guaranteed-turns-as-Prop), mirroring the
// CS:GO Prop Hunt port's rotation + the plan's "fairness counter plus a volunteer queue".
void PH_Teams_ComputeRoster()
{
	int candidates[MAXPLAYERS + 1];
	int numCandidates = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (PH_IsEligibleParticipant(i))
			candidates[numCandidates++] = i;
	}

	if (numCandidates == 0)
		return;

	int wantHunters = g_iCvarHunters;
	if (numCandidates <= wantHunters)
		wantHunters = (numCandidates > 1) ? numCandidates - 1 : numCandidates;
	if (wantHunters < 0)
		wantHunters = 0;

	bool used[MAXPLAYERS + 1];
	int numChosen = 0;

	for (int idx = 0; idx < numCandidates && numChosen < wantHunters; idx++)
	{
		int client = candidates[idx];
		if (g_bHunterVolunteer[client] && g_iGuaranteedHunterTurns[client] <= 0)
		{
			used[client] = true;
			numChosen++;
		}
	}

	while (numChosen < wantHunters)
	{
		int bestClient = -1;
		int bestTurns = 999999;

		for (int idx = 0; idx < numCandidates; idx++)
		{
			int client = candidates[idx];
			if (used[client])
				continue;

			if (g_iGuaranteedHunterTurns[client] < bestTurns)
			{
				bestTurns = g_iGuaranteedHunterTurns[client];
				bestClient = client;
			}
		}

		if (bestClient == -1)
			break;

		used[bestClient] = true;
		numChosen++;
	}

	for (int idx = 0; idx < numCandidates; idx++)
	{
		int client = candidates[idx];

		if (used[client])
		{
			if (GetClientTeam(client) != PH_TEAM_HUNTER)
				ChangeClientTeam(client, PH_TEAM_HUNTER);

			g_bWasHunterLastRound[client] = true;
			g_bHunterVolunteer[client] = false;
			g_iGuaranteedHunterTurns[client] = g_iCvarGuaranteedHunterTurns;
		}
		else
		{
			if (GetClientTeam(client) != PH_TEAM_PROP)
				ChangeClientTeam(client, PH_TEAM_PROP);

			g_bWasHunterLastRound[client] = false;
			if (g_iGuaranteedHunterTurns[client] > 0)
				g_iGuaranteedHunterTurns[client]--;
		}
	}
}
