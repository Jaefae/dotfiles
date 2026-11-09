-- File-link recognition for the LEADER+g "open in nvim" QuickSelect.
--
-- Pure Lua with no `wezterm` dependency, so the parser can be exercised
-- outside WezTerm (see the self-test at the bottom, run with
-- `nvim -l dot_config/wezterm/filelinks.lua`).
--
-- Two halves that must stay in agreement:
--   * M.patterns: regexes handed to QuickSelectArgs. WezTerm joins them into
--     one `(p1|p2|...)` alternation and matches with fancy_regex, so earlier
--     patterns win at a given start position, and lookbehind is available.
--     They must use only NON-capturing groups: QuickSelect selects the
--     highest-numbered capture group that matched, not the whole match, so a
--     stray `(...)` would hand the parser a fragment.
--   * M.parse(): turns the selected text back into { path, line, col } (or
--     { url } for web links) using Lua patterns.

local M = {}

-- A path component character. Deliberately excludes quotes, brackets,
-- parens, commas and colons, which delimit paths in tool output.
local SEG = [=[[\w.@~+%-]]=]
-- Location suffix: `:12`, `:12:5` (gcc/rg/rustc/go/node), `(12)`, `(12,5)`
-- (MSVC, tsc, dotnet).
local LOC = [=[(?::\d+(?::\d+)?|\(\d+(?:,\s?\d+)?\))]=]
-- Don't start a match in the middle of a token (e.g. the `T18` in an ISO
-- timestamp, or the tail of a longer path).
local START = [=[(?<![\w.@~+%/\\-])]=]

