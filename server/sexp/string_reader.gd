extends "reader.gd"

var buf
var i

func _init(msg_str):
	buf = msg_str
	i = -1

func next_char():
	i += 1
	return buf[i]
