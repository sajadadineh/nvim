return { -- LSP Configuration & Plugins
  'neovim/nvim-lspconfig',
  dependencies = {
    -- Automatically install LSPs and related tools to stdpath for Neovim
    'williamboman/mason.nvim',
    'williamboman/mason-lspconfig.nvim',
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    { 'j-hui/fidget.nvim', opts = {} },
    { 'folke/neodev.nvim', opts = {} },
  },
  config = function()
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('sajad-lsp-attach', { clear = true }),
      callback = function(event)
        local map = function(keys, func, desc)
          vim.keymap.set('n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
        end

        -- Jump to the definition of the word under your cursor.
        local function goto_definition_in_tab()
          local params = vim.lsp.util.make_position_params()
          vim.lsp.buf_request(0, 'textDocument/definition', params, function(err, result, ctx, _)
            if err or not result or vim.tbl_isempty(result) then
              print 'Definition not found'
              return
            end

            local def_uri = result[1].uri or result[1].targetUri
            local def_path = vim.uri_to_fname(def_uri)

            -- Try to get the position (line and character)
            local def_pos = nil
            if result[1].range then
              def_pos = result[1].range.start
            elseif result[1].targetRange then
              def_pos = result[1].targetRange.start
            elseif result[1].selectionRange then
              def_pos = result[1].selectionRange.start
            end

            local found_tab = nil

            -- Check if the buffer is already open in a tab
            for _, tabnr in ipairs(vim.api.nvim_list_tabpages()) do
              for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(tabnr)) do
                local bufnr = vim.api.nvim_win_get_buf(winid)
                if vim.api.nvim_buf_get_name(bufnr) == def_path then
                  found_tab = tabnr
                  vim.api.nvim_set_current_tabpage(tabnr)
                  vim.api.nvim_set_current_win(winid)
                  vim.api.nvim_set_current_buf(bufnr)

                  -- If we have a valid position, move the cursor to that position
                  if def_pos then
                    vim.api.nvim_win_set_cursor(winid, { def_pos.line + 1, def_pos.character })
                  end

                  return
                end
              end
            end

            -- If not found, open in a new tab
            if not found_tab then
              vim.cmd('tabnew ' .. def_path)
              -- Jump to the location using LSP utility
              if def_pos then
                vim.lsp.util.jump_to_location(result[1])
              end
            end
          end)
        end

        vim.keymap.set('n', 'gd', goto_definition_in_tab, { desc = '[G]oto [D]efinition' })

        -- Find references for the word under your cursor.
        map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')

        -- Jump to the implementation of the word under your cursor.
        map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')

        -- Jump to the type of the word under your cursor.
        map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')

        -- Fuzzy find all the symbols in your current document.
        map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')

        -- Fuzzy find all the symbols in your current workspace.
        map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')

        -- Rename the variable under your cursor.
        map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')

        -- Execute a code action, usually your cursor needs to be on top of an error
        map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')

        -- Opens a popup that displays documentation about the word under your cursor
        map('K', vim.lsp.buf.hover, 'Hover Documentation')

        -- WARN: This is not Goto Definition, this is Goto Declaration.
        map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

        -- When you move your cursor, the highlights will be cleared (the second autocommand).
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client.server_capabilities.documentHighlightProvider then
          vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
            buffer = event.buf,
            callback = vim.lsp.buf.document_highlight,
          })

          vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
            buffer = event.buf,
            callback = vim.lsp.buf.clear_references,
          })
        end
      end,
    })

    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())

    -- Enable the following language servers
    local servers = {
      -- clangd = {},
      -- gopls = {},
      -- pyright = {},
      -- rust_analyzer = {},
      -- ... etc. See `:help lspconfig-all` for a list of all the pre-configured LSPs
      --
      -- Some languages (like typescript) have entire language plugins that can be useful:
      --    https://github.com/pmizio/typescript-tools.nvim
      --
      -- But for many setups, the LSP (`tsserver`) will work just fine
      -- tsserver = {},
      lua_ls = {
        -- cmd = {...},
        -- filetypes = { ...},
        -- capabilities = {},
        settings = {
          Lua = {
            completion = {
              callSnippet = 'Replace',
            },
          },
        },
      },
    }

    require('mason').setup()

    local ensure_installed = vim.tbl_keys(servers or {})
    vim.list_extend(ensure_installed, {
      'stylua',
    })
    require('mason-tool-installer').setup { ensure_installed = ensure_installed }

    require('mason-lspconfig').setup {
      handlers = {
        function(server_name)
          local server = servers[server_name] or {}
          server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
          require('lspconfig')[server_name].setup(server)
        end,
      },
    }
  end,
}
