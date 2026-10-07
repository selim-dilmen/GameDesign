extends Node3D
# Level 1 – "Die offensichtliche Lösung ist falsch"
#
# Das Bean-Kind liegt im Bett, aber es ist zu hell.
# Der offensichtliche Lichtschalter schaltet nur die Nachttischlampe an (noch heller!).
# Lösung: Den versteckten Stock hinter dem Schrank holen und dem Schalter einen Schlag
# verpassen -> Kurzschluss, Lampe kaputt, Licht aus. Danach das Kind zudecken.
# Gesteuert wird alles mit Linksklick in der Nähe der Dinge.

const REACH_BED := 3.2
const REACH_SWITCH := 2.2
const REACH_STICK := 1.6

const AMBIENT_BRIGHT := 1.0
const AMBIENT_DARK := 0.3
const MOON_DARK := 0.45

const HINT_STICK_AFTER := 100.0
const HINT_SWITCH_AFTER := 60.0

@onready var player: CharacterBody3D = $Player
@onready var carry_bone: Node3D = $Player/CarryBone
@onready var held_stick: MeshInstance3D = $Player/CarryBone/StickHeld
@onready var spring_arm: SpringArm3D = $Player/CameraOrigin/SpringArm3D

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var moon: DirectionalLight3D = $Moonlight
@onready var window_glass: MeshInstance3D = $Room/WindowGlass

@onready var ceiling_bulb: MeshInstance3D = $CeilingLamp/Bulb
@onready var ceiling_light: OmniLight3D = $CeilingLamp/Light

@onready var table_lamp: Node3D = $TableLamp
@onready var table_shade: MeshInstance3D = $TableLamp/Shade
@onready var table_light: OmniLight3D = $TableLamp/Light

@onready var switch_node: Node3D = $Switch
@onready var switch_toggle: MeshInstance3D = $Switch/Toggle
@onready var spark_light: OmniLight3D = $Switch/SparkLight

@onready var stick: Node3D = $Stick
@onready var bed: Node3D = $Bed
@onready var blanket: MeshInstance3D = $Bed/Blanket
@onready var eye_left: MeshInstance3D = $Bed/Child/Body/EyeLeft
@onready var eye_right: MeshInstance3D = $Bed/Child/Body/EyeRight
@onready var zzz: Label3D = $Zzz

@onready var message_label: Label = $CanvasLayer/HUD/MessageLabel
@onready var crosshair: Label = $CanvasLayer/HUD/Crosshair
@onready var finish_panel: PanelContainer = $CanvasLayer/FinishPanel
@onready var finish_label: Label = $CanvasLayer/FinishPanel/MarginContainer/VBoxContainer/FinishLabel
@onready var main_menu_button: Button = $CanvasLayer/FinishPanel/MarginContainer/VBoxContainer/MainMenuButton
@onready var next_level_button: Button = $CanvasLayer/FinishPanel/MarginContainer/VBoxContainer/NextLevelButton

var has_stick := false
var table_lamp_on := false
var lights_out := false
var tucked_in := false
var swinging := false
var switch_flipped := false
var switch_presses := 0
var bed_talks := 0
var hint_timer := 0.0
var hint_stage := 0
var message_id := 0


func _ready() -> void:
	spring_arm.add_excluded_object(player.get_rid())
	finish_panel.visible = false
	message_label.visible = false
	crosshair.visible = false
	held_stick.visible = false
	zzz.visible = false
	table_light.visible = false
	spark_light.light_energy = 0.0
	carry_bone.rotation_degrees.x = -20.0
	main_menu_button.pressed.connect(_go_to_main_menu)
	next_level_button.pressed.connect(_go_to_next_level)
	var env: Environment = world_env.environment
	env.ambient_light_energy = AMBIENT_BRIGHT
	moon.light_energy = 0.0
	show_message("Das Bean-Kind liegt im Bett und will schlafen.", 5.0)


func _process(delta: float) -> void:
	if tucked_in:
		return

	# Tipps, falls man nicht weiterkommt
	hint_timer += delta
	if hint_stage == 0 and not has_stick and hint_timer >= HINT_STICK_AFTER:
		hint_stage = 1
		show_message("Vielleicht liegt hinter einem der Möbel etwas Nützliches …", 6.0)
	elif hint_stage < 2 and has_stick and not lights_out and hint_timer >= HINT_SWITCH_AFTER:
		hint_stage = 2
		show_message("Dem Schalter sollte man mal ordentlich die Meinung sagen …", 6.0)

	# Der Punkt in der Bildschirmmitte leuchtet, wenn ein Klick etwas bewirkt
	crosshair.visible = _find_target() != ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_to_main_menu()
		return
	if tucked_in:
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_on_click()


