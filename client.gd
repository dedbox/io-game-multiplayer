extends Node

var cli = PacketPeerUDP.new()
var cli_port
var cli_addr

var srv = PacketPeerUDP.new()
var srv_addr

var pulse

var agent_factory = preload("res://agent.tscn")
var agent

func _ready():
	setup_cli()
	setup_srv()
	send('CONNECT')
	
	agent = agent_factory.instance()
	add_child(agent)
	
	set_fixed_process(true)

func _fixed_process(delta):
	if OS.get_ticks_msec() - pulse > 2000:
		send('CONNECT')
	
	while cli.get_available_packet_count() > 0:
		var msg = recv().split(' ')
		print(msg)
		if msg[0] == 'TICK':
			agent.set_pos(Vector2(float(msg[1]), float(msg[2])))

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
	pulse = OS.get_ticks_msec()

func recv():
	return cli.get_packet().get_string_from_ascii()
