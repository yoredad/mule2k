extends SceneTree

func _init() -> void:
	var img: Image = Image.load_from_file("res://assets/mule_sheet.png")
	var cols_blank: Array = []
	for x in img.get_width():
		var any := false
		for y in range(0, img.get_height(), 4):
			if img.get_pixel(x, y).a > 0.1:
				any = true
				break
		if not any:
			cols_blank.append(x)
	var rows_blank: Array = []
	for y in img.get_height():
		var any := false
		for x in range(0, img.get_width(), 4):
			if img.get_pixel(x, y).a > 0.1:
				any = true
				break
		if not any:
			rows_blank.append(y)
	print("blank col ranges:")
	_print_runs(cols_blank)
	print("blank row ranges:")
	_print_runs(rows_blank)
	quit(0)

func _print_runs(list: Array) -> void:
	if list.is_empty():
		print("  none")
		return
	var start: int = list[0]
	var prev: int = list[0]
	for v in list.slice(1):
		if v != prev + 1:
			print("  ", start, "-", prev)
			start = v
		prev = v
	print("  ", start, "-", prev)
