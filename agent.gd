extends AnimatedSprite

func get_looking():
	return 'left' if self.is_flipped_h() else 'right'

func set_looking(dir):
	if dir == 'left':
		if not self.is_flipped_h():
			self.set_flip_h(true)
	elif dir == 'right':
		if self.is_flipped_h():
			self.set_flip_h(false)
