extends Node

export var server_addr = ["192.168.1.49", 3700]
export var beacon_addr = ["192.168.1.49", 3699]

export var my_speed = 100

const Symbol = preload("res://server/sexp/symbol.gd")
const Symtab = preload("res://server/sexp/symtab.gd")
const ControlClient = preload("res://server/control_client.gd")
const WorldClient = preload("res://server/world_client.gd")

var ctrl
var world
var my_id

var agent_factory = preload("res://agent.tscn")
var agents = {}
var my_agent

var skins = [
	null,
	[load("res://MrG/sprite/animations.tres"), 1, 1, 0, -30],
	[load("res://athan/sprite/animations.tres"), 2, 2, 0, -13],
	[load("res://Evan/slime/animations.tres"), 3, 3, 1.5, -3]
	]

func _ready():
	# initialize the symbol table
	Globals.set("symtab", Symtab.new())
	var symtab = Globals.get("symtab")
	var START = symtab.intern("START")
	
	# start a UDP listener for world updates
	world = WorldClient.new(beacon_addr)
	print("%s:%d listening" % world.local_addr)
	
	# start a TCP client for agent control
	ctrl = ControlClient.new(server_addr)
	print("%s:%d connected" % server_addr)
	
	# spawn my agent
	ctrl.write([START, world.local_addr[1]])
	my_id = ctrl.read()
	print("agent id ", my_id)
	
	while agents.size() == 0:
		_process(0.01)
	
	# initialize my agent
	my_agent = agents[my_id]
	my_agent.get_node("camera").make_current()
	
	set_process(true)
	set_process_input(true)

func _process(delta):
	var msg = world.try_recv()
	if msg != null:
		var msg_addr = msg[0]
		
		# unmarshal agents
		var new_agents = {}
		for row in msg[1]:
			print("ROW ", row)
			var id = row[0]
			var pos = Vector2(float(row[3][0]), float(row[3][1]))
			var meta = adict(row[5])
			
			# find or create agent
			if id in agents:
				new_agents[id] = agents[id]
			else:
				new_agents[id] = agent_factory.instance()
				add_child(new_agents[id])
			var agent = new_agents[id]
			
			# update position
			var old_pos = agent.get_pos()
			if old_pos == pos:
				agent.set_animation('standing')
			else:
				agent.set_pos(pos)
				agent.set_animation('running')
				if pos.x < old_pos.x:
					agent.set_looking('left')
				elif pos.x > old_pos.x:
					agent.set_looking('right')
			
			# update skin
			if "skin" in meta:
				print("SET-SKIN ", meta["skin"])
				set_skin(agent, meta["skin"])
			
			# update my agent ref
			if id == my_id:
				my_agent = agent
		
		# handle disconnects
		for id in agents:
			if not id in new_agents:
				remove_child(agents[id])
				agents[id].queue_free()
		
		agents = new_agents

func adict(alist):
	var dict = {}
	for list in alist:
		dict[list[0].string] = list[2]
	return dict

func limit(vec, rect):
	var out = Vector2(0, 0)
	out.x = min(rect.pos.x + rect.size.width, max(rect.pos.x, vec.x))
	out.y = min(rect.pos.y + rect.size.height, max(rect.pos.y, vec.y))
	return out

func set_skin(agent, id):
	agent.set_sprite_frames(skins[id][0])
	agent.set_scale(Vector2(skins[id][1], skins[id][2]))
	agent.set_offset(Vector2(skins[id][3], skins[id][4]))

func use_skin(id):
	set_skin(my_agent, id)
	var symtab = Globals.get("symtab")
	ctrl.write([symtab.intern("SET"), world.local_addr[1], symtab.intern("skin"), id])
	ctrl.read()

func _input(event):
	var symtab = Globals.get("symtab")
	if event.is_action_pressed('move_to'):
		var min_x = my_agent.get_node("camera").get_limit(MARGIN_LEFT)
		var min_y = my_agent.get_node("camera").get_limit(MARGIN_TOP)
		var max_x = my_agent.get_node("camera").get_limit(MARGIN_RIGHT)
		var max_y = my_agent.get_node("camera").get_limit(MARGIN_BOTTOM)
		var cam_limit = Rect2(min_x, min_y, max_x - min_x, max_y - min_y)
		var origin = get_viewport().get_canvas_transform()[2]
		var to = limit(event.pos - origin, cam_limit)
		ctrl.write([symtab.intern("MOVE"), world.local_addr[1], [to.x, to.y], my_speed])
		ctrl.read()
	if event.is_action_pressed('use_skin_1'):
		use_skin(1)
	if event.is_action_pressed('use_skin_2'):
		use_skin(2)
	if event.is_action_pressed('use_skin_3'):
		use_skin(3)
