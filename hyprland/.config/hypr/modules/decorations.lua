-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 7,

        border_size = 1,

        -- col.active_border / inactive_border: from orrery-theme (see hyprland.lua)

        resize_on_border = false,
        allow_tearing    = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 4,
        rounding_power = 4,

        active_opacity   = 0.9,
        inactive_opacity = 0.7,
        dim_inactive     = false,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            -- color: from orrery-theme (see hyprland.lua)
        },

        blur = {
            enabled           = true,
            size              = 8,
            passes            = 3,
            ignore_opacity    = true,
            new_optimizations = true,
            vibrancy          = 0.1696,
            -- xray           = false,
        },
    },

    animations = {
        enabled = true,
    },
})


-------------------
---- ANIMATION ----
-------------------

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1} } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1} } })
-- the shell's own motion (quickshell Commons/Motion.qml): every overlay the
-- shell opens uses these, with the same 320 ms in / 180 ms out as its panels
hl.curve("orreryIn",       { type = "bezier", points = { {0.05, 0.7},  {0.1, 1} } })
hl.curve("orreryOut",      { type = "bezier", points = { {0.3, 0},     {0.8, 0.15} } })
-- Material 3 Expressive "default spatial": a small overshoot, then settle
hl.curve("orreryLand",     { type = "bezier", points = { {0.38, 1.21}, {0.22, 1} } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 2,    bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 5,    bezier = "orreryLand",   style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.8,  bezier = "orreryOut",    style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 2,    bezier = "orreryIn" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.8,  bezier = "orreryOut" })
-- popups (the bar's panels, app menus): the shell animates its panels itself,
-- so Hyprland only fades them in briefly and removes them at once; with its
-- default 300 ms fade the old panel ghosted over the new one on a switch
hl.animation({ leaf = "fadePopupsIn",  enabled = true, speed = 1.5,  bezier = "orreryIn" })
hl.animation({ leaf = "fadePopupsOut", enabled = false })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })


--newer upstream feel for window motion:
--hl.curve("easy", { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })
--hl.animation({ leaf = "windows", enabled = true, speed = 4.79, spring = "easy" })


-------------------------
---- WORKSPACE RULES ----
-------------------------

-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({ name = "no-gaps-wtv1", match = { float = false, workspace = "w[tv1]" }, border_size = 0, rounding = 0 })
-- hl.window_rule({ name = "no-gaps-f1",   match = { float = false, workspace = "f[1]"   }, border_size = 0, rounding = 0 })


-----------------
---- LAYOUTS ----
-----------------

hl.config({
    dwindle = {

        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    -- No stock wallpaper, logo or splash: until the shell's wallpaper fades in
    -- (a second or two after login), the screen is the theme's own background
    -- colour (misc.background_color, set by orrery-theme in current/hyprland.lua)
    misc = {
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
    },
})

-- Corners and border thickness chosen in Menu > Appearance > Corners & borders
-- (orrery-border): look.local.lua, next to this file, is loaded after it and
-- is not part of the repo.
local look = io.open(os.getenv("HOME") .. "/.config/hypr/modules/look.local.lua")
if look then look:close(); pcall(dofile, os.getenv("HOME") .. "/.config/hypr/modules/look.local.lua") end
