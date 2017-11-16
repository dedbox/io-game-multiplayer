extends Node

const Symbol = preload("res://server/sexp/symbol.gd")

func write_literal(lit):
	breakpoint

func write(msg):
	var type = typeof(msg)
	if type == TYPE_ARRAY:
		write_list(msg)
	elif type == TYPE_INT or type == TYPE_REAL:
		write_number(msg)
	elif type == TYPE_OBJECT:
		if msg extends Symbol:
			write_symbol(msg)
		else:
			breakpoint
	else:
		breakpoint

func write_list(list):
	var k = 0
	var N = list.size()
	write_literal("(")
	for datum in list:
		write(datum)
		k += 1
		if k < N:
			write_literal(" ")
	write_literal(")")

func write_number(num):
	write_literal(num)

func write_symbol(sym):
	write_literal(sym.string)
