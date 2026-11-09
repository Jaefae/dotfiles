-- Leader key and pane nav/split/resize bindings, plus the QuickSelect-to-nvim
-- flow. Not templated: no per-machine or theme values live here.
local wezterm = require("wezterm")
local act = wezterm.action
local filelinks = require("filelinks")

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

-- ---------------------------------------------------------------------------
-- LEADER+g: QuickSelect a file reference on screen and open it in nvim.
-- Recognition/parsing lives in filelinks.lua; this part finds nvim and
-- spawns it.
-- ---------------------------------------------------------------------------

local IS_WINDOWS = wezterm.target_triple:find("windows") ~= nil
local SEP = IS_WINDOWS and "\\" or "/"
local PATH_LIST_SEP = IS_WINDOWS and ";" or ":"

local function file_exists(path)
	local f = io.open(path, "r")
	if f then
		f:close()
		return true
	end
	return false
end

local function is_dir(path)
	return (pcall(wezterm.read_dir, path))
end

local function find_in_path(names, path)
	for dir in path:gmatch("[^" .. PATH_LIST_SEP .. "]+") do
		for _, name in ipairs(names) do
			local candidate = dir .. SEP .. name
			if file_exists(candidate) then
				return candidate
			end
		end
	end
	return nil
end

-- macOS/Linux: WezTerm launched from the Dock/Finder/a desktop launcher
-- inherits the session manager's bare PATH (/usr/bin:/bin:...), without
-- Homebrew or ~/.local/bin. Ask the user's own login+interactive shell for
-- its PATH once (cached until the config reloads) and give it to nvim, so
-- nvim and everything it runs (LSP servers, rg, git) resolve exactly as they
-- do in a normal tab. printf/"$PATH" behave the same in sh, bash, zsh and
-- fish; the marker skips anything the rc files print.
local login_path

local function get_login_path()
	if login_path then
		return login_path
	end
	local shell = os.getenv("SHELL") or "/bin/zsh"
	local ok, success, stdout = pcall(
		wezterm.run_child_process,
		{ shell, "-l", "-i", "-c", 'printf "\\n__WEZTERM_PATH__=%s\\n" "$PATH"' }
	)
	local found = ok and success and stdout and stdout:match("__WEZTERM_PATH__=([^\n]*)")
	if found and found ~= "" then
		login_path = found
	else
		wezterm.log_warn("open-in-nvim: couldn't read PATH from " .. shell .. "; using fallback dirs")
		login_path = table.concat({
			wezterm.home_dir .. "/.local/bin",
			"/opt/homebrew/bin",
			"/usr/local/bin",
			os.getenv("PATH") or "/usr/bin:/bin",
		}, ":")
	end
	return login_path
end

-- Returns (nvim executable, extra env) or nil if nvim can't be found.
local function locate_nvim()
	if IS_WINDOWS then
		-- GUI apps on Windows get the full registry PATH, but it can be stale
		-- if nvim was installed after WezTerm started, so also check the
		-- default install locations (official MSI, winget/scoop shims).
		local local_app_data = os.getenv("LOCALAPPDATA") or ""
		local search = table.concat({
			os.getenv("PATH") or "",
			(os.getenv("ProgramFiles") or "C:\\Program Files") .. "\\Neovim\\bin",
			local_app_data .. "\\Microsoft\\WinGet\\Links",
			wezterm.home_dir .. "\\scoop\\shims",
		}, ";")
		return find_in_path({ "nvim.exe", "nvim.cmd", "nvim.bat" }, search), nil
	end
	local path = get_login_path()
	return find_in_path({ "nvim" }, path), { PATH = path }
end

local function notify(window, message)
	wezterm.log_warn("open-in-nvim: " .. message)
	window:toast_notification("WezTerm", message, nil, 4000)
end

local function open_selection_in_nvim(window, pane)
	local target = filelinks.parse(window:get_selection_text_for_pane(pane))
	if not target then
		return
	end
	if target.url then
		wezterm.open_with(target.url)
		return
	end

	-- Relative paths (the norm in compiler/grep output) resolve against the
	-- originating pane's cwd, not the new tab's default cwd.
	local ok, raw_cwd = pcall(function()
		return pane:get_current_working_dir()
	end)
	local cwd = ok and filelinks.cwd_to_path(raw_cwd) or nil

	-- `git diff` headers print paths as a/<path> and b/<path>.
	local candidates = { target.path }
	local unprefixed = target.path:match("^[ab][/\\](.+)$")
	if unprefixed then
		table.insert(candidates, unprefixed)
	end
	local full
	for _, candidate in ipairs(candidates) do
		local resolved = filelinks.resolve(candidate, cwd, wezterm.home_dir, SEP)
		if file_exists(resolved) or is_dir(resolved) then
			full = resolved
			break
		end
	end
	if not full then
		notify(window, "No such file: " .. target.path .. (cwd and (" (from " .. cwd .. ")") or ""))
		return
	end

	local nvim, env = locate_nvim()
	if not nvim then
		notify(window, "Couldn't find nvim on PATH")
		return
	end

	local args = { nvim }
	if target.line and target.col then
		table.insert(args, string.format("+call cursor(%d,%d)", target.line, target.col))
	elseif target.line then
		table.insert(args, "+" .. target.line)
	end
	table.insert(args, full)

	window:perform_action(
		act.SpawnCommandInNewTab({
			args = args,
			cwd = cwd,
			set_environment_variables = env,
		}),
		pane
	)
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
				patterns = filelinks.patterns,
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
