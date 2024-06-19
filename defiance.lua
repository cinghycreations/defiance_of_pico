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

local MODE_ALL_LEVELS = 0
local MODE_SINGLE_LEVEL = 1

local ALL_LEVELS_SCORE_SLOT = 0

local page = nil
local next_page = nil
local current_session = nil

local splash_selected_level = 0

local dbg = {
	start_level = nil,
	no_hud = false,
}

local function session_init(mode, starting_level, total_frames)
	local session = {}
	session.mode = mode or MODE_ALL_LEVELS
	session.level = starting_level or 1
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
	session.level_record = nil
	session.total_record = nil

	local level_record = dget( session.level )
	if level_record ~= 0 then
		session.level_record = level_record
	end

	local total_record = dget( ALL_LEVELS_SCORE_SLOT )
	if total_record ~= 0 then
		session.total_record = total_record
	end

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

local function clamp(value, min, max)
	if value < min then
		return min
	elseif value > max then
		return max
	else
		return value
	end
end

local function session_update(session)
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

local function format_time(frames)
	local time = frames * (1 / 60)

	if time >= 1000 then
		return '999.999'
	end

	secs = flr(time)
	msec = flr( ( time - flr(time) ) * 1000 )

	s_sec = tostr(secs)
	if #s_sec == 1 then
		s_sec = '  ' .. s_sec
	elseif #s_sec == 2 then
		s_sec = ' ' .. s_sec
	end

	s_msec = tostr(msec)
	if #s_msec == 1 then
		s_msec = '00' .. s_msec
	elseif #s_msec == 2 then
		s_msec = '0' .. s_msec
	elseif #s_msec == 3 then
	else
		s_msec = sub( s_msec, 1, 3 )
	end

	return s_sec .. '.' .. s_msec
end

local function format2(value)
	if value < 10 then return ' ' .. tostr(value) else return tostr(value) end
end

local function create_caption(session)
	return 'level ' .. format2(session.level) .. '            time ' .. format_time( session.level_frames )
end

local function session_draw(session)
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
	cartdata( 'defiance_of_pico-' .. '459c4f1f-b663-46c5-bb41-2e9ed887bed3')

	if dbg.start_level ~= nil then
		current_session = session_init( MODE_SINGLE_LEVEL, dbg.start_level )
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
		if btnp(0) then
			splash_selected_level = clamp( splash_selected_level - 1, 0, #levels )
		elseif btnp(1) then
			splash_selected_level = clamp( splash_selected_level + 1, 0, #levels )
		elseif btnp(4) then
			if splash_selected_level == 0 then
				current_session = session_init( MODE_ALL_LEVELS )
			else
				current_session = session_init( MODE_SINGLE_LEVEL, splash_selected_level )
			end
			next_page = PAGE_SESSION
		end
	elseif page == PAGE_SESSION then
		session_update( current_session )
	elseif page == PAGE_SUCCESS then
		if btnp(4) or btnp(5) then
			if not current_session.level_record or current_session.level_frames < current_session.level_record then
				dset( current_session.level, current_session.level_frames )
			end

			if current_session.mode == MODE_ALL_LEVELS and current_session.level == #levels then
				if not current_session.total_record or current_session.total_frames < current_session.total_record then
					dset( ALL_LEVELS_SCORE_SLOT, current_session.total_frames )
				end
			end
		end

		if btnp(5) then
			current_session = session_init( current_session.mode, current_session.level, current_session.total_frames )
			next_page = PAGE_SESSION
		elseif btnp(4) then
			if current_session.mode == MODE_ALL_LEVELS then
				if current_session.level + 1 > #levels then
					next_page = PAGE_ENDGAME
				else
					current_session = session_init( current_session.mode, current_session.level + 1, current_session.total_frames )
					next_page = PAGE_SESSION
				end
			else
				current_session = session_init( current_session.mode, current_session.level, current_session.total_frames )
				next_page = PAGE_SESSION
			end
		end
	elseif page == PAGE_FAIL then
		if btnp(4) then
			current_session = session_init( current_session.mode, current_session.level, current_session.total_frames )
			next_page = PAGE_SESSION
		elseif btnp(5) then
			next_page = PAGE_SPLASH
		end
	elseif page == PAGE_REPEAT then
		if btnp(4) then
			current_session = session_init( current_session.mode, current_session.level, current_session.total_frames )
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
		print( '        pico of defiance' )
		print( '' )
		if splash_selected_level == 0 then
			print( '     ⬅️ play all levels ➡️' )
		else
			print( '       ⬅️ play level ' .. splash_selected_level .. ' ➡️' )
		end
		print( '' )
		print( '        press ❎ to play         ' )
	elseif page == PAGE_SESSION then
		session_draw( current_session )
	elseif page == PAGE_SUCCESS then
		session_draw( current_session )
		cursor( 0, 6 * 8 )
		print( '    you collected all crowns!   ' )
		print( '' )
		
		print( '   your level time is ' .. format_time( current_session.level_frames ) )
		if not current_session.level_record or current_session.level_frames < current_session.level_record then
			print( '   new level record!' )
		else
			print( '   record is ' .. format_time( current_session.level_record ) )
		end
		print( '' )

		if current_session.mode == MODE_ALL_LEVELS and current_session.level == #levels then
			print( '   your total time is ' .. format_time( current_session.total_frames ) )
			if not current_session.total_record or current_session.total_frames < current_session.total_record then
				print( '   new all levels record!' )
			else
				print( '   record is ' .. format_time( current_session.total_record ) )
			end
			print( '' )
		end

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