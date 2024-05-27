local TILE_EMPTY = 0
local TILE_CROWN = 3
local TILE_SHELF = 1
local TILE_BOOSTER = 2
local TILE_SPIKES = 4
local LEVEL_TESTBED = 255
local LEVEL_COUNT = 16

dbg = {
	start_level = nil,
	no_hud = false,
}

areas = {
	scratch = { 0, 0, 16, 32 },
	splash = { 48, 0, 16, 16 },
	levels = {
		[1] = { 64, 0, 16, 16 },
		[2] = { 64, 16, 16, 16 },
		[3] = { 80, 0, 16, 16 },
		[4] = { 80, 16, 16, 16 },
		[5] = { 96, 0, 16, 16 },
		[6] = { 96, 16, 16, 16 },
		[7] = { 112, 0, 16, 16 },
		[8] = { 112, 16, 16, 16 },
		[9] = { 0, 32, 16, 32 },
		[10] = { 16, 32, 16, 32 },
		[11] = { 32, 32, 16, 32 },
		[12] = { 48, 32, 16, 32 },
		[13] = { 64, 32, 16, 32 },
		[14] = { 80, 32, 16, 32 },
		[15] = { 96, 32, 16, 32 },
		[16] = { 112, 32, 16, 32 },
		[LEVEL_TESTBED] = { 48, 16, 16, 16 },
	},
}

function session_init(level, lives)
	session = {}
	session.level = level or 1
	session.platform_speed = 1.2
	session.platform_offset = 0
	session.ball_position = { 0, 256 - 64 }
	session.ball_speed = 0
	session.ball_impulse = -3.25
	session.ball_booster_impulse = -5
	session.ball_gravity = 9.81
	session.crowns_left = 0
	session.lives = lives or 3

	if session.level <= 8 then
		session.background = 1
	else
		session.background = 2
	end

	for i = 0, areas.scratch[3] - 1 do
		for j = 0, areas.scratch[4] - 1 do
			mset( areas.scratch[1] + i, areas.scratch[2] + j, 0 )
		end
	end

	bounds = areas.levels[session.level]
	for i = 0, bounds[3] - 1 do
		for j = 0, bounds[4] - 1 do
			local tile = mget( bounds[1] + i, bounds[2] + j )
			if tile == TILE_CROWN then
				session.crowns_left = session.crowns_left + 1
			end
			mset( areas.scratch[1] + i, areas.scratch[2] + ( areas.scratch[4] - bounds[4] ) + j, tile )
		end
	end
end

function clamp(value, min, max)
	if value < min then
		return min
	elseif value > max then
		return max
	else
		return value
	end
end

function session_update()
	local elapsed_time = 1 / 60

	-- platform
	if btn(0) then session.platform_offset = session.platform_offset - session.platform_speed end
	if btn(1) then session.platform_offset = session.platform_offset + session.platform_speed end
	session.platform_offset = clamp( session.platform_offset, 4, 128 - 4 )

	-- ball gravity
	session.ball_position[1] = session.platform_offset
	session.ball_speed = session.ball_speed + session.ball_gravity * elapsed_time
	session.ball_position[2] = session.ball_position[2] + session.ball_speed

	-- collisions
	center_cell = { flr( session.ball_position[1] / 8 ), flr( session.ball_position[2] / 8 ) }
	center_tile = mget( center_cell[1], center_cell[2] )

	if center_tile == TILE_CROWN then
		session.crowns_left = session.crowns_left - 1
		mset( center_cell[1], center_cell[2], TILE_EMPTY )
	end

	local ground_sample_offsets = { { -2, 4 }, { 0, 4 }, { 2, 4 } }
	for key, value in pairs( ground_sample_offsets ) do
		ground_cell = { flr( ( session.ball_position[1] + value[1] ) / 8 ), flr( ( session.ball_position[2] + value[2] ) / 8 ) }
		ground_tile = mget( ground_cell[1], ground_cell[2] )

		if session.ball_speed > 0 then
			if ground_tile == TILE_SHELF or ground_cell[2] == 31 then
				session.ball_position[2] = ground_cell[2] * 8 - 4
				session.ball_speed = session.ball_impulse
			elseif ground_tile == TILE_BOOSTER then
				session.ball_position[2] = ground_cell[2] * 8 - 4
				session.ball_speed = session.ball_booster_impulse
			end
		end
	end

	-- success
	if session.crowns_left == 0 then
		success_init()
		_update60 = success_update
		_draw = success_draw
		return
	end

	-- fail
	if center_tile == TILE_SPIKES then
		session.lives = session.lives - 1
		fail_init()
		_update60 = fail_update
		_draw = fail_draw
		return
	end
