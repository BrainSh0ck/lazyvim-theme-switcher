-- ~/.config/nvim/lua/plugins/theme-switcher.lua
-- test
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
      if theme_cache then return theme_cache end
      local themes = vim.fn.getcompletion("", "color")
      table.sort(themes)
      theme_cache = themes
      return themes
    end

    vim.api.nvim_create_autocmd("ColorSchemePre", {
      callback = function() theme_cache = nil end,
    })

    local function set_transparent(transparent)
      current_transparent = transparent
      local bg = transparent and "none" or nil
      local function hl_clear(group)
        if bg then
          vim.api.nvim_set_hl(0, group, { bg = bg })
        else
          vim.cmd("hi clear " .. group)
        end
      end
      for _, group in ipairs({
        "Normal", "NormalFloat", "SignColumn",
        "StatusLine", "StatusLineNC", "VertSplit",
        "WinSeparator", "Pmenu", "TelescopeNormal", "TelescopeBorder"
      }) do
        hl_clear(group)
      end
      if not transparent and vim.g.colors_name then
        vim.cmd.colorscheme(vim.g.colors_name)
      end
    end

    local function save_state(theme_name, transparent)
      vim.fn.writefile({ theme_name }, current_theme_file)
      vim.fn.writefile({ transparent and "1" or "0" }, transparency_file)
    end

    local function load_saved_state()
      local theme_ok, saved_theme = pcall(vim.fn.readfile, current_theme_file)
      local trans_ok, saved_trans = pcall(vim.fn.readfile, transparency_file)

      local theme = (theme_ok and #saved_theme > 0) and saved_theme[1] or nil
      local transparent = (trans_ok and #saved_trans > 0) and saved_trans[1] == "1"

      if theme and vim.tbl_contains(get_all_themes(), theme) then
        vim.cmd.colorscheme(theme)
        set_transparent(transparent)
        vim.schedule(function()
          vim.notify(
            ("Theme restored: %s%s"):format(
              theme,
              transparent and " (transparent)" or ""
            ),
            vim.log.levels.INFO,
            { title = "Theme Switcher" }
          )
        end)
      elseif theme then
        vim.notify("Previously saved theme '"..theme.."' no longer exists", vim.log.levels.WARN)
      end
    end

    local function switch_theme(name, transparent_opt)
      local ok, _ = pcall(vim.cmd.colorscheme, name)
      if not ok then
        vim.notify("Theme '" .. name .. "' not found", vim.log.levels.ERROR)
        return false
      end

      local transparent = current_transparent
      if transparent_opt ~= nil then
        transparent = transparent_opt
      end

      set_transparent(transparent)
      save_state(name, transparent)

      vim.notify(
        ("Theme → %s%s"):format(name, transparent and " (transparent)" or ""),
        vim.log.levels.INFO,
        { title = "Theme Switcher" }
      )
      return true
    end

    local function open_picker()
      local themes = get_all_themes()
      if #themes == 0 then
        vim.notify("No colorschemes found!", vim.log.levels.WARN)
        return
      end

      local pickers = require("telescope.pickers")
      local finders = require("telescope.finders")
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")
      local conf = require("telescope.config").values

      pickers.new({}, {
        prompt_title = "Select Colorscheme (transparent = ✓)",
        finder = finders.new_table({
          results = themes,
          entry_maker = function(entry)
            local display = entry
            if entry == vim.g.colors_name and current_transparent then
              display = display .. "  transparent"
            end
            return { value = entry, display = display, ordinal = entry }
          end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(bufnr, map)
          local function apply(save_transparent)
            local selection = action_state.get_selected_entry()
            actions.close(bufnr)
            if selection then
              switch_theme(selection.value, save_transparent)
            end
          end

          map("i", "<CR>", function() apply(current_transparent) end)
          map("n", "<CR>", function() apply(current_transparent) end)

          map("i", "<C-t>", function()
            local selection = action_state.get_selected_entry()
            if selection then
              switch_theme(selection.value, not current_transparent)
            end
          end)

          map("i", "<C-p>", function()
            local selection = action_state.get_selected_entry()
            if selection then
              vim.cmd.colorscheme(selection.value)
              vim.notify("Preview: " .. selection.value, vim.log.levels.INFO, { title = "Theme Preview" })
            end
          end)

          return true
        end,
      }):find()
    end

    vim.api.nvim_create_user_command("Theme", function(opts)
      local args = vim.split(vim.trim(opts.args), "%s+")
      local theme_name = args[1]
      local trans_str = args[2]

      -- NEW FEATURE: allow ":Theme true" or ":Theme false" to change transparency only
      if theme_name == "true" or theme_name == "false" then
        local new_transparent = (theme_name == "true")
        local current = vim.g.colors_name
        if current then
          switch_theme(current, new_transparent)
        else
          vim.notify("No theme is currently active", vim.log.levels.WARN)
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
          vim.notify("Second argument must be 'true' or 'false'", vim.log.levels.ERROR)
          return
        end
      end

      switch_theme(theme_name, transparent)
    end, {
      nargs = "*",
      complete = function(arglead)
        local themes = get_all_themes()
        if arglead and arglead ~= "" then
          return vim.tbl_filter(function(theme)
            return theme:lower():find(arglead:lower(), 1, true) ~= nil
          end, themes)
        end
        return themes
      end,
    })

    vim.schedule(load_saved_state)
  end,
}
