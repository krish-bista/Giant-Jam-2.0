class_name ArtifactData
## Artifact table. Values match docs/balance/5_artifacts.tsv.

const ALL := {
	"edge_shard": {"name": "Edge Shard", "rarity": "common", "desc": "+3 damage", "mods": {"damage": 3.0}, "flag": ""},
	"heart_fragment": {"name": "Heart Fragment", "rarity": "common", "desc": "+25 max health", "mods": {"max_health": 25.0}, "flag": ""},
	"quick_sigil": {"name": "Quick Sigil", "rarity": "common", "desc": "+15% speed", "mods": {"speed": 33.0}, "flag": ""},
	"lucky_coin": {"name": "Lucky Coin", "rarity": "common", "desc": "+10 luck", "mods": {"luck": 10.0}, "flag": ""},
	"mirror_polish": {"name": "Mirror Polish", "rarity": "rare", "desc": "Reflected damage +50%", "mods": {"reflect_power": 0.5}, "flag": ""},
	"blood_echo": {"name": "Blood Echo", "rarity": "rare", "desc": "25% of damage taken heals back", "mods": {}, "flag": "heal_on_hurt"},
	"hypno_lens": {"name": "Hypno Lens", "rarity": "rare", "desc": "Hypno Reverse lasts +3s", "mods": {}, "flag": "long_hypno"},
	"echo_blade": {"name": "Echo Blade", "rarity": "rare", "desc": "Every 4th swing hits double", "mods": {}, "flag": "echo_blade"},
	"double_reflection": {"name": "Double Reflection", "rarity": "epic", "desc": "Reflected damage hits twice", "mods": {}, "flag": "double_reflect"},
	"glass_heart": {"name": "Glass Heart", "rarity": "epic", "desc": "+8 damage, -20 max health", "mods": {"damage": 8.0, "max_health": -20.0}, "flag": ""},
}

## Rarity weights per source: [common, rare, epic]
const WEIGHTS := {
	"enemy": [70.0, 25.0, 5.0],
	"chest": [50.0, 40.0, 10.0],
	"hunt": [0.0, 100.0, 0.0],
	"boss": [0.0, 60.0, 40.0],
}

static func icon_path(id: String) -> String:
	return "res://assets/ui/ui_artifact_%s.png" % id
