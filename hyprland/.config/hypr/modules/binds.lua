---------------------
---- MY PROGRAMS ----
---------------------

-- terminal and browser can be changed with `orrery-default terminal|browser <name>`
-- (Menu › Settings › Default apps); the files hold just the command name.
local function default_app(kind, fallback)
	local f = io.open(os.getenv("HOME") .. "/.config/orrery/defaults/" .. kind)
	if not f then
		return fallback
	end
	local v = f:read("*l")
	f:close()
	return (v and v ~= "") and v or fallback
end
-- the first of these that is installed (a fresh machine may have no zen)
local function installed(names)
	for _, n in ipairs(names) do
		local p = io.popen("command -v " .. n .. " 2>/dev/null")
		local out = p and p:read("*l") or nil
		if p then
			p:close()
		end
		if out and out ~= "" then
			return n
		end
	end
	return names[1]
end
local terminal = default_app("terminal", "kitty")
local fileManager = "thunar"
local browser = default_app("browser", installed({ "zen-browser", "firefox", "chromium", "brave" }))

local mainMod = "SUPER"

---------------------
---- KEYBINDINGS ----
---------------------

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal)) -- Terminal
hl.bind(mainMod .. " + Q", hl.dsp.window.close()) -- Close window
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("~/.config/hypr/scripts/powermenu.sh")) -- Power menu
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager)) -- File manager
hl.bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" })) -- Float window
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("~/.config/hypr/scripts/launcher.sh")) -- App launcher
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- Toggle split
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("~/.config/hypr/scripts/lock.sh")) -- Lock screen
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("~/.config/hypr/scripts/browser.sh " .. browser)) -- Browser (debounced)
hl.bind(mainMod .. " + CTRL + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/shell.sh restart")) -- Restart the shell
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("qs ipc call bar toggle")) -- Bar style: Legacy, Floating, Minimal
hl.bind(mainMod .. " + CTRL + I", hl.dsp.exec_cmd("~/.config/hypr/scripts/caffeine.sh toggle")) -- Caffeine (stay awake)
hl.bind(mainMod .. " + CTRL + SHIFT + space", hl.dsp.exec_cmd("orrery-theme-menu theme")) -- Theme picker
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("orrery-theme-menu wallpaper")) -- Wallpaper picker
hl.bind(mainMod .. " + CTRL + space", hl.dsp.exec_cmd("orrery-wall next")) -- Next wallpaper
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("orrery-agent launch")) -- Default coding agent
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd("qs ipc call menu toggle")) -- The menu
hl.bind(mainMod .. " + CTRL + O", hl.dsp.exec_cmd("qs ipc call menu open toggle")) -- The menu, opened on Toggle

-- Screenshots (scripts/screenshot.sh): saved to ~/Pictures/screenshot and
-- copied to the clipboard. Esc, or the same shortcut again, cancels a selection.
local shot = "~/.config/hypr/scripts/screenshot.sh "
hl.bind("Print", hl.dsp.exec_cmd(shot .. "region")) -- Screenshot a region
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd(shot .. "screen")) -- Screenshot the whole screen
hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd(shot .. "pick")) -- Screenshot a window (click it)

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" })) -- Focus left
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" })) -- Focus right
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" })) -- Focus up
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" })) -- Focus down

-- Move the active window with mainMod + SHIFT + arrow keys
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" })) -- Move window left
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" })) -- Move window right
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" })) -- Move window up
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" })) -- Move window down

-- Resize the active window with mainMod + CTRL + arrow keys (hold to keep going)
hl.bind(mainMod .. " + CTRL + left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true }) -- Resize narrower
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }), { repeating = true }) -- Resize wider
hl.bind(mainMod .. " + CTRL + up", hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true }) -- Resize shorter
hl.bind(mainMod .. " + CTRL + down", hl.dsp.window.resize({ x = 0, y = 40, relative = true }), { repeating = true }) -- Resize taller

-- Workspaces 1-10, and move-window-to-workspace.
for i = 1, 10 do
	local key = i % 10 -- workspace 10 maps to key 0
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic")) -- Scratchpad
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" })) -- Move window to scratchpad

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" })) -- Next workspace
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" })) -- Previous workspace

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true }) -- Move window (drag)
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true }) -- Resize window (drag)

hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
) -- Volume up
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
) -- Volume down
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true } -- a toggle: holding the key must not flip it again and again
) -- Mute
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true }
) -- Mute microphone
hl.bind(
	"XF86MonBrightnessUp",
	hl.dsp.exec_cmd("~/.config/hypr/scripts/brightness.sh up"),
	{ locked = true, repeating = true }
) -- Brightness up
hl.bind(
	"XF86MonBrightnessDown",
	hl.dsp.exec_cmd("~/.config/hypr/scripts/brightness.sh down"),
	{ locked = true, repeating = true }
) -- Brightness down

-- Media keys (playerctl); these work on the lock screen too
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true }) -- Media next
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true }) -- Media play/pause
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true }) -- Media play/pause
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true }) -- Media previous

hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" })) -- Fullscreen
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized" })) -- Maximize

hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("~/.config/hypr/scripts/clipboard.sh")) -- Clipboard history

-- Your own binds go in binds.local.lua next to this file: it is loaded
-- after this one (so it can rebind a key) and is not part of the repo.
local f = io.open(os.getenv("HOME") .. "/.config/hypr/modules/binds.local.lua")
if f then f:close(); pcall(dofile, os.getenv("HOME") .. "/.config/hypr/modules/binds.local.lua") end
