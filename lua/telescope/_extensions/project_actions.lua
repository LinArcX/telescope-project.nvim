local builtin = require("telescope.builtin")
local actions = require("telescope.actions")
local state = require('telescope.state')
local action_state = require('telescope.actions.state')
local transform_mod = require('telescope.actions.mt').transform_mod

local project_actions = {}


local _close = function(prompt_bufnr, keepinsert)
  local picker = action_state.get_current_picker(prompt_bufnr)
  local prompt_win = state.get_status(prompt_bufnr).prompt_win
  local original_win_id = picker.original_win_id

  if picker.previewer then
    picker.previewer:teardown()
  end

  actions.close_pum(prompt_bufnr)
  if not keepinsert then
    vim.cmd [[stopinsert]]
  end

  vim.api.nvim_win_close(prompt_win, true)

  pcall(vim.cmd, string.format([[silent bdelete! %s]], prompt_bufnr))
  pcall(vim.api.nvim_set_current_win, original_win_id)
end

local project_dirs_file = vim.fn.stdpath('data') .. '/telescope-projects.txt'

project_actions.add_project = function(prompt_bufnr)
  local git_root = vim.fn.systemlist("git -C " .. vim.loop.cwd() .. " rev-parse --show-toplevel")[
    1
  ]
  local project_directory = git_root
  if not git_root then
    project_directory = vim.loop.cwd()
    return
  end

  local project_title = project_directory:match("[^/]+$")
  local project_to_add = project_title .. "=" .. project_directory .. "\n"

  local file = assert(
    io.open(project_dirs_file, "a"),
    "No project file exists"
  )

  local project_already_added = false
  for line in io.lines(project_dirs_file) do
    local project_exists_check = line .. "\n" == project_to_add
    if project_exists_check then
      project_already_added = true
      print('This project already exists.')
      return
    end
  end

  if not project_already_added then
    io.output(file)
    io.write(project_to_add)
    print('project added: ' .. project_title)
  end
  io.close(file)
  actions.close(prompt_bufnr)
  require 'telescope'.extensions.project.project()
end

project_actions.delete_project = function(prompt_bufnr)
  local newLines = ""
  for line in io.lines(project_dirs_file) do
    local title, path = line:match("^(.-)=(.-)$")
    if title ~= actions.get_selected_entry(prompt_bufnr).display then
      newLines = newLines .. title .. '=' .. path .. "\n"
    end
  end
  local file = assert(
    io.open(project_dirs_file, "w"),
    "No project file exists"
  )
  file:write(newLines)
  file:close()
  print('Project deleted: ' .. actions.get_selected_entry(prompt_bufnr).display)
  actions.close(prompt_bufnr)
  require 'telescope'.extensions.project.project()
end

project_actions.find_project_files = function(prompt_bufnr)
  local dir = actions.get_selected_entry(prompt_bufnr).value
  _close(prompt_bufnr, true)
  builtin.find_files({cwd = dir})
  vim.fn.execute("cd " .. dir, "silent")
end

project_actions.search_in_project_files = function(prompt_bufnr)
  local dir = actions.get_selected_entry(prompt_bufnr).value
  _close(prompt_bufnr, true)
  builtin.live_grep({cwd = dir})
  vim.fn.execute("cd " .. dir, "silent")
end

project_actions.change_working_directory = function(prompt_bufnr)
  local dir = actions.get_selected_entry(prompt_bufnr).value
  actions.close(prompt_bufnr)
  vim.fn.execute("cd " .. dir, "silent")
end

project_actions = transform_mod(project_actions);
return project_actions
