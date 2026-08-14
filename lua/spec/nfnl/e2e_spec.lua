-- [nfnl] fnl/spec/nfnl/e2e_spec.fnl
local _local_1_ = require("plenary.busted")
local describe = _local_1_.describe
local it = _local_1_.it
local before_each = _local_1_.before_each
local after_each = _local_1_.after_each
local assert = require("luassert.assert")
local core = require("nfnl.core")
local fs = require("nfnl.fs")
local api = require("nfnl.api")
local temp_dir = vim.fn.tempname()
local unrelated_temp_dir = vim.fn.tempname()
local fnl_dir = fs["join-path"]({temp_dir, "fnl"})
local lua_dir = fs["join-path"]({temp_dir, "lua"})
local config_path = fs["join-path"]({temp_dir, ".nfnl.fnl"})
local fnl_path = fs["join-path"]({fnl_dir, "foo.fnl"})
local macro_fnl_path = fs["join-path"]({fnl_dir, "bar.fnl"})
local macro_lua_path = fs["join-path"]({lua_dir, "bar.lua"})
local lua_path = fs["join-path"]({lua_dir, "foo.lua"})
fs.mkdirp(fnl_dir)
fs.mkdirp(unrelated_temp_dir)
local function delete_buf_file(path)
  pcall(vim.cmd, ("bwipeout! " .. path))
  return os.remove(path)
end
local function run_e2e_tests()
  core["run!"](delete_buf_file, {config_path, fnl_path, macro_fnl_path, lua_path})
  local function _2_()
    vim.cmd(("edit " .. fnl_path))
    vim.o.filetype = "fennel"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {"(print \"Hello, World!\")"})
    vim.cmd("write")
    return assert.is_nil(core.slurp(lua_path))
  end
  it("does nothing when there's no .nfnl.fnl configuration", _2_)
  local function _3_()
    vim.cmd(("edit " .. config_path))
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {"{}"})
    vim.cmd("write")
    vim.cmd("trust")
    vim.cmd(("edit " .. fnl_path))
    vim.o.filetype = "fennel"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {"(print \"Hello, World!\")"})
    vim.cmd("write")
    assert.are.equal(1, vim.fn.isdirectory(lua_dir))
    local lua_result = core.slurp(lua_path)
    print("Lua result:", lua_result)
    return assert.are.equal("-- [nfnl] fnl/foo.fnl\nreturn print(\"Hello, World!\")\n", lua_result)
  end
  it("compiles when there's a trusted .nfnl.fnl configuration file", _3_)
  local function _4_()
    vim.cmd(("edit " .. macro_fnl_path))
    vim.o.filetype = "fennel"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {(";; [nfnl" .. "-" .. "macro]"), "{:infix (fn [a op b] `(,op ,a ,b))}"})
    vim.cmd("write")
    vim.cmd(("edit " .. fnl_path))
    vim.o.filetype = "fennel"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {"(import-macros {: infix} :bar)", "(infix 10 + 20)"})
    vim.cmd("write")
    assert.is_nil(core.slurp(macro_lua_path))
    local lua_result = core.slurp(lua_path)
    print("Lua result:", lua_result)
    return assert.are.equal("-- [nfnl] fnl/foo.fnl\nreturn (10 + 20)\n", lua_result)
  end
  return it("can import-macros and use them, the macros aren't compiled", _4_)
end
local function _5_()
  local initial_cwd = nil
  local function _6_()
    initial_cwd = vim.fn.getcwd()
    return vim.api.nvim_set_current_dir(temp_dir)
  end
  before_each(_6_)
  local function _7_()
    return vim.api.nvim_set_current_dir(initial_cwd)
  end
  after_each(_7_)
  return run_e2e_tests()
end
describe("e2e file compiling from a project dir", _5_)
local function _8_()
  local initial_cwd = nil
  local function _9_()
    initial_cwd = vim.fn.getcwd()
    return vim.api.nvim_set_current_dir(unrelated_temp_dir)
  end
  before_each(_9_)
  local function _10_()
    return vim.api.nvim_set_current_dir(initial_cwd)
  end
  after_each(_10_)
  return run_e2e_tests()
