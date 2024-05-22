import json

with open( 'levels.tmj', 'r' ) as mapfile:
	levels = json.load( mapfile )
	data = levels['layers'][0]['data']
	for i in range(64):
		for j in range(128):
			tile = data[ 128 * i + j ]
			tile = 0 if tile == 0 else tile - 1
			print( '{:02x}'.format( tile ), end = '' )
		print()
