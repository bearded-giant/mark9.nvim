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
  config = function()
    require("mark9").setup({
      use_telescope = true,
      sign_icon = "*",
      virtual_text = true,
      virtual_icon = "*",
      virtual_text_pos = "eol",
      window_padding = 1,
    })
  end,
  keys = {
    { "<leader>ha", function() require("mark9.marks").add_mark() end, desc = "Add mark" },
    { "<leader>hl", function() require("mark9.marks").telescope_picker() end, desc = "List marks" },
    { "<leader>hL", function() require("mark9.telescope").picker() end, desc = "Telescope picker" },
    { "<leader>hc", function() require("mark9.marks").clear_all_marks() end, desc = "Clear all" },
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

---

## Configuration

You can configure `mark9` via `setup({ ... })`:

```lua
require("mark9").setup({
  use_telescope = true,         -- whether to use Telescope or fallback window
  sign_icon = "*",              -- icon in signcolumn
  virtual_text = true,         -- show inline icon at line
  virtual_icon = "*",          -- text for inline icon
  virtual_text_pos = "eol",   -- eol | overlay | right_align
  window_padding = 1,          -- lines of padding for fallback list menu
})
```

---

## Persistence

Mark files are automatically saved on exit and reloaded per project.
They’re stored in:

```
~/.local/share/nvim/mark9/<sanitized-project-root>.json
```

This avoids `.gitignore` issues and prevents shared state across projects.

---

## Roadmap

- [x] Telescope picker with preview
- [x] FIFO overwrite behavior
- [x] Project-local scoped persistence
- [ ] Dot-repeatable mark navigation
- [ ] Marks sorted and grouped by file in UI
- [ ] Custom Telescope extension (optional config)
- [ ] Optional help file for `:h mark9`

---

## License

MIT
