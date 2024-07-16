-- maintainers: cwrau, DavidLangen

local M = {}

---@param command string
---@return string|nil
local function getCommandResult(command)
  local commandHandle = io.popen(command, "r")
  local result
  if commandHandle then
    commandHandle:flush()
    result = tostring(commandHandle:read("a"))
    commandHandle:close()
    if result == "" then
      result = nil
    end
  end
  return result
end

---@param file string
---@return string|nil
local function getRelativeFilePath(file)
  local filePath = getCommandResult("git ls-files --full-name " .. file)
  if filePath then
    return vim.trim(filePath)
  end
  return nil
end

---@return string|nil
local function getGitRemote()
  local remoteString = getCommandResult("git remote -v")
  if remoteString then
    local remotes = {}
    for remote in remoteString:gmatch("[^\r\n]+") do
      local fields = {}
      for field in remote:gmatch("([^%s]+)") do
        table.insert(fields, field)
      end
      remotes[fields[1]] = fields[2]
    end
    if remotes["origin"] then
      return remotes["origin"]
    else
      for _, remote in pairs(remotes) do
        return remote
      end
    end
  end
  return nil
end

---@return string|nil
local function getGithubUrl()
  local remote = getGitRemote()
  local url
  if remote then
    if remote:gmatch("^git@github.com:") then
      url = remote:gsub("git@github.com:", "https://github.com/")
    elseif remote:gmatch("^https://github.com/") then
      url = remote
    else
      return nil
    end
    url = url:gsub(".git$", "")
  end
  return vim.trim(url)
end

---@return string|nil
local function getGitBranch()
  local branch = getCommandResult("git branch --show")
  if branch then
    return vim.trim(branch)
  end
  return nil
end

---@return nil
function M.copyCurrentFileSelectionLink()
  local githubUrl = getGithubUrl()
  if githubUrl then
    local currentFileName = vim.api.nvim_buf_get_name(0)
    local relativeFilePath = getRelativeFilePath(currentFileName)
    if relativeFilePath then
      local branch = assert(getGitBranch(), "Should be in git repo")
      local mode = vim.fn.mode()
      local startLine = vim.fn.getpos("v")[2]
      local startChar = vim.fn.getpos("v")[3]
      local endLine = vim.fn.getpos(".")[2]
      local endChar = vim.fn.getpos(".")[3]
      local endLineLength = vim.fn.col({ endLine, "$" }) - 1

      local fullFileUrl = githubUrl .. "/blob/" .. branch .. "/" .. relativeFilePath .. "?plain=1#L" .. startLine
      if startChar ~= 1 and mode == "v" then
        fullFileUrl = fullFileUrl .. "C" .. startChar
      end
      local shouldAppendEndChar = mode == "v" and endChar < endLineLength
      if startLine ~= endLine or shouldAppendEndChar then
        fullFileUrl = fullFileUrl .. "-L" .. endLine
        if shouldAppendEndChar then
          fullFileUrl = fullFileUrl .. "C" .. endChar
        end
      end
      vim.fn.setreg("*", fullFileUrl)
      vim.notify("Copied GitHub url to clipboard")
    else
      vim.notify("File is not in git repository")
    end
  end
end

function M.setup()
  require("which-key").add({
    {
      "<leader>cg",
      M.copyCurrentFileSelectionLink,
      desc = "Copy GitHub URL of current line",
      mode = { "n" },
    },
    {
      "<leader>cg",
      M.copyCurrentFileSelectionLink,
      desc = "Copy GitHub URL of current selection",
      mode = { "v" },
    },
  })
end

return M
