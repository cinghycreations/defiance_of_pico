local BUILD_VERSION = '1.0'

local TILE_EMPTY = 0
local TILE_CROWN = 3
local TILE_SHELF = 1
local TILE_BOOSTER = 2
local TILE_SPIKES = 4

local SFX_JUMP = 10
local SFX_JUMP_TRAMPOLINE = 11
local SFX_COLLECT_CROWN = 12
local SFX_SPIKE = 13
local SFX_WIN = 14

local PAGE_SPLASH = 0
local PAGE_RECORDS = 5
local PAGE_SESSION = 1
local PAGE_SUCCESS = 2
local PAGE_FAIL = 3
local PAGE_REPEAT = 4

local MODE_ALL_LEVELS = 0
local MODE_SINGLE_LEVEL = 1

local ALL_LEVELS_SCORE_SLOT = 0

local page = nil
local next_page = nil
local current_session = nil

local splash_selected_level = 0
local records_page_data = nil

local dbg = {
	start_level = nil,
	no_hud = false,
	no_death = false,
}

local function session_init(mode, starting_level, frames)
	local session = {}
	session.mode = mode or MODE_ALL_LEVELS
	session.level = starting_level or 1
	session.camera_offset = 0
	session.platform_speed = 1.2
	session.platform_offset = 0
	session.ball_position = { 0, 256 - 8 }
	session.ball_speed = 0
	session.ball_impulse = -3.25
	session.ball_booster_impulse = -5
	session.ball_gravity = 9.81
	session.crowns_left = 0
	session.frames = frames or 0
	session.record = nil

	if session.mode == MODE_ALL_LEVELS then
		record = dget( ALL_LEVELS_SCORE_SLOT )
	else
		record = dget( session.level )
	end
	if record ~= 0 then
		session.record = record
	end

	if session.level <= 4 then
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
	if btnp(❎) or btnp(🅾️) then
		next_page = PAGE_REPEAT
		return
	end

	local elapsed_time = 1 / 60

	-- frames
	session.frames = session.frames + 1

	-- platform
	if btn(⬅️) then session.platform_offset = session.platform_offset - session.platform_speed end
	if btn(➡️) then session.platform_offset = session.platform_offset + session.platform_speed end
	session.platform_offset = clamp( session.platform_offset, 4, 128 - 4 )

	-- ball gravity
	session.ball_position[1] = session.platform_offset
	session.ball_speed = session.ball_speed + session.ball_gravity * elapsed_time
	session.ball_position[2] = session.ball_position[2] + session.ball_speed

	-- collisions

	local corner_sample_offsets = { { -2, -2 }, { -2, 2 }, { 2, -2 }, { 2, 2 }  }
	for key, value in pairs( corner_sample_offsets ) do
		crown_cell = { flr( ( session.ball_position[1] + value[1] ) / 8 ), flr( ( session.ball_position[2] + value[2] ) / 8 ) }
		crown_tile = mget( crown_cell[1], crown_cell[2] )

		if crown_tile == TILE_CROWN then
			session.crowns_left = session.crowns_left - 1
			mset( crown_cell[1], crown_cell[2], TILE_EMPTY )
			sfx( SFX_COLLECT_CROWN )
		end
	end

	local ground_sample_offsets = { { -2, 4 }, { 0, 4 }, { 2, 4 } }
	for key, value in pairs( ground_sample_offsets ) do
		ground_cell = { flr( ( session.ball_position[1] + value[1] ) / 8 ), flr( ( session.ball_position[2] + value[2] ) / 8 ) }
		ground_tile = mget( ground_cell[1], ground_cell[2] )

		if session.ball_speed > 0 then
			if ground_tile == TILE_SHELF or ground_cell[2] == 31 then
				session.ball_position[2] = ground_cell[2] * 8 - 4
				session.ball_speed = session.ball_impulse
				sfx( SFX_JUMP )
			elseif ground_tile == TILE_BOOSTER then
				session.ball_position[2] = ground_cell[2] * 8 - 4
				session.ball_speed = session.ball_booster_impulse
				sfx( SFX_JUMP_TRAMPOLINE )
			end
		end
	end

	-- success
	if session.crowns_left == 0 then
		next_page = PAGE_SUCCESS
		sfx( SFX_WIN )
		return
	end

	-- fail
	if not dbg.no_death then
		center_cell = { flr( session.ball_position[1] / 8 ), flr( session.ball_position[2] / 8 ) }
		center_tile = mget( center_cell[1], center_cell[2] )
		if center_tile == TILE_SPIKES then
			next_page = PAGE_FAIL
			sfx( SFX_SPIKE )
			return
		end
	end
end

