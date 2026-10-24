class_name EnemyData
## Enemy and boss stats. Numbers follow docs/balance/2_enemies.tsv and 4_bosses.tsv.

const TYPES := {
	# Tutorial dummy: never dies, swings when the player is close (for block / reflect practice).
	"dummy": {"tex": "res://assets/enemies/tut_dummy.png", "hp": 30.0, "dmg": 12.0, "speed": 0.0,
		"range": 120.0, "cd": 2.2, "windup": 0.9, "radius": 16.0, "state": "idle", "immortal": true, "drops": false},
	"drone": {"tex": "res://assets/enemies/city_drone.png", "hp": 20.0, "dmg": 8.0, "speed": 115.0,
		"range": 34.0, "cd": 1.2, "windup": 0.45, "radius": 14.0, "state": "chase"},
	"gunner": {"tex": "res://assets/enemies/city_gunner.png", "hp": 25.0, "dmg": 10.0, "speed": 90.0,
		"range": 300.0, "cd": 2.2, "windup": 0.5, "radius": 14.0, "state": "chase", "ranged": true, "keep": 190.0},
	"raptor": {"tex": "res://assets/enemies/jungle_raptor.png", "hunter_tex": "res://assets/enemies/jungle_raptor_hunter.png",
		"hp": 30.0, "dmg": 10.0, "speed": 200.0, "flee_speed": 140.0, "range": 34.0, "cd": 0.9, "windup": 0.3,
		"radius": 14.0, "state": "flee"},
	"brute": {"tex": "res://assets/enemies/jungle_brute.png", "hp": 80.0, "dmg": 18.0, "speed": 150.0, "flee_speed": 75.0,
		"range": 46.0, "cd": 2.0, "windup": 0.7, "radius": 22.0, "state": "flee"},
	"construct": {"tex": "res://assets/enemies/core_construct.png", "hp": 35.0, "dmg": 12.0, "speed": 300.0,
		"range": 42.0, "cd": 1.1, "windup": 0.4, "radius": 15.0, "state": "mirror"},
}

const BOSSES := {
	"hypnotic": {"tex": "res://assets/bosses/city_hypno_boss.png", "name": "THE HYPNOTIC", "hp": 150.0, "dmg": 10.0,
		"speed": 85.0, "radius": 30.0, "cd": 2.4, "patterns": ["hypno_pulse", "volley", "volley"],
		"intro": "Look at me. Closer. ...Which way is up now?", "death": "You'll see it too. Soon.",
		"fixed_drop": "hypno_lens", "summon": []},
	"warden": {"tex": "res://assets/bosses/city_warden.png", "name": "THE WARDEN", "hp": 400.0, "dmg": 10.0,
		"speed": 95.0, "radius": 40.0, "cd": 2.0, "patterns": ["line", "volley", "charge"],
		"intro": "Hold the portal. Whatever it costs.", "death": "...It's already too late for us.",
		"summon": ["drone", "drone", "drone"]},
	"alpha_rex": {"tex": "res://assets/bosses/jungle_alpha_rex.png", "name": "ALPHA REX", "hp": 500.0, "dmg": 12.0,
		"speed": 125.0, "radius": 40.0, "cd": 1.8, "patterns": ["charge", "tail"], "swap_flee": true,
		"intro": "The jungle remembers its first intruder.", "death": "",
		"summon": ["raptor_hunter", "raptor_hunter"]},
	"sentinel": {"tex": "res://assets/bosses/core_sentinel.png", "name": "CORE SENTINEL", "hp": 550.0, "dmg": 12.0,
		"speed": 80.0, "radius": 40.0, "cd": 1.9, "patterns": ["ring", "circle_player", "volley"],
		"intro": "You again. You always come back.", "death": "We only wanted somewhere to run.",
		"summon": ["construct", "construct"]},
}
