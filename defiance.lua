debug_skip_splash = false

function session_init()
	session = {}
	session.level = 0
	session.platform_speed = 1.2
	session.platform_offset = 0
	session.ball_position = { 0, 256 - 12 }
	session.ball_speed = 0
	session.ball_impulse = -3.25
	session.ball_booster_impulse = -5
	session.ball_gravity = 9.81
	session.tokens_left = 3
	session.lives = 3
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
	local TILE_EMPTY = 0
	local TILE_TOKEN = 3
	local TILE_SHELF = 1
	local TILE_PLATFORM = 5
	local TILE_BOOSTER = 2
	local TILE_SPIKES = 4

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

	if center_tile == TILE_TOKEN then
		session.tokens_left = session.tokens_left - 1
		mset( center_cell[1], center_cell[2], TILE_EMPTY )
	end

	if session.ball_speed > 0 then
		if ground_tile == TILE_SHELF or ground_tile == TILE_PLATFORM then
			session.ball_position[2] = ground_cell[2] * 8 - 4
			session.ball_speed = session.ball_impulse
		elseif ground_tile == TILE_BOOSTER then
			session.ball_position[2] = ground_cell[2] * 8 - 4
			session.ball_speed = session.ball_booster_impulse
		end
	end

	-- success
	if session.tokens_left == 0 then
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

function create_caption(session)
	caption = 'tokens '
	if session.tokens_left < 10 then caption = caption .. ' ' .. tostr(session.tokens_left) else caption = caption .. tostr(session.tokens_left) end
	caption = caption .. '               balls '
	if session.lives < 10 then caption = caption .. ' ' .. tostr(session.lives) else caption = caption .. tostr(session.lives) end
	return caption
end

function session_draw()
	cls()
	camera( 0, 128 )

	-- map
	map( session.level * 16, 0, 0, 0, 16, 32 )

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
		splash_init()
		_update60 = splash_update
		_draw = splash_draw
		return
	end
end

function success_draw()
	session_draw()
	print( 'you collected all tokens!' )
	print( 'press x or o to continue' )
end

function fail_init()
end

function fail_update()
	if btnp(4) or btnp(5) then
		session_init()
		_update60 = session_update
		_draw = session_draw
	end
end

function fail_draw()
	session_draw()
	print( 'argh! you ended up on a spike.' )
	print( 'press x or o to restart' )
end

function splash_init()
end

function splash_update()
	if btnp(4) or btnp(5) then
		session_init()
		_update60 = session_update
		_draw = session_draw
		return
	end
end

function splash_draw()
	cls()
	print( 'pico of defiance' )
	print( 'press ❎ or 🅾️ to play' )
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