end
describe("e2e file compiling from outside project dir", _8_)
local function make_nested_project()
  local outer_dir = vim.fn.tempname()
  local nested_dir = fs["join-path"]({outer_dir, "pack", "nested"})
  local paths = {["outer-dir"] = outer_dir, ["nested-dir"] = nested_dir, ["outer-config"] = fs["join-path"]({outer_dir, ".nfnl.fnl"}), ["nested-config"] = fs["join-path"]({nested_dir, ".nfnl.fnl"}), ["outer-fnl"] = fs["join-path"]({outer_dir, "fnl", "outer.fnl"}), ["outer-lua"] = fs["join-path"]({outer_dir, "lua", "outer.lua"}), ["nested-fnl"] = fs["join-path"]({nested_dir, "fnl", "inner.fnl"}), ["nested-lua"] = fs["join-path"]({nested_dir, "lua", "inner.lua"})}
  fs.mkdirp(fs["join-path"]({outer_dir, "fnl"}))
  fs.mkdirp(fs["join-path"]({outer_dir, "lua"}))
  fs.mkdirp(fs["join-path"]({nested_dir, "fnl"}))
  fs.mkdirp(fs["join-path"]({nested_dir, "lua"}))
  core.spit(paths["outer-config"], "{}")
  core.spit(paths["nested-config"], "{}")
  vim.secure.trust({action = "allow", path = paths["outer-config"]})
  vim.secure.trust({action = "allow", path = paths["nested-config"]})
  return paths
end
local function _11_()
  local function _12_()
    local _let_13_ = make_nested_project()
    local outer_dir = _let_13_["outer-dir"]
    local outer_fnl = _let_13_["outer-fnl"]
    local outer_lua = _let_13_["outer-lua"]
    local nested_fnl = _let_13_["nested-fnl"]
    local nested_lua = _let_13_["nested-lua"]
    core.spit(outer_fnl, "(print :outer)")
    core.spit(nested_fnl, "(print :inner)")
    api["compile-all-files"](outer_dir)
    assert.are.equal("-- [nfnl] fnl/outer.fnl\nreturn print(\"outer\")\n", core.slurp(outer_lua))
    return assert.is_nil(core.slurp(nested_lua))
  end
  it("compiles the outer project without descending into the nested one", _12_)
  local function _14_()
    local _let_15_ = make_nested_project()
    local outer_dir = _let_15_["outer-dir"]
    return assert.are.same({}, api["find-orphans"]({dir = outer_dir, ["passive?"] = true}))
  end
  it("finds orphans when it isn't handed a config", _14_)
  local function _16_()
    local _let_17_ = make_nested_project()
    local outer_dir = _let_17_["outer-dir"]
    local nested_lua = _let_17_["nested-lua"]
    core.spit(nested_lua, "-- [nfnl] fnl/gone.fnl\nreturn nil\n")
    return assert.are.same({}, api["find-orphans"]({dir = outer_dir, ["passive?"] = true}))
  end
  it("ignores orphan Lua files inside the nested project", _16_)
  local function _18_()
    local _let_19_ = make_nested_project()
    local outer_dir = _let_19_["outer-dir"]
    local outer_lua = _let_19_["outer-lua"]
    local initial_cwd = vim.fn.getcwd()
    core.spit(outer_lua, "-- [nfnl] fnl/gone.fnl\nreturn nil\n")
    vim.api.nvim_set_current_dir(unrelated_temp_dir)
    local orphans = api["find-orphans"]({dir = outer_dir, ["passive?"] = true})
    vim.api.nvim_set_current_dir(initial_cwd)
    return assert.are.same({outer_lua}, orphans)
  end
  it("finds orphans as absolute paths when the cwd isn't the project root", _18_)
  local function _20_()
    local _let_21_ = make_nested_project()
    local outer_dir = _let_21_["outer-dir"]
    local nested_fnl = _let_21_["nested-fnl"]
    local nested_lua = _let_21_["nested-lua"]
    local initial_cwd = vim.fn.getcwd()
    core.spit(nested_fnl, "(print :inner)")
    vim.api.nvim_set_current_dir(outer_dir)
    api["compile-file"]({path = nested_fnl})
    vim.api.nvim_set_current_dir(initial_cwd)
    return assert.are.equal("-- [nfnl] fnl/inner.fnl\nreturn print(\"inner\")\n", core.slurp(nested_lua))
  end
  it("compiles a nested file with its own project's config", _20_)
  local function _22_()
    local _let_23_ = make_nested_project()
    local nested_dir = _let_23_["nested-dir"]
    local nested_fnl = _let_23_["nested-fnl"]
    local nested_lua = _let_23_["nested-lua"]
    local orphan_lua = fs["join-path"]({nested_dir, "lua", "gone.lua"})
    core.spit(nested_fnl, "(print :inner)")
    core.spit(orphan_lua, "-- [nfnl] fnl/gone.fnl\nreturn nil\n")
    api["compile-all-files"](nested_dir)
    assert.are.equal("-- [nfnl] fnl/inner.fnl\nreturn print(\"inner\")\n", core.slurp(nested_lua))
    return assert.are.same({orphan_lua}, api["find-orphans"]({dir = nested_dir, ["passive?"] = true}))
  end
  return it("still compiles and garbage collects the nested project on its own", _22_)
end
return describe("e2e nested project boundaries", _11_)
