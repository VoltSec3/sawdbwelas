local HttpService = game:GetService("HttpService")

local okAnalytics, RbxAnalyticsService = pcall(function()
  return game:GetService("RbxAnalyticsService")
end)

if not okAnalytics then
  RbxAnalyticsService = nil
end

local HWID = {}
HWID.FILE = "leetware/hwid.txt"
HWID._current = nil

local function trim(value)
  if type(value) ~= "string" then
    return nil
  end

  value = value:gsub("^%s+", ""):gsub("%s+$", "")

  if value == "" then
    return nil
  end

  return value
end

local function encode(value)
  value = trim(value)

  if not value then
    return nil
  end

  local ok, digest = pcall(function()
    return HttpService:Base64Encode(value)
  end)

  return ok and digest or value
end

local function readPersisted()
  if not readfile or not isfile then
    return nil
  end

  local ok, value = pcall(function()
    if not isfile(HWID.FILE) then
      return nil
    end

    return readfile(HWID.FILE)
  end)

  if not ok then
    return nil
  end

  return trim(value)
end

local function writePersisted(value)
  if not writefile then
    return false
  end

  local ok = pcall(function()
    if makefolder and isfolder and not isfolder("leetware") then
      makefolder("leetware")
    end

    writefile(HWID.FILE, value)
  end)

  return ok
end

local function readExecutorHwid()
  if typeof(gethwid) ~= "function" then
    return nil
  end

  local ok, value = pcall(gethwid)

  if not ok then
    return nil
  end

  return trim(value)
end

local function readAnalyticsId()
  if not RbxAnalyticsService then
    return nil
  end

  local ok, id = pcall(function()
    return RbxAnalyticsService:GetClientId()
  end)

  if not ok then
    return nil
  end

  return trim(id)
end

-- Persist the resolved HWID so it stays the same for every future run. The
-- value written here is the final (already encoded) value sent to the API.
function HWID.persist(value)
  value = trim(value)

  if not value then
    return nil
  end

  HWID._current = value
  writePersisted(value)

  return value
end

-- Returns every HWID value this install could have used, most stable first.
-- Authentication retries these so an activation created by an older loader
-- version (or by the analytics fallback) can still be recovered.
function HWID.candidates()
  local list = {}
  local seen = {}

  local function add(value)
    value = trim(value)

    if not value or seen[value] then
      return
    end

    seen[value] = true
    list[#list + 1] = value
  end

  add(HWID._current)
  add(readPersisted())

  -- Executor-provided HWIDs are designed to survive sessions. Roblox's
  -- analytics client id is only a fallback: depending on the executor/client
  -- build it can change between launches, which would break an activation.
  add(encode(readExecutorHwid()))
  add(encode(readAnalyticsId()))
  add(encode("unknown-hwid"))

  return list
end

function HWID.generate()
  local persisted = readPersisted()

  if persisted then
    HWID._current = persisted
    return persisted
  end

  local candidates = HWID.candidates()
  local value = candidates[1] or encode("unknown-hwid")

  HWID.persist(value)

  return value
end

return HWID