M.patterns = {
	-- Python traceback: File "src/app.py", line 12
	[=[File "[^"\n]+", line \d+]=],
	-- Perl / Tcl style: script.pl line 12
	START .. SEG .. [=[+\.\w+ line \d+]=],
	-- Any URL. Listed before the path patterns so `https://host/a/b` is taken
	-- whole instead of its `//host/a/b` tail being mistaken for a path.
	-- file:// URIs are opened in nvim; other schemes go to the browser.
	[=[\b[A-Za-z][A-Za-z0-9+.-]*://[^\s"'<>`]+]=],
	-- Anything with a path separator, optionally drive-qualified (C:\ or
	-- C:/), optionally with a location: src/main.rs:3:5, ./a.go:7,
	-- C:\proj\Foo.cs(12,5), ~/notes/todo.md, /etc/hosts.
	START .. [=[(?:[A-Za-z]:)?]=] .. SEG .. [=[*(?:[/\\]]=] .. SEG .. [=[+)+[/\\]?]=] .. LOC .. "?",
	-- Bare filename with an extension: init.lua, foo.test.ts:4, Foo.java(9).
	-- (Skips the abbreviations "e.g"/"i.e", which otherwise look like one.)
	START .. [=[(?!(?:e\.g|i\.e)\b)]=] .. SEG .. [=[*[\w-]\.[A-Za-z]\w*]=] .. LOC .. "?",
	-- Bare dotfile: .zshrc, .gitignore.
	START .. [=[\.[A-Za-z][\w.-]*]=] .. LOC .. "?",
	-- Bare extensionless name, but only with a location (otherwise every
	-- word on screen would match): Makefile:12, Dockerfile:3.
	-- localhost:PORT is excluded since it is never a file.
	START .. [=[(?!localhost:)[A-Za-z_]\w*]=] .. LOC,
}

local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function percent_decode(s)
	return (s:gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end))
end

-- Splits a trailing location suffix off a path. Greedy `.+` before the
-- final `:N` keeps a Windows drive colon (C:\x.lua:12) in the path.
local function split_location(s)
	local path, line, col = s:match("^(.-)%((%d+),%s?(%d+)%)$")
	if path then
		return path, line, col
	end
	path, line = s:match("^(.-)%((%d+)%)$")
	if path then
		return path, line
	end
	path, line, col = s:match("^(.+):(%d+):(%d+)$")
	if path then
		return path, line, col
	end
	path, line = s:match("^(.+):(%d+)$")
	if path then
		return path, line
	end
	return s
end

-- Drops sentence punctuation that the regexes can swallow at the end of a
-- path ("see src/foo.lua."), while leaving `.`/`..`/`foo/..` intact.
local function strip_trailing_punctuation(path)
	path = path:gsub("[,;:]+$", "")
	if #path > 1 and path:sub(-1) == "." and not path:match("[./\\]%.$") then
		path = path:sub(1, -2)
	end
	return path
end

local function to_number(n)
	return n and tonumber(n) or nil
end

-- Returns one of:
--   { path = "...", line = 12|nil, col = 5|nil }
--   { url = "https://..." }
--   nil (nothing usable in the selection)
function M.parse(selection)
	if not selection then
		return nil
	end
	local s = trim(selection)
	if s == "" then
		return nil
	end

	local py_path, py_line = s:match('^File "(.+)", line (%d+)$')
	if py_path then
		return { path = py_path, line = to_number(py_line) }
	end

	local pl_path, pl_line = s:match("^(%S+) line (%d+)$")
	if pl_path then
		return { path = pl_path, line = to_number(pl_line) }
	end

	local scheme, rest = s:match("^(%a[%w+.-]*)://(.*)$")
	if scheme then
		if scheme:lower() ~= "file" then
			-- Trailing punctuation is almost always prose, not part of the URL.
			return { url = (s:gsub("[.,;:!?)%]'\"]+$", "")) }
		end
		-- file://host/path or file:///path; only local files make sense.
		local host, path = rest:match("^([^/]*)(/.*)$")
		if not host or (host ~= "" and host ~= "localhost") then
			return nil
		end
		path = percent_decode(path)
		-- file:///C:/x -> C:/x
		path = path:gsub("^/(%a:[/\\])", "%1")
		local p, line, col = split_location(path)
		return { path = p, line = to_number(line), col = to_number(col) }
	end

	local path, line, col = split_location((s:gsub("[,;:]+$", "")))
	path = strip_trailing_punctuation(path)
	if path == "" then
		return nil
	end
	return { path = path, line = to_number(line), col = to_number(col) }
end

function M.is_absolute(path)
	return path:match("^/") ~= nil
		or path:match("^%a:[/\\]") ~= nil
		or path:match("^\\\\") ~= nil
end

-- Resolves `path` against `cwd`, expanding a leading `~`.
function M.resolve(path, cwd, home, sep)
	sep = sep or "/"
	if home and (path == "~" or path:match("^~[/\\]")) then
		path = home .. path:sub(2)
	end
	if M.is_absolute(path) or not cwd or cwd == "" then
		return path
	end
	path = path:gsub("^%.[/\\]", "")
	if cwd:sub(-1) == "/" or cwd:sub(-1) == "\\" then
		return cwd .. path
	end
	return cwd .. sep .. path
end

-- Converts what pane:get_current_working_dir() returns into a local
-- filesystem path. Newer WezTerm returns a Url object (with .file_path);
-- older builds return a "file://host/path" string. On Windows the path
-- comes back as "/C:/Users/..." and needs its leading slash dropped.
function M.cwd_to_path(cwd)
	if cwd == nil then
		return nil
	end
	local path
	if type(cwd) == "string" then
		local rest = cwd:match("^file://[^/]*(/.*)$")
		path = rest and percent_decode(rest) or cwd
	else
		path = cwd.file_path
	end
	if not path or path == "" then
		return nil
	end
	return (path:gsub("^/(%a:[/\\])", "%1"))
end

-- Self-test: `nvim -l dot_config/wezterm/filelinks.lua` (any Lua 5.1+
-- interpreter works). Exits non-zero on the first failure.
if arg and arg[0] and arg[0]:match("filelinks%.lua$") then
	local cases = {
		{ "src/main.rs:3:5", { path = "src/main.rs", line = 3, col = 5 } },
		{ "./main.go:12", { path = "./main.go", line = 12 } },
		{ "my_file.lua:7:", { path = "my_file.lua", line = 7 } },
		{ "my_file.lua:7", { path = "my_file.lua", line = 7 } },
		{ "/abs/path/x.js:1:2", { path = "/abs/path/x.js", line = 1, col = 2 } },
		{ "~/notes/todo.md", { path = "~/notes/todo.md" } },
		{ "src/app.ts(12,5)", { path = "src/app.ts", line = 12, col = 5 } },
		{ "foo.cpp(42)", { path = "foo.cpp", line = 42 } },
		{ [[C:\proj\Foo.cs(12,5)]], { path = [[C:\proj\Foo.cs]], line = 12, col = 5 } },
		{ [[C:\proj\Foo.cs:12]], { path = [[C:\proj\Foo.cs]], line = 12 } },
		{ [[C:\proj\Foo.cs]], { path = [[C:\proj\Foo.cs]] } },
		{ 'File "src/app.py", line 88', { path = "src/app.py", line = 88 } },
		{ "script.pl line 12", { path = "script.pl", line = 12 } },
		{ "file:///Users/me/a%20b.lua:3", { path = "/Users/me/a b.lua", line = 3 } },
		{ "file:///C:/proj/x.lua", { path = "C:/proj/x.lua" } },
		{ "file://otherhost/x.lua", false },
		{ "https://github.com/a/b.", { url = "https://github.com/a/b" } },
		{ "src/foo.lua.", { path = "src/foo.lua" } },
		{ "..", { path = ".." } },
		{ "Makefile:12", { path = "Makefile", line = 12 } },
		{ ".zshrc", { path = ".zshrc" } },
	}
	local function same(a, b)
		if a == nil or b == nil or a == false or b == false then
			return (a or false) == (b or false)
		end
		for _, k in ipairs({ "path", "line", "col", "url" }) do
			if a[k] ~= b[k] then
				return false
			end
		end
		return true
	end
	local function show(t)
		if not t then
			return "nil"
		end
		return string.format("{path=%s line=%s col=%s url=%s}", tostring(t.path), tostring(t.line), tostring(t.col), tostring(t.url))
	end

	local failed = 0
	for _, c in ipairs(cases) do
		local got = M.parse(c[1])
		if not same(got, c[2]) then
			failed = failed + 1
			print("FAIL parse(" .. c[1] .. ") = " .. show(got) .. ", want " .. show(c[2] or nil))
		end
	end

	local resolves = {
		{ { "src/a.lua", "/proj" }, "/proj/src/a.lua" },
		{ { "./a.lua", "/proj/" }, "/proj/a.lua" },
		{ { "~/a.lua", "/proj", "/Users/me" }, "/Users/me/a.lua" },
		{ { "/etc/hosts", "/proj" }, "/etc/hosts" },
		{ { [[C:\x\a.lua]], [[D:\y]], nil, "\\" }, [[C:\x\a.lua]] },
		{ { "a.lua", [[C:\proj]], nil, "\\" }, [[C:\proj\a.lua]] },
	}
	for _, r in ipairs(resolves) do
		local got = M.resolve(r[1][1], r[1][2], r[1][3], r[1][4])
		if got ~= r[2] then
			failed = failed + 1
			print("FAIL resolve(" .. r[1][1] .. ") = " .. got .. ", want " .. r[2])
		end
	end

	local cwds = {
		{ { file_path = "/C:/Users/me" }, "C:/Users/me" },
		{ { file_path = "/Users/me" }, "/Users/me" },
		{ "file://mac.local/Users/me/my%20dir", "/Users/me/my dir" },
		{ "file://host/C:/x", "C:/x" },
	}
	for _, c in ipairs(cwds) do
		local got = M.cwd_to_path(c[1])
		if got ~= c[2] then
			failed = failed + 1
			print("FAIL cwd_to_path = " .. tostring(got) .. ", want " .. c[2])
		end
	end

	if failed > 0 then
		print(failed .. " failure(s)")
		os.exit(1)
	end
	print("filelinks: all " .. (#cases + #resolves + #cwds) .. " checks passed")
end

return M
