hs.window.animationDuration = 0

-- window placement -----------------------------------------------------------

local function moveTo(x, w)
	return function()
		local win = hs.window.focusedWindow()
		if not win then
			return
		end
		local f = win:screen():frame()
		win:setFrame({ x = f.x + (f.w * x), y = f.y, w = f.w * w, h = f.h })
	end
end

hs.hotkey.bind({ "ctrl", "alt" }, "h", moveTo(0, 0.5))
hs.hotkey.bind({ "ctrl", "alt" }, "l", moveTo(0.5, 0.5))
hs.hotkey.bind({ "ctrl", "alt" }, "k", moveTo(0, 1)) -- maximize

-- launch or focus an app
local function launcher(appName)
	return function()
		hs.application.launchOrFocus(appName)
	end
end

-- cycle between windows of the frontmost app
local function cycleAppWindows(direction)
	local app = hs.application.frontmostApplication()
	if not app then
		return
	end

	local wins = hs.fnutils.filter(app:allWindows(), function(w)
		return w:isStandard()
	end)
	if #wins < 2 then
		return
	end

	-- stable order so cycling doesn't jump around as focus changes
	table.sort(wins, function(a, b)
		return a:id() < b:id()
	end)

	local current = hs.window.focusedWindow()
	local idx = 1
	if current then
		for i, w in ipairs(wins) do
			if w:id() == current:id() then
				idx = i
				break
			end
		end
	end

	local target = wins[((idx - 1 + direction) % #wins) + 1]
	if target:isMinimized() then
		target:unminimize()
	end
	target:focus()
end

hs.hotkey.bind({ "ctrl", "alt" }, "j", function()
	cycleAppWindows(1)
end)

-- app launchers --------------------------------------------------------------

-- defaults shared by every machine
local apps = {
	F = "Finder",
	[","] = "GitHub Copilot",
	S = "Spotify",
}

-- optional per-machine overrides from ~/.hammerspoon/local.lua (merged over defaults)
local ok, extra = pcall(require, "local")
if ok and type(extra) == "table" then
	for key, name in pairs(extra) do
		apps[key] = name
	end
end

for key, name in pairs(apps) do
	if name then
		hs.hotkey.bind({ "cmd", "ctrl" }, key, launcher(name))
	end
end

-- every other letter/digit under cmd+ctrl tells you it's unbound
-- (Q is left alone so cmd+ctrl+q still locks the screen)
for key in ("0123456789ABCDEFGHIJKLMNOPRSTUVWXYZ"):gmatch(".") do
	if not apps[key] then
		hs.hotkey.bind({ "cmd", "ctrl" }, key, function()
			hs.alert.show("⌃⌘" .. key .. " is not bound to an app")
		end)
	end
end

-- misc -----------------------------------------------------------------------

hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "R", hs.reload)
hs.alert.show("Config loaded" .. (ok and " (+local)" or ""))
