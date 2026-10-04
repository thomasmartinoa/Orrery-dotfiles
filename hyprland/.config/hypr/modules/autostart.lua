

hl.on("hyprland.start", function()
    hl.exec_cmd("~/.config/hypr/scripts/shell.sh start")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    --hl.exec_cmd("systemctl --user start hyprpolkitagent")
   -- hl.exec_cmd("xdg-desktop-portal-hyprland")
    hl.exec_cmd("batsignal -b")
    hl.exec_cmd("wl-paste --watch cliphist store")
    -- apps installed or first opened since the last theme switch (Firefox,
    -- VS Code) get the current theme now
    hl.exec_cmd("~/.local/bin/orrery-theme apps")
end)