# ---------------------------------------------------------------- Klick-Logik

func _on_click() -> void:
	var target := _find_target()
	if has_stick:
		if target == "bed":
			_tuck_in()
		else:
			_swing_stick()
		return
	match target:
		"bed":
			_talk_to_child()
		"switch":
			_use_switch()
		"stick":
			_pick_up_stick()


func _xz_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _find_target() -> String:
	var best := ""
	var best_ratio := INF
	var checks := [
		["bed", bed.global_position, REACH_BED, (not has_stick) or lights_out],
		["switch", switch_node.global_position, REACH_SWITCH, not lights_out],
		["stick", stick.global_position, REACH_STICK, not has_stick],
	]
	for c in checks:
		if not c[3]:
			continue
		var ratio: float = _xz_dist(player.global_position, c[1]) / c[2]
		if ratio < 1.0 and ratio < best_ratio:
			best = c[0]
			best_ratio = ratio
	return best


func show_message(text: String, duration: float = 4.0) -> void:
	message_id += 1
	var my_id := message_id
	message_label.text = text
	message_label.visible = true
	var t := create_tween()
	t.tween_interval(duration)
	t.tween_callback(func():
		if my_id == message_id:
			message_label.visible = false)


# ---------------------------------------------------------------- Das Kind

func _talk_to_child() -> void:
	if lights_out:
		_tuck_in()
		return
	bed_talks += 1
	if table_lamp_on:
		show_message("Kind: „Aaah, jetzt ist es NOCH heller! Mach das aus!“", 4.5)
		return
	var lines: Array[String] = [
		"Kind: „Es ist zu hell … ich kann so nicht einschlafen.“",
		"Kind: „Bitte mach das Licht aus!“",
		"Kind: „Es ist immer noch viel zu hell …“",
	]
	show_message(lines[mini(bed_talks - 1, lines.size() - 1)], 4.5)


# ---------------------------------------------------------------- Schalter (Falle)

func _use_switch() -> void:
	switch_presses += 1
	switch_flipped = not switch_flipped
	var t := create_tween()
	t.tween_property(switch_toggle, "position:y", -0.05 if switch_flipped else 0.05, 0.08)

	table_lamp_on = not table_lamp_on
	_set_table_lamp(table_lamp_on)

	if table_lamp_on:
		show_message("Klick! Die Nachttischlampe geht an.", 3.0)
		var c := create_tween()
		c.tween_interval(1.8)
		c.tween_callback(_child_complains_about_lamp)
	else:
		show_message("Klick. Die Nachttischlampe geht wieder aus – im Zimmer bleibt es trotzdem hell.", 4.5)

	if switch_presses == 5 and hint_stage == 0:
		show_message("Der Schalter ist wohl nicht die Lösung … aber irgendwie muss das Licht doch ausgehen.", 5.0)


func _child_complains_about_lamp() -> void:
	if table_lamp_on and not lights_out:
		show_message("Kind: „Aaah! Noch heller! Mach das aus!“", 4.0)


func _set_table_lamp(on: bool) -> void:
	table_light.visible = on
	var mat := table_shade.material_override as StandardMaterial3D
	if mat:
		mat.emission_enabled = on


# ---------------------------------------------------------------- Stock

func _pick_up_stick() -> void:
	has_stick = true
	hint_timer = 0.0
	stick.visible = false
	held_stick.visible = true
	var t := create_tween()
	t.tween_property(carry_bone, "rotation_degrees:x", -70.0, 0.15)
	t.tween_property(carry_bone, "rotation_degrees:x", -20.0, 0.2)
	show_message("Ein stabiler Stock. Damit kann man bestimmt ordentlich zuschlagen.", 5.0)


func _swing_stick() -> void:
	if swinging:
		return
	swinging = true
	var t := create_tween()
	t.tween_property(carry_bone, "rotation_degrees:x", 55.0, 0.12)
	t.tween_property(carry_bone, "rotation_degrees:x", -85.0, 0.10)
	t.tween_callback(_check_hit)
	t.tween_property(carry_bone, "rotation_degrees:x", -20.0, 0.25)
	t.tween_callback(func(): swinging = false)


func _check_hit() -> void:
	if lights_out:
		return
	var to_switch := switch_node.global_position - player.global_position
	to_switch.y = 0.0
	if to_switch.length() > REACH_SWITCH + 0.2:
		return
	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	if forward.normalized().dot(to_switch.normalized()) < 0.1:
		return
	_break_lamp()


