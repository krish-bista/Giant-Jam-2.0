class_name EnemyData
## Enemy and boss stats. Numbers follow docs/balance/2_enemies.tsv and 4_bosses.tsv.
## "sheet" = 4x4 monster sheet, "char" = character folder prefix (Walk/Idle/Attack strips).

const N := "res://assets/ninja/"

const TYPES := {
	# Tutorial: a hologram knight that never dies and swings when the player is close.
	"dummy": {"char": N + "chars/holo", "hp": 30.0, "dmg": 12.0, "speed": 0.0, "range": 120.0, "cd": 2.2,
		"windup": 0.9, "radius": 16.0, "state": "idle", "immortal": true, "drops": false, "light": Color(0.4, 0.9, 1.0), "parry_cue": true},
	"drone": {"sheet": N + "enemies/eye.png", "hp": 34.0, "dmg": 10.0, "speed": 115.0, "range": 34.0, "cd": 1.2,
		"windup": 0.45, "radius": 14.0, "state": "chase", "float": true, "light": Color(0.7, 0.4, 1.0)},
	"gunner": {"sheet": N + "enemies/octopus.png", "hp": 40.0, "dmg": 12.0, "speed": 90.0, "range": 300.0, "cd": 1.9,
		"windup": 0.75, "radius": 14.0, "state": "chase", "ranged": true, "keep": 190.0, "light": Color(0.5, 1.0, 0.4)},
	"raptor": {"sheet": N + "enemies/trex.png", "hunter_sheet": N + "enemies/trex_red.png", "hp": 42.0, "dmg": 12.0,
		"speed": 200.0, "flee_speed": 140.0, "range": 34.0, "cd": 0.9, "windup": 0.3, "radius": 14.0, "state": "flee"},
	"brute": {"sheet": N + "enemies/bear.png", "hp": 120.0, "dmg": 20.0, "speed": 150.0, "flee_speed": 75.0,
		"range": 46.0, "cd": 2.0, "windup": 0.7, "radius": 22.0, "state": "flee", "scale": 4.0},
	# The Hollow Future (grim world): normal enemies
	"husk": {"char": N + "enemies/husk", "hp": 44.0, "dmg": 13.0, "speed": 125.0, "range": 34.0, "cd": 1.1,
		"windup": 0.4, "radius": 14.0, "state": "chase", "light": Color(0.5, 0.3, 0.7)},
	"wraith": {"sheet": N + "enemies/wraith.png", "hp": 34.0, "dmg": 11.0, "speed": 165.0, "range": 34.0, "cd": 1.0,
		"windup": 0.35, "radius": 13.0, "state": "chase", "float": true, "light": Color(0.7, 0.3, 1.0)},
	"seer": {"sheet": N + "enemies/seer.png", "hp": 40.0, "dmg": 13.0, "speed": 80.0, "range": 330.0, "cd": 2.4,
		"windup": 0.9, "radius": 14.0, "state": "chase", "ranged": true, "keep": 230.0, "float": true, "light": Color(1.0, 0.25, 0.3)},
	"hollow_brute": {"char": N + "enemies/brute_demon", "hp": 140.0, "dmg": 22.0, "speed": 95.0, "range": 46.0, "cd": 2.0,
		"windup": 0.8, "radius": 22.0, "state": "chase", "scale": 4.0, "light": Color(0.8, 0.2, 0.3)},
	"construct": {"char": N + "enemies/robot", "hp": 35.0, "dmg": 12.0, "speed": 300.0, "range": 42.0, "cd": 1.1,
		"windup": 0.4, "radius": 15.0, "state": "mirror", "light": Color(0.8, 0.3, 1.0)},
}

const BOSSES := {
	"hypnotic": {"name": "THE HYPNOTIC", "hp": 200.0, "dmg": 12.0, "speed": 85.0, "radius": 50.0, "cd": 2.4,
		"patterns": ["hypno_pulse", "volley", "volley"], "voice": "hypnotic",
		"intro": "Look at me. Closer. ...Which way is up now?", "death": "You'll see it too. Soon.",
		"fixed_drop": "hypno_lens", "summon": [], "face": N + "bosses/squid_face.png"},
	"warden": {"name": "THE WARDEN", "hp": 380.0, "dmg": 14.0, "speed": 95.0, "radius": 52.0, "cd": 2.0,
		"patterns": ["line", "volley", "charge"], "voice": "warden",
		"intro": "Hold the portal. Whatever it costs.", "death": "...It's already too late for us.",
		"summon": ["drone", "drone", "drone"], "face": N + "bosses/cyclops_face.png"},
	"alpha_rex": {"name": "THE ALPHA", "hp": 620.0, "dmg": 16.0, "speed": 125.0, "radius": 60.0, "cd": 1.8,
		"patterns": ["charge", "jump_slam", "tail"], "swap_flee": true, "voice": "",
		"intro": "The jungle remembers its first intruder.", "death": "",
		"summon": ["raptor_hunter", "raptor_hunter"], "face": N + "bosses/beast_face.png"},
	"sentinel": {"name": "CORE SENTINEL", "hp": 500.0, "dmg": 15.0, "speed": 210.0, "radius": 46.0, "cd": 1.9,
		"patterns": ["ring", "swoop", "circle_player", "volley"], "voice": "sentinel",
		"intro": "You again. You always come back.", "death": "We only wanted somewhere to run.",
		"summon": ["husk", "husk"], "face": N + "bosses/wyrm_faceset.png"},
}
