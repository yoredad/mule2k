extends SceneTree

func _init() -> void:
	var img: Image = Image.load_from_file("res://assets/mule_sheet.png")
	var w := 120
	var h := 56
	var cw := img.get_width() / w
	var ch := img.get_height() / h
	for gy in h:
		var line := ""
		for gx in w:
			var total := 0.0
			var count := 0
			for yy in range(gy * ch, (gy + 1) * ch, 4):
				for xx in range(gx * cw, (gx + 1) * cw, 4):
					total += img.get_pixel(xx, yy).a
					count += 1
			var a := total / count
			line += "." if a < 0.05 else ("#" if a > 0.3 else "+")
		print(line)
	quit(0)
