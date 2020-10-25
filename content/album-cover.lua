local gears = require("gears")
local wibox = require("wibox")
local dpi = require("beautiful").xresources.apply_dpi
local config_dir = gears.filesystem.get_configuration_dir()
local widget_icon_dir = config_dir .. "widget/spotify/icons/"

local album_cover_img = wibox.widget {
	{
		id = "cover",
		image = widget_icon_dir .. "vinyl.jpg",
		resize = true,
		clip_shape = function(cr, width, height)
			gears.shape.rounded_rect(cr, width, height, dpi(4))
		end,
		widget = wibox.widget.imagebox,
	},
	layout = wibox.layout.fixed.vertical
}


return album_cover_img