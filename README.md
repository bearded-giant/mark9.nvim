# mark9.nvim

**mark9.nvim** is a minimal, line-level Harpoon-style mark plugin for Neovim.

This is a solve I wanted which bridges the simplicity of Harpoon with the line-level recall of marks.

`mark9` provides:

- Persistent line-level marks (limited to 9, file-scoped)
- Gutter and virtual icons for visibility
- A floating list menu (optional)
- Telescope integration with preview
- FIFO cycling when all slots are full
- Project-scoped persistence without polluting your repo

---

## Installation

### Using [Lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "bearded-giant/mark9.nvim",
  lazy = false, -- ensures it loads on startup, required for early mark access
  config = function()
    require("mark9").setup({})
  end,
  keys = {
    { "<leader>ha", function() require("mark9.marks").add_mark() end, desc = "Add mark" },
    { "<leader>hl", function() vim.cmd("Mark9List") end, desc = "List marks" },
    { "<leader>hL", function() require("mark9.telescope").picker() end, desc = "Telescope picker" },
    { "<leader>hc", function() vim.cmd("Mark9ClearAll") end, desc = "Clear all marks" },
  },
  dependencies = { "nvim-telescope/telescope.nvim" },
}
```

---

## Usage

| Mapping      | Description           |
| ------------ | --------------------- |
| `<leader>ha` | Add current line mark |
| `<leader>hl` | Show mark list        |
| `<leader>hL` | Open Telescope picker |
| `<leader>hc` | Clear all marks       |

Available user commands:

- `:Mark9List` — Open the mark picker (Telescope or floating, depending on config)
- `:Mark9Delete A` — Delete a mark by ID (e.g. A)
- `:Mark9ClearAll` — Remove all marks

---

## Configuration

Default options for mark9.nvim:

```lua
{
  -- Note: Mark9Telescope will display directly in telescope regardless of this setting
  use_telescope = false,           -- use Telescope for the Mark9List command, default is floating window

  sign_icon = "➤",                 -- icon in the gutter (sign column)
  sign_enabled = true,             -- whether to show the icon in the gutter
  virtual_text_enabled = false,    -- show inline icon at the marked line
  virtual_icon = "◆",              -- icon for inline icon
  virtual_text_pos = "eol",        -- 'eol', 'left_align', or 'right_align'
  window_padding = 2,              -- vertical padding in floating window
  horizontal_padding = 2,          -- horizontal padding in floating window
  window_position = "center",      -- 'center', 'top_left', 'top_right', 'bottom_left', 'bottom_right'
  window_width_percent = 0.4,      -- floating window width as a percent of editor width
  highlight_line_enabled = true,   -- highlight marked line
  highlight_group = "Visual",      -- highlight group used
  mark_chars = { "A", "B", "C", "D", "E", "F", "G", "H", "I" }, -- characters to use
}
```

---

## Persistence

Mark files are automatically saved on exit and reloaded per project on startup.
They’re stored in:

```
~/.local/share/nvim/mark9/<sanitized-project-root>.json
```

This avoids `.gitignore` issues and prevents shared state across projects.
When you start Neovim in a project directory, any previously saved marks will be automatically restored.

---

## Roadmap

- [x] Telescope picker with preview
- [x] FIFO overwrite behavior
- [x] Project-local scoped persistence
- [x] Floating window picker
- [x] `dd` deletion support in both pickers
- [x] Gutter and virtual icon support
- [x] Inline line highlighting
- [x] Full config exposure
- [x] Optional help file for `:h mark9`
- [ ] Dot-repeatable mark navigation
- [ ] Marks grouped by file in UI

---

## License

MIT
