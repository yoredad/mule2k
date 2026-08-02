extends SceneTree

## Generates the raster launcher PNGs from the SVG masters.
## Run after a project import:
##   godot --headless --path . --script res://tools/generate_icons.gd

const SOURCE_MASTER := "res://assets/icons/yin_yang_icon.svg"
const SOURCE_FOREGROUND := "res://assets/icons/adaptive_foreground.svg"
const SOURCE_BACKGROUND := "res://assets/icons/adaptive_background.svg"
const SOURCE_MONOCHROME := "res://assets/icons/adaptive_monochrome.svg"

var failures: Array[String] = []


func _initialize() -> void:
	_generate(SOURCE_MASTER, "res://assets/icons/yin_yang_icon_1024.png", 1024, true)
	_generate(SOURCE_MASTER, "res://assets/icons/yin_yang_store_512.png", 512, true)
	_generate(SOURCE_MASTER, "res://assets/icons/android/yin_yang_main_192.png", 192, true)
	_generate(SOURCE_FOREGROUND, "res://assets/icons/android/yin_yang_foreground_432.png", 432, false)
	_generate(SOURCE_BACKGROUND, "res://assets/icons/android/yin_yang_background_432.png", 432, true)
	_generate(SOURCE_MONOCHROME, "res://assets/icons/android/yin_yang_monochrome_432.png", 432, false)
	if failures.is_empty():
		print("ALL ICONS GENERATED")
		quit(0)
	else:
		for failure in failures:
			print("FAIL: " + failure)
		quit(1)


func _generate(source_path: String, target_path: String, target_size: int, require_opaque: bool) -> void:
	var texture := load(source_path) as Texture2D
	if texture == null:
		failures.append("cannot load " + source_path)
		return
	var image := texture.get_image()
	if image == null:
		failures.append("cannot decode " + source_path)
		return
	if image.get_width() != target_size:
		image.resize(target_size, target_size, Image.INTERPOLATE_LANCZOS)
	var opaque := true
	var transparent := false
	var pixels := image.get_data()
	for i in range(0, pixels.size(), 4):
		if pixels[i + 3] < 255:
			opaque = false
		else:
			transparent = true
	if require_opaque and not opaque:
		failures.append("%s is not fully opaque" % target_path)
		return
	if not require_opaque and not transparent:
		failures.append("%s has no transparency" % target_path)
		return
	var dir := target_path.get_base_dir().trim_prefix("res://")
	if not DirAccess.dir_exists_absolute("res://" + dir):
		var maker := DirAccess.open("res://")
		if maker == null or maker.make_dir_recursive(dir) != OK:
			failures.append("cannot create directory " + dir)
			return
	if image.save_png("res://" + target_path.trim_prefix("res://")) != OK:
		failures.append("cannot write " + target_path)
		return
	print("  wrote " + target_path)
