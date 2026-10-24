extends SceneTree

class Target:
    extends Node2D
    var hits: int = 0
    var health: float = 100.0
    var last_source: Node
    func take_damage(amount: float, source: Node) -> void:
        hits += 1
        health -= amount
        last_source = source

var failures: int = 0
var checks: int = 0

func check(condition: bool, description: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("FAIL: " + description)
    else:
        print("PASS: " + description)

func _initialize() -> void:
    call_deferred("run_checks")

func frames(count: int) -> void:
    for i in count:
        await physics_frame

func mouse_button(pressed: bool) -> void:
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = pressed
    event.position = Vector2(900, 360)
    Input.parse_input_event(event)

func space(pressed: bool) -> void:
    var event := InputEventKey.new()
    event.physical_keycode = KEY_SPACE
    event.pressed = pressed
    Input.parse_input_event(event)

func run_checks() -> void:
    var scene: PackedScene = load("res://scenes/player/player_test_arena.tscn")
    check(scene != null, "arena parses")
    var arena = scene.instantiate()
    root.add_child(arena)
    await process_frame
    var player = arena.get_node("Player")
    var sword = player.get_node("DivineSword")
    var dummy = arena.get_node("TrainingDummy")
    player.set_physics_process(false)
    sword.set_process(false)
    check(player.damage == 20 and sword.attack_range == 65.0 and sword.arc_angle == 100.0,
        "damage, range and cone defaults")
    check(sword.cooldown == 0.4 and sword.slash_duration == 0.15, "cooldown and visual duration defaults")
    check(dummy.is_in_group("enemies") and dummy.health == 100.0, "dummy contract and HP")

    var positions: Array[Vector2] = [Vector2(65, 0), Vector2(65.1, 0),
        Vector2.RIGHT.rotated(deg_to_rad(49)) * 60,
        Vector2.RIGHT.rotated(deg_to_rad(-49)) * 60,
        Vector2.RIGHT.rotated(deg_to_rad(51)) * 60,
        Vector2.RIGHT.rotated(deg_to_rad(-51)) * 60, Vector2(-40, 0)]
    var targets: Array[Target] = []
    for offset in positions:
        var target := Target.new()
        arena.add_child(target)
        target.position = offset
        target.add_to_group("enemies")
        targets.append(target)
    player.add_to_group("enemies")
    check(sword.try_attack(Vector2.RIGHT, player.damage, player), "first swing succeeds")
    check(targets[0].health == 80.0, "65-pixel boundary hit uses player damage")
    check(targets[1].hits == 0, "beyond 65 pixels is excluded")
    check(targets[2].hits == 1 and targets[3].hits == 1, "both sides inside cone hit")
    check(targets[4].hits == 0 and targets[5].hits == 0 and targets[6].hits == 0, "outside cone and behind are excluded")
    check(targets[0].last_source == player, "damage source is the player")
    check(player.health == 100, "sword never damages its player")
    check(not sword.try_attack(Vector2.RIGHT, 20, player), "cooldown rejects immediate repeat")
    sword._process(0.2)
    check(targets[0].hits == 1 and sword._slash_time_left == 0.0, "one hit per target and slash ends")
    sword._process(0.19)
    check(not sword.try_attack(Vector2.RIGHT, 20, player), "cooldown rejects before 0.4 seconds")
    sword._process(0.02)
    sword.attacks_enabled = false
    check(not sword.try_attack(Vector2.RIGHT, 20, player), "blocking hook prevents attacks")
    sword.attacks_enabled = true
    check(sword.try_attack(Vector2.RIGHT, 20, player), "cooldown permits subsequent attack")
    for target in targets:
        target.free()
    player.remove_from_group("enemies")

    dummy.position = Vector2(40, 0)
    for hit in range(5):
        sword._process(0.41)
        sword.try_attack(Vector2.RIGHT, player.damage, player)
        check(dummy.health == 100.0 - 20.0 * (hit + 1), "dummy health after hit %d" % (hit + 1))
        if hit == 0:
            check(dummy.get_node("Visual").modulate.r == 1.0 and dummy.get_node("Visual").modulate.g < 0.2, "dummy flashes red")
    check(dummy.get_node("HealthLabel").text == "Defeated" and not dummy.is_in_group("enemies"), "five hits defeat and remove dummy from targets")

    var input_target := Target.new()
    arena.add_child(input_target)
    input_target.add_to_group("enemies")
    sword._process(0.41)
    mouse_button(true)
    await process_frame
    player._update_facing()
    input_target.global_position = player.global_position + player.facing_direction * 40.0
    player._physics_process(1.0 / 60.0)
    check(input_target.hits == 1, "left mouse input swings in current facing direction")
    sword._process(0.6)
    player._physics_process(1.0 / 60.0)
    check(input_target.hits == 1, "holding click does not repeat after cooldown")
    mouse_button(false)
    mouse_button(true)
    await process_frame
    player._update_facing()
    input_target.global_position = player.global_position + player.facing_direction * 40.0
    player._physics_process(1.0 / 60.0)
    check(input_target.hits == 2, "fresh click swings again")
    mouse_button(false)

    player.position = Vector2.ZERO
    player.set_physics_process(true)
    sword.set_process(true)
    Input.action_press("move_right")
    await frames(5)
    check(player.position.x > 0 and is_equal_approx(player.velocity.length(), 220.0), "WASD movement remains at 220")
    Input.action_press("move_down")
    await frames(3)
    check(is_equal_approx(player.velocity.length(), 220.0) and player.velocity.x > 0 and player.velocity.y > 0, "diagonal movement stays normalized")
    player.controls_reversed = true
    await frames(3)
    check(player.velocity.x < 0 and player.velocity.y < 0, "reversed controls still work")
    player.controls_reversed = false
    Input.action_release("move_down")
    player.position = Vector2(580, 100)
    await frames(20)
    check(player.position.x <= 594.1 and player.position.x >= 593.0, "walking collides with arena wall")

    player.position = Vector2(0, 160)
    var dash_starts: Array[Vector2] = []
    player.dash_started.connect(func(direction: Vector2): dash_starts.append(direction))
    space(true)
    await frames(3)
    check(dash_starts.size() == 1 and is_equal_approx(player.velocity.length(), 600.0), "Space dash still starts at 600")
    check(dash_starts[0].is_equal_approx(Vector2.RIGHT), "dash follows movement direction")
    space(false)
    sword._cooldown_left = 0.0
    mouse_button(true)
    player._update_facing()
    input_target.global_position = player.global_position + player.facing_direction * 40.0
    await frames(2)
    check(input_target.hits == 3 and player._dash_time_left > 0.0, "sword works during dash")
    mouse_button(false)
    await frames(10)
    check(player._dash_time_left == 0.0 and is_equal_approx(player.velocity.length(), 220.0), "dash ends and normal movement resumes")
    space(true)
    await frames(2)
    check(dash_starts.size() == 1, "dash cooldown still rejects early press")
    space(false)
    await frames(50)
    player.position = Vector2(560, 100)
    space(true)
    await frames(10)
    check(dash_starts.size() == 2 and player.position.x <= 594.1, "dash cooldown recovers and dash respects walls")
    space(false)
    await frames(30)
    player.position = Vector2(0, 160)
    player._update_facing()
    input_target.global_position = player.global_position + player.facing_direction * 40.0
    mouse_button(true)
    await frames(2)
    check(input_target.hits == 4 and player.velocity.length() > 0.0, "sword works during normal movement")
    mouse_button(false)
    Input.action_release("move_right")
    print("RESULT: %d checks, %d failures" % [checks, failures])
    arena.queue_free()
    await process_frame
    quit(1 if failures else 0)
