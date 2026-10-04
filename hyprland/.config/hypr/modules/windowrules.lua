-------------------
---- LAYER RULES --
-------------------

-- The Quickshell shell
-- the shell's overlays only fade here: the shell scales their card itself
-- (Commons/Arrive.qml), so the dimmed backdrop and its blur never zoom
hl.layer_rule({ match = { namespace = "^orrery-powermenu$" },      blur = true, ignore_alpha = 0.7, animation = "fade" })
hl.layer_rule({ match = { namespace = "^orrery-notifications$" },  blur = true, ignore_alpha = 0.4, animation = "slide right" })
hl.layer_rule({ match = { namespace = "^orrery-control-center$" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "^orrery-picker$" },         blur = true, ignore_alpha = 0.7, animation = "fade" })
hl.layer_rule({ match = { namespace = "^orrery-launcher$" },       blur = true, ignore_alpha = 0.5, animation = "fade" })
hl.layer_rule({ match = { namespace = "^orrery-clipboard$" },      blur = true, ignore_alpha = 0.5, animation = "fade" })
hl.layer_rule({ match = { namespace = "^orrery-menu$" },           blur = true, ignore_alpha = 0.5, animation = "fade" })
-- the bar re-anchors when it moves to another edge; animated, that resize
-- stretched it across the screen for a few frames
hl.layer_rule({ match = { namespace = "^orrery-bar$" },            no_anim = true })
hl.layer_rule({ match = { namespace = "^orrery-bar-ghost$" },      no_anim = true })
hl.layer_rule({ match = { namespace = "^orrery-dock$" },           no_anim = true })   -- the dock slides itself
hl.layer_rule({ match = { namespace = "^orrery-dock$" },           blur = true, ignore_alpha = 0.5 })

--------------------
---- WINDOW RULES --
--------------------

-- floating terminal for menu actions (orrery-float, orrery-edit): centred, medium.
-- size takes expressions, not percentages ("60%" is silently ignored)
hl.window_rule({
	name = "orrery-float",
	match = { class = "^orrery-float$" },
	float = true,
	size = { "monitor_w * 0.78", "monitor_h * 0.82" },
	-- centred, 12px above the middle so its bottom clears a bottom dock
	-- (window_w is the size before the size rule, so use the same fractions)
	move = { "monitor_w * 0.11", "monitor_h * 0.09 - 12" },
})

hl.window_rule({
	name = "idle-inhibit-fullscreen",
	match = { fullscreen = true },
	idle_inhibit = "fullscreen",
})
