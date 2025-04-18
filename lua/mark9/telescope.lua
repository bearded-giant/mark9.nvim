local M = {}

local Config = require("mark9.config")
local Marks = require("mark9.marks")
local api = vim.api
local fn = vim.fn

function M.get_marks()
	local marks = {}
	for _, char in ipairs(Config.options.mark_chars) do
		local pos = api.nvim_get_mark(char, {})
		if pos and pos[1] > 0 then
			local file = fn.bufname(pos[4])
			table.insert(marks, {
				char = char,
				value = char,
				file = file,
				lnum = pos[1],
				col = pos[2],
				display = string.format("%s: %s:%d", char, fn.fnamemodify(file, ":t"), pos[1]),
			})
		end
	end
	return marks
end

function M.picker()
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local previewers = require("telescope.previewers")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	local entries = M.get_marks()

	pickers
		.new({}, {
			prompt_title = "Mark9 (Telescope)",
			finder = finders.new_table({
				results = entries,
				entry_maker = function(entry)
					return {
						value = entry,
						display = entry.display,
						ordinal = entry.display,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = previewers.new_buffer_previewer({
				define_preview = function(self, entry)
					local val = entry.value
					if fn.filereadable(val.file) == 1 then
						local bufnr = fn.bufnr(val.file, true)
						local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
						api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
						api.nvim_buf_call(self.state.bufnr, function()
							fn.cursor(val.lnum, 1)
						end)
					end
				end,
			}),
			attach_mappings = function(prompt_bufnr, map)
				local function get_selected()
					return action_state.get_selected_entry()
				end

				actions.select_default:replace(function()
					local selection = get_selected()
					actions.close(prompt_bufnr)
					if selection and selection.value then
						local val = selection.value
						vim.cmd("edit " .. val.file)
						api.nvim_win_set_cursor(0, { val.lnum, val.col })
						vim.cmd("normal! zz")
					end
				end)

				map("n", "dd", function()
					local selection = get_selected()
					if not selection then
						return
					end
					local char = selection.value.char

					vim.cmd("delmarks " .. char)
					local ext = Marks._get_extmark(char)
					if ext and api.nvim_buf_is_valid(ext.buf) then
						pcall(api.nvim_buf_del_extmark, ext.buf, ext.ns, ext.id)
						fn.sign_unplace("Mark9Signs", { buffer = ext.buf })
					end

					vim.notify("[mark9] Deleted mark '" .. char .. "'", vim.log.levels.INFO)
					actions.close(prompt_bufnr)

					-- debounce refresh
					vim.schedule(function()
						M.picker()
					end)
				end)

				return true
			end,
		})
		:find()
end

return M
