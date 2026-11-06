# run_map.gd — 局内分支舆图：分层 DAG，每层从起点分叉，终点固定 BOSS 房
# 节点类型：start / combat / elite / event / shop / trial / boss
class_name RunMap
extends RefCounted

# 每层的行定义（第 0 行是起点，最后一行是 BOSS）
const ROW_DEFS := [
	["start"],
	["combat", "event"],
	["combat", "shop"],
	["combat", "elite", "event"],
	["combat", "trial"],
	["combat", "event", "shop"],
	["boss"],
]
const ROW_Y0 := 300.0
const ROW_DY := -39.0
const X_CENTER := 320.0
const X_GAP := 132.0

var nodes: Array[Dictionary] = []
var current_id: int = 0   # 起点节点；每进入一间房后推进到对应节点
var visited: Array[int] = [0]


func generate(seed_value: int = -1) -> void:
	nodes.clear()
	var rng := RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()

	for row in ROW_DEFS.size():
		var types: Array = (ROW_DEFS[row] as Array).duplicate()
		if types.size() > 1 and types[0] != "boss":
			_shuffle(types, rng)
		var count := types.size()
		for col in count:
			_add_node(row, col, count, types[col])

	_connect_rows(rng)
	current_id = 0
	visited = [0]


func _add_node(row: int, col: int, count: int, type: String) -> void:
	var x := X_CENTER + (float(col) - float(count - 1) / 2.0) * X_GAP
	var y := ROW_Y0 + row * ROW_DY
	nodes.append({
		"id": nodes.size(), "row": row, "col": col, "type": type,
		"x": x, "y": y, "next": [] as Array[int],
	})


func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _ids_in_row(row: int) -> Array[int]:
	var out: Array[int] = []
	for n in nodes:
		if int(n["row"]) == row:
			out.append(int(n["id"]))
	return out


func _link(a: int, b: int) -> void:
	if b not in nodes[a]["next"]:
		nodes[a]["next"].append(b)


func _connect_rows(rng: RandomNumberGenerator) -> void:
	for row in ROW_DEFS.size() - 1:
		var a_ids := _ids_in_row(row)
		var b_ids := _ids_in_row(row + 1)
		for i in a_ids.size():
			var a := a_ids[i]
			var anchor := 0
			if a_ids.size() > 1:
				anchor = int(round(float(i) * float(b_ids.size() - 1) / float(a_ids.size() - 1)))
			else:
				anchor = (b_ids.size() - 1) / 2
			_link(a, b_ids[anchor])
			# 约半数节点额外分叉一条，形成交叉路径
			if b_ids.size() > 1 and rng.randf() < 0.5:
				var alt := clampi(anchor + (1 if rng.randf() < 0.5 else -1), 0, b_ids.size() - 1)
				_link(a, b_ids[alt])
		# 保证下一行每个节点都有入边（不会出现孤岛）
		for j in b_ids.size():
			var has_in := false
			for a in a_ids:
				if b_ids[j] in nodes[a]["next"]:
					has_in = true
					break
			if not has_in:
				var src_i := 0
				if a_ids.size() > 1 and b_ids.size() > 1:
					src_i = clampi(int(round(float(j) * float(a_ids.size() - 1) / float(b_ids.size() - 1))),
						0, a_ids.size() - 1)
				_link(a_ids[src_i], b_ids[j])


func node(id: int) -> Dictionary:
	if id < 0 or id >= nodes.size():
		return {}
	return nodes[id]


func type_of(id: int) -> String:
	return String(node(id).get("type", ""))


func reachable() -> Array[int]:
	var out: Array[int] = []
	for id in nodes[current_id]["next"]:
		out.append(int(id))
	return out


func is_finished() -> bool:
	return nodes[current_id]["next"].is_empty()
