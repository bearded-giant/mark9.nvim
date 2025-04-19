local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local entry_display = require("telescope.pickers.entry_display")
local Config = require("mark9.config")

local api = vim.api
local fn = vim.fn

local M = {}

function M.picker()
	local marks = {}

	for _, char in ipairs(Config.options.mark_chars) do
		local pos = api.nvim_get_mark(char, {})
		if pos and pos[1] > 0 then
			local file = fn.bufname(pos[4])
			local line = pos[1]
			local col = pos[2]
			local text = ""
			pcall(function()
				text = api.nvim_buf_get_lines(fn.bufnr(file), line - 1, line, false)[1] or ""
			end)
			table.insert(marks, {
				char = char,
				file = file,
				file_short = fn.fnamemodify(file, ":."),
				line = line,
				col = col,
				text = text,
			})
		end
	end

	local displayer = entry_display.create({
		separator = " ",
		items = {
			{ width = 3 }, -- slot
			{ width = 30 }, -- file
			{ width = 5 }, -- line number
			{ remaining = true }, -- text
		},
	})

	local function make_display(entry)
		return displayer({
			entry.char,
			entry.file_short,
			tostring(entry.line),
			entry.text,
		})
	end

	local function preview_command(entry, bufnr, _)
		if not entry.file or not fn.filereadable(entry.file) then
			return
		end

		local lines = {}
		pcall(function()
			lines = api.nvim_buf_get_lines(fn.bufnr(entry.file), 0, -1, false)
		end)
		api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

		vim.schedule(function()
			local win = fn.bufwinid(bufnr)
			if win ~= -1 and api.nvim_win_is_valid(win) then
				api.nvim_win_set_cursor(win, { entry.line, 0 })
				api.nvim_win_set_option(win, "number", true)
				api.nvim_win_set_option(win, "relativenumber", false)
				api.nvim_win_set_option(win, "cursorline", true)
			end
		end)
	end

	pickers
		.new({}, {
			prompt_title = "Mark9 Marks",
			finder = finders.new_table({
				results = marks,
				entry_maker = function(entry)
					return {
						value = entry,
						display = make_display,
						ordinal = entry.text,
						filename = entry.file,
						lnum = entry.line,
						file = entry.file,
						line = entry.line,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = previewers.new_buffer_previewer({
				define_preview = preview_command,
			}),
		})
		:find()
end

return M
