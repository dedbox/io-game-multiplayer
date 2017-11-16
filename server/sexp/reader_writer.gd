extends Node

var reader
var writer

func _init(reader, writer):
	self.reader = reader
	self.writer = writer

func read():
	return self.reader.read()

func write(msg):
	self.writer.write(msg)
