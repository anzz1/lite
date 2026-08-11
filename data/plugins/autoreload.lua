local core = require "core"
local config = require "core.config"
local Doc = require "core.doc"

config.autoreload_ask = true

local times = setmetatable({}, { __mode = "k" })

local function update_time(doc)
  local info = system.get_file_info(doc.filename)
  times[doc] = info.modified
end


local function reload_doc(doc)
  local fp = io.open(doc.filename, "r")
  local text = fp:read("*a")
  fp:close()

  local sel = { doc:get_selection() }
  doc:remove(1, 1, math.huge, math.huge)
  doc:insert(1, 1, text:gsub("\r", ""):gsub("\n$", ""))
  doc:set_selection(table.unpack(sel))

  update_time(doc)
  doc:clean()
  core.log_quiet("Auto-reloaded doc \"%s\"", doc.filename)
end


core.add_thread(function()
  while true do
    -- check all doc modified times
    for _, doc in ipairs(core.docs) do
      local info = system.get_file_info(doc.filename or "")
      if info and times[doc] ~= info.modified then
        if config.autoreload_ask and doc:is_dirty() then
          if system.show_confirm_dialog("lite", string.format("File changed outside the editor.\nReload %s?", doc:get_name():match("[^/%\\]*$"))) then
            reload_doc(doc)
          else
            times[doc] = info.modified
          end
        else
          reload_doc(doc)
        end
      end
      coroutine.yield()
    end

    -- wait for next scan
    coroutine.yield(config.project_scan_rate)
  end
end)


-- patch `Doc.save|load` to store modified time
local load = Doc.load
local save = Doc.save

Doc.load = function(self, ...)
  local res = load(self, ...)
  update_time(self)
  return res
end

Doc.save = function(self, ...)
  local res = save(self, ...)
  update_time(self)
  return res
end