local function format_time(frames)
	if frames == 0 then
		return '   none'
	end

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
	return 'level ' .. format2(session.level) .. '            time ' .. format_time( session.frames )
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
	cartdata( 'defiance_of_pico_' .. 'v0-1')

	music( 0 )
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
	if next_page ~= nil then
		if next_page == PAGE_SPLASH then
			if page ~= PAGE_RECORDS then
				music( 0 )
			end
		elseif next_page == PAGE_SESSION or next_page == PAGE_SUCCESS or next_page == PAGE_FAIL or next_page == PAGE_REPEAT then
			music( -1 )
		elseif next_page == PAGE_RECORDS then
		end
	end

	page = next_page or page
	next_page = nil

	if page == PAGE_SPLASH then
		if btnp(⬅️) then
			splash_selected_level = clamp( splash_selected_level - 1, 0, #levels )
		elseif btnp(➡️) then
			splash_selected_level = clamp( splash_selected_level + 1, 0, #levels )
		elseif btnp(❎) then
			if splash_selected_level == 0 then
				current_session = session_init( MODE_ALL_LEVELS )
			else
				current_session = session_init( MODE_SINGLE_LEVEL, splash_selected_level )
			end
			next_page = PAGE_SESSION
		elseif btnp(🅾️) then
			next_page = PAGE_RECORDS
			records_page_data = nil
		end
	elseif page == PAGE_RECORDS then
		if records_page_data == nil then
			records_page_data = {}
			records_page_data[ALL_LEVELS_SCORE_SLOT] = dget( ALL_LEVELS_SCORE_SLOT )
			for level = 1, #levels do
				records_page_data[level] = dget( level )
			end
		end

		if btnp(🅾️) then
			next_page = PAGE_SPLASH
		end
	elseif page == PAGE_SESSION then
		session_update( current_session )
	elseif page == PAGE_SUCCESS then
		if btnp(❎) or btnp(🅾️) then
			if current_session.mode == MODE_ALL_LEVELS then
				if current_session.level == #levels and ( not current_session.record or current_session.frames < current_session.record ) then
					dset( ALL_LEVELS_SCORE_SLOT, current_session.frames )
				end
			else
				if not current_session.record or current_session.frames < current_session.record then
					dset( current_session.level, current_session.frames )
				end
			end
		end

		if btnp(🅾️) then
			next_page = PAGE_SPLASH
		elseif btnp(❎) then
			if current_session.mode == MODE_ALL_LEVELS then
				if current_session.level + 1 > #levels then
					next_page = PAGE_SPLASH
				else
					current_session = session_init( current_session.mode, current_session.level + 1, current_session.frames )
					next_page = PAGE_SESSION
				end
			else
				current_session = session_init( current_session.mode, current_session.level )
				next_page = PAGE_SESSION
			end
		end
	elseif page == PAGE_FAIL then
		if btnp(❎) then
			if current_session.mode == MODE_ALL_LEVELS then
				current_session = session_init( current_session.mode, current_session.level, current_session.frames )
			else
				current_session = session_init( current_session.mode, current_session.level )
			end
			next_page = PAGE_SESSION
		elseif btnp(🅾️) then
			next_page = PAGE_SPLASH
		end
	elseif page == PAGE_REPEAT then
		if btnp(❎) then
			if current_session.mode == MODE_ALL_LEVELS then
				current_session = session_init( current_session.mode, current_session.level, current_session.frames )
			else
				current_session = session_init( current_session.mode, current_session.level )
			end
			next_page = PAGE_SESSION
		elseif btnp(🅾️) then
			next_page = PAGE_SPLASH
		end
	end
end

function _draw()
	if page == PAGE_SPLASH then
		cls()
		map( 48, 0, 0, 0, 16, 16 )
		cursor( 0, 11 * 6 )
		if splash_selected_level == 0 then
			print( '     ⬅️ full playthrough ➡️' )
		else
			print( '          ⬅️ level ' .. splash_selected_level .. ' ➡️' )
		end
		print( '' )
		print( '        press ❎ to play' )
		print( '    press 🅾️ to show records' )
		cursor( 0, 19 * 6 )
		print( '   a game by cinghy creations   ' )
		print( 'sfx by gruber  music by snabisch\0' )
	elseif page == PAGE_RECORDS then
		cls()
		map( 48, 0, 0, 0, 16, 16 )
		cursor( 0, 8 * 6 )
		for level = 1, #levels do
			print( '       level ' .. level .. '     ' .. format_time( records_page_data[level] ) )
		end
		print( '  full playthrough ' .. format_time( records_page_data[ALL_LEVELS_SCORE_SLOT] ) )
		print( '' )
		print( '       press 🅾️ to go back' )
		cursor( 0, 20 * 6 )
		print( 'v' .. BUILD_VERSION .. '\0' )
	elseif page == PAGE_SESSION then
		session_draw( current_session )
	elseif page == PAGE_SUCCESS then
		session_draw( current_session )
		cursor( 0, 6 * 8 )
		print( '    you collected all crowns!   ' )
		print( '' )
		
		if current_session.mode == MODE_SINGLE_LEVEL or ( current_session.mode == MODE_ALL_LEVELS and current_session.level == #levels ) then
			print( '      your time is ' .. format_time( current_session.frames ) )
			if not current_session.record or current_session.frames < current_session.record then
				print( '          new record!' )
			else
				print( '   record is ' .. format_time( current_session.record ) )
			end
			print( '' )
		end

		if current_session.mode == MODE_ALL_LEVELS then
			print( '       press ❎ to proceed' )
			print( '       press 🅾️ to quit' )
		else
			print( '       press ❎ to retry' )
			print( '       press 🅾️ to quit' )
		end
	elseif page == PAGE_FAIL then
		session_draw( current_session )
		cursor( 0, 7 * 8 )
		print( ' argh! you ended up on a spike.' )
		print( '        press ❎ to retry' )
		print( '       press 🅾️ to quit' )
	elseif page == PAGE_REPEAT then
		session_draw( current_session )
		cursor( 0, 7 * 8 )
		print( ' do you want to retry, or quit? ' )
		print( '       press ❎ to retry' )
		print( '        press 🅾️ to quit' )
	end
end
