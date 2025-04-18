-- mark9/marks.lua
local M = {}

local Config = require("mark9.config")
local api = vim.api
local fn = vim.fn

local ns_id = api.nvim_create_namespace("mark9")
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

	vim.api.nvim_create_user_command("Mark9Menu", function()
		M.floating_menu()
	end, {})

	vim.api.nvim_create_user_command("Mark9List", function()
		M.telescope_picker()
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

-- rest unchanged --

function M.floating_menu()
	local marks = {}
	for _, char in ipairs(Config.options.mark_chars) do
		local pos = api.nvim_get_mark(char, {})
		if pos and pos[1] > 0 then
			local file = fn.bufname(pos[4])
			local line_text = ""
			pcall(function()
				line_text = api.nvim_buf_get_lines(fn.bufnr(file), pos[1] - 1, pos[1], false)[1] or ""
			end)
			table.insert(marks, {
				char = char,
				file = file,
				line = pos[1],
				text = line_text,
			})
		end
	end

	local buf = api.nvim_create_buf(false, true)
	local lines = {}
	for i, m in ipairs(marks) do
		lines[i] = string.format("%s. %s:%d  %s", m.char, fn.fnamemodify(m.file, ":t"), m.line, m.text)
	end
	-- vertical padding
	for _ = 1, Config.options.window_padding or 0 do
		table.insert(lines, 1, "")
		table.insert(lines, "")
	end

	-- horizontal padding
	local hpad = string.rep(" ", Config.options.horizontal_padding or 0)
	for i, line in ipairs(lines) do
		lines[i] = hpad .. line .. hpad
	end
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local height = #lines + Config.options.window_padding * 2
	local width = math.floor(vim.o.columns * (Config.options.window_width_percent or 0.4))

	local row, col = 0, 0
	local pad_h = Config.options.window_padding or 1
	local pad_v = Config.options.window_padding or 1
	local pos = Config.options.window_position or "center"

	if pos == "top_left" then
		row, col = pad_v, pad_h
	elseif pos == "top_right" then
		row = pad_v
		col = vim.o.columns - width - pad_h
	elseif pos == "bottom_left" then
		row = vim.o.lines - height - pad_v
		col = pad_h
	elseif pos == "bottom_right" then
		row = vim.o.lines - height - pad_v
		col = vim.o.columns - width - pad_h
	else -- default to center
		row = math.floor((vim.o.lines - height) / 2)
		col = math.floor((vim.o.columns - width) / 2)
	end

	local win = api.nvim_open_win(buf, true, {
		relative = "editor",
		row = row,
		col = col,
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = "Marks",
		title_pos = "center",
	})

	api.nvim_win_set_option(win, "cursorline", true)

	local function refresh_menu()
		lines = {}
		for i, m in ipairs(marks) do
			lines[i] = string.format("%s. %s:%d  %s", m.char, fn.fnamemodify(m.file, ":t"), m.line, m.text)
		end
		api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	end

	vim.keymap.set("n", "q", function()
		if api.nvim_win_is_valid(win) then
			api.nvim_win_close(win, true)
		end
	end, { buffer = buf })

	vim.keymap.set("n", "<CR>", function()
		local idx = api.nvim_win_get_cursor(win)[1]
		local m = marks[idx]
		if m then
			api.nvim_win_close(win, true)
			vim.cmd("edit " .. m.file)
			api.nvim_win_set_cursor(0, { m.line, 0 })
			vim.cmd("normal! zz")
		end
	end, { buffer = buf })

	vim.keymap.set("n", "dd", function()
		local idx = api.nvim_win_get_cursor(win)[1]
		local m = marks[idx]
		if m then
			vim.cmd("delmarks " .. m.char)
			local ext = extmarks_by_char[m.char]
			if ext and api.nvim_buf_is_valid(ext.buf) then
				pcall(api.nvim_buf_del_extmark, ext.buf, ns_id, ext.id)
				fn.sign_unplace(sign_group, { buffer = ext.buf })
			end
			extmarks_by_char[m.char] = nil
			table.remove(marks, idx)
			table.remove(lines, idx)
			vim.notify("[mark9] Deleted mark '" .. m.char .. "'", vim.log.levels.INFO)
			M.save_marks()
			vim.schedule(function()
				if #marks == 0 and api.nvim_win_is_valid(win) then
					api.nvim_win_close(win, true)
				else
					refresh_menu()
				end
			end)
		end
	end, { buffer = buf })
end

function M.telescope_picker()
	if Config.options.use_telescope then
		require("mark9.telescope").picker(true)
	else
		M.floating_menu()
	end
end

function M._get_extmark(char)
	local ext = extmarks_by_char[char]
	if ext then
		return { buf = ext.buf, id = ext.id, ns = ns_id }
	end
end

return M
