import json

map_lines = []
with open( 'levels.tmj', 'r' ) as mapfile:
	levels = json.load( mapfile )
	data = levels['layers'][0]['data']
	for i in range(64):
		map_line = ''
		for j in range(128):
			tile = data[ 128 * i + j ]
			tile = 0 if tile == 0 else tile - 1
			map_line += '{:02x}'.format( tile )
		map_lines.append( map_line + '\n' )

with open( 'defiance.p8', 'r' ) as cartfile:
	cart_lines = cartfile.readlines()

with open( 'defiance.p8', 'w' ) as cartfile:
	for line in cart_lines:
		cartfile.write( line )
		if line.strip() == '__map__':
			break

	for line in map_lines:
		cartfile.write( line )
