extends Node3D

# Falls die Animationen im GLB anders heißen: Namen hier anpassen
# (stehen beim Spielstart in der Konsole unter "Animationen: ...").
const IDLE_ANIM := "Idle"
const WALK_ANIM := "Walk"

@onready var anim: AnimationPlayer = find_child("AnimationPlayer", true, false)
@onready var player: CharacterBody3D = get_parent()


func _ready() -> void:
	if anim == null:
		push_warning("Kein AnimationPlayer im Modell gefunden")
		return
	print("Animationen: ", anim.get_animation_list())
	# GLB-Animationen loopen oft nicht automatisch
	for n in [IDLE_ANIM, WALK_ANIM]:
		if anim.has_animation(n):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	if anim.has_animation(IDLE_ANIM):
		anim.play(IDLE_ANIM)


func _process(_delta: float) -> void:
	if anim == null:
		return
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > 0.2
	var wanted := WALK_ANIM if moving else IDLE_ANIM
	if anim.current_animation != wanted and anim.has_animation(wanted):
		anim.play(wanted, 0.2)
