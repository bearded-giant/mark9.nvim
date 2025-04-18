-- mark9/init.lua
local M = {}

function M.setup(opts)
	require("mark9.config").setup(opts or {})
	require("mark9.marks").setup()
end

return M
