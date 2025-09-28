local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local previewers = require("telescope.previewers")
local entry_display = require("telescope.pickers.entry_display")
local Config = require("mark9.config")
local api = vim.api
local fn = vim.fn

local M = {}

local function get_marks()
	local marks = {}
	local invalid_marks = {}

	for _, char in ipairs(Config.options.mark_chars) do
		local pos = api.nvim_get_mark(char, {})
		if pos and pos[1] > 0 then
			local file = fn.bufname(pos[4]) or ""

			if file == "" then
				-- Mark has no associated file, clean it up
				table.insert(invalid_marks, char)
			else
				-- Check if file exists
				local file_exists = fn.filereadable(fn.expand(file)) == 1
				if not file_exists then
					-- File doesn't exist, mark for cleanup
					table.insert(invalid_marks, char)
				else
					-- File exists, include in list
					local text = ""
					pcall(function()
						if fn.bufnr(file) > 0 then
							local bufnr = fn.bufnr(file)
							if api.nvim_buf_is_valid(bufnr) then
								local line_count = api.nvim_buf_line_count(bufnr)
								if pos[1] > 0 and pos[1] <= line_count then
									text = api.nvim_buf_get_lines(bufnr, pos[1] - 1, pos[1], false)[1] or ""
									text = text:gsub("^%s+", "") -- strip leading whitespace
								end
							end
						end
					end)

					table.insert(marks, {
						char = char,
						file = file,
						line = pos[1],
						col = pos[2],
						text = text,
					})
				end
			end
		end
	end

	-- Clean up invalid marks
	if #invalid_marks > 0 then
		for _, char in ipairs(invalid_marks) do
			vim.cmd("delmarks " .. char)
			fn.sign_unplace("Mark9Signs")
		end
		-- Save marks after cleanup
		local marks_module = require("mark9.marks")
		marks_module.save_marks()
		vim.notify(string.format("[mark9] Cleaned up %d invalid mark(s)", #invalid_marks), vim.log.levels.INFO)
	end

	return marks
end

function M.picker()
	local marks = get_marks()

	if #marks == 0 then
		vim.notify("[mark9] No marks to show", vim.log.levels.INFO)
		return
	end

	pickers
		.new({}, {
			prompt_title = "mark9",
			preview_title = "Mark Preview",
			results_title = "Marks",
			layout_strategy = "horizontal",
			layout_config = {
				horizontal = {
					width = 0.9,
					height = 0.9,
					preview_width = 0.5,
					preview_cutoff = 0,
				},
			},
			finder = finders.new_table({
				results = marks,
				entry_maker = function(entry)
					local displayer = entry_display.create({
						separator = " ",
						items = {
							{ width = 3 },
							{ width = 20 },
							{ remaining = true },
						},
					})

					return {
						value = entry,
						display = function(e)
							return displayer({
								e.value.char,
								fn.fnamemodify(e.value.file, ":t") .. ":" .. e.value.line,
								e.value.text,
							})
						end,
						ordinal = entry.file .. entry.text,
						filename = entry.file,
						lnum = entry.line,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = previewers.new_buffer_previewer({
				title = "Mark Preview",
				define_preview = function(self, entry)
					local filepath = entry.filename
					local lnum = entry.lnum

					-- Check if file path is valid
					if not filepath or filepath == "" then
						api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { "No file path available" })
						return
					end

					-- Try to read the file directly first
					local file_lines = {}
					local file_readable = fn.filereadable(fn.expand(filepath)) == 1

					if file_readable then
						-- Read file from disk
						file_lines = fn.readfile(fn.expand(filepath))
					else
						-- Try to get from buffer if file not on disk
						local bufnr = fn.bufnr(filepath)
						if bufnr > 0 and api.nvim_buf_is_loaded(bufnr) then
							local ok, lines = pcall(api.nvim_buf_get_lines, bufnr, 0, -1, false)
							if ok then
								file_lines = lines
							end
						end
					end

					-- Check if we got any content
					if #file_lines == 0 then
						api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {
							"Cannot read file: " .. filepath,
							"",
							"The file may have been deleted or moved."
						})
						return
					end

					-- Set the content
					api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, file_lines)

					-- Set filetype for syntax highlighting
					local ft = fn.fnamemodify(filepath, ":e")
					if ft and ft ~= "" then
						pcall(api.nvim_buf_set_option, self.state.bufnr, "filetype", ft)
					end

					-- Enable line numbers
					pcall(vim.api.nvim_win_set_option, self.state.winid, "number", true)
					pcall(vim.api.nvim_win_set_option, self.state.winid, "relativenumber", false)
					pcall(vim.api.nvim_win_set_option, self.state.winid, "cursorline", true)

					-- Jump to marked line
					local line_count = #file_lines
					if line_count > 0 and lnum and lnum > 0 then
						local target_line = math.min(lnum, line_count)
						pcall(vim.api.nvim_win_set_cursor, self.state.winid, { target_line, 0 })
					end

					-- Highlight the marked line
					local ns_id = api.nvim_create_namespace("mark9_telescope_preview")
					api.nvim_buf_clear_namespace(self.state.bufnr, ns_id, 0, -1)

					if lnum and lnum > 0 and lnum <= line_count then
						api.nvim_buf_add_highlight(
							self.state.bufnr,
							ns_id,
							Config.options.highlight_group or "Visual",
							lnum - 1,
							0,
							-1
						)
					end
				end,
			}),
			attach_mappings = function(prompt_bufnr, map)
				local actions = require("telescope.actions")
				local action_state = require("telescope.actions.state")

				-- Default mappings
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					if selection then
						actions.close(prompt_bufnr)
						vim.schedule(function()
							local ok = pcall(vim.cmd, "edit " .. vim.fn.fnameescape(selection.value.file))
							if ok then
								local line_count = api.nvim_buf_line_count(0)
								local target_line = math.min(selection.value.line, line_count)
								if target_line > 0 then
									api.nvim_win_set_cursor(0, { target_line, 0 })
									vim.cmd("normal! zz")
								end
							end
						end)
					end
				end)

				-- Delete mark with dd (both modes)
				map("i", "dd", function()
					local selection = action_state.get_selected_entry()
					if selection then
						vim.cmd("delmarks " .. selection.value.char)
						actions.close(prompt_bufnr)
						vim.notify("[mark9] Deleted mark '" .. selection.value.char .. "'", vim.log.levels.INFO)
						-- Clean up extmarks and signs
						local marks_module = require("mark9.marks")
						marks_module.save_marks()
					end
				end)

				map("n", "dd", function()
					local selection = action_state.get_selected_entry()
					if selection then
						vim.cmd("delmarks " .. selection.value.char)
						actions.close(prompt_bufnr)
						vim.notify("[mark9] Deleted mark '" .. selection.value.char .. "'", vim.log.levels.INFO)
						-- Clean up extmarks and signs
						local marks_module = require("mark9.marks")
						marks_module.save_marks()
					end
				end)

				-- Your config already has C-u/C-d for preview scrolling, so no need to override

				return true
			end,
		})
		:find()
end

return M

