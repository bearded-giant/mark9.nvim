if vim.g.loaded_mark9 then
	return
end
vim.g.loaded_mark9 = true

-- Only auto-initialize if the config is not set
if not vim.g.mark9_user_config then
	vim.schedule(function()
		require("mark9").setup()
	end)
end
