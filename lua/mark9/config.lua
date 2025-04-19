-- mark9/config.lua
local M = {}

--[[
Default options for mark9.nvim

  use_telescope          = Use Telescope for the mark list (fallbacks to floating window if false)
  sign_icon              = Icon displayed in the sign column
  virtual_text           = Show inline virtual text at the mark line
  virtual_icon           = The symbol/text used for inline virtual text
  virtual_text_pos       = Position for virtual icon: 'eol', 'overlay', or 'right_align'
  horizontal_padding     = Extra horizontal padding for floating window (in spaces)
  window_padding         = Extra top/bottom padding for floating window (in lines)
  window_position        = 'center', 'top_left', 'top_right', 'bottom_left', or 'bottom_right'
  window_width_percent   = Width of floating window as percent of editor width (e.g., 0.4 = 40%)
  mark_chars             = Characters used for file-local marks (default A–I)
]]

M.options = {
	use_telescope = false,
	sign_icon = "📌",
	virtual_text = true,
	virtual_icon = "🔖",
	virtual_text_pos = "eol",
	horizontal_padding = 2,
	window_padding = 2,
	window_position = "center",
	window_width_percent = 0.4,
	mark_chars = { "A", "B", "C", "D", "E", "F", "G", "H", "I" },
}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

return M
