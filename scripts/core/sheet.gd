class_name Sheet
## Builds SpriteFrames from the Ninja Adventure sheets (cached).
## Character sheets: Walk.png is 4 columns (down, up, left, right) x 4 frames; Idle/Attack are 4 x 1.
## Monster sheets: one 4x4 image with the same layout.

const N := "res://assets/ninja/"
const DIRS := ["down", "up", "left", "right"]

## FX strips: name -> [frames, fps]
const FX := {
	"slash_arc": [6, 24], "slash_01": [5, 24], "slash_circular": [7, 22], "circular_slash": [4, 18],
	"slash_curved": [4, 20], "cut_x": [4, 20], "explosion": [9, 20], "shield_blue": [6, 18],
	"shield_yellow": [6, 18], "spark": [10, 24], "circle_white": [4, 16], "circle_spark": [6, 18],
	"aura": [5, 12], "smoke": [6, 14], "smoke_circular": [8, 16], "thunder": [8, 18],
	"energy_ball": [4, 12], "energy_ball_pink": [4, 12], "big_energy_ball": [4, 12],
	"big_energy_ball_purple": [4, 12], "fireball": [4, 12],
}

static var _cache := {}


static func dir_of(v: Vector2) -> String:
	if v.length_squared() < 0.0001:
		return "down"
	if absf(v.x) > absf(v.y):
		return "right" if v.x > 0.0 else "left"
	return "down" if v.y > 0.0 else "up"


static func _region(tex: Texture2D, x: int, y: int, w: int, h: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(x, y, w, h)
	return a


## Single horizontal strip -> one animation called "default".
static func strip(path: String, frames: int, fps := 12.0, loop := false) -> SpriteFrames:
	var key := "strip:%s:%d:%s" % [path, frames, loop]
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = load(path)
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", fps)
	sf.set_animation_loop("default", loop)
	var fw := int(tex.get_width() / frames)
	for i in frames:
		sf.add_frame("default", _region(tex, i * fw, 0, fw, tex.get_height()))
	_cache[key] = sf
	return sf


static func fx(name: String, loop := false) -> SpriteFrames:
	var d: Array = FX.get(name, [4, 12])
	return strip(N + "fx/%s.png" % name, d[0], d[1], loop)


## Character: walk_<dir>, idle_<dir>, attack_<dir>
static func character(base: String) -> SpriteFrames:
	var key := "char:" + base
	if _cache.has(key):
		return _cache[key]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var walk: Texture2D = load(base + "_walk.png")
	var idle: Texture2D = load(base + "_idle.png")
	var attack: Texture2D = load(base + "_attack.png") if ResourceLoader.exists(base + "_attack.png") else idle
	for i in 4:
		var d: String = DIRS[i]
		sf.add_animation("walk_" + d)
		sf.set_animation_speed("walk_" + d, 9.0)
		for f in 4:
			sf.add_frame("walk_" + d, _region(walk, i * 16, f * 16, 16, 16))
		sf.add_animation("idle_" + d)
		sf.add_frame("idle_" + d, _region(idle, i * 16, 0, 16, 16))
		sf.add_animation("attack_" + d)
		sf.set_animation_loop("attack_" + d, false)
		sf.add_frame("attack_" + d, _region(attack, i * 16, 0, 16, 16))
	_cache[key] = sf
	return sf


## Monster 4x4 sheet: walk_<dir> and idle_<dir>
static func monster(path: String) -> SpriteFrames:
	var key := "mon:" + path
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = load(path)
	var fw := int(tex.get_width() / 4)
	var fh := int(tex.get_height() / 4)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for i in 4:
		var d: String = DIRS[i]
		sf.add_animation("walk_" + d)
		sf.set_animation_speed("walk_" + d, 8.0)
		for f in 4:
			sf.add_frame("walk_" + d, _region(tex, i * fw, f * fh, fw, fh))
		sf.add_animation("idle_" + d)
		sf.add_frame("idle_" + d, _region(tex, i * fw, 0, fw, fh))
		sf.add_animation("attack_" + d)
		sf.add_frame("attack_" + d, _region(tex, i * fw, fh, fw, fh))
	_cache[key] = sf
	return sf


## Boss: several strips with frame counts -> animations named after the strip.
static func boss(base: String, anims: Dictionary) -> SpriteFrames:
	var key := "boss:" + base
	if _cache.has(key):
		return _cache[key]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim in anims:
		var path := "%s_%s.png" % [base, anim]
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		var info: Array = anims[anim]
		var frames: int = info[0]
		var fw := int(tex.get_width() / frames)
		sf.add_animation(anim)
		sf.set_animation_speed(anim, info[1])
		sf.set_animation_loop(anim, info[2] if info.size() > 2 else true)
		for i in frames:
			sf.add_frame(anim, _region(tex, i * fw, 0, fw, tex.get_height()))
	_cache[key] = sf
	return sf


static func sprite_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://assets/shaders/sprite_fx.gdshader")
	return m


static func light_texture() -> Texture2D:
	if _cache.has("light"):
		return _cache.light
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	_cache.light = t
	return t


static func make_light(color: Color, energy := 1.0, scale := 1.0) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_texture()
	l.color = color
	l.energy = energy
	l.texture_scale = scale
	l.blend_mode = Light2D.BLEND_MODE_ADD
	return l
