extends Node
## Plays sounds by name: Audio.sfx("sfx_hit"). Finds .ogg or .wav in audio/sfx/.
## Music: Audio.music("music_city") loops with a short crossfade. Audio.music("") stops.

const POOL_SIZE := 16

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _cache := {}
var _music: AudioStreamPlayer
var _music_key := ""
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_music.finished.connect(func(): if _music_key != "": _music.play())


func _load(folder: String, key: String) -> AudioStream:
	var id := folder + key
	if _cache.has(id):
		return _cache[id]
	var stream: AudioStream = null
	for ext in [".ogg", ".wav"]:
		var path := "res://audio/%s/%s%s" % [folder, key, ext]
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	_cache[id] = stream
	return stream


func sfx(key: String, pitch_var := 0.08, volume_db := 0.0) -> void:
	var stream := _load("sfx", key)
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	p.play()


func music(key: String, fade := 0.8) -> void:
	if key == _music_key:
		return
	_music_key = key
	if is_instance_valid(_music_tween):
		_music_tween.kill()
	_music_tween = create_tween()
	if _music.playing:
		_music_tween.tween_property(_music, "volume_db", -40.0, fade * 0.5)
	_music_tween.tween_callback(func():
		_music.stop()
		if key == "":
			return
		_music.stream = _load("music", key)
		_music.volume_db = -40.0
		_music.play())
	if key != "":
		_music_tween.tween_property(_music, "volume_db", 0.0, fade)
