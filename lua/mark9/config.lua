local M = {}

-- default options
M.options = {
	use_telescope = false,
	sign_icon = "➤",
	sign_enabled = true,
	virtual_text_enabled = false,
	virtual_icon = "◆", -- ◆ | ◇
	virtual_text_pos = "eol", -- 'eol', 'left_align', or 'right_align'
	highlight_line_enabled = true,
	highlight_group = "Visual",
	horizontal_padding = 2,
	window_padding = 2,
	window_position = "center", -- center | top_left | top_right | bottom_left | bottom_right
	window_width_percent = 0.4,
	mark_chars = { "A", "B", "C", "D", "E", "F", "G", "H", "I" },
}

function M.setup(opts)
	local merged_opts = vim.tbl_deep_extend("force", M.options, opts or {})
	merged_opts.use_telescope = false
	M.options = merged_opts
end

return M
