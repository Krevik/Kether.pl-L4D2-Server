#if defined _godframes_included
  #endinput
#endif
#define _godframes_included

/**
 * @brief		Forward when an invulnerable client is taking damage.
 * @brief		You can modify damage and return Plugin_Changed or Plugin_Handled etc like OnTakeDamage.
 *
 * @param		client			The client who is invulnerable.
 * @param		attacker		The attacker damaging the client.
 * @param		damage			Amount of damage being dealt.
 * @param		damagetype		Bitfield of damage types.
 * @return		Plugin_Changed to modify values or Plugin_Continue to continue without changes.
 */
forward Action OnTakeDamage_Invulnerable(int client, int attacker, float &damage, int &damagetype);