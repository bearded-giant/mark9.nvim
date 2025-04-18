-- mark9.lua (plugin-style module for line-level marks)
-- Features:
-- - 9 persistent file-level marks ('A'–'I')
-- - Gutter + virtual text icons
-- - Duplicate prevention
-- - FIFO cycling
-- - Project-scoped persistence (stored in ~/.local/share/nvim/mark9/)
-- - Telescope picker with preview

local M = {}
local Config = require("mark9.config")

local api = vim.api
local fn = vim.fn
local ns_id = api.nvim_create_namespace("mark9")
local mark_chars = Config.options.mark_chars
local extmarks_by_char = {}
local sign_group = "Mark9Signs"
local sign_name = "Mark9Icon"
local marks_cache = {}

function M.setup()
	fn.sign_define(sign_name, { text = Config.options.sign_icon, texthl = "DiagnosticHint" })

	vim.api.nvim_create_user_command("Mark9Save", function()
		M.save_marks()
		vim.notify("[mark9] Project marks saved")
	end, {})

	vim.api.nvim_create_user_command("Mark9Load", function()
		M.load_marks()
		vim.notify("[mark9] Project marks loaded")
	end, {})

	vim.api.nvim_create_autocmd("VimEnter", {
		callback = function()
			M.load_marks()
		end,
	})

	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			M.save_marks()
		end,
	})
end

-- (rest of file remains unchanged)
