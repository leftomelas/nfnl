-- [nfnl] fnl/nfnl/gc.fnl
local _local_1_ = require("nfnl.module")
local autoload = _local_1_.autoload
local define = _local_1_.define
local core = autoload("nfnl.core")
local fs = autoload("nfnl.fs")
local config = autoload("nfnl.config")
local header = autoload("nfnl.header")
local M = define("nfnl.gc")
local function orphan_3f(root_dir, path)
  local line = fs["read-first-line"](path)
  local source_path = header["source-path"](line)
  local and_2_ = header["tagged?"](line)
  if and_2_ then
    local function _3_()
      if source_path then
        return fs["join-path"]({root_dir, source_path})
      else
        return nil
      end
    end
    and_2_ = not fs["exists?"](_3_())
  end
  return and_2_
end
M["find-orphan-lua-files"] = function(_4_)
  local cfg = _4_.cfg
  local root_dir = _4_["root-dir"]
  local fnl_path__3elua_path = cfg({"fnl-path->lua-path"})
  local ignore_patterns = cfg({"orphan-detection", "ignore-patterns"})
  local owner_3f = config["owner-filter"](root_dir)
  local function _5_(path)
    return (owner_3f(path) and orphan_3f(root_dir, path))
  end
  local function _6_(rel_path)
    return fs["join-path"]({root_dir, rel_path})
  end
  local function _7_(rel_path)
    local function _8_(pat)
      return rel_path:find(pat)
    end
    return not core.some(_8_, ignore_patterns)
  end
  local function _9_(fnl_pattern)
    local lua_pattern = fnl_path__3elua_path(fnl_pattern)
    return fs.relglob(root_dir, lua_pattern)
  end
  return core.filter(_5_, core.map(_6_, core.filter(_7_, core.keys(core["->set"](core.mapcat(_9_, cfg({"source-file-patterns"})))))))
end
--[[ (local config (require "nfnl.config")) (M.find-orphan-lua-files (config.find-and-load ".")) ]]
return M
