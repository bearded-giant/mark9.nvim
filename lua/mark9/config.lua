local M = {}

--[[
Default options for mark9.nvim

  use_telescope         = use Telescope for the mark list (fallbacks to floating window if false)
  sign_icon             = icon displayed in the gutter
  virtual_text          = show virtual inline icon at the mark line
  virtual_icon          = the virtual text symbol used (if enabled)
  virtual_text_pos      = where to place the virtual icon: 'eol', 'overlay', or 'right_align'
  horizontal_padding   = extra horizontal padding used in floating UI
  window_padding        = extra top and bottom padding used in floating UI
  window_position       = 'center', 'top_left', 'top_right', 'bottom_left', or 'bottom_right'
  window_width_percent  = floating window width as percentage of editor width (e.g., 0.4 = 40%)
  mark_chars            = characters to use for file-local marks (A–I)
]]

M.options = {
	use_telescope = false,
	sign_icon = "*",
	virtual_text = true,
	virtual_icon = "*",
	virtual_text_pos = "eol",
	horizontal_padding = 2,
	window_padding = 2,
	window_position = "center", -- center | top_left | top_right | bottom_left | bottom_right
	window_width_percent = 0.4, -- 40% of the editor width by default
	mark_chars = { "A", "B", "C", "D", "E", "F", "G", "H", "I" },
}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

return M
