-- Right-status bar: cwd, git branch (when inside a repo), and a clock.
-- Branch is read straight from .git/HEAD instead of shelling out to `git`
-- (spawning a subprocess there caused visible typing lag). But
-- update-right-status fires on EVERY repaint, including idle cursor-blink
-- animation frames (animation_fps = 60) — not just keystrokes — so even a
-- cheap file read done unconditionally adds up to 60 disk hits/sec per
-- pane. Cache per-cwd and only touch disk every REFRESH_SECONDS.
local wezterm = require("wezterm")

local M = {}

local REFRESH_SECONDS = 2
local branch_cache = {} -- cwd -> { branch = string|false, at = epoch seconds }

local function basename_pair(path)
	local parts = {}
	for part in path:gmatch("[^/\\]+") do
		table.insert(parts, part)
	end
	local n = #parts
	if n == 0 then
		return path
	elseif n == 1 then
		return parts[1]
	end
	return parts[n - 1] .. "/" .. parts[n]
end

local function read_file(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local contents = f:read("*a")
	f:close()
	return contents
end

-- Walks upward from `dir` looking for .git, then resolves HEAD (following
-- the `gitdir:` pointer for worktrees/submodules) into a branch name.
local function git_branch_uncached(dir)
	local current = dir
	for _ = 1, 64 do -- cap the walk; bail rather than loop forever on odd paths
		local git_path = current .. "/.git"
		local info = read_file(git_path .. "/HEAD") -- plain repo: .git is a dir
		if not info then
			local gitfile = read_file(git_path) -- worktree/submodule: .git is a file
			local gitdir = gitfile and gitfile:match("gitdir:%s*(.-)%s*$")
			if gitdir then
				if not gitdir:match("^/") and not gitdir:match("^%a:[/\\]") then
					gitdir = current .. "/" .. gitdir
				end
				info = read_file(gitdir .. "/HEAD")
			end
		end
		if info then
			local branch = info:match("ref:%s*refs/heads/(.-)%s*$")
			return branch or info:sub(1, 7) -- detached HEAD: show short sha
		end

		local parent = current:match("^(.*)[/\\][^/\\]+$")
		if not parent or parent == current then
			return nil
		end
		current = parent
	end
	return nil
end

local function git_branch(dir)
	local now = os.time()
	local cached = branch_cache[dir]
	if cached and (now - cached.at) < REFRESH_SECONDS then
		return cached.branch or nil
	end

	local branch = git_branch_uncached(dir) or false
	branch_cache[dir] = { branch = branch, at = now }
	return branch or nil
end

-- update-right-status itself fires far more often than the status needs to
-- change (every repaint, up to animation_fps), so throttle the whole
-- rebuild too, not just the disk-touching part.
local last_rendered_at = {} -- window_id -> epoch seconds

wezterm.on("update-right-status", function(window, pane)
	local now = os.time()
	local window_id = window:window_id()
	if last_rendered_at[window_id] == now then
		return
	end
	last_rendered_at[window_id] = now

	local palette = window:effective_config().resolved_palette
	local cwd_uri = pane:get_current_working_dir()
	local segments = {}

	if cwd_uri then
		local path = cwd_uri.file_path or tostring(cwd_uri)
		table.insert(segments, { Foreground = { Color = palette.ansi[5] } })
		table.insert(segments, { Text = basename_pair(path) })

		local branch = git_branch(path)
		if branch then
			table.insert(segments, { Foreground = { Color = palette.ansi[3] } })
			table.insert(segments, { Text = "  " .. branch })
		end
	end

	table.insert(segments, { Foreground = { Color = palette.foreground } })
	table.insert(segments, { Text = "  " .. wezterm.strftime("%H:%M") })

	window:set_right_status(wezterm.format(segments))
end)

function M.apply_to_config(_config) end

return M
