-- mark9.config.lua
local M = {}

M.options = {
	use_telescope = false,
	sign_icon = "⚑",
	virtual_text = true,
	virtual_icon = "🔖",
	virtual_text_pos = "eol", -- options: "eol", "overlay", "right_align"
	window_padding = 1,
}

function M.setup(user_opts)
	M.options = vim.tbl_deep_extend("force", M.options, user_opts or {})
end

return M
