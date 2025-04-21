local M = {}

local Config = require("mark9.config")
local api = vim.api
local fn = vim.fn
local uv = vim.loop

local ns_id = api.nvim_create_namespace("mark9")
local extmarks_by_char = {}
local sign_group = "Mark9Signs"
local sign_name = "Mark9Icon"

function M.setup()
	fn.sign_define(sign_name, {
		text = Config.options.sign_icon or "*",
		texthl = "DiagnosticHint",
		numhl = "",
	})

	for _, char in ipairs(Config.options.mark_chars) do
		local pos = api.nvim_get_mark(char, {})
		if pos and pos[1] > 0 then
			local file = fn.bufname(pos[4])
			if file ~= "" then
				local buf = fn.bufnr(file)
				if buf > 0 then
					local line = pos[1]

					local id = nil
					if Config.options.virtual_text_enabled and api.nvim_buf_is_valid(buf) then
						local line_count = api.nvim_buf_line_count(buf)
						if line > 0 and line <= line_count then
							id = api.nvim_buf_set_extmark(buf, ns_id, line - 1, 0, {
								virt_text = { { Config.options.virtual_icon, "DiagnosticHint" } },
								virt_text_pos = Config.options.virtual_text_pos,
							})
						end
					end

					if api.nvim_buf_is_valid(buf) then
						local line_count = api.nvim_buf_line_count(buf)
						if line > 0 and line <= line_count then
							if Config.options.sign_enabled then
								fn.sign_place(0, sign_group, sign_name, buf, { lnum = line, priority = 10 })
							end

							if Config.options.highlight_line_enabled then
								api.nvim_buf_add_highlight(
									buf,
									ns_id,
									Config.options.highlight_group or "Visual",
									line - 1,
									0,
									-1
								)
							end
						end
					end

					extmarks_by_char[char] = { buf = buf, id = id }
				end
			end
		end
	end

	api.nvim_create_user_command("Mark9Add", function()
		M.add_mark()
	end, {})

	api.nvim_create_user_command("Mark9List", function()
		M.list_picker()
	end, {})

	api.nvim_create_user_command("Mark9Telescope", function()
		M.telescope_picker()
	end, {})

	api.nvim_create_user_command("Mark9Delete", function(opts)
		local char = opts.args:upper()
		if not vim.tbl_contains(Config.options.mark_chars, char) then
			vim.notify("[mark9] Invalid mark id: " .. char, vim.log.levels.WARN)
			return
		end
		vim.cmd("delmarks " .. char)
		local ext = extmarks_by_char[char]
		if ext and api.nvim_buf_is_valid(ext.buf) then
			pcall(api.nvim_buf_del_extmark, ext.buf, ns_id, ext.id)
			fn.sign_unplace(sign_group, { buffer = ext.buf })
			if Config.options.highlight_line_enabled then
				api.nvim_buf_clear_namespace(ext.buf, ns_id, 0, -1)
			end
		end
		extmarks_by_char[char] = nil
		vim.notify("[mark9] Deleted mark '" .. char .. "'", vim.log.levels.INFO)
		M.save_marks()
	end, {
		nargs = 1,
		complete = function()
			return Config.options.mark_chars
		end,
	})

	api.nvim_create_user_command("Mark9ClearAll", function()
		for _, char in ipairs(Config.options.mark_chars) do
			vim.cmd("delmarks " .. char)
			local ext = extmarks_by_char[char]
			if ext and api.nvim_buf_is_valid(ext.buf) then
				pcall(api.nvim_buf_del_extmark, ext.buf, ns_id, ext.id)
				fn.sign_unplace(sign_group, { buffer = ext.buf })
				if Config.options.highlight_line_enabled then
					api.nvim_buf_clear_namespace(ext.buf, ns_id, 0, -1)
				end
			end
			extmarks_by_char[char] = nil
		end
		vim.notify("[mark9] All marks cleared", vim.log.levels.INFO)
		M.save_marks()
	end, {})
end

function M.add_mark()
	local cur_buf = api.nvim_get_current_buf()
	local cur_line = fn.line(".")

	for _, char in ipairs(Config.options.mark_chars) do
		local pos = api.nvim_get_mark(char, {})
		if pos and pos[1] == cur_line and pos[4] == cur_buf then
			vim.notify("[mark9] Line already marked (" .. char .. ")", vim.log.levels.INFO)
			return
		end
	end

	local next = nil
	for _, char in ipairs(Config.options.mark_chars) do
		local pos = api.nvim_get_mark(char, {})
		if not pos or pos[1] == 0 then
			next = char
			break
		end
	end

	if not next then
		next = Config.options.mark_chars[1]
		vim.cmd("delmarks " .. next)
	end

	vim.cmd("mark " .. next)

	local id = nil
	if Config.options.virtual_text_enabled then
		id = api.nvim_buf_set_extmark(cur_buf, ns_id, cur_line - 1, 0, {
			virt_text = { { Config.options.virtual_icon, "DiagnosticHint" } },
			virt_text_pos = Config.options.virtual_text_pos,
		})
	end

	if Config.options.sign_enabled then
		fn.sign_place(0, sign_group, sign_name, cur_buf, { lnum = cur_line, priority = 10 })
	end

	if Config.options.highlight_line_enabled then
		api.nvim_buf_add_highlight(cur_buf, ns_id, Config.options.highlight_group or "Visual", cur_line - 1, 0, -1)
	end

	extmarks_by_char[next] = { buf = cur_buf, id = id }
	vim.notify("[mark9] Marked line " .. cur_line .. " (" .. next .. ")", vim.log.levels.INFO)
	M.save_marks()
