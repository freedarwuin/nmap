---
-- Implements reports of file listings.
--
-- TODO: report files as structured data with the same human readable
-- output.
--
-- Scripts that use this module can use the script arguments listed below:
-- @args ls.maxdepth [optional] the maximum depth to recurse into a directory
--                   (default: no recursion).
-- @args ls.maxfiles [optional] the maximum number of files to return
--                   (default: 1, no recursion).
-- @args ls.pattern  [optional] return only files that match the given pattern
-- @args ls.checksum [optional] download each file and calculate a SHA1 checksum
-- @args ls.errors   [optional] report errors
-- @args ls.empty    [optional] report empty volumes (with no information
--                   or error)
--
-- These arguments can either be set for all the scripts using this
-- module (--script-args ls.arg=value) or for one particular script
-- (--script-args afp-ls.arg=value). If both are specified for the
-- same argument, the script-specific value is used.
--
-- @author Pierre Lalet <pierre@droids-corp.org>
-- @copyright Same as Nmap--See http://nmap.org/book/man-legal.html
-----------------------------------------------------------------------

local LIBRARY_NAME = "ls"

local stdnse = require "stdnse"
local tab = require "tab"
local table = require "table"

_ENV = stdnse.module("ls", stdnse.seeall)

local config_values = {
  ["maxdepth"] = 1,
  ["maxfiles"] = 10,
  ["pattern"] = "*",
  ["checksum"] = false,
  ["errors"] = false,
  ["empty"] = false,
  ["human"] = false,
}

local function convert_arg(argval, argtype)
  if argtype == "number" then
    return tonumber(argval)
  elseif argtype == "boolean" then
    if argval == "true" or argval == "yes" then
      return true
    else
      return false
    end
  end
  return argval
end

for argname, argvalue in pairs(config_values) do
  local argval = stdnse.get_script_args(LIBRARY_NAME .. "." .. argname)
  if argval ~= nil then
    config_values[argname] = convert_arg(argval, type(argvalue))
  end
end

function config(argname)
  -- get a config value from (by order or priority):
  --   1. a script-specific argument (e.g., http-ls.*)
  --   2. a module argument (ls.*)
  --   3. the default value
  local argval = stdnse.get_script_args(stdnse.getid() .. "." .. argname)
  if argval == nil then
    return config_values[argname]
  else
    return convert_arg(argval, type(config_values[argname]))
  end
end

function new_listing()
  local output = stdnse.output_table()
  output['curvol'] = nil
  output['volumes'] = {}
  output['errors'] = {}
  output['info'] = {}
  output['total'] = {
    ['files'] = 0,
    ['bytes'] = 0,
  }
  return output
end

function new_vol(output, name, hasperms)
  local curvol = stdnse.output_table()
  local files = tab.new()
  local i = 1
  if hasperms then
     tab.add(files, 1, "PERMISSION")
     tab.add(files, 2, "UID")
     tab.add(files, 3, "GID")
     i = 4
  end
  tab.add(files, i, "SIZE")
  tab.add(files, i + 1, "TIME")
  tab.add(files, i + 2, "FILENAME")
  if config("checksum") then
    tab.add(files, i + 3, "CHECKSUM")
  end
  tab.nextrow(files)
  curvol['name'] = name
  curvol['files'] = files
  curvol['count'] = 0
  curvol['bytes'] = 0
  curvol['errors'] = {}
  curvol['info'] = {}
  curvol['hasperms'] = hasperms
  output['curvol'] = curvol
end

function report_error(output, err)
  if output["curvol"] == nil then
    stdnse.debug1("error: " .. err)
  else
    stdnse.debug1("error [" .. output["curvol"]["name"] .. "]: " .. err)
  end
  if config('errors') then
    if output["curvol"] == nil then
      table.insert(output["errors"], err)
    else
      table.insert(output["curvol"]["errors"], err)
    end
  end
end

function report_info(output, info)
  if output["curvol"] == nil then
    stdnse.debug1("info: " .. info)
    table.insert(output["info"], info)
  else
    stdnse.debug1("info [" .. output["curvol"]["name"] .. "]: " .. info)
    table.insert(output["curvol"]["info"], info)
  end
end

local units = {
  ["k"] = 1024,
  ["m"] = 1048576,
  ["g"] = 1073741824,
  ["t"] = 1099511627776,
  ["p"] = 1125899906842624,
}

