-- Leader key and pane nav/split/resize bindings, plus the QuickSelect-to-nvim
-- flow. Not templated: no per-machine or theme values live here.
local wezterm = require("wezterm")
local act = wezterm.action

local M = {}

-- Leader key: CTRL+; chosen to avoid clashing with shell/readline bindings
-- (CTRL+A/B etc are already claimed by bash/zsh and PSReadLine).
local LEADER = { key = ";", mods = "CTRL", timeout_milliseconds = 1000 }

local function is_nvim(pane)
	return pane:get_user_vars().IS_NVIM == "true"
end

-- Passes CTRL+hjkl through to nvim when nvim owns the pane (nvim sets the
-- IS_NVIM user var on VimEnter/VimLeave — see config/options.lua in the nvim
-- config), otherwise navigates WezTerm panes directly.
local function nav_or_passthrough(direction_wez, key_nvim)
	return wezterm.action_callback(function(window, pane)
		if is_nvim(pane) then
			window:perform_action(act.SendKey({ key = key_nvim, mods = "CTRL" }), pane)
		else
			window:perform_action(act.ActivatePaneDirection(direction_wez), pane)
		end
	end)
end

-- QuickSelect: pick a path:line match on screen and open it directly in nvim.
local function open_selection_in_nvim(window, pane)
	local selection = window:get_selection_text_for_pane(pane)
	local path, line = selection:match("([%w./\\-]+):(%d+)")
	if path then
		window:perform_action(act.SpawnCommandInNewTab({ args = { "nvim", "+" .. line, path } }), pane)
	end
end

-- Held down after LEADER+r: hjkl keep resizing the current pane until
-- Escape/q exits the table, instead of requiring the leader each press.
local RESIZE_PANE = "resize_pane"

function M.apply_to_config(config)
	config.leader = LEADER

	config.keys = {
		{ key = "h", mods = "CTRL", action = nav_or_passthrough("Left", "h") },
		{ key = "j", mods = "CTRL", action = nav_or_passthrough("Down", "j") },
		{ key = "k", mods = "CTRL", action = nav_or_passthrough("Up", "k") },
		{ key = "l", mods = "CTRL", action = nav_or_passthrough("Right", "l") },
		{ key = "\\", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
		{ key = "-", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
		{ key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
		{ key = ".", mods = "LEADER", action = act.ToggleFullScreen },
		{ key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = false }) },
		{ key = "w", mods = "CTRL|SHIFT", action = act.CloseCurrentPane({ confirm = false }) },
		{ key = "v", mods = "LEADER", action = act.ActivateCopyMode },
		{ key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
		{ key = "n", mods = "LEADER", action = act.ActivateTabRelative(1) },
		{ key = "p", mods = "LEADER", action = act.ActivateTabRelative(-1) },
		{
			key = "R",
			mods = "LEADER",
			action = act.PromptInputLine({
				description = "New tab name:",
				action = wezterm.action_callback(function(window, _pane, line)
					if line then
						window:active_tab():set_title(line)
					end
				end),
			}),
		},
		{ key = "r", mods = "LEADER", action = act.ActivateKeyTable({ name = RESIZE_PANE, one_shot = false }) },
		{
			key = "g",
			mods = "LEADER",
			action = act.QuickSelectArgs({
				label = "open in nvim",
				patterns = { "[\\w./\\-]+:\\d+" },
				action = wezterm.action_callback(open_selection_in_nvim),
			}),
		},
	}

	-- Explicit ALT+1-9 tab activation: Windows doesn't reliably fall through
	-- to WezTerm's built-in default for this combo.
	for i = 1, 9 do
		table.insert(config.keys, { key = tostring(i), mods = "ALT", action = act.ActivateTab(i - 1) })
	end

	config.key_tables = {
		[RESIZE_PANE] = {
			{ key = "h", action = act.AdjustPaneSize({ "Left", 3 }) },
			{ key = "j", action = act.AdjustPaneSize({ "Down", 3 }) },
			{ key = "k", action = act.AdjustPaneSize({ "Up", 3 }) },
			{ key = "l", action = act.AdjustPaneSize({ "Right", 3 }) },
			{ key = "Escape", action = "PopKeyTable" },
			{ key = "q", action = "PopKeyTable" },
		},
	}
end

return M
