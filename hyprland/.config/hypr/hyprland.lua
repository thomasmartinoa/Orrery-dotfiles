require("modules/env")
require("modules/autostart")
require("modules/binds")
require("modules/monitors")
require("modules/decorations")
require("modules/windowrules")

-- Theme colours (borders, shadow) rendered by `orrery-theme set <name>`.
-- Loaded last so they override anything in the modules. pcall: a fresh
-- install has no current/ yet, and a missing theme must not break Hyprland.
pcall(dofile, os.getenv("HOME") .. "/.config/orrery/current/hyprland.lua")
-- ...and your corners and border from orrery-border after the theme's, so
-- they win over a theme's radius
local look = io.open(os.getenv("HOME") .. "/.config/hypr/modules/look.local.lua")
if look then look:close(); pcall(dofile, os.getenv("HOME") .. "/.config/hypr/modules/look.local.lua") end

-----------------
---- XWAYLAND ---
-----------------

hl.config({
	xwayland = {
		force_zero_scaling = true,
	},
})
---------------
---- INPUT ----
---------------
hl.config({
	input = {
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		kb_options = "",
		kb_rules = "",
		numlock_by_default = true,

		follow_mouse = 1,

		sensitivity = 0, 

		touchpad = {
			natural_scroll = true,
		},
	},
})


hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

-- hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })

-- Your own Hyprland settings (keyboard layout, touchpad, anything above), in
-- ~/.config/hypr/hyprland.local.lua: loaded last, so it wins, and not part of
-- the repo, so updates never touch it. For example:
--   hl.config({ input = { kb_layout = "de" } })
local own = io.open(os.getenv("HOME") .. "/.config/hypr/hyprland.local.lua")
if own then own:close(); pcall(dofile, os.getenv("HOME") .. "/.config/hypr/hyprland.local.lua") end
