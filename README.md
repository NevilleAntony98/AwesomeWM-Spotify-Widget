# AwesomeWM - Spotify Widget

A simple song info and playback widget for Spotify inspired from [mpd music widgets in manilaromes rice](https://github.com/manilarome/the-glorious-dotfiles)

It uses Spotify's D-Bus interface to fetch title, artist and album cover for the current song and to control playback as well.

## Dependencies
It requires [lua-dbus_proxy](https://github.com/stefano-m/lua-dbus_proxy). You can use `luarocks` to install it:

`luarocks install dbus_proxy --lua-version=5.3`

_Note: you must install it with the right Lua version. I use Awesome v4.3 compiled against Lua v5.3_

## Additional notes:
The widget needs to know if Spotify is running to connect to it's D-Bus interface. One way to do it is to constantly `pgrep` if Spotify is running at every interval, but that seems wasteful. So to be more efficient I made the widget to listen to `"spotify::opened"` signal to set up the D-Bus proxy. So we __MUST__ emit a `"spotify::opened"` whenever we start spotify. You can do that either by:

-   Changing the `Exec` in Spotify's `.desktop` file to also emit the signal while opening:

    ```diff
    - Exec=spotify
    + Exec=sh -c "path/to/my/script"
    ```
    where the script will be something like:

    ```sh
    #!/bin/sh

    spotify &
    awesome-client 'awesome.emit_signal("spotify::opened")'
    ```


-   _OR_, add a client rule for Spotify:

    ```lua
    ruled.client.append_rule {
        rule = {
            class = '[Ss]potify'
        },
        callback = function(c)
            awesome.emit_signal('spotify::opened')
        end
    }
    ```

## Preview

![Preview](preview.png)