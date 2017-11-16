extends Node

var _read_buf = ""
var symtab = Globals.get("symtab")

func next_char():
	breakpoint

func peek_char():
	while _read_buf.length() == 0:
		_read_buf = next_char()
	return _read_buf[0]

func read_char():
	var char = peek_char()
	_read_buf.erase(0, 1)
	return char

func read():
	skip_space()
	var char = peek_char()
	if char == "#":
		return read_special()
	elif char == "(":
		return read_list()
	elif char == "\"":
		return read_string()
	elif ("A" <= char and char <= "Z") or ("a" <= char and char <= "z") or char == "-" or char == ".":
		return read_symbol()
	elif "0" <= char and char <= "9":
		return read_number()
	else:
		breakpoint

func skip_space():
	var char = peek_char()
	while char == " " or char == "\t" or char == "\r" or char == "\n":
		read_char()
		char = peek_char()

func read_special():
	read_char() # sharp sign
	var char = read_char()
	if char == "f":
		return false
	elif char == "t":
		return true
	else:
		breakpoint

func read_list():
	var list = []
	read_char() # open paren
	skip_space()
	var char = peek_char()
	while char != ")":
		list.append(read())
		skip_space()
		char = peek_char()
	read_char() # close paren
	return list

func read_string():
	var string = ""
	read_char() # open quote
	var char = peek_char()
	while char != "\"":
		string += read_char()
		char = peek_char()
	read_char() # close quote
	return string

func read_symbol():
	var string = ""
	var char = peek_char()
	while ("A" <= char and char <= "Z") or ("a" <= char and char <= "z") or ("-" <= char and char <= ":"):
		string += read_char()
		char = peek_char()
	return symtab.intern(string)

func read_number():
	var number = parse_digits()
	var char = peek_char()
	if char == ".":
		number += read_char()
		number += parse_digits()
		return float(number)
	else:
		return int(number)

func parse_digits():
	var digits = ""
	var char = peek_char()
	while "0" <= char and char <= "9":
		digits += read_char()
		char = peek_char()
	return digits
