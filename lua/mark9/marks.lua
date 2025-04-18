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
	fn.sign_define(sign_name, { text = "⚑", texthl = "DiagnosticHint" })

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

local function get_project_root()
	local cwd = fn.getcwd()
	local git_root = fn.systemlist("git -C " .. cwd .. " rev-parse --show-toplevel")[1]
	return git_root and git_root ~= "" and git_root or cwd
end

local function get_mark_store_file()
	local root = get_project_root():gsub("/", "%%")
	local dir = fn.stdpath("data") .. "/mark9/"
	fn.mkdir(dir, "p")
	return dir .. root .. ".json"
end

function M.save_marks()
	local data = {}
	for _, mark_char in ipairs(mark_chars) do
		local pos = api.nvim_get_mark(mark_char, {})
		if pos and pos[1] > 0 then
			local file = fn.bufname(pos[4])
			table.insert(data, {
				char = mark_char,
				file = file,
				line = pos[1],
				col = pos[2],
				timestamp = os.time(),
			})
		end
	end
	local f = io.open(get_mark_store_file(), "w")
	if f then
		f:write(vim.fn.json_encode(data))
		f:close()
	end
end

function M.load_marks()
	local file = get_mark_store_file()
	local f = io.open(file, "r")
	if not f then
		return
	end
	local content = f:read("*a")
	f:close()
	local data = vim.fn.json_decode(content)
	for _, m in ipairs(data or {}) do
		if fn.filereadable(m.file) == 1 then
			vim.cmd("edit " .. m.file)
			vim.cmd("mark " .. m.char)
			api.nvim_win_set_cursor(0, { m.line, m.col })
			M.place_extmark(fn.bufnr(), m.line, m.char)
		end
	end
end

function M.place_extmark(buf_id, line_num, char)
	if not api.nvim_buf_is_valid(buf_id) then
		return
	end
	local id = api.nvim_buf_set_extmark(buf_id, ns_id, line_num - 1, 0, {
		virt_text = { { "🔖", "DiagnosticHint" } },
		virt_text_pos = "eol",
	})
	extmarks_by_char[char] = { buf = buf_id, id = id }
	fn.sign_place(0, sign_group, sign_name, buf_id, { lnum = line_num, priority = 10 })
end

function M.clear_all_marks()
	for _, char in ipairs(mark_chars) do
		vim.cmd("delmarks " .. char)
		local ext = extmarks_by_char[char]
		if ext and api.nvim_buf_is_valid(ext.buf) then
			pcall(api.nvim_buf_del_extmark, ext.buf, ns_id, ext.id)
			fn.sign_unplace(sign_group, { buffer = ext.buf })
		end
		extmarks_by_char[char] = nil
	end
end

function M.get_next_char()
	for _, char in ipairs(mark_chars) do
		local pos = api.nvim_get_mark(char, {})
		if not pos or pos[1] == 0 then
			return char
		end
	end
	-- cycle: return oldest
	local oldest = nil
	local oldest_time = math.huge
	for _, char in ipairs(mark_chars) do
		local pos = api.nvim_get_mark(char, {})
		local ts = marks_cache[char] or 0
		if ts < oldest_time then
			oldest = char
			oldest_time = ts
		end
	end
	return oldest
end

function M.add_mark()
	local cur_buf = api.nvim_get_current_buf()
	local cur_line = fn.line(".")
	local file = api.nvim_buf_get_name(cur_buf)

	for _, char in ipairs(mark_chars) do
		local pos = api.nvim_get_mark(char, {})
		if pos and pos[1] == cur_line and fn.bufname(pos[4]) == file then
			vim.notify("[mark9] Line already marked in slot '" .. char .. "'", vim.log.levels.INFO)
			return
		end
	end

	local mark_char = M.get_next_char()
	vim.cmd("mark " .. mark_char)
	M.place_extmark(cur_buf, cur_line, mark_char)
	marks_cache[mark_char] = os.time()
	vim.notify("[mark9] Marked line " .. cur_line .. " with '" .. mark_char .. "'", vim.log.levels.INFO)
end

function M.jump_to_mark(char)
	local pos = api.nvim_get_mark(char, {})
	if not pos or pos[1] == 0 then
		vim.notify("[mark9] Mark '" .. char .. "' not set", vim.log.levels.INFO)
		return
	end
	local file = fn.bufname(pos[4])
	if fn.bufnr(file) ~= api.nvim_get_current_buf() then
		vim.cmd("edit " .. file)
	end
	api.nvim_win_set_cursor(0, { pos[1], pos[2] })
	vim.cmd("normal! zz")
end

-- Telescope integration
function M.telescope_picker()
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	local entries = {}
	for _, char in ipairs(mark_chars) do
		local pos = api.nvim_get_mark(char, {})
		if pos and pos[1] > 0 then
			local file = fn.bufname(pos[4])
			local line_text = ""
			pcall(function()
				line_text = api.nvim_buf_get_lines(fn.bufnr(file), pos[1] - 1, pos[1], false)[1] or ""
			end)
			table.insert(entries, {
				value = char,
				ordinal = char .. " " .. file,
				display = char .. ": " .. fn.fnamemodify(file, ":t") .. ":" .. pos[1] .. "  " .. line_text,
			})
		end
	end

	pickers
		.new({}, {
			prompt_title = "Mark9 Jump",
			finder = finders.new_table({
				results = entries,
				entry_maker = function(e)
					return e
				end,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(_, map)
				actions.select_default:replace(function()
					local entry = action_state.get_selected_entry()
					actions.close()
					M.jump_to_mark(entry.value)
				end)
				return true
			end,
		})
		:find()
end

-- Keymaps
vim.keymap.set("n", "<leader>ha", M.add_mark, { desc = "Mark9: Add line mark" })
vim.keymap.set("n", "<leader>hl", M.telescope_picker, { desc = "Mark9: List & jump" })
vim.keymap.set("n", "<leader>hc", M.clear_all_marks, { desc = "Mark9: Clear all" })
vim.keymap.set("n", "<leader>hL", M.telescope_picker, { desc = "Mark9: Telescope picker" })

return M
