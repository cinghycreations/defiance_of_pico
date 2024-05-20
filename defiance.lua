function session_init(session)
	session.level = 0
	session.platform_speed = 2
	session.platform_offset = 0
	session.ball_position = { 0, 256 - 12 }
	session.ball_speed = 0
	session.ball_impulse = -4
	session.ball_gravity = 9.81
end

function clamp(value, min, max)
	if ( value < min ) then
		return min
	elseif ( value > max ) then
		return max
	else
		return value
	end
end

function update_session(session, elapsed_time)
	-- platform
	if ( btn(0) ) then session.platform_offset -= session.platform_speed end
	if ( btn(1) ) then session.platform_offset += session.platform_speed end
	session.platform_offset = clamp( session.platform_offset, 4, 128 - 4 )

	-- ball gravity
	session.ball_position[1] = session.platform_offset
	session.ball_speed += session.ball_gravity * elapsed_time
	session.ball_position[2] += session.ball_speed

	-- ball collision
	ground_cell = {
		flr( session.ball_position[1] / 8 ),
		flr( (session.ball_position[2] + 4) / 8 )
	}
	ground_tile = mget( ground_cell[1], ground_cell[2] )

	if ( ground_tile == 1 or ground_tile == 5 ) then
		session.ball_position[2] = ground_cell[2] * 8 - 4
		session.ball_speed = session.ball_impulse
	end
end

function _init()
	session = {}
	session_init(session)
end

function _update60()
	update_session( session, 1 / 60 )
end

function _draw()
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
end
