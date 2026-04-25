extends Camera3D

# Cámara cercana en tercera persona.
# Sigue principalmente el avance del jugador y suaviza el movimiento lateral
# para que no se mueva demasiado al ir a la izquierda o derecha.

@export var target_path: NodePath
@export var follow_speed: float = 10.0
@export var offset: Vector3 = Vector3(0, 3.9, 6.25)
@export var look_ahead: Vector3 = Vector3(0, 1.05, -1.85)
@export var lateral_follow_factor: float = 0.22
@export var lateral_look_factor: float = 0.35

var target: Node3D = null
var base_x: float = 0.0

func _ready() -> void:
	if target_path != NodePath(""):
		target = get_node(target_path) as Node3D
	base_x = global_position.x
	current = true
	fov = 58.0

func _process(delta: float) -> void:
	if target == null:
		return

	var desired_position: Vector3 = target.global_position + offset
	desired_position.x = base_x + target.global_position.x * lateral_follow_factor + offset.x
	global_position = global_position.lerp(desired_position, clamp(follow_speed * delta, 0.0, 1.0))

	var look_position: Vector3 = target.global_position + look_ahead
	look_position.x = target.global_position.x * lateral_look_factor
	look_at(look_position, Vector3.UP)
