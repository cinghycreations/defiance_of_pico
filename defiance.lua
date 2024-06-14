local TILE_EMPTY = 0
local TILE_CROWN = 3
local TILE_SHELF = 1
local TILE_BOOSTER = 2
local TILE_SPIKES = 4

local PAGE_SPLASH = 0
local PAGE_SESSION = 1
local PAGE_SUCCESS = 2
local PAGE_FAIL = 3
local PAGE_REPEAT = 4
local PAGE_ENDGAME = 5

page = nil
next_page = nil
current_session = nil

dbg = {
	start_level = nil,
	no_hud = false,
}

function session_init(level, total_frames)
	local session = {}
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

	local scratch_area = { 0, 0, 16, 32 }
	for i = 0, scratch_area[3] - 1 do
		for j = 0, scratch_area[4] - 1 do
			mset( scratch_area[1] + i, scratch_area[2] + j, 0 )
		end
	end

	for level_cell = 1, #levels[session.level] do
		local x = levels[session.level][level_cell][1]
		local y = levels[session.level][level_cell][2]
		local tile = levels[session.level][level_cell][3]

		if tile == TILE_CROWN then
			session.crowns_left = session.crowns_left + 1
		end
		mset( scratch_area[1] + x, scratch_area[2] + y, tile )
	end

	return session
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

function session_update(session)
	if btnp(4) or btnp(5) then
		next_page = PAGE_REPEAT
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
		next_page = PAGE_SUCCESS
		return
	end

	-- fail
	if center_tile == TILE_SPIKES then
		next_page = PAGE_FAIL
		return
	end
end

function format2(value)
	if value < 10 then return ' ' .. tostr(value) else return tostr(value) end
end

function create_caption(session)
	return 'level ' .. format2(session.level) .. '   frames ' .. session.level_frames
end

function session_draw(session)
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

function _init()
	if dbg.start_level ~= nil then
		current_session = session_init( dbg.start_level )
		page = PAGE_SESSION
		next_page = nil
	else
		current_session = {}
		page = PAGE_SPLASH
		next_page = nil
	end
end

function _update60()
	page = next_page or page
	next_page = nil

	if page == PAGE_SPLASH then
		if btnp(4) then
			current_session = session_init()
			next_page = PAGE_SESSION
		end
	elseif page == PAGE_SESSION then
		session_update( current_session )
	elseif page == PAGE_SUCCESS then
		if btnp(5) then
			current_session = session_init( current_session.level, current_session.total_frames )
			next_page = PAGE_SESSION
		elseif btnp(4) then
			if current_session.level + 1 > #levels then
				next_page = PAGE_ENDGAME
			else
				current_session = session_init( current_session.level + 1, current_session.total_frames )
				next_page = PAGE_SESSION
			end
		end
	elseif page == PAGE_FAIL then
		if btnp(4) then
			current_session = session_init( current_session.level, current_session.total_frames )
			next_page = PAGE_SESSION
		elseif btnp(5) then
			next_page = PAGE_SPLASH
		end
	elseif page == PAGE_REPEAT then
		if btnp(4) then
			current_session = session_init( current_session.level, current_session.total_frames )
			next_page = PAGE_SESSION
		elseif btnp(5) then
			next_page = PAGE_SPLASH
		end
	elseif page == PAGE_ENDGAME then
		if btnp(4) or btnp(5) then
			next_page = PAGE_SPLASH
		end
	end
end

function _draw()
	if page == PAGE_SPLASH then
		cls()
		cursor( 0, 7 * 8 )
		print( '       pico of defiance         ' )
		print( '       press ❎ to play         ' )
	elseif page == PAGE_SESSION then
		session_draw( current_session )
	elseif page == PAGE_SUCCESS then
		local level_time = current_session.level_frames * ( 1 / 60 )
		local total_time = current_session.total_frames * ( 1 / 60 )

		session_draw( current_session )
		cursor( 0, 7 * 8 )
		print( '    you collected all crowns!   ' )
		print( '   your time is ' .. level_time )
		print( '       press ❎ to proceed      ' )
		print( '       press 🅾️ to retry     ' )
	elseif page == PAGE_FAIL then
		session_draw( current_session )
		cursor( 0, 7 * 8 )
		print( ' argh! you ended up on a spike. ' )
		print( '        press ❎ to retry      ' )
		print( '       press 🅾️ to quit        ' )
	elseif page == PAGE_REPEAT then
		session_draw( current_session )
		cursor( 0, 7 * 8 )
		print( ' do you want to retry, or quit? ' )
		print( '       press ❎ to retry       ' )
		print( '        press 🅾️ to quit       ' )
	elseif page == PAGE_ENDGAME then
		cls()
		print( '*** placeholder endgame ***' )
	end
end