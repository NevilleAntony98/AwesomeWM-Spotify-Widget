local awful = require("awful")
local gears = require("gears")
local Proxy = require("dbus_proxy")

local ui_content = require("widget.spotify.content")
local album_cover = ui_content.album_cover
local song_info = ui_content.song_info
local vol_slider = ui_content.volume_slider
local media_buttons = ui_content.media_buttons

local config_dir = gears.filesystem.get_configuration_dir()
local widget_icon_dir = config_dir .. "widget/spotify/icons/"
local EXEC_SPOTIFY = "spotify"
local NEW_COVER_URL = "http://i.scdn.co/image/"
local proxy = nil

local get_song_info = function()
	local song_info = {}

	if proxy ~= nil then
		song_info.title = proxy:Get("org.mpris.MediaPlayer2.Player", "Metadata")["xesam:title"]
		song_info.artist = proxy:Get("org.mpris.MediaPlayer2.Player", "Metadata")["xesam:artist"][1]
		local old_url = proxy:Get("org.mpris.MediaPlayer2.Player", "Metadata")["mpris:artUrl"]
		song_info.cover = string.gsub(old_url, "https://open.spotify.com/image/", NEW_COVER_URL)
	end

	return song_info
end

-- I'm using /dev/shm to avoid writing to disk and possibly faster read/write speeds
local update_cover = function(cover_url)
	local cover_sink = "/dev/shm/spotify_album_cover"
	local download_cover = "curl " .. cover_url .. " > " .. cover_sink .. " --fail --silent --show-error"

	awful.spawn.easy_async_with_shell(
		download_cover,
		function(stdout)
			local album_icon = widget_icon_dir .. "vinyl" .. ".jpg"

			if (stdout == nil or stdout == "") then
				album_icon = cover_sink
			end

			album_cover.cover:set_image(gears.surface.load_uncached(album_icon))
			album_cover:emit_signal("widget::redraw_needed")
			album_cover:emit_signal("widget::layout_changed")
			collectgarbage("collect")
		end
	)
end

local set_default_cover = function()
	local album_icon = widget_icon_dir .. "vinyl" .. ".jpg"
	album_cover.cover:set_image(gears.surface.load_uncached(album_icon))
	album_cover:emit_signal("widget::redraw_needed")
	album_cover:emit_signal("widget::layout_changed")
	collectgarbage("collect")
end

local update_title = function(song_title)
	local title_widget = song_info.music_title
	local title_text = song_info.music_title:get_children_by_id("title")[1]

	local title = "Unknown Title"
	if song_title ~= nil then
		title = song_title
	end

	title_text:set_text(title)
	title_widget:emit_signal("widget::redraw_needed")
	title_widget:emit_signal("widget::layout_changed")
	collectgarbage("collect")
end

local update_artist = function(song_artist)
	local artist_widget = song_info.music_artist
	local artist_text = artist_widget:get_children_by_id("artist")[1]

	local artist = "Unknown Artist"
	if song_artist ~= nil then
		artist = song_artist
	end

	artist_text:set_text(artist)
	artist_widget:emit_signal("widget::redraw_needed")
	artist_widget:emit_signal("widget::layout_changed")
	collectgarbage("collect")
end

local update_buttons = function()
	local play_button_img = media_buttons.play_button_image.play

	if proxy.PlaybackStatus == "Playing" then
		play_button_img:set_image(widget_icon_dir .. "pause.svg")
	else
		play_button_img:set_image(widget_icon_dir .. "play.svg")
	end
end

local update_song_info = function()
	local song_info = get_song_info()
	update_cover(song_info.cover)
	update_title(song_info.title)
	update_artist(song_info.artist)
	update_buttons()
end

local is_spotify_open = false
local on_spotify_stopped = function()
	is_spotify_open = false
	set_default_cover()
	update_title("Play some music!")
	update_artist("Spotify")
	update_buttons()
end

--[[
	On changing/playing/pausing a song, multiple properties such as PlaybackStatus, and several metadata properties change
	which emits multiple "PropertiesChanged" signal through dbus. This causes unnecessary calls to our signal handler when
	actually only a single song changed or a song was played/paused. So to avoid this, a timeout is set during which all
	signals are ignored. 0.6s seems to be a good timeout duration.
--]]
local IGNORE_TIMEOUT = 0.6
local ignore_signals = false
local set_dbus_proxy = function()
		-- If a proxy was already set before just reuse that, since the old connection can still be resused even when the app
		-- is restarted
		if not (proxy == nil) then
			return
		end

		proxy = Proxy.Proxy:new({
			bus = Proxy.Bus.SESSION,
			name = "org.mpris.MediaPlayer2.spotify",
			interface = "org.mpris.MediaPlayer2.Player",
			path = "/org/mpris/MediaPlayer2"
		})

		proxy:on_properties_changed(
			function (p, changed, invalidated)
				-- A simple heuristic to see if spotify was closed. Spotify seems to only have invalidated properties on closing
				for _, v in ipairs(invalidated) do
					on_spotify_stopped()
					return
				end

				if ignore_signals then
					return
				end

				ignore_signals = true;

				update_song_info()

				gears.timer.start_new(IGNORE_TIMEOUT,
				                      function()
				                      	ignore_signals = false
				                      	return false
				                      end)

			end)
	end

awesome.connect_signal(
	"spotify::opened",
	function()
		-- Give Spotify some time to set up their dbus before we ask for a connection
		gears.timer.start_new(1.5,
		                      function()
		                      	is_spotify_open = true
		                      	ignore_signals = false
		                      	set_dbus_proxy()
		                      	return false
		                      end)
	end)


media_buttons.play_button:buttons(
	gears.table.join(
		awful.button(
			{},
			1,
			nil,
			function()
				if not is_spotify_open then
					awful.spawn(EXEC_SPOTIFY, false)
					return
				end

				proxy:PlayPause()
			end
		)
	)
)

media_buttons.next_button:buttons(
	gears.table.join(
		awful.button(
			{},
			1,
			nil,
			function()
				if is_spotify_open then
					proxy:Next()
				end
			end
		)
	)
)

media_buttons.prev_button:buttons(
	gears.table.join(
		awful.button(
			{},
			1,
			nil,
			function()
				if is_spotify_open then
					proxy:Previous()
				end
			end
		)
	)
)
