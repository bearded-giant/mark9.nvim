if vim.g.loaded_mark9 then
	return
end
vim.g.loaded_mark9 = true

vim.schedule(function()
	require("mark9").setup()
end)
