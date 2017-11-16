extends Node

var peer = PacketPeerUDP.new()
var local_addr
var remote_addr

const SexpStringReader = preload("res://server/sexp/string_reader.gd")

func _init(beacon_addr):
	peer.listen(0, "0.0.0.0")
	send_literal(beacon_addr, "PING")
	while peer.get_available_packet_count() == 0:
		pass
	var msg = recv()
	local_addr = msg[1][2]
	remote_addr = [peer.get_packet_ip(), peer.get_packet_port()]

func send_literal(addr, msg_str):
	peer.set_send_address(addr[0], addr[1])
	write_literal(msg_str)

func write_literal(lit):
	peer.put_packet(String(lit).to_utf8())

func recv():
	var msg_str = peer.get_packet().get_string_from_utf8()
	var msg = SexpStringReader.new(msg_str).read()
	var addr = [peer.get_packet_ip(), peer.get_packet_port()]
	return [addr, msg]

func try_recv():
	return recv() if peer.get_available_packet_count() > 0 else null