# ---------------------------------------------------------------- Kurzschluss

func _break_lamp() -> void:
	lights_out = true
	crosshair.visible = false
	_spawn_sparks()

	# Blitz am Schalter, Schalter hängt schief
	spark_light.light_energy = 8.0
	var flash := create_tween()
	flash.tween_property(spark_light, "light_energy", 0.0, 0.3)
	switch_toggle.position.y = -0.05

	# Nachttischlampe geht aus und kippt um
	_set_table_lamp(false)
	var fall := create_tween()
	fall.tween_property(table_lamp, "rotation_degrees:z", 80.0, 0.45) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	# Deckenlicht flackert und geht aus
	var flicker := create_tween()
	flicker.tween_property(ceiling_light, "light_energy", 0.6, 0.07)
	flicker.tween_property(ceiling_light, "light_energy", 2.0, 0.07)
	flicker.tween_property(ceiling_light, "light_energy", 0.3, 0.10)
	flicker.tween_property(ceiling_light, "light_energy", 0.0, 0.15)
	flicker.tween_callback(_ceiling_off)

	# Zimmer wird dunkel, aber man sieht noch etwas (Mondlicht)
	var env: Environment = world_env.environment
	var window_mat := window_glass.material_override as StandardMaterial3D
	var dark := create_tween().set_parallel(true)
	dark.tween_property(env, "ambient_light_energy", AMBIENT_DARK, 1.0)
	dark.tween_property(moon, "light_energy", MOON_DARK, 1.0)
	if window_mat:
		dark.tween_property(window_mat, "emission_energy_multiplier", 3.0, 1.0)

	show_message("Funken! Die Lampe ist kaputt – und im ganzen Zimmer geht das Licht aus.", 4.5)
	var talk := create_tween()
	talk.tween_interval(4.8)
	talk.tween_callback(_child_after_dark)


func _ceiling_off() -> void:
	ceiling_light.visible = false
	var mat := ceiling_bulb.material_override as StandardMaterial3D
	if mat:
		mat.emission_enabled = false
		mat.albedo_color = Color(0.25, 0.25, 0.2)


func _child_after_dark() -> void:
	if not tucked_in:
		show_message("Kind: „Endlich dunkel … Kannst du mich zudecken?“", 6.0)


func _spawn_sparks() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.3)
	mat.emission_energy_multiplier = 4.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 0.05)
	for i in 10:
		var s := MeshInstance3D.new()
		s.mesh = mesh
		s.material_override = mat
		switch_node.add_child(s)
		s.position = Vector3(0.1, 0.0, 0.0)
		var dir := Vector3(randf_range(0.3, 1.0), randf_range(-0.4, 0.8), randf_range(-0.8, 0.8))
		var t := create_tween().set_parallel(true)
		t.tween_property(s, "position", s.position + dir * 0.9, 0.5).set_ease(Tween.EASE_OUT)
		t.tween_property(s, "scale", Vector3.ZERO, 0.5)
		t.chain().tween_callback(s.queue_free)


# ---------------------------------------------------------------- Zudecken / Ende

func _tuck_in() -> void:
	tucked_in = true
	player.can_control = false
	player.velocity = Vector3.ZERO
	crosshair.visible = false
	held_stick.visible = false

	var b := create_tween().set_parallel(true)
	b.tween_property(blanket, "position", Vector3(0.0, 1.025, 0.4), 1.4).set_trans(Tween.TRANS_SINE)
	b.tween_property(blanket, "scale", Vector3.ONE, 1.4).set_trans(Tween.TRANS_SINE)

	show_message("Du deckst das Kind liebevoll zu …", 3.0)

	var s := create_tween()
	s.tween_interval(1.6)
	s.tween_callback(_child_falls_asleep)
	s.tween_interval(3.2)
	s.tween_callback(_finish_level)


func _child_falls_asleep() -> void:
	show_message("Kind: „Danke … gute Nacht.“", 4.0)
	var e := create_tween().set_parallel(true)
	e.tween_property(eye_left, "scale:y", 0.1, 0.8)
	e.tween_property(eye_right, "scale:y", 0.1, 0.8)
	zzz.visible = true
	var base_y := zzz.position.y
	var bob := create_tween().set_loops()
	bob.tween_property(zzz, "position:y", base_y + 0.4, 1.4)
	bob.tween_property(zzz, "position:y", base_y, 1.4)


func _finish_level() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	finish_label.text = "Level 1 geschafft!"
	finish_panel.visible = true


func _go_to_main_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://MainMenu.tscn")


func _go_to_next_level() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://Levels/Level_2.tscn")
