local TILE_EMPTY = 0
local TILE_CROWN = 3
local TILE_SHELF = 1
local TILE_BOOSTER = 2
local TILE_SPIKES = 4

debug_skip_splash = false

areas = {
	scratch = { 0, 0, 16, 32 },
	background1 = { 16, 0, 16, 32 },
	background2 = { 32, 0, 16, 32 },
	splash = { 48, 0, 16, 16 },
	levels = {
		{ 64, 0, 16, 16 },
		{ 64, 16, 16, 16 },
		--[[
		{ 80, 0, 16, 16 },
		{ 80, 16, 16, 16 },
		{ 96, 0, 16, 16 },
		{ 96, 16, 16, 16 },
		{ 112, 0, 16, 16 },
		{ 112, 16, 16, 16 },
		{ 0, 32, 16, 32 },
		{ 16, 32, 16, 32 },
		{ 32, 32, 16, 32 },
		{ 48, 32, 16, 32 },
		{ 64, 32, 16, 32 },
		{ 80, 32, 16, 32 },
		{ 96, 32, 16, 32 },
		{ 112, 32, 16, 32 },
		]]
	},
}

function session_init(level, lives)
	session = {}
	session.level = level or 1
	session.background = 0
	session.platform_speed = 1.2
	session.platform_offset = 0
	session.ball_position = { 0, 256 - 64 }
	session.ball_speed = 0
	session.ball_impulse = -3.25
	session.ball_booster_impulse = -5
	session.ball_gravity = 9.81
	session.crowns_left = 0
	session.lives = lives or 3

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
	ground_cell = { flr( session.ball_position[1] / 8 ), flr( (session.ball_position[2] + 4) / 8 ) }
	ground_tile = mget( ground_cell[1], ground_cell[2] )

	if center_tile == TILE_CROWN then
		session.crowns_left = session.crowns_left - 1
		mset( center_cell[1], center_cell[2], TILE_EMPTY )
	end

	if session.ball_speed > 0 then
		if ground_tile == TILE_SHELF or ground_cell[2] == 31 then
			session.ball_position[2] = ground_cell[2] * 8 - 4
			session.ball_speed = session.ball_impulse
		elseif ground_tile == TILE_BOOSTER then
			session.ball_position[2] = ground_cell[2] * 8 - 4
			session.ball_speed = session.ball_booster_impulse
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

function create_caption(session)
	caption = 'crowns '
	if session.crowns_left < 10 then caption = caption .. ' ' .. tostr(session.crowns_left) else caption = caption .. tostr(session.crowns_left) end
	caption = caption .. '               balls '
	if session.lives < 10 then caption = caption .. ' ' .. tostr(session.lives) else caption = caption .. tostr(session.lives) end
	return caption
end

function session_draw()
	cls()
	camera( 0, 128 )

	-- background
	map( (session.background + 1) * 16, 0, 0, 0, 16, 32 )

	-- map
	map( 0, 0, 0, 0, 16, 32 )

	-- platform
	spr( 6, session.platform_offset - 12 + 0, 256 - 8 )
	spr( 7, session.platform_offset - 12 + 8, 256 - 8 )
	spr( 8, session.platform_offset - 12 + 16, 256 - 8 )

	-- ball
	spr( 9, session.ball_position[1] - 4, session.ball_position[2] - 4 )

	-- hud
	camera( 0, 0 )
	print( create_caption( session ), 7 )
end

function success_init()
end

function success_update()
	if btnp(4) or btnp(5) then
		if session.level + 1 > #areas.levels then
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
	print( 'you collected all crowns!' )
	print( 'press ❎ or 🅾️ to proceeed' )
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
	print( 'argh! you ended up on a spike.' )
	if session.lives > 0 then
		print( 'press ❎ or 🅾️ to restart' )
	else
		print( 'no balls left...' )
		print( 'press ❎ or 🅾️ to quit' )
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
	print( 'pico of defiance' )
	print( 'press ❎ or 🅾️ to play' )
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

if debug_skip_splash then
	_init = session_init
	_update60 = session_update
	_draw = session_draw
else
	_init = splash_init
	_update60 = splash_update
	_draw = splash_draw
end
