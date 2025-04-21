local M = {}

function M.setup(opts)
	if opts then
		vim.g.mark9_user_config = true
		require("mark9.config").setup(opts)
	elseif not vim.g.mark9_setup_complete then
		require("mark9.config").setup({})
	end
	
	vim.g.mark9_setup_complete = true
	require("mark9.marks").setup()
end

function M.menu()
	-- if require("mark9.config").options.use_telescope then
	--     local ok, telescope = pcall(require, "mark9.telescope")
	--     if ok then
	--         telescope.picker()
	--     else
	--         require("mark9.marks").floating_menu()
	--     end
	-- else
	--     require("mark9.marks").floating_menu()
	-- end
	
	require("mark9.marks").floating_menu()
end

return M
