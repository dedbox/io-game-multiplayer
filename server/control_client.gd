extends "sexp/reader_writer.gd"

var stream = StreamPeerTCP.new()

class ControlClientReader extends "sexp/reader.gd":
	var stream
	
	func _init(stream):
		self.stream = stream
	
	func next_char():
		return stream.get_utf8_string(1)

class ControlClientWriter extends "sexp/writer.gd":
	var stream
	
	func _init(stream):
		self.stream = stream
	
	func write_literal(lit):
		stream.put_utf8_string(String(lit))

func _init(addr).(ControlClientReader.new(stream), ControlClientWriter.new(stream)):
	stream.connect(addr[0], addr[1])