local function get_size(size)
  local bsize
  bsize = tonumber(size)
  if bsize == nil then
    local unit = string.lower(string.sub(size, -1, -1))
    bsize = tonumber(string.sub(size, 0, -2))
    if units[unit] ~= nil and bsize ~= nil then
      bsize = bsize * units[unit]
    else
      bsize = nil
    end
  end
  return bsize
end

function add_file(output, file)
  -- returns true iff script should continue
  local files = output["curvol"]["files"]
  local size, isize
  if output["curvol"]["hasperms"] then
    isize = 4
  else
    isize = 1
  end
  for i, info in ipairs(file) do
    if i == isize then
      size = get_size(info)
      if size then
	output["curvol"]["bytes"] = output["curvol"]["bytes"] + size
	info = size
      end
    end
    if type(info) == "number" then
      tab.add(files, i, tostring(info))
    else
      tab.add(files, i, info)
    end
  end
  tab.nextrow(files)
  output["curvol"]["count"] = output["curvol"]["count"] + 1
  return (config("maxfiles") == 0 or config("maxfiles") == nil
	    or config("maxfiles") > output["curvol"]["count"])
end

function end_vol(output)
  local vol = {["volume"] = output["curvol"]["name"]}
  local empty = true
  if #output["curvol"]["files"] ~= 1 then
    vol["files"] = output["curvol"]["files"]
    empty = false
  end
  if #output["curvol"]["errors"] ~= 0 then
    vol["errors"] = output["curvol"]["errors"]
    empty = false
  end
  if #output["curvol"]["info"] ~= 0 then
    vol["info"] = output["curvol"]["info"]
    empty = false
  end
  if not empty or config("empty") then
    table.insert(output["volumes"], vol)
  end
  output["total"]["files"] = output["total"]["files"] + output["curvol"]["count"]
  output["total"]["bytes"] = output["total"]["bytes"] + output["curvol"]["bytes"]
  output["curvol"] = nil
end

local function files_to_structured(files)
  local result = {}
  local fields = table.remove(files, 1)
  for i, file in ipairs(files) do
    result[i] = stdnse.output_table()
    for j, value in ipairs(file) do
      result[i][string.lower(fields[j])] = value
    end
  end
  return result
end

local function files_to_readable(files)
  local outtab = tab.new()
  local fields = files[1]
  local file, size, isize, unit, units, outfile
  tab.addrow(outtab, unpack(fields))
  for i, field in ipairs(fields) do
    if string.lower(field) == "size" then
      isize = i
      break
    end
  end
  for i = 2, #files do
    file = files[i]
    outfile = {}
    for j, value in ipairs(file) do
      outfile[j] = value
    end
    if config("human") then
      size = tonumber(outfile[isize])
      unit = nil
      units = {"k", "M", "G", "T", "P"}
      if size ~= nil then
	while size > 1024 and #units > 0 do
	  unit = table.remove(units, 1)
	  size = size / 1024
	end
	if unit == nil then
	  outfile[isize] = tostring(size)
	else
	  outfile[isize] = string.format("%.1f %s", size, unit)
	end
      end
    end
    tab.addrow(outtab, unpack(outfile))
  end
  return tab.dump(outtab)
end

function end_listing(output)
  assert(output["curvol"] == nil)
  local line
  local text = "\n"
  local empty = true
  if #output["info"] == 0 then
    output["info"] = nil
  else
    for _, line in ipairs(output["info"]) do
      text = text .. line .. "\n"
    end
    empty = false
  end
  if #output["errors"] == 0 then
    output["errors"] = nil
  else
    for _, line in ipairs(output["errors"]) do
      text = text .. "ERROR: " .. line .. "\n"
    end
    empty = false
  end
  if #output["volumes"] == 0 then
    output["volumes"] = nil
    output["total"] = nil
  else
    for _, volume in ipairs(output["volumes"]) do
      text = text .. "Volume " .. volume["volume"] .. "\n"
      if volume["info"] then
	for _, line in ipairs(volume["info"]) do
	  text = "  " .. text .. line .. "\n"
	end
      end
      if volume["errors"] then
	for _, line in ipairs(volume["errors"]) do
	  text = "  " .. text .. "ERROR: " .. line .. "\n"
	end
      end
      if volume["files"] then
	text = text .. files_to_readable(volume["files"])
	volume["files"] = files_to_structured(volume["files"])
      end
      text = text .. "\n"
    end
    empty = false
  end
  if empty then
    return nil
  else
    return output, text
  end
end

return _ENV
