-- ~/.config/nvim/lua/config/codex.lua

local M = {}

M.state = {
  buf = nil,
  win = nil,
  job = nil,
}

function M.toggle()
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    vim.api.nvim_win_close(M.state.win, true)

    -- kill terminal job
    if M.state.job then
      vim.fn.jobstop(M.state.job)
    end

    M.state = {
      buf = nil,
      win = nil,
      job = nil,
    }

    return
  end

  -- create buffer
  local buf = vim.api.nvim_create_buf(false, true)

  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.85)

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = '',
    border = 'rounded',
    title = ' Codex ',
    title_pos = 'center',
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  -- prettier window
  vim.wo[win].winblend = 5
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].cursorline = false

  local job = vim.fn.termopen 'codex'

  M.state.buf = buf
  M.state.win = win
  M.state.job = job

  -- ESC => normal mode inside terminal
  vim.keymap.set('t', '<Esc>', [[<C-\><C-n>]], {
    buffer = buf,
    silent = true,
  })

  -- q => close everything
  vim.keymap.set('n', 'q', function()
    M.toggle()
  end, {
    buffer = buf,
    silent = true,
  })

  vim.cmd 'startinsert'
end

return M
