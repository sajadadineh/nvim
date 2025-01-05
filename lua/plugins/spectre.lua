return {
  'nvim-pack/nvim-spectre',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('spectre').setup {
      live_update = true,
    }
  end,
  keys = {
    {
      '<leader>Sr',
      function()
        require('spectre').open()
      end,
      desc = 'Spectre: Search and Replace in Project',
    },
    {
      '<leader>Sf',
      function()
        require('spectre').open_file_search()
      end,
      desc = 'Spectre: Search and Replace in File',
    },
    {
      '<leader>Sw',
      function()
        require('spectre').open_visual()
      end,
      desc = 'Spectre: Search Current Word',
    },
    {
      '<leader>Sc',
      function()
        require('spectre').open_visual { select_word = true }
      end,
      desc = 'Spectre: Search Cursor Word',
    },
  },
}
