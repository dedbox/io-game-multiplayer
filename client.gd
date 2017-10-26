extends Node

var cli = PacketPeerUDP.new()
var cli_port
var cli_addr

var srv = PacketPeerUDP.new()
var srv_addr

onready var pulse = OS.get_ticks_msec()

var agent_factory = preload("res://agent.tscn")
var agent
var others = {}

var characters = [
	null,
	[load("res://MrG/sprite/animations.tres"), 1, 1, 0, -30],
	[load("res://athan/sprite/animations.tres"), 2, 2, 0, -13],
	[load("res://Evan/slime/animations.tres"), 3, 3, 1.5, -3]
	]

const PULSE_PERIOD = 500

func _ready():
	setup_cli()
	setup_srv()
	send('CONNECT')
	
	agent = agent_factory.instance()
	agent.get_node("camera").make_current()
	add_child(agent)
	
	set_process_input(true)
	set_fixed_process(true)

func limit(vec, rect):
	var out = Vector2(0, 0)
	out.x = min(rect.pos.x + rect.size.width, max(rect.pos.x, vec.x))
	out.y = min(rect.pos.y + rect.size.height, max(rect.pos.y, vec.y))
	return out

func use_character(id):
	print('USE CHARACTER', id)
	agent.set_sprite_frames(characters[id][0])
	agent.set_scale(Vector2(characters[id][1], characters[id][2]))
	agent.set_offset(Vector2(characters[id][3], characters[id][4]))

func _input(event):
	if event.is_action_pressed('move_to'):
		var min_x = agent.get_node("camera").get_limit(MARGIN_LEFT)
		var min_y = agent.get_node("camera").get_limit(MARGIN_TOP)
		var max_x = agent.get_node("camera").get_limit(MARGIN_RIGHT)
		var max_y = agent.get_node("camera").get_limit(MARGIN_BOTTOM)
		var cam_limit = Rect2(min_x, min_y, max_x - min_x, max_y - min_y)
		var origin = get_viewport().get_canvas_transform()[2]
		var to = limit(event.pos - origin, cam_limit)
		send('MOVE|' + str(to.x) + '|' + str(to.y))
		print('MOVE|' + str(to.x) + '|' + str(to.y))
	if event.is_action_pressed('use_character_1'):
		use_character(1)
	if event.is_action_pressed('use_character_2'):
		use_character(2)
	if event.is_action_pressed('use_character_3'):
		use_character(3)

func _fixed_process(delta):
	if OS.get_ticks_msec() - pulse >= PULSE_PERIOD:
		send('CONNECT')
		pulse = OS.get_ticks_msec()
	
	while cli.get_available_packet_count() > 0:
		var msg = Array(recv().split('|'))
#		print(msg)
		
		if msg[0] == 'TICK':
			var pos = agent.get_pos()
			var animation = agent.get_animation()
			var looking = agent.get_looking()
			
			var new_pos = Vector2(float(msg[1]), float(msg[2]))
			if new_pos == agent.get_pos():
				animation = 'standing'
			else:
				agent.set_pos(new_pos)
				animation = 'running'
				if new_pos.x < pos.x:
					looking = 'left'
				elif new_pos.x > pos.x:
					looking = 'right'
			
			animation == agent.get_animation() or agent.set_animation(animation)
			looking == agent.get_looking() or agent.set_looking(looking)
		
		if msg[0] == 'OTHERS':
			var agents = {}
			msg.pop_front()
			while msg.size() > 0:
				var addr = msg[0]
				var x = msg[1]
				var y = msg[2]
				msg.pop_front()
				msg.pop_front()
				msg.pop_front()
				if addr in others:
					agents[addr] = others[addr]
				else:
					agents[addr] = agent_factory.instance()
					add_child(agents[addr])
				agents[addr].set_pos(Vector2(x, y))
			for addr in others:
				if not addr in agents:
					remove_child(others[addr])
					others[addr].queue_free()
			others = agents

func setup_cli():
	cli_port = 3701 + randi() % 1000
	while cli.listen(cli_port) != OK:
		cli_port += 1
	
	for addr in IP.get_local_addresses():
		if not (String(addr).begins_with('127') or ':' in String(addr)):
			cli_addr = addr
			print('client %s:%d' % [cli_addr, cli_port])
			return
	print('NO LOCAL ADDRESS!! ', IP.get_local_addresses())
	breakpoint

func setup_srv():
	srv.listen(3699)
	while srv.get_available_packet_count() == 0:
		pass
	srv_addr = srv.get_packet().get_string_from_utf8()
	srv.close()
	srv.listen(3700)
	cli.set_send_address(srv_addr, 3700)
	print('server %s:3700' % srv_addr)

func send(msg):
	cli.put_packet(String(msg).to_utf8())

func recv():
	return cli.get_packet().get_string_from_ascii()
