return {
  "BrainSh0ck/lazyvim-theme-switcher",
  name = "theme-switcher",
  lazy = false,
  priority = 1000,
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    local themes_path = vim.fn.stdpath("data") .. "/theme_switcher"
    local current_theme_file = themes_path .. "/current.txt"
    local transparency_file = themes_path .. "/transparent.txt"
    vim.fn.mkdir(themes_path, "p")

    local theme_cache = nil
    local current_transparent = false

    local function get_all_themes()
      if theme_cache then
        return theme_cache
      end
      local themes = vim.fn.getcompletion("", "color")
      table.sort(themes)
      theme_cache = themes
      return themes
    end

    vim.api.nvim_create_autocmd("ColorSchemePre", {
      callback = function()
        theme_cache = nil
      end,
    })

    local transparency_groups = {
      "Normal",
      "NormalFloat",
      "NormalNC",
      "SignColumn",
      "StatusLine",
      "StatusLineNC",
      "VertSplit",
      "WinSeparator",
      "Pmenu",
      "PmenuSbar",
      "PmenuThumb",
      "TelescopeNormal",
      "TelescopeBorder",
      "TelescopePromptNormal",
      "TelescopePromptBorder",
      "TelescopeResultsNormal",
      "TelescopeResultsBorder",
      "TelescopePreviewNormal",
      "TelescopePreviewBorder",
      "NeoTreeNormal",
      "NeoTreeNormalNC",
      "WhichKeyFloat",
    }

    local function set_transparent(transparent)
      current_transparent = transparent
      if transparent then
        for _, group in ipairs(transparency_groups) do
          vim.api.nvim_set_hl(0, group, { bg = "none" })
        end
      else
        if vim.g.colors_name then
          vim.cmd.colorscheme(vim.g.colors_name)
        end
      end
    end

    local function save_state(theme_name, transparent)
      local ok1 = pcall(vim.fn.writefile, { theme_name }, current_theme_file)
      local ok2 = pcall(vim.fn.writefile, { transparent and "1" or "0" }, transparency_file)
      if not (ok1 and ok2) then
        vim.notify("Failed to save theme state", vim.log.levels.WARN, { title = "Theme Switcher" })
      end
    end

    local function load_saved_state()
      local theme_ok, saved_theme = pcall(vim.fn.readfile, current_theme_file)
      local trans_ok, saved_trans = pcall(vim.fn.readfile, transparency_file)
      local theme = (theme_ok and #saved_theme > 0) and saved_theme[1] or nil
      local transparent = (trans_ok and #saved_trans > 0) and saved_trans[1] == "1"
      if theme and vim.tbl_contains(get_all_themes(), theme) then
        local ok = pcall(vim.cmd.colorscheme, theme)
        if ok then
          set_transparent(transparent)
          vim.schedule(function()
            vim.notify(
              ("Theme restored: %s%s"):format(theme, transparent and " (transparent)" or ""),
              vim.log.levels.INFO,
              { title = "Theme Switcher" }
            )
          end)
        else
          vim.notify("Failed to load saved theme: " .. theme, vim.log.levels.WARN)
        end
      elseif theme then
        vim.notify("Previously saved theme '" .. theme .. "' no longer exists", vim.log.levels.WARN)
      end
    end

    local function switch_theme(name, transparent_opt)
      local ok = pcall(vim.cmd.colorscheme, name)
      if not ok then
        vim.notify("Theme '" .. name .. "' not found", vim.log.levels.ERROR, { title = "Theme Switcher" })
        return false
      end
      local transparent = transparent_opt ~= nil and transparent_opt or current_transparent
      set_transparent(transparent)
      save_state(name, transparent)
      vim.notify(
        ("Theme → %s%s"):format(name, transparent and " (transparent)" or ""),
        vim.log.levels.INFO,
        { title = "Theme Switcher" }
      )
      return true
    end

    local function toggle_transparency()
      local current = vim.g.colors_name
      if not current then
        vim.notify("No theme is currently active", vim.log.levels.WARN, { title = "Theme Switcher" })
        return
      end
      local new_transparent = not current_transparent
      set_transparent(new_transparent)
      save_state(current, new_transparent)
      vim.notify(
        ("Transparency %s"):format(new_transparent and "enabled" or "disabled"),
        vim.log.levels.INFO,
        { title = "Theme Switcher" }
      )
    end

    local function open_picker()
      local themes = get_all_themes()
      if #themes == 0 then
        vim.notify("No colorschemes found!", vim.log.levels.WARN, { title = "Theme Switcher" })
        return
      end
      local pickers = require("telescope.pickers")
      local finders = require("telescope.finders")
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")
      local conf = require("telescope.config").values

      pickers
        .new({}, {
          prompt_title = "Select Colorscheme (C-t = toggle transparency, C-p = preview)",
          finder = finders.new_table({
            results = themes,
            entry_maker = function(entry)
              local display = entry
              if entry == vim.g.colors_name then
                display = display .. " [current]"
                if current_transparent then
                  display = display .. " [transparent]"
                end
              end
              return { value = entry, display = display, ordinal = entry }
            end,
          }),
          sorter = conf.generic_sorter({}),
          attach_mappings = function(bufnr, map)
            local function apply_theme(with_transparency)
              local selection = action_state.get_selected_entry()
              actions.close(bufnr)
              if selection then
                switch_theme(selection.value, with_transparency)
              end
            end

            map("i", "<CR>", function() apply_theme(current_transparent) end)
            map("n", "<CR>", function() apply_theme(current_transparent) end)
            map("i", "<C-t>", function() apply_theme(not current_transparent) end)
            map("n", "<C-t>", function() apply_theme(not current_transparent) end)
            map("i", "<C-p>", function()
              local selection = action_state.get_selected_entry()
              if selection then
                vim.cmd.colorscheme(selection.value)
                vim.notify("Preview: " .. selection.value, vim.log.levels.INFO, { title = "Theme Preview" })
              end
            end)
            map("n", "<C-p>", function()
              local selection = action_state.get_selected_entry()
              if selection then
                vim.cmd.colorscheme(selection.value)
                vim.notify("Preview: " .. selection.value, vim.log.levels.INFO, { title = "Theme Preview" })
              end
            end)
            return true
          end,
        })
        :find()
    end

    vim.api.nvim_create_user_command("Theme", function(opts)
      local args = vim.split(vim.trim(opts.args), "%s+")
      local theme_name = args[1]
      local trans_str = args[2]

      if theme_name == "true" or theme_name == "false" then
        local new_transparent = (theme_name == "true")
        local current = vim.g.colors_name
        if current then
          set_transparent(new_transparent)
          save_state(current, new_transparent)
          vim.notify(
            ("Transparency %s"):format(new_transparent and "enabled" or "disabled"),
            vim.log.levels.INFO,
            { title = "Theme Switcher" }
          )
        else
          vim.notify("No theme is currently active", vim.log.levels.WARN, { title = "Theme Switcher" })
        end
        return
      end

      if not theme_name or theme_name == "" then
        open_picker()
        return
      end

      local transparent = nil
      if trans_str then
        if trans_str == "true" or trans_str == "1" then
          transparent = true
        elseif trans_str == "false" or trans_str == "0" then
          transparent = false
        else
          vim.notify("Second argument must be 'true' or 'false'", vim.log.levels.ERROR, { title = "Theme Switcher" })
          return
        end
      end

      switch_theme(theme_name, transparent)
    end, {
      nargs = "*",
      complete = function(arglead, cmdline)
        local args = vim.split(cmdline, "%s+")
        if #args <= 2 then
          local themes = get_all_themes()
          local options = vim.list_extend({ "true", "false" }, themes)
          if arglead and arglead ~= "" then
            return vim.tbl_filter(function(item)
              return item:lower():find(arglead:lower(), 1, true) ~= nil
            end, options)
          end
          return options
        end
        if #args == 3 then
          return { "true", "false" }
        end
        return {}
      end,
    })

    vim.api.nvim_create_user_command("ThemeToggleTransparency", toggle_transparency, {})

    vim.schedule(load_saved_state)
  end,
}
