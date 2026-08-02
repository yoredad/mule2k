extends SceneTree

func _init() -> void:
	print("Starting icon generation...")
	
	# Create directories if they do not exist
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("res://assets/icons/android"):
		dir.make_dir_recursive("res://assets/icons/android")
	
	var err: Error
	
	# 1. yin_yang_icon_1024.png (1024x1024, opaque)
	var img_1024 := Image.load_from_file("res://assets/icons/yin_yang_icon.svg")
	if img_1024 != null:
		err = img_1024.save_png("res://assets/icons/yin_yang_icon_1024.png")
		if err == OK:
			print("Generated yin_yang_icon_1024.png")
		else:
			print("Failed to save yin_yang_icon_1024.png: ", err)
	else:
		print("Failed to load yin_yang_icon.svg")
	
	# 2. yin_yang_store_512.png (512x512, opaque)
	# Since load_from_file returns the default rasterized size of SVG (which is 1024x1024), we can resize it.
	if img_1024 != null:
		var img_512 := Image.new()
		img_512.copy_from(img_1024)
		img_512.resize(512, 512, Image.INTERPOLATE_LANCZOS)
		err = img_512.save_png("res://assets/icons/yin_yang_store_512.png")
		if err == OK:
			print("Generated yin_yang_store_512.png")
		
		# 3. android/yin_yang_main_192.png (192x192, opaque)
		var img_192 := Image.new()
		img_192.copy_from(img_1024)
		img_192.resize(192, 192, Image.INTERPOLATE_LANCZOS)
		err = img_192.save_png("res://assets/icons/android/yin_yang_main_192.png")
		if err == OK:
			print("Generated yin_yang_main_192.png")
	
	# 4. android/yin_yang_foreground_432.png (432x432, transparent outside)
	var img_fg_432 := Image.load_from_file("res://assets/icons/yin_yang_icon_transparent.svg")
	if img_fg_432 != null:
		err = img_fg_432.save_png("res://assets/icons/android/yin_yang_foreground_432.png")
		if err == OK:
			print("Generated yin_yang_foreground_432.png")
	else:
		print("Failed to load yin_yang_icon_transparent.svg")
	
	# 5. android/yin_yang_background_432.png (432x432, opaque green)
	var img_bg_432 := Image.create_empty(432, 432, false, Image.FORMAT_RGBA8)
	img_bg_432.fill(Color("#123B2D"))
	err = img_bg_432.save_png("res://assets/icons/android/yin_yang_background_432.png")
	if err == OK:
		print("Generated yin_yang_background_432.png")
	
	# 6. android/yin_yang_monochrome_432.png (432x432, transparent line-art)
	var img_mono_432 := Image.load_from_file("res://assets/icons/yin_yang_monochrome.svg")
	if img_mono_432 != null:
		err = img_mono_432.save_png("res://assets/icons/android/yin_yang_monochrome_432.png")
		if err == OK:
			print("Generated yin_yang_monochrome_432.png")
	else:
		print("Failed to load yin_yang_monochrome.svg")
	
	print("Icon generation completed.")
	quit(0)
