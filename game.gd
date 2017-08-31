extends Node

var peer = PacketPeerUDP.new()
var agent_factory = preload("res://agent.tscn")
var agent

func _ready():
	var port = 3701
	while peer.listen(port) != OK:
		port += 1
	peer.set_send_address('0.0.0.0', 3700)
	
	agent = agent_factory.instance()
	add_child(agent)
	
#	peer.listen(3700, '192.168.1.254')
	
	set_fixed_process(true)

func _fixed_process(delta):
	while peer.get_available_packet_count() > 0:
		var msg = peer.get_packet().get_string_from_ascii().split(' ')
		msgs.push_back(msg)

func start_client():
	send('CONNECT')

func send(msg):
	peer.set_send_address("127.0.0.1", 3700)
	peer.put_packet(String(msg).to_utf8())
	print("SEND ", msg)

var msgs = []

#		var data = peer.get_packet().get_string_from_ascii().split(' ')
#		var idx = int(data[0])
#		var theta = float(data[1])
#		var pos_x = float(data[2])
#		var pos_y = float(data[3])
#		print('TICK %d %.2f (%.2f, %.2f)' % [idx, theta, pos_x, pos_y])
#		agent.set_pos(Vector2(pos_x, pos_y))
