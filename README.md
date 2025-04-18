# mark9.nvim

**mark9.nvim** is a minimal, line-level Harpoon-style mark plugin for Neovim.
This plugin bridges the simplicity of Harpoon with the line-level recall of marks.

## Features

- Persistent line-level marks (limited to 9, file-scoped)
- Gutter and virtual icons for visibility
- A floating list menu (optional)
- Telescope integration with preview
- FIFO cycling when all slots are full
- Project-scoped persistence without polluting your repo

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

## Usage

### Key Mappings

| Mapping      | Description           |
| ------------ | --------------------- |
| `<leader>ha` | Add current line mark |
| `<leader>hl` | Show mark list        |
| `<leader>hL` | Open Telescope picker |
| `<leader>hc` | Clear all marks       |

### Commands

| Command     | Description                         |
| ----------- | ----------------------------------- |
| `Mark9Save` | Manually save marks to project file |
| `Mark9Load` | Manually load marks from file       |
| `Mark9Menu` | Open floating mark menu             |
| `Mark9List` | Open Telescope mark picker          |

## Configuration

### Default Configuration

```lua
require("mark9").setup({
  -- UI Options
  use_telescope = true,        -- Use Telescope for mark list (fallbacks to floating window if false)
  sign_icon = "_",             -- Icon displayed in the gutter
  virtual_text = true,         -- Show virtual inline icon at the mark line
  virtual_icon = "_",          -- Symbol used for virtual text (if enabled)
  virtual_text_pos = "eol",    -- Position: 'eol', 'overlay', or 'right_align'

  -- Floating Window Options
  horizontal_padding =  2    -- Horizontal padding in floating window
  window_padding = 1,          -- Top and Bottom padding in floating window
  window_position = "center",  -- 'center', 'top_left', 'top_right', 'bottom_left', 'bottom_right'
  window_width_percent = 0.4,  -- Window width as percentage of editor width

  -- Mark Configuration
  mark_chars = { "A", "B", "C", "D", "E", "F", "G", "H", "I" } -- Characters used for marks
})
```

## Persistence

Mark files are automatically saved on exit and reloaded per project.
They're stored in:

```
~/.local/share/nvim/mark9/<sanitized-project-root>.json
```

This avoids `.gitignore` issues and prevents shared state across projects.

## Roadmap

- [x] Telescope picker with preview
- [x] FIFO overwrite behavior
- [x] Project-local scoped persistence
- [ ] Dot-repeatable mark navigation
- [ ] Marks sorted and grouped by file in UI
- [ ] Custom Telescope extension (optional config)
- [ ] Optional help file for `:h mark9`

## License

MIT
