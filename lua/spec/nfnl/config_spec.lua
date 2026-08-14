-- [nfnl] fnl/spec/nfnl/config_spec.fnl
local _local_1_ = require("plenary.busted")
local describe = _local_1_.describe
local it = _local_1_.it
local assert = require("luassert.assert")
local config = require("nfnl.config")
local core = require("nfnl.core")
local fs = require("nfnl.fs")
local function _2_()
  local function _3_()
    assert.equals("function", type(config.default))
    assert.equals("table", type(config.default({["root-dir"] = "/tmp/foo"})))
    return assert.equals(vim.fn.getcwd(), config.default({})["root-dir"])
  end
  return it("is a function that returns a table", _3_)
end
describe("default", _2_)
local function _4_()
  local function _5_()
    local opts = {["root-dir"] = "/tmp/foo"}
    assert.is_string(config["cfg-fn"]({}, opts)({"fennel-macro-path"}))
    assert.is_nil(config["cfg-fn"]({}, opts)({"nope"}))
    assert.equals("yep", config["cfg-fn"]({nope = "yep"}, opts)({"nope"}))
    return assert.equals("yep", config["cfg-fn"]({["fennel-macro-path"] = "yep"}, opts)({"fennel-macro-path"}))
  end
  return it("builds a function that looks up values in a table falling back to defaults", _5_)
end
describe("cfg-fn", _4_)
local function _6_()
  local function _7_()
    assert.is_true(config["config-file-path?"]("./foo/.nfnl.fnl"))
    assert.is_true(config["config-file-path?"](".nfnl.fnl"))
    return assert.is_false(config["config-file-path?"](".fnl.fnl"))
  end
  return it("returns true for config file paths", _7_)
end
describe("config-file-path?", _6_)
local function _8_()
  local function _9_()
    local _let_10_ = config["find-and-load"](".")
    local cfg = _let_10_.cfg
    local root_dir = _let_10_["root-dir"]
    local config0 = _let_10_.config
    assert.are.same({verbose = true}, config0)
    assert.equals(vim.fn.getcwd(), root_dir)
    return assert.equals("function", type(cfg))
  end
  it("loads the repo config file", _9_)
  local function _11_()
    return assert.are.same({}, config["find-and-load"]("/some/made/up/dir"))
  end
  return it("returns an empty table if a config file isn't found", _11_)
end
describe("find-and-load", _8_)
local function sorted(xs)
  table.sort(xs)
  return xs
end
local function _12_()
  local function _13_()
    assert.are.same({"/foo/bar/nfnl", "/foo/baz/my-proj"}, sorted(config["path-dirs"]({runtimepath = "/foo/bar/nfnl,/foo/bar/other-thing", ["rtp-patterns"] = {(fs["path-sep"]() .. "nfnl$")}, ["base-dirs"] = {"/foo/baz/my-proj"}})))
    return assert.are.same({"/foo/bar/nfnl", "/foo/baz/my-proj"}, sorted(config["path-dirs"]({runtimepath = "/foo/bar/nfnl,/foo/bar/other-thing", ["rtp-patterns"] = {(fs["path-sep"]() .. "nfnl$")}, ["base-dirs"] = {"/foo/baz/my-proj", "/foo/bar/nfnl"}})))
  end
  return it("builds path dirs from runtimepath, deduplicates the base-dirs", _13_)
end
describe("path-dirs", _12_)
local function _14_()
  local root_dir = vim.fn.tempname()
  local plain_dir = fs["join-path"]({root_dir, "fnl", "deep"})
  local spacey_dir = fs["join-path"]({root_dir, "fnl", "my dir"})
  local nested_dir = fs["join-path"]({root_dir, "pack", "nested"})
  local nested_sub_dir = fs["join-path"]({nested_dir, "fnl"})
  fs.mkdirp(plain_dir)
  fs.mkdirp(spacey_dir)
  fs.mkdirp(nested_sub_dir)
  core.spit(fs["join-path"]({root_dir, ".nfnl.fnl"}), "{}")
  core.spit(fs["join-path"]({nested_dir, ".nfnl.fnl"}), "{}")
  local function _15_()
    return assert.is_true(config["owner-filter"](root_dir)(fs["join-path"]({root_dir, "foo.fnl"})))
  end
  it("includes files directly under the root dir", _15_)
  local function _16_()
    return assert.is_true(config["owner-filter"](root_dir)(fs["join-path"]({plain_dir, "foo.fnl"})))
  end
  it("includes files under a subdirectory with no config of its own", _16_)
  local function _17_()
    return assert.is_false(config["owner-filter"](root_dir)(fs["join-path"]({nested_dir, "foo.fnl"})))
  end
  it("excludes files inside a nested project", _17_)
  local function _18_()
    return assert.is_false(config["owner-filter"](root_dir)(fs["join-path"]({nested_sub_dir, "foo.fnl"})))
  end
  it("excludes files under a nested project", _18_)
  local function _19_()
    return assert.is_true(config["owner-filter"]("/some/made/up/dir")("/some/made/up/dir/foo.fnl"))
  end
  it("includes paths with no config file above them at all", _19_)
  local function _20_()
    return assert.is_true(config["owner-filter"](root_dir)(fs["join-path"]({spacey_dir, "foo.fnl"})))
  end
  it("includes files under a directory Vim's path syntax can't search", _20_)
  local function _21_()
    local initial_cwd = vim.fn.getcwd()
    vim.api.nvim_set_current_dir(nested_dir)
    local owner_3f = config["owner-filter"](root_dir)
    local result = owner_3f(fs["join-path"]({spacey_dir, "foo.fnl"}))
    vim.api.nvim_set_current_dir(initial_cwd)
    return assert.is_true(result)
  end
  it("includes those files even when the cwd is inside a nested project", _21_)
  local function _22_()
    local owner_3f = config["owner-filter"](root_dir)
    assert.is_false(owner_3f(fs["join-path"]({nested_dir, "a.fnl"})))
    assert.is_false(owner_3f(fs["join-path"]({nested_dir, "b.fnl"})))
    assert.is_true(owner_3f(fs["join-path"]({plain_dir, "a.fnl"})))
    return assert.is_true(owner_3f(fs["join-path"]({plain_dir, "b.fnl"})))
  end
  return it("gives the same answer for repeated calls on one directory", _22_)
end
return describe("owner-filter", _14_)
