-- ~/.config/nvim/lua/plugins/theme-switcher.lua

return {
  "nvim-lua/plenary.nvim", -- dummy spec so Lazy accepts the file
  name = "theme-switcher",
  lazy = false,
  priority = 1000,
  dependencies = { "nvim-telescope/telescope.nvim" },

  config = function()
    local themes_path = vim.fn.stdpath("data") .. "/theme_switcher"
    local current_theme_file = themes_path .. "/current.txt"
    vim.fn.mkdir(themes_path, "p")

    -- Cache for fast completion
    local theme_cache = nil
    local function get_all_themes()
      if theme_cache then return theme_cache end
      local themes = vim.fn.getcompletion("", "color")
      table.sort(themes)
      theme_cache = themes
      return themes
    end

    -- Invalidate cache when new colorschemes are added/removed
    vim.api.nvim_create_autocmd("ColorSchemePre", {
      callback = function() theme_cache = nil end,
    })

    local function save_theme(name)
      vim.fn.writefile({ name }, current_theme_file)
    end

    local function load_saved_theme()
      if not vim.uv.fs_stat(current_theme_file) then return end
      local file = io.open(current_theme_file, "r")
      if not file then return end
      local saved = file:read("*l")
      file:close()
      if saved and saved ~= "" then
        if vim.tbl_contains(get_all_themes(), saved) then
          vim.cmd.colorscheme(saved)
          vim.schedule(function()
            vim.notify("Theme restored: " .. saved, vim.log.levels.INFO, { title = "Theme Switcher" })
          end)
        end
      end
    end

    local function open_picker()
      local themes = get_all_themes()
      if #themes == 0 then
        vim.notify("No colorschemes found!", vim.log.levels.WARN)
        return
      end

      require("telescope.pickers").new({}, {
        prompt_title = "Select Colorscheme",
        finder = require("telescope.finders").new_table({ results = themes }),
        sorter = require("telescope.config").values.generic_sorter({}),
        attach_mappings = function(bufnr, map)
          local actions = require("telescope.actions")
          local action_state = require("telescope.actions.state")

          local function apply_and_save()
            local selection = action_state.get_selected_entry()
            actions.close(bufnr)
            if selection then
              local theme = selection[1]
              vim.cmd.colorscheme(theme)
              save_theme(theme)
              vim.notify("Theme → " .. theme, vim.log.levels.INFO, { title = "Theme Switcher" })
            end
          end

          map("i", "<CR>", apply_and_save)
          map("n", "<CR>", apply_and_save)
          map("i", "<C-t>", function()
            local theme = action_state.get_selected_entry()[1]
            vim.cmd.colorscheme(theme)
            vim.notify("Preview: " .. theme, vim.log.levels.INFO, { title = "Theme Preview" })
          end)

          return true
        end,
      }):find()
    end

    -- :Theme with  Tab completion
    vim.api.nvim_create_user_command("Theme", function(o)
      if o.args and o.args ~= "" then
        local ok = pcall(vim.cmd.colorscheme, o.args)
        if ok then
          save_theme(o.args)
          vim.notify("Theme → " .. o.args, vim.log.levels.INFO, { title = "Theme Switcher" })
        else
          vim.notify("Theme '" .. o.args .. "' not found", vim.log.levels.ERROR)
        end
      else
        open_picker()
      end
    end, {
      nargs = "?", -- 0 or 1 argument
      complete = function(arglead, cmdline, cursorpos)
        -- This gives you instant, filtered Tab completion
        local themes = get_all_themes()
        if arglead and arglead ~= "" then
          return vim.tbl_filter(function(theme)
            return theme:lower():find(arglead:lower(), 1, true) ~= nil
          end, themes)
        end
        return themes
      end,
    })

    -- Restore last theme on startup
    vim.schedule(load_saved_theme)
  end,
}

