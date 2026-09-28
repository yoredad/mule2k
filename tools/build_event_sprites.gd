extends SceneTree

const EVENTS: Array[String] = [
	"pirates", "sunspots", "acidrain", "pest",
	"meteorite", "fireinstore", "quake", "radiation",
]
const FRAME_RATE: float = 8.0

func _init() -> void:
	var failed := false
	for event_name in EVENTS:
		var dir_path := "res://assets/events/%s" % event_name
		var frames: Array = DirAccess.get_files_at(dir_path)
		frames = frames.filter(func(f: String): return f.begins_with("frame_") and f.ends_with(".png"))
		frames.sort()
		if frames.is_empty():
			push_error("no frames found for %s" % event_name)
			failed = true
			continue
		var sprite_frames := SpriteFrames.new()
		sprite_frames.set_animation_loop("default", true)
		sprite_frames.set_animation_speed("default", FRAME_RATE)
		for frame in frames:
			var texture := load(dir_path + "/" + frame) as Texture2D
			if texture == null:
				push_error("could not load texture %s/%s" % [dir_path, frame])
				failed = true
				break
			sprite_frames.add_frame("default", texture)
		if failed:
			continue
		var err := ResourceSaver.save(sprite_frames, dir_path + "/sprite_frames.tres")
		print("%s: %d frames at %s fps -> err %d" % [event_name, frames.size(), FRAME_RATE, err])
	quit(1 if failed else 0)
