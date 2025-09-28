local M = {}

local Config = require("mark9.config")
local api = vim.api
local fn = vim.fn
local uv = vim.loop

local ns_id = api.nvim_create_namespace("mark9")
local extmarks_by_char = {}
local sign_group = "Mark9Signs"
local sign_name = "Mark9Icon"

function M.load_marks()
	local root = vim.fn.getcwd()
	local hash = vim.fn.fnamemodify(root, ":p"):gsub("/", "%%")
	local path = vim.fn.stdpath("data") .. "/mark9/" .. hash .. ".json"

	local fd, err = uv.fs_open(path, "r", 420)
	if not fd then
		return
	end

	local stat = uv.fs_fstat(fd)
	if not stat then
		uv.fs_close(fd)
		return
	end

	local data = uv.fs_read(fd, stat.size, 0)
	uv.fs_close(fd)

	if not data then
		return
	end

	local ok, marks = pcall(vim.json.decode, data)
	if not ok or not marks then
		return
	end

	for _, mark in ipairs(marks) do
		local char = mark.char
		local file = mark.file or ""
		local line = mark.line

		if char and file ~= "" and line and line > 0 then
			pcall(function()
				local abs_file = vim.fn.fnamemodify(file, ":p")
				local buf = fn.bufnr(abs_file)
				if buf <= 0 then
					buf = vim.fn.bufadd(abs_file)
				end

				if buf > 0 then
					vim.fn.bufload(buf)
					pcall(vim.api.nvim_buf_set_mark, buf, char, line, mark.col or 0, {})
					
					if Config.options.sign_enabled then
						fn.sign_place(0, sign_group, sign_name, buf, { lnum = line, priority = 10 })
					end
					
					if Config.options.virtual_text_enabled then
						pcall(api.nvim_buf_set_extmark, buf, ns_id, line - 1, 0, {
							virt_text = { { Config.options.virtual_icon, "DiagnosticHint" } },
							virt_text_pos = Config.options.virtual_text_pos,
						})
					end
					
					if Config.options.highlight_line_enabled then
						pcall(api.nvim_buf_add_highlight,
							buf,
							ns_id,
							Config.options.highlight_group or "Visual",
							line - 1,
							0,
							-1
						)
					end
				end
			end)
		end
	end
end

function M.setup()
	fn.sign_define(sign_name, {
		text = Config.options.sign_icon or "*",
		texthl = "DiagnosticHint",
		numhl = "",
	})

	M.load_marks()

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
		-- if not Config.options.use_telescope then
		-- 	vim.notify(
		-- 		"[mark9] Telescope is disabled. Enable with use_telescope=true or use Mark9List instead.",
		-- 		vim.log.levels.WARN
		-- 	)
		-- 	return
		-- end

		local ok = pcall(require, "telescope")
		if not ok then
			vim.notify("[mark9] Telescope plugin is not available. Please install telescope.nvim", vim.log.levels.ERROR)
			return
		end

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

	api.nvim_create_user_command("Mark9DeleteAtLine", function()
		M.delete_mark_at_line()
	end, {})

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
	
	api.nvim_create_autocmd("VimLeavePre", {
		group = api.nvim_create_augroup("Mark9Save", { clear = true }),
		callback = function()
			M.save_marks()
		end,
	})
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

function M.delete_mark_at_line()
	local cur_buf = api.nvim_get_current_buf()
	local cur_line = fn.line(".")

	for _, char in ipairs(Config.options.mark_chars) do
		local pos = api.nvim_get_mark(char, {})
		if pos and pos[1] == cur_line and pos[4] == cur_buf then
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
			vim.notify("[mark9] Deleted mark '" .. char .. "' at line " .. cur_line, vim.log.levels.INFO)
			M.save_marks()
			return true
		end
	end

	vim.notify("[mark9] No mark at current line", vim.log.levels.INFO)
	return false
end

