extends SceneTree

class Attacker:
    extends Node2D
    var hits: int = 0
    var last_amount: float = 0.0
    var last_source: Node
    var saw_marker: bool = false
    var bounce: bool = false
    func take_damage(amount: float, source: Node) -> void:
        hits += 1
        last_amount = amount
        last_source = source
        saw_marker = source.get_meta("reflecting", false)
        # Intentionally ignores the metadata protocol; cap only protects a failing test.
        if bounce and hits < 8:
            source.take_damage(int(amount), self)

var checks: int = 0
var failures: int = 0

func check(condition: bool, description: String) -> void:
    checks += 1
    if condition:
        print("PASS: " + description)
    else:
        failures += 1
        push_error("FAIL: " + description)

func _initialize() -> void:
    call_deferred("run_checks")

func mouse(button: MouseButton, pressed: bool) -> void:
    var event := InputEventMouseButton.new()
    event.button_index = button
    event.pressed = pressed
    event.position = Vector2(900, 360)
    Input.parse_input_event(event)

func block(held: bool) -> void:
    mouse(MOUSE_BUTTON_RIGHT, held)
    await process_frame

func frames(count: int) -> void:
    for i in count:
        await physics_frame

func run_checks() -> void:
    var player = load("res://scenes/player/player.tscn").instantiate()
    root.add_child(player)
    await process_frame
    player.set_physics_process(false)
    player.facing_direction = Vector2.RIGHT
    var sword = player.get_node("DivineSword")
    var shield = player.get_node("MirrorShield")
    sword.set_process(false)
    shield.set_process(false)
    var attacker := Attacker.new()
    root.add_child(attacker)
    attacker.position = Vector2(40, 0)
    attacker.add_to_group("enemies")

    check(player.reflect_power == 1.0, "reflection defaults to full returned damage")
    player.take_damage(20, attacker)
    check(player.health == 80.0 and attacker.hits == 0, "unshielded hit deals normal damage")
    player.health = 100.0
    await block(true)
    check(shield.is_held and shield.is_perfect() and not sword.attacks_enabled, "right press raises shield immediately")
    player.take_damage(20, attacker)
    check(player.health == 100.0 and attacker.hits == 1 and attacker.last_amount == 20.0, "perfect frontal hit is fully reflected")
    check(attacker.last_source == player and attacker.saw_marker, "reflection uses player source and metadata protocol")
    check(not player._reflecting and not player.has_meta("reflecting"), "reflection guard and marker restored")
    check(shield._flash_left > 0.0, "perfect hit starts white flash")

    var original_timer = shield._perfect_timer
    await create_timer(0.32).timeout
    check(not shield.is_perfect(), "perfect window expires while held")
    await block(true)
    check(shield._perfect_timer == original_timer and not shield.is_perfect(), "repeated held press never refreshes window")
    player.take_damage(20, attacker)
    check(is_equal_approx(player.health, 94.0) and attacker.hits == 1, "late block takes exactly 30 percent without reflection")
    var health_events: Array[float] = []
    player.health_changed.connect(func(current: float, _maximum: int): health_events.append(current))
    player.take_damage(1, attacker)
    check(is_equal_approx(player.health, 93.7) and is_equal_approx(health_events.back(), 93.7), "fractional blocked damage and health signal are preserved")

    await block(false)
    check(not shield.is_held and sword.attacks_enabled, "release drops shield and enables sword")
    await block(true)
    check(shield.is_perfect() and shield._perfect_timer != original_timer, "repress creates a fresh perfect window")
    player.reflect_power = 1.5
    player.take_damage(20, attacker)
    check(attacker.last_amount == 30.0, "reflection scales with reflect_power")

    player.health = 100.0
    attacker.position = Vector2(-40, 0)
    player.take_damage(20, attacker)
    check(player.health == 80.0, "rear hit bypasses perfect shield")
    attacker.position = Vector2.RIGHT.rotated(deg_to_rad(79)) * 40.0
    player.take_damage(20, attacker)
    check(player.health == 80.0, "79 degrees is within frontal 160-degree arc")
    attacker.position = Vector2.RIGHT.rotated(deg_to_rad(80)) * 40.0
    check(shield.blocks_source(attacker, Vector2.RIGHT), "positive 80-degree boundary is included")
    attacker.position = Vector2.RIGHT.rotated(deg_to_rad(-80)) * 40.0
    check(shield.blocks_source(attacker, Vector2.RIGHT), "negative 80-degree boundary is included")
    attacker.position = Vector2.RIGHT.rotated(deg_to_rad(-81)) * 40.0
    player.take_damage(20, attacker)
    check(player.health == 60.0, "81 degrees is outside frontal arc")
    shield._perfect_timer.time_left = 0.0
    attacker.position = Vector2(-40, 0)
    player.take_damage(20, attacker)
    check(player.health == 40.0, "rear hit also bypasses mature block")

    player.health = 100.0
    await block(false)
    await block(true)
    player.take_damage(10, null)
    var no_position := Node.new()
    root.add_child(no_position)
    player.take_damage(10, no_position)
    var freed := Node2D.new()
    freed.free()
    player.take_damage(10, freed)
    player.take_damage(10, 123)
    check(player.health == 60.0, "null, positionless, freed and non-object sources safely bypass shield")
    no_position.free()
    attacker.position = player.position
    player.take_damage(10, attacker)
    check(player.health == 50.0, "coincident source bypasses undefined direction")
    var no_damage_api := Node2D.new()
    root.add_child(no_damage_api)
    no_damage_api.position = Vector2(40, 0)
    player.take_damage(20, no_damage_api)
    check(player.health == 50.0, "positioned source without damage API is safely absorbed")
    shield._perfect_timer.time_left = 0.0
    player.take_damage(20, no_damage_api)
    check(player.health == 44.0, "positioned source without damage API receives normal block mitigation")
    no_damage_api.free()

    await block(false)
    await block(true)
    attacker.position = Vector2(40, 0)
    player.health = 100.0
    attacker.hits = 0
    attacker.bounce = true
    player.set_meta("reflecting", false)
    player.take_damage(20, attacker)
    check(attacker.hits == 1 and player.health == 100.0, "noncooperative reflecting attacker cannot recurse")
    check(player.has_meta("reflecting") and player.get_meta("reflecting") == false, "preexisting reflection marker is restored")
    player.remove_meta("reflecting")
    attacker.bounce = false
    attacker.set_meta("reflecting", true)
    player.take_damage(20, attacker)
    check(attacker.hits == 1 and player.health == 100.0, "incoming reflected hit is absorbed without rereflection")
    attacker.remove_meta("reflecting")

    var opponent = load("res://scenes/player/player.tscn").instantiate()
    root.add_child(opponent)
    opponent.set_physics_process(false)
    opponent.position = Vector2(40, 0)
    opponent.facing_direction = Vector2.LEFT
    opponent._set_shield_held(true)
    player.take_damage(20, opponent)
    check(player.health == 100.0 and opponent.health == 100.0, "two perfect shields terminate reflection safely")
    opponent.free()

    await block(false)
    sword._process(0.5)
    sword.try_attack(Vector2.RIGHT, player.damage, player)
    var slash_time: float = sword._slash_time_left
    var sword_cooldown: float = sword._cooldown_left
    await block(true)
    check(sword._slash_time_left == slash_time and sword._cooldown_left == sword_cooldown, "raising shield preserves existing swing and cooldown")
    sword._process(0.5)
    check(not sword.try_attack(Vector2.RIGHT, 20, player), "held shield prevents new sword attacks")
    mouse(MOUSE_BUTTON_LEFT, true)
    await process_frame
    check(not player._attack_requested, "left click while held is discarded")
    mouse(MOUSE_BUTTON_LEFT, false)
    await block(false)
    var previous_hits := attacker.hits
    mouse(MOUSE_BUTTON_LEFT, true)
    await process_frame
    player._update_facing()
    attacker.global_position = player.global_position + player.facing_direction * 40.0
    player._physics_process(1.0 / 60.0)
    check(attacker.hits == previous_hits + 1, "fresh sword click works after shield release")
    mouse(MOUSE_BUTTON_LEFT, false)

    player.facing_direction = Vector2.RIGHT
    player.reflect_power = 1.0
    var dummy = load("res://scenes/player/attacking_dummy.tscn").instantiate()
    root.add_child(dummy)
    dummy.position = Vector2(40, 0)
    await block(true)
    dummy._attack_left = 0.04
    await frames(5)
    check(player.health == 100.0 and dummy.health == 80.0, "simulated attacking dummy is reflected during window")
    await create_timer(0.32).timeout
    dummy._attack_left = 0.01
    await frames(3)
    check(player.health == 94.0 and dummy.health == 80.0, "dummy hit after window is mitigated")
    await block(false)
    dummy._attack_left = 0.01
    await frames(3)
    check(player.health == 74.0, "dummy hit after release deals full damage")
    dummy.free()

    await block(true)
    player.set_physics_process(true)
    Input.action_press("move_right")
    await frames(4)
    check(is_equal_approx(player.velocity.length(), 220.0), "movement remains available while blocking")
    check(is_equal_approx(shield.rotation, player.facing_direction.angle()), "shield follows mouse facing")
    var dash_event := InputEventKey.new()
    dash_event.physical_keycode = KEY_SPACE
    dash_event.pressed = true
    Input.parse_input_event(dash_event)
    await frames(3)
    check(player._dash_time_left > 0.0 and is_equal_approx(player.velocity.length(), 600.0) and shield.is_held, "dash remains available with shield held")
    dash_event.pressed = false
    Input.parse_input_event(dash_event)
    Input.action_release("move_right")
    player.set_physics_process(false)
    player._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
    check(not shield.is_held and sword.attacks_enabled, "focus loss safely releases shield")
    await block(true)
    attacker.global_position = player.global_position - player.facing_direction * 40.0
    player.take_damage(1000, attacker)
    check(player.health == 0.0 and not shield.is_held and not sword.attacks_enabled, "death lowers shield and disables attacks")
    await block(false)
    await block(true)
    check(not shield.is_held, "dead player cannot raise shield")
    await block(false)
    attacker.free()
    player.queue_free()
    await process_frame
    print("RESULT: %d shield checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
