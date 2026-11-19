#if defined __ksr_schema_included
	#endinput
#endif
#define __ksr_schema_included

void CreateTables()
{
	char query[4096];

	Format(query, sizeof(query),
		"CREATE TABLE IF NOT EXISTS players ("
		... "steamid TEXT PRIMARY KEY, "
		... "name TEXT NOT NULL DEFAULT '', "
		... "first_name TEXT NOT NULL DEFAULT '', "
		... "last_name TEXT NOT NULL DEFAULT '', "
		... "total_points REAL NOT NULL DEFAULT 0.0, "
		... "rounds_played INTEGER NOT NULL DEFAULT 0, "
		... "last_seen INTEGER NOT NULL DEFAULT (strftime('%%s', 'now'))"
		... ");");
	g_Db.Query(SQL_ErrorOnly, query);

	Format(query, sizeof(query),
		"CREATE TABLE IF NOT EXISTS round_stats ("
		... "id INTEGER PRIMARY KEY AUTOINCREMENT, "
		... "steamid TEXT NOT NULL, "
		... "name TEXT NOT NULL DEFAULT '', "
		... "round_index INTEGER NOT NULL, "
		... "map_name TEXT NOT NULL DEFAULT '', "
		... "team INTEGER NOT NULL DEFAULT 0, "
		... "raw_points REAL NOT NULL DEFAULT 0.0, "
		... "awarded_points REAL NOT NULL DEFAULT 0.0, "
		... "dmg_infected INTEGER NOT NULL DEFAULT 0, "
		... "dmg_survivor INTEGER NOT NULL DEFAULT 0, "
		... "dmg_tank INTEGER NOT NULL DEFAULT 0, "
		... "dmg_witch INTEGER NOT NULL DEFAULT 0, "
		... "common_kills INTEGER NOT NULL DEFAULT 0, "
		... "special_clears INTEGER NOT NULL DEFAULT 0, "
		... "self_clears INTEGER NOT NULL DEFAULT 0, "
		... "skeets INTEGER NOT NULL DEFAULT 0, "
		... "skeets_melee INTEGER NOT NULL DEFAULT 0, "
		... "deadstops INTEGER NOT NULL DEFAULT 0, "
		... "boomer_pops INTEGER NOT NULL DEFAULT 0, "
		... "boomer_pops_splash INTEGER NOT NULL DEFAULT 0, "
		... "pin_assists INTEGER NOT NULL DEFAULT 0, "
		... "pin_dps_assist REAL NOT NULL DEFAULT 0.0, "
		... "big_hit_assists INTEGER NOT NULL DEFAULT 0, "
		... "big_hit_assist_score REAL NOT NULL DEFAULT 0.0, "
		... "spit_ticks_pinned INTEGER NOT NULL DEFAULT 0, "
		... "spit_ticks_incap INTEGER NOT NULL DEFAULT 0, "
		... "tank_boom_assists INTEGER NOT NULL DEFAULT 0, "
		... "witch_assists INTEGER NOT NULL DEFAULT 0, "
		... "spit_setup_assists INTEGER NOT NULL DEFAULT 0, "
		... "boom_kill_assists INTEGER NOT NULL DEFAULT 0, "
		... "charger_multi INTEGER NOT NULL DEFAULT 0, "
		... "spit_multi_hits INTEGER NOT NULL DEFAULT 0, "
		... "shove_si INTEGER NOT NULL DEFAULT 0, "
		... "witch_crowns INTEGER NOT NULL DEFAULT 0, "
		... "rock_skeets INTEGER NOT NULL DEFAULT 0, "
		... "chain_clear_boom INTEGER NOT NULL DEFAULT 0, "
		... "safe_saves INTEGER NOT NULL DEFAULT 0, "
		... "zero_ff_bonus INTEGER NOT NULL DEFAULT 0, "
		... "shared_focus INTEGER NOT NULL DEFAULT 0, "
		... "boom_focus INTEGER NOT NULL DEFAULT 0, "
		... "stagger_setup INTEGER NOT NULL DEFAULT 0, "
		... "chain_control INTEGER NOT NULL DEFAULT 0, "
		... "tank_support INTEGER NOT NULL DEFAULT 0, "
		... "alarm_triggers INTEGER NOT NULL DEFAULT 0, "
		... "tank_hold_time REAL NOT NULL DEFAULT 0.0, "
		... "tank_passes INTEGER NOT NULL DEFAULT 0, "
		... "tank_kills INTEGER NOT NULL DEFAULT 0, "
		... "tank_wipe_bonus INTEGER NOT NULL DEFAULT 0, "
		... "charger_levels INTEGER NOT NULL DEFAULT 0, "
		... "tongue_cuts INTEGER NOT NULL DEFAULT 0, "
		... "special_shove_saves INTEGER NOT NULL DEFAULT 0, "
		... "rock_eaten_penalty INTEGER NOT NULL DEFAULT 0, "
		... "revive_interrupts INTEGER NOT NULL DEFAULT 0, "
		... "revives INTEGER NOT NULL DEFAULT 0, "
		... "medkit_gives INTEGER NOT NULL DEFAULT 0, "
		... "special_rescues INTEGER NOT NULL DEFAULT 0, "
		... "jockey_blocks INTEGER NOT NULL DEFAULT 0, "
		... "tank_play_actions INTEGER NOT NULL DEFAULT 0, "
		... "ff_dealt INTEGER NOT NULL DEFAULT 0, "
		... "ff_taken INTEGER NOT NULL DEFAULT 0, "
		... "headshot_si INTEGER NOT NULL DEFAULT 0, "
		... "boomer_vomit_casts INTEGER NOT NULL DEFAULT 0, "
		... "boomer_vomit_hits INTEGER NOT NULL DEFAULT 0, "
		... "flow_percent REAL NOT NULL DEFAULT 0.0, "
		... "survival_time REAL NOT NULL DEFAULT 0.0, "
		... "alive_end INTEGER NOT NULL DEFAULT 0, "
		... "ts INTEGER NOT NULL DEFAULT (strftime('%%s', 'now'))"
		... ");");
	g_Db.Query(SQL_ErrorOnly, query);

	EnsureColumn("round_stats", "jockey_blocks", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "tank_play_actions", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "skeets_melee", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "boomer_pops_splash", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "pin_assists", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "big_hit_assists", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "big_hit_assist_score", "REAL NOT NULL DEFAULT 0.0");
	EnsureColumn("round_stats", "pin_dps_assist", "REAL NOT NULL DEFAULT 0.0");
	EnsureColumn("round_stats", "spit_ticks_pinned", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "spit_ticks_incap", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "tank_boom_assists", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "witch_assists", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "spit_setup_assists", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "boom_kill_assists", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "charger_multi", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "spit_multi_hits", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "shove_si", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "witch_crowns", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "rock_skeets", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "chain_clear_boom", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "safe_saves", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "zero_ff_bonus", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "shared_focus", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "boom_focus", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "stagger_setup", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "chain_control", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "tank_support", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "alarm_triggers", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "tank_hold_time", "REAL NOT NULL DEFAULT 0.0");
	EnsureColumn("round_stats", "tank_passes", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "tank_kills", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "tank_wipe_bonus", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "charger_levels", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "tongue_cuts", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "special_shove_saves", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "rock_eaten_penalty", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "revive_interrupts", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "ff_dealt", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "ff_taken", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "headshot_si", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "boomer_vomit_casts", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "boomer_vomit_hits", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "flow_percent", "REAL NOT NULL DEFAULT 0.0");
	EnsureColumn("round_stats", "survival_time", "REAL NOT NULL DEFAULT 0.0");
	EnsureColumn("round_stats", "alive_end", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "common_damage", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "witch_kills", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "scoring_version", "INTEGER NOT NULL DEFAULT 1");
	EnsureColumn("players", "first_name", "TEXT NOT NULL DEFAULT ''");
	EnsureColumn("players", "last_name", "TEXT NOT NULL DEFAULT ''");
	EnsureColumn("players", "rating", "REAL NOT NULL DEFAULT 0.0");
	EnsureColumn("players", "rating_rounds", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("players", "rating_surv", "REAL NOT NULL DEFAULT 0.0");
	EnsureColumn("players", "rating_surv_rounds", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("players", "rating_inf", "REAL NOT NULL DEFAULT 0.0");
	EnsureColumn("players", "rating_inf_rounds", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "rating_z", "REAL NOT NULL DEFAULT 0.0");
	EnsureColumn("round_stats", "death_charges", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "hunter_pounce_dmg", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "jockey_high_pounces", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "dmg_as_tank", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "inf_incaps", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "inf_kills", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "pins_landed", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "got_skeeted", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "got_deadstopped", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "got_popped", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "got_leveled", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "got_tongue_cut", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "dmg_smoker", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "dmg_boomer", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "dmg_hunter", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "dmg_spitter", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "dmg_jockey", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "dmg_charger", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "spawns_smoker", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "spawns_boomer", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "spawns_hunter", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "spawns_spitter", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "spawns_jockey", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "spawns_charger", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "dmg_si_upright", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "dmg_on_incapped", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "dmg_tank_upright", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "tank_lives", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "tank_dmg_rel", "REAL NOT NULL DEFAULT 0.0");
	EnsureColumn("round_stats", "kill_flow_denied", "REAL NOT NULL DEFAULT 0.0");
	EnsureColumn("round_stats", "incaps_taken", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "end_standing", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "end_perm_hp", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "end_temp_hp", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "end_medkit", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "end_pills", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "half_index", "INTEGER NOT NULL DEFAULT -1");
	EnsureColumn("round_stats", "half_max_score", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "half_bonus", "REAL NOT NULL DEFAULT 0.0");
	EnsureColumn("round_stats", "half_tank_passes", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "half_tank_kills", "INTEGER NOT NULL DEFAULT 0");
	EnsureColumn("round_stats", "half_witch_bonus", "INTEGER NOT NULL DEFAULT 0");

	Format(query, sizeof(query),
		"CREATE TABLE IF NOT EXISTS baselines ("
		... "team INTEGER PRIMARY KEY, "
		... "mean REAL NOT NULL DEFAULT 0.0, "
		... "sd REAL NOT NULL DEFAULT 1.0, "
		... "samples INTEGER NOT NULL DEFAULT 0"
		... ");");
	g_Db.Query(SQL_ErrorOnly, query);

	// Which scoring version the stored baselines describe. A baseline is the mean and
	// spread of raw round scores, so it is only meaningful for the weights that
	// produced it: load one from another version and every z-score is off until
	// the rolling average has crawled over to the new distribution.
	Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL DEFAULT '');");
	g_Db.Query(SQL_ErrorOnly, query);

	Format(query, sizeof(query), "UPDATE players SET first_name = CASE WHEN first_name='' THEN name ELSE first_name END;");
	g_Db.Query(SQL_ErrorOnly, query);
	Format(query, sizeof(query), "UPDATE players SET last_name = CASE WHEN last_name='' THEN name ELSE last_name END;");
	g_Db.Query(SQL_ErrorOnly, query);
}