function M.telescope_picker()
	local original_setting = Config.options.use_telescope
	local ok, telescope = pcall(require, "mark9.telescope")
	if ok then
		telescope.picker()
	else
		vim.notify("[mark9] Telescope module not available", vim.log.levels.WARN)
		M.floating_menu()
	end
	Config.options.use_telescope = original_setting
end

function M.list_picker()
	local use_telescope = Config.options.use_telescope
	if use_telescope then
		M.telescope_picker()
	else
		M.floating_menu()
	end
	Config.options.use_telescope = use_telescope
end

function M.floating_menu()
	local marks = {}
	local invalid_marks = {}

	for _, char in ipairs(Config.options.mark_chars) do
		local pos = api.nvim_get_mark(char, {})
		if pos and pos[1] > 0 then
			local file = fn.bufname(pos[4]) or ""

			-- Check if file is valid
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
					local display_file = file
					local line_text = ""

					pcall(function()
						if fn.bufnr(file) > 0 then
							local bufnr = fn.bufnr(file)
							if api.nvim_buf_is_valid(bufnr) then
								local line_count = api.nvim_buf_line_count(bufnr)
								if pos[1] > 0 and pos[1] <= line_count then
									line_text = api.nvim_buf_get_lines(bufnr, pos[1] - 1, pos[1], false)[1] or ""
									line_text = line_text:gsub("^%s+", "")
								end
							end
						end
					end)

					table.insert(marks, {
						char = char,
						file = file,
						display_file = display_file,
						line = pos[1],
						text = line_text,
					})
				end
			end
		end
	end

	-- Clean up invalid marks
	if #invalid_marks > 0 then
		for _, char in ipairs(invalid_marks) do
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
		M.save_marks()
		vim.notify(string.format("[mark9] Cleaned up %d invalid mark(s)", #invalid_marks), vim.log.levels.INFO)
	end

	local buf = api.nvim_create_buf(false, true)
	api.nvim_buf_set_option(buf, "modifiable", false)
	api.nvim_buf_set_option(buf, "buftype", "nofile")
	api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	api.nvim_buf_set_option(buf, "swapfile", false)
	api.nvim_buf_set_option(buf, "buflisted", false)
	api.nvim_buf_set_option(buf, "filetype", "mark9")
	
	local lines = {}
	for _, m in ipairs(marks) do
		local filename = m.file ~= "" and fn.fnamemodify(m.file, ":t") or "<Unknown>"
		table.insert(lines, string.format("%s - %s:%d %s", m.char, filename, m.line, m.text))
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

	api.nvim_buf_set_option(buf, "modifiable", true)
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	api.nvim_buf_set_option(buf, "modifiable", false)

	local height = Config.options.window_height or math.min(#lines, Config.options.window_max_height or 20)
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
	api.nvim_win_set_option(win, "winfixbuf", true)
	
	if #marks > 0 then
		api.nvim_win_set_cursor(win, { vp + 1, 0 })
	end
	
	local augroup = api.nvim_create_augroup("Mark9Modal", { clear = true })
	api.nvim_create_autocmd({"BufLeave", "WinLeave"}, {
		group = augroup,
		buffer = buf,
		callback = function()
			if api.nvim_win_is_valid(win) then
				api.nvim_win_close(win, true)
			end
		end,
	})
	
	for _, key in ipairs(Config.options.keymaps.disabled or {}) do
		vim.keymap.set({'n', 'i'}, key, '<Nop>', { buffer = buf, silent = true })
	end
	
	local buffer_switch_cmds = {':b', ':buffer', ':bn', ':bnext', ':bp', ':bprev', ':e', ':edit', ':n', ':next', ':prev', ':previous'}
	for _, cmd in ipairs(buffer_switch_cmds) do
		vim.keymap.set('n', cmd, '<Nop>', { buffer = buf, silent = true })
	end

	for _, key in ipairs(Config.options.keymaps.close or { "q" }) do
		vim.keymap.set("n", key, function()
			if api.nvim_win_is_valid(win) then
				api.nvim_win_close(win, true)
			end
		end, { buffer = buf })
	end

	for _, key in ipairs(Config.options.keymaps.select or { "<CR>" }) do
		vim.keymap.set("n", key, function()
		local idx = api.nvim_win_get_cursor(win)[1] - vp
		local m = marks[idx]
		if m and m.file and m.file ~= "" then
			api.nvim_win_close(win, true)
			vim.schedule(function()
				local ok = pcall(vim.cmd, "edit " .. vim.fn.fnameescape(m.file))
				if ok then
					local line_count = api.nvim_buf_line_count(0)
					local target_line = math.min(m.line, line_count)
					if target_line > 0 then
						api.nvim_win_set_cursor(0, { target_line, 0 })
						vim.cmd("normal! zz")
					end
				else
					vim.notify("[mark9] Cannot open file: " .. m.file, vim.log.levels.ERROR)
				end
			end)
		elseif m then
			vim.notify("[mark9] Mark has invalid file reference", vim.log.levels.WARN)
		end
		end, { buffer = buf })
	end
	
	for i, mark in ipairs(marks) do
		vim.keymap.set("n", mark.char, function()
			if mark.file and mark.file ~= "" then
				api.nvim_win_close(win, true)
				vim.schedule(function()
					local ok = pcall(vim.cmd, "edit " .. vim.fn.fnameescape(mark.file))
					if ok then
						local line_count = api.nvim_buf_line_count(0)
						local target_line = math.min(mark.line, line_count)
						if target_line > 0 then
							api.nvim_win_set_cursor(0, { target_line, 0 })
							vim.cmd("normal! zz")
						end
					else
						vim.notify("[mark9] Cannot open file: " .. mark.file, vim.log.levels.ERROR)
					end
				end)
			else
				vim.notify("[mark9] Mark has invalid file reference", vim.log.levels.WARN)
			end
		end, { buffer = buf })

		vim.keymap.set("n", tostring(i), function()
			if mark.file and mark.file ~= "" then
				api.nvim_win_close(win, true)
				vim.schedule(function()
					local ok = pcall(vim.cmd, "edit " .. vim.fn.fnameescape(mark.file))
					if ok then
						local line_count = api.nvim_buf_line_count(0)
						local target_line = math.min(mark.line, line_count)
						if target_line > 0 then
							api.nvim_win_set_cursor(0, { target_line, 0 })
							vim.cmd("normal! zz")
						end
					else
						vim.notify("[mark9] Cannot open file: " .. mark.file, vim.log.levels.ERROR)
					end
				end)
			else
				vim.notify("[mark9] Mark has invalid file reference", vim.log.levels.WARN)
			end
		end, { buffer = buf })
	end

	for _, key in ipairs(Config.options.keymaps.delete or { "dd" }) do
		vim.keymap.set("n", key, function()
		local cursor_line = api.nvim_win_get_cursor(win)[1]
		local idx = cursor_line - vp
		if idx < 1 or idx > #marks then
			return
		end
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
						string.format("%s - %s:%d %s", mark.char, fn.fnamemodify(mark.file, ":t"), mark.line, mark.text)
					)
				end

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
					api.nvim_buf_set_option(buf, "modifiable", true)
					api.nvim_buf_set_lines(buf, 0, -1, false, updated_lines)
					api.nvim_buf_set_option(buf, "modifiable", false)
					
					local new_cursor_line = cursor_line
					if new_cursor_line > #updated_lines then
						new_cursor_line = #updated_lines
					end
					if new_cursor_line < vp + 1 and #marks > 0 then
						new_cursor_line = vp + 1
					end
					if api.nvim_win_is_valid(win) then
						api.nvim_win_set_cursor(win, { new_cursor_line, 0 })
					end
				end
			end)
		end
		end, { buffer = buf })
	end
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
