class_name WeaponData
## One special weapon per world (on top of the Divine Sword). Use it with [F].
## You lose it when you enter another world; each world has its own, hidden somewhere.

const N := "res://assets/ninja/"

const ALL := {
	"flare_bow": {"name": "Flare Bow", "world": "world1", "desc": "Piercing arrows of light", "cooldown": 0.8,
		"sprite": N + "weapons/bow.png", "icon": "res://assets/ui/ui_icon_bow.png",
		"line": "A Flare Bow. Arrows made of light.", "color": Color(1.0, 0.85, 0.4)},
	"hunter_axe": {"name": "Hunter's Axe", "world": "world2", "desc": "A huge cleave that stuns", "cooldown": 1.3,
		"sprite": N + "weapons/axe.png", "icon": "res://assets/ui/ui_icon_axe.png",
		"line": "A Hunter's Axe. Heavy. Honest.", "color": Color(1.0, 0.6, 0.3)},
	"echo_wand": {"name": "Echo Wand", "world": "world3", "desc": "Homing shards from a dead future", "cooldown": 1.5,
		"sprite": N + "weapons/wand.png", "icon": "res://assets/ui/ui_icon_wand.png",
		"line": "An Echo Wand. It hums with a future that shouldn't exist.", "color": Color(0.8, 0.4, 1.0)},
}
