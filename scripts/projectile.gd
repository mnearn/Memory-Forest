extends Node3D

var main_ref: Node3D
var direction: Vector3 = Vector3.ZERO
var speed: float = 12.0
var damage: float = 10.0
var source_type: String = "enemy"

func init(_main_ref: Node3D, _source_type: String, _direction: Vector3, _damage: float) -> void:
    main_ref = _main_ref
    source_type = _source_type
    direction = _direction.normalized()
    damage = _damage

    var mesh = SphereMesh.new()
    mesh.radius = 0.2
    mesh.height = 0.4
    var mesh_instance = MeshInstance3D.new()
    mesh_instance.mesh = mesh
    add_child(mesh_instance)

    var material = StandardMaterial3D.new()
    material.albedo_color = Color(1.0, 0.35, 0.22) if source_type == "enemy" else Color(0.5, 1.0, 0.75)
    mesh_instance.material_override = material

func _physics_process(delta: float) -> void:
    if main_ref == null:
        queue_free()
        return

    position += direction * speed * delta

    if "player" in main_ref:
        var player = main_ref.player
        if is_instance_valid(player) and global_position.distance_to(player.global_position) < 1.25:
            if player.has_method("take_damage"):
                player.take_damage(damage, global_position)
            queue_free()
            return

    if global_position.length() > 60.0:
        queue_free()