end

function format2(value)
	if value < 10 then return ' ' .. tostr(value) else return tostr(value) end
end

function create_caption(session)
	return 'level ' .. format2(session.level) .. '    crowns ' .. format2(session.crowns_left) .. '   balls ' .. format2(session.lives)
end

function session_draw()
	cls()

	camera_position = clamp( session.ball_position[2] - 16, 0, 128 )
	camera( 0, camera_position )

	-- background
	map( session.background * 16, 0, 0, 0, 16, 32 )

	-- map
	map( 0, 0, 0, 0, 16, 32 )

	-- platform
	spr( 6, session.platform_offset - 12 + 0, 256 - 8 )
	spr( 7, session.platform_offset - 12 + 8, 256 - 8 )
	spr( 8, session.platform_offset - 12 + 16, 256 - 8 )

	-- ball
	spr( 9, session.ball_position[1] - 4, session.ball_position[2] - 4 )

	-- hud
	if not dbg.no_hud then
		camera( 0, 0 )
		print( create_caption( session ), 7 )
	end
end

function success_init()
end

function success_update()
	if btnp(4) or btnp(5) then
		if session.level == LEVEL_TESTBED then
			session_init( LEVEL_TESTBED, 99 )
			_update60 = session_update
			_draw = session_draw
		elseif session.level + 1 > LEVEL_COUNT then
			endgame_init()
			_update60 = endgame_update
			_draw = endgame_draw
		else
			session_init( session.level + 1 )
			_update60 = session_update
			_draw = session_draw
		end
	end
end

function success_draw()
	session_draw()
	cursor( 0, 7 * 8 )
	print( '    you collected all crowns!   ' )
	print( '   press ❎ or 🅾️ to proceeed  ' )
end

function fail_init()
end

function fail_update()
	if btnp(4) or btnp(5) then
		if session.lives > 0 then
			session_init( session.level, session.lives )
			_update60 = session_update
			_draw = session_draw
		else
			splash_init()
			_update60 = splash_update
			_draw = splash_draw
		end
	end
end

function fail_draw()
	session_draw()
	cursor( 0, 7 * 8 )
	print( ' argh! you ended up on a spike. ' )
	if session.lives > 0 then
		print( '    press ❎ or 🅾️ to restart  ' )
	else
		print( '         no balls left...       ' )
		print( '      press ❎ or 🅾️ to quit   ' )
	end
end

function splash_init()
end

function splash_update()
	if btnp(4) or btnp(5) then
		session_init()
		_update60 = session_update
		_draw = session_draw
	end
end

function splash_draw()
	cls()
	cursor( 0, 7 * 8 )
	print( '       pico of defiance         ' )
	print( '    press ❎ or 🅾️ to play     ' )
end

function endgame_init()
end

function endgame_update()
	if btnp(4) or btnp(5) then
		splash_init()
		_update60 = splash_update
		_draw = splash_draw
	end
end

function endgame_draw()
	cls()
	print( '*** placeholder endgame ***' )
end

if dbg.start_level ~= nil then
	_init = function() session_init( dbg.start_level, 99 ) end
	_update60 = session_update
	_draw = session_draw
else
	_init = splash_init
	_update60 = splash_update
	_draw = splash_draw
end
