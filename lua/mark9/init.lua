local M = {}

function M.setup(opts)
	vim.g.mark9_user_config = true
	require("mark9.config").setup(opts or {})
	require("mark9.marks").setup()
end

function M.menu()
	if require("mark9.config").options.use_telescope then
		require("mark9.telescope").picker()
	else
		require("mark9.marks").floating_menu()
	end
end

return M
