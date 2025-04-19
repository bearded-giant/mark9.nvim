local M = {}

-- default options
M.options = {
	use_telescope = false,
	sign_icon = "📌",
	virtual_text = true,
	virtual_icon = "🔖",
	virtual_text_pos = "eol",
	highlight_line = true,
	highlight_group = "Visual",
	horizontal_padding = 2,
	window_padding = 2,
	window_position = "center", -- center | top_left | top_right | bottom_left | bottom_right
	window_width_percent = 0.4,
	mark_chars = { "A", "B", "C", "D", "E", "F", "G", "H", "I" },
}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

return M
