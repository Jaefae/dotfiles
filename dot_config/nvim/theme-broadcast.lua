-- Tells running nvim instances to switch theme. Run by theme-sync and
-- theme-sync.ps1 as:
--   nvim --clean -l ~/.config/nvim/theme-broadcast.lua <slug> <socket>...
--
-- Sends RPC *notifications* rather than requests (which is what
-- `nvim --server X --remote-expr` uses): a request blocks until the target
-- answers, and an nvim sitting at a prompt ("Press ENTER", input(), ...)
-- defers RPC requests indefinitely, which would hang theme-sync. A
-- notification is queued and runs as soon as that nvim is free.
--
-- Not under lua/ and not init.lua, so nvim never loads it on its own.
local slug = arg[1]
if not slug then
	io.stderr:write("usage: theme-broadcast.lua <slug> <socket>...\n")
	os.exit(1)
end

local channels = {}
for i = 2, #arg do
	-- A stale socket (crashed nvim) just fails to connect.
	local ok, chan = pcall(vim.fn.sockconnect, "pipe", arg[i], { rpc = true })
	if ok and type(chan) == "number" and chan > 0 then
		vim.rpcnotify(chan, "nvim_exec_lua", "require('theme').reload(...)", { slug })
		table.insert(channels, chan)
	end
end

-- Notifications are written asynchronously: let the event loop flush them
-- before this process exits.
vim.wait(100)
for _, chan in ipairs(channels) do
	pcall(vim.fn.chanclose, chan)
end