end

function M.telescope_picker()
	require("mark9.telescope").picker()
end

function M.list_picker()
	if Config.options.use_telescope then
		M.telescope_picker()
	else
		M.floating_menu()
	end
end

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
	for _, m in ipairs(marks) do
		table.insert(lines, string.format("%s - %s:%d  %s", m.char, fn.fnamemodify(m.file, ":t"), m.line, m.text))
	end

	local vp = Config.options.window_padding or 0
	for _ = 1, vp do
		table.insert(lines, 1, "")
	end
	for _ = 1, vp do
		table.insert(lines, "")
	end

	local hp = Config.options.horizontal_padding or 0
	if hp > 0 then
		local pad = string.rep(" ", hp)
		for i, l in ipairs(lines) do
			lines[i] = pad .. l .. pad
		end
	end

	api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local height = #lines
	local width = math.floor(vim.o.columns * (Config.options.window_width_percent or 0.4))
	local row, col = 0, 0
	local pos = Config.options.window_position or "center"
	if pos == "top_left" then
		row = vp
		col = hp
	elseif pos == "top_right" then
		row = vp
		col = vim.o.columns - width - hp
	elseif pos == "bottom_left" then
		row = vim.o.lines - height - vp
		col = hp
	elseif pos == "bottom_right" then
		row = vim.o.lines - height - vp
		col = vim.o.columns - width - hp
	else
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

	vim.keymap.set("n", "q", function()
		if api.nvim_win_is_valid(win) then
			api.nvim_win_close(win, true)
		end
	end, { buffer = buf })

	vim.keymap.set("n", "<CR>", function()
		local idx = api.nvim_win_get_cursor(win)[1] - vp
		local m = marks[idx]
		if m then
			api.nvim_win_close(win, true)
			vim.cmd("edit " .. m.file)
			api.nvim_win_set_cursor(0, { m.line, 0 })
			vim.cmd("normal! zz")
		end
	end, { buffer = buf })

	vim.keymap.set("n", "dd", function()
		local idx = api.nvim_win_get_cursor(win)[1] - vp
		local m = marks[idx]
		if m then
			vim.cmd("delmarks " .. m.char)
			local ext = extmarks_by_char[m.char]
			if ext and api.nvim_buf_is_valid(ext.buf) then
				pcall(api.nvim_buf_del_extmark, ext.buf, ns_id, ext.id)
				fn.sign_unplace(sign_group, { buffer = ext.buf })
				if Config.options.highlight_line_enabled then
					api.nvim_buf_clear_namespace(ext.buf, ns_id, 0, -1)
				end
			end
			extmarks_by_char[m.char] = nil
			table.remove(marks, idx)
			vim.notify("[mark9] Deleted mark '" .. m.char .. "'", vim.log.levels.INFO)
			M.save_marks()
			vim.schedule(function()
				if #marks == 0 and api.nvim_win_is_valid(win) then
					api.nvim_win_close(win, true)
					return
				end

				local updated_lines = {}
				for _, mark in ipairs(marks) do
					table.insert(
						updated_lines,
						string.format(
							"%s - %s:%d  %s",
							mark.char,
							fn.fnamemodify(mark.file, ":t"),
							mark.line,
							mark.text
						)
					)
				end

				-- Apply vertical and horizontal padding again
				for _ = 1, vp do
					table.insert(updated_lines, 1, "")
				end
				for _ = 1, vp do
					table.insert(updated_lines, "")
				end

				if hp > 0 then
					local pad = string.rep(" ", hp)
					for i, l in ipairs(updated_lines) do
						updated_lines[i] = pad .. l .. pad
					end
				end

				if api.nvim_buf_is_valid(buf) then
					api.nvim_buf_set_lines(buf, 0, -1, false, updated_lines)
				end
			end)
		end
	end, { buffer = buf })
end

function M.save_marks()
	local marks = {}
	for _, char in ipairs(Config.options.mark_chars) do
		local pos = api.nvim_get_mark(char, {})
		if pos and pos[1] > 0 then
			local file = fn.bufname(pos[4])

			if Config.options.highlight_line_enabled then
				local buf = fn.bufnr(file)
				if api.nvim_buf_is_valid(buf) then
					local line_count = api.nvim_buf_line_count(buf)
					if pos[1] > 0 and pos[1] <= line_count then
						api.nvim_buf_add_highlight(
							buf,
							ns_id,
							Config.options.highlight_group or "Visual",
							pos[1] - 1,
							0,
							-1
						)
					end
				end
			end

			table.insert(marks, {
				char = char,
				file = file,
				line = pos[1],
				col = pos[2],
			})
		end
	end

	local root = vim.fn.getcwd()
	local hash = vim.fn.fnamemodify(root, ":p"):gsub("/", "%%")
	local path = vim.fn.stdpath("data") .. "/mark9/" .. hash .. ".json"

	uv.fs_mkdir(vim.fn.stdpath("data") .. "/mark9", 448)
	local fd = assert(uv.fs_open(path, "w", 420))
	uv.fs_write(fd, vim.json.encode(marks))
	uv.fs_close(fd)
end

return M
