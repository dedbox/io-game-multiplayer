extends Node

var symbols = {}

const Symbol = preload("res://server/sexp/symbol.gd")

func intern(string):
	if not string in symbols:
		symbols[string] = Symbol.new(string)
	return symbols[string]
