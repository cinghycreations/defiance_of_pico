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
}

function session_init(level, total_frames)
	session = {}
	session.level = level or 1
	session.camera_offset = 0
	session.platform_speed = 1.2
	session.platform_offset = 0
	session.ball_position = { 0, 256 - 64 }
	session.ball_speed = 0
	session.ball_impulse = -3.25
	session.ball_booster_impulse = -5
	session.ball_gravity = 9.81
	session.crowns_left = 0
	session.level_frames = 0
	session.total_frames = total_frames or 0

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

	for level_cell = 1, #levels[session.level] do
		local x = levels[session.level][level_cell][1]
		local y = levels[session.level][level_cell][2]
		local tile = levels[session.level][level_cell][3]

		if tile == TILE_CROWN then
			session.crowns_left = session.crowns_left + 1
		end
		mset( areas.scratch[1] + x, areas.scratch[2] + y, tile )
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
	if btnp(4) then
		repeat_init()
		_update60 = repeat_update
		_draw = repeat_draw
		return
	end

	local elapsed_time = 1 / 60

	-- frames
	session.level_frames = session.level_frames + 1
	session.total_frames = session.total_frames + 1

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
	return 'level ' .. format2(session.level) .. '   frames ' .. session.level_frames
end

function session_draw()
	cls()

	if session.ball_position[2] - 16 < session.camera_offset then
		session.camera_offset = session.ball_position[2] - 16
	elseif session.ball_position[2] + 16 > session.camera_offset + 128 then
		session.camera_offset = session.ball_position[2] + 16 - 128
	end
	session.camera_offset = clamp( session.camera_offset, 0, 128 )
	camera( 0, session.camera_offset )

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
	if btnp(4) then
		session_init( session.level, session.total_frames )
		_update60 = session_update
		_draw = session_draw
	elseif btnp(5) then
		if session.level == LEVEL_TESTBED then
			session_init( LEVEL_TESTBED )
			_update60 = session_update
			_draw = session_draw
		elseif session.level + 1 > #levels then
			endgame_init()
			_update60 = endgame_update
			_draw = endgame_draw
		else
			session_init( session.level + 1, session.total_frames )
			_update60 = session_update
			_draw = session_draw
		end
	end
end

function success_draw()
	local level_time = session.level_frames * ( 1 / 60 )
	local total_time = session.total_frames * ( 1 / 60 )

	session_draw()
	cursor( 0, 7 * 8 )
	print( '    you collected all crowns!   ' )
	print( '   your time is ' .. level_time )
	print( '       press ❎ to retry      ' )
	print( '       press 🅾️ to proceed     ' )
end

function fail_init()
end

function fail_update()
	if btnp(4) then
		session_init( session.level, session.total_frames )
		_update60 = session_update
		_draw = session_draw
	elseif btnp(5) then
		splash_init()
		_update60 = splash_update
		_draw = splash_draw
	end
end

function fail_draw()
	session_draw()
	cursor( 0, 7 * 8 )
	print( ' argh! you ended up on a spike. ' )
	print( '        press ❎ to retry      ' )
	print( '       press 🅾️ to quit        ' )
end

function repeat_init()
end

function repeat_update()
	if btnp(4) then
		session_init( session.level, session.total_frames )
		_update60 = session_update
		_draw = session_draw
	elseif btnp(5) then
		splash_init()
		_update60 = splash_update
		_draw = splash_draw
	end
end

function repeat_draw()
	session_draw()
	cursor( 0, 7 * 8 )
	print( ' do you want to retry, or quit? ' )
	print( '       press ❎ to retry       ' )
	print( '        press 🅾️ to quit       ' )
end

function splash_init()
end

function splash_update()
	if btnp(4) then
		session_init()
		_update60 = session_update
		_draw = session_draw
	end
end

function splash_draw()
	cls()
	cursor( 0, 7 * 8 )
	print( '       pico of defiance         ' )
	print( '       press ❎ to play         ' )
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
	_init = function() session_init( dbg.start_level ) end
	_update60 = session_update
	_draw = session_draw
else
	_init = splash_init
	_update60 = splash_update
	_draw = splash_draw
end
