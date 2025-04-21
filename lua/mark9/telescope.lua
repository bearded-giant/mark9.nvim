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
	for _, char in ipairs(Config.options.mark_chars) do
		local pos = api.nvim_get_mark(char, {})
		if pos and pos[1] > 0 then
			local file = fn.bufname(pos[4]) or ""
			local display_file = file
			if file == "" then
				display_file = "<Unknown File>"
				file = display_file  -- Use a placeholder so it can be displayed
			end
			
			local text = ""
			pcall(function()
				if file ~= "<Unknown File>" and fn.bufnr(file) > 0 then
					local bufnr = fn.bufnr(file)
					if api.nvim_buf_is_valid(bufnr) then
						local line_count = api.nvim_buf_line_count(bufnr)
						if pos[1] > 0 and pos[1] <= line_count then
							text = api.nvim_buf_get_lines(bufnr, pos[1] - 1, pos[1], false)[1] or ""
							text = text:gsub("^%s+", "") -- Strip leading whitespace
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
				define_preview = function(self, entry)
					local filepath = entry.filename
					local lnum = entry.lnum
					
					-- Check if file exists and can be loaded
					if filepath == "<Unknown File>" or filepath:match("^<.*>$") then
						api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {"File not available"})
						return
					end
					
					local bufnr = fn.bufnr(filepath, true)
					if bufnr < 0 then
						api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {"File not loaded in editor"})
						return
					end
					
					if not api.nvim_buf_is_loaded(bufnr) then
						local ok = pcall(vim.fn.bufload, bufnr)
						if not ok then
							api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {"Cannot load file"})
							return
						end
					end
					
					pcall(api.nvim_buf_set_option, self.state.bufnr, "filetype", vim.bo[bufnr].filetype)
					
					local ok, lines = pcall(api.nvim_buf_get_lines, bufnr, 0, -1, false)
					if not ok or #lines == 0 then
						api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {"File is empty or cannot be read"})
						return
					end
					
					api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
					
					vim.api.nvim_win_set_option(self.state.winid, "number", true)
					vim.api.nvim_win_set_option(self.state.winid, "relativenumber", false)
					
					local line_count = #lines
					if line_count > 0 then
						local target_line = math.min(lnum, line_count)
						pcall(vim.api.nvim_win_set_cursor, self.state.winid, { target_line, 0 })
					end
					
					vim.api.nvim_win_set_option(self.state.winid, "cursorline", true)
					
					local ns_id = api.nvim_create_namespace("mark9_telescope_preview")
					api.nvim_buf_clear_namespace(self.state.bufnr, ns_id, 0, -1)
					
					if lnum > 0 and lnum <= line_count then
						api.nvim_buf_add_highlight(
							self.state.bufnr,
							ns_id,
							Config.options.highlight_group,
							lnum - 1,
							0,
							-1
						)
					end
				end,
			}),
			attach_mappings = function(_, map)
				map("i", "dd", function(prompt_bufnr)
					local selection = require("telescope.actions.state").get_selected_entry()
					local actions = require("telescope.actions")
					if selection then
						vim.cmd("delmarks " .. selection.value.char)
						actions.close(prompt_bufnr)
						vim.notify("[mark9] Deleted mark '" .. selection.value.char .. "'", vim.log.levels.INFO)
					end
				end)
				return true
			end,
		})
		:find()
end

return M