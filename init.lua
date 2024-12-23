-- Set <space> as the leader key
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Set to true if you have a Nerd Font installed
vim.g.have_nerd_font = false

-- [[ Setting options ]]
vim.opt.number = true
vim.opt.relativenumber = true
vim.cmd [[
try
  colorscheme habamax 
catch /^Vim\%((\a\+)\)\=:E185/
  colorscheme default 
  set background=dark
endtry
]]

vim.opt.mouse = 'a'

vim.opt.showmode = true

vim.opt.clipboard = 'unnamedplus'

-- Enable break indent
vim.opt.breakindent = true

-- Save undo history
vim.opt.undofile = true

-- Case-insensitive
vim.opt.ignorecase = false
vim.opt.smartcase = false

-- Keep signcolumn on by default
vim.opt.signcolumn = 'yes'

-- Decrease update time
vim.opt.updatetime = 250

-- Decrease mapped sequence wait time
-- Displays which-key popup sooner
vim.opt.timeoutlen = 300

-- Configure how new splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.opt.inccommand = 'split'

-- Show which line your cursor is on
vim.opt.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 10

-- [[ console.log ]]
vim.api.nvim_set_keymap('n', '<leader>cl', ':lua AppendConsoleLog()<CR>', { noremap = true, silent = true })

function AppendConsoleLog()
  local line = 'console.log("******************************************************");'
  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, current_line, current_line, false, { line })
end

-- [[ console.log ]]

-- [[ confirm command ]]
local confirm_commands = { 'qa' }

local function confirm_before_quit(cmd)
  if vim.tbl_contains(confirm_commands, cmd) then
    local choice = vim.fn.confirm("Do you even know what kind of shit you're getting yourself into <" .. cmd .. '>?', '&Yeah\n&Nah', 2)
    if choice == 1 then
      vim.cmd(cmd)
    end
  else
    vim.cmd(cmd)
  end
end

vim.api.nvim_create_user_command('QA', function()
  confirm_before_quit 'qa'
end, {})

-- Replace qa with QA completely
vim.cmd 'cmap qa QA'
-- [[ confirm command ]]

-- [[ alies command ]]
-- vim.cmd 'cmap ex Ex'
-- [[ alies command ]]

-- [[ Basic Keymaps ]]

-- Open Oil
-- vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
vim.api.nvim_create_user_command("Ex", function()
  vim.cmd("Oil")
end, { desc = "Run Oil instead of :Ex" })

-- Set highlight on search, but clear on pressing <Esc> in normal mode
vim.opt.hlsearch = true
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous [D]iagnostic message' })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next [D]iagnostic message' })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic [E]rror messages' })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Terminal
-- TODO: This won't work in all terminal emulators/tmux/etc. Try your own mapping
vim.api.nvim_create_autocmd('TermOpen', {
    group = vim.api.nvim_create_augroup('custom-terminal-open', {clear = true}),
    callback = function ()
    vim.opt.number = false
    vim.opt.relativenumber = false
    vim.api.nvim_win_set_width(0, 85)
    vim.api.nvim_buf_set_keymap(0, 't', '<Esc>', [[<C-\><C-n>]], { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(0, 'n', 'i', 'i', { noremap = true, silent = true })
    end
})
vim.keymap.set('n', '<space>st', function ()
    vim.cmd.vnew()
    vim.cmd.term()
    vim.cmd('startinsert')
end)

-- Keybinds to make split navigation easier.
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- Refresh setting
vim.keymap.set('n', '<leader>rr', ':source $MYVIMRC<CR>', { noremap = true, silent = true })

-- [[ Basic Autocommands ]]

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('sajad-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- [[ Install `lazy.nvim` plugin manager ]]
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
end ---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

-- [[ Configure and install plugins ]]
require('lazy').setup({
  'tpope/vim-sleuth',

  require 'plugins.oil',
  require 'plugins.hop',
  require 'plugins.gitsigns',
  require 'plugins.which-key',
  require 'plugins.telescope',
  require 'plugins.lspconfig',
  require 'plugins.autoformat',
  require 'plugins.autocompletion',
  require 'plugins.comment',
  -- require 'plugins.colorscheme',
  -- require 'plugins.commentColor',
  require 'plugins.mini',
  require 'plugins.treesitter',
  require 'plugins.debug',
  require 'plugins.indent_line',
  require 'plugins.lint',
}, {
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})
