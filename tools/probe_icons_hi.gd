extends SceneTree

func _init() -> void:
	var img: Image = Image.load_from_file("res://assets/mule_sheet.png")
	var bands := [[284, 440], [462, 620], [637, 796], [810, 971], [987, 1147]]
	for c in 5:
		var x0: int = bands[c][0]
		var x1: int = bands[c][1]
		var y0 := 97
		var y1 := 244
		var w: int = x1 - x0
		var h: int = y1 - y0
		print("--- icon ", c, " ---")
		var cw := w / 40.0
		var ch := h / 32.0
		for gy in 32:
			var line := ""
			for gx in 40:
				var total := 0.0
				var count := 0
				for yy in range(int(y0 + gy * ch), int(y0 + (gy + 1) * ch), 2):
					for xx in range(int(x0 + gx * cw), int(x0 + (gx + 1) * cw), 2):
						total += img.get_pixel(xx, yy).a
						count += 1
				var a := total / count
				line += "." if a < 0.05 else ("#" if a > 0.35 else "+")
			print(line)
	quit(0)
