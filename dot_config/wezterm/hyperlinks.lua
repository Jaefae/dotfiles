-- Custom hyperlink rules on top of WezTerm's defaults.
local wezterm = require("wezterm")

local M = {}

function M.apply_to_config(config)
	local rules = wezterm.default_hyperlink_rules()
	-- GitHub owner/repo#123 shorthand -> issue/PR link.
	table.insert(rules, {
		regex = [[\b([\w\-]+/[\w\-]+)#(\d+)\b]],
		format = "https://github.com/$1/issues/$2",
	})
	config.hyperlink_rules = rules
end

return M
