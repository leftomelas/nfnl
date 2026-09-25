-- [nfnl] fnl/spec/nfnl/compile_spec.fnl
local _local_1_ = require("plenary.busted")
local describe = _local_1_.describe
local it = _local_1_.it
local assert = require("luassert.assert")
local config = require("nfnl.config")
local compile = require("nfnl.compile")
local core = require("nfnl.core")
local fs = require("nfnl.fs")
local function _2_()
  local function _3_()
    assert.is_true(compile["macro-source?"]({source = ("; " .. "[nfnl-macro]\n(+ 10 20)")}))
    return nil
  end
  it("detects macro source by marker in source", _3_)
  local function _4_()
    assert.is_true(compile["macro-source?"]({path = "/my/dir/foo.fnlm", source = "(+ 10 20)"}))
    return nil
  end
  it("detects macro source by .fnlm extension", _4_)
  local function _5_()
    assert.is_false(compile["macro-source?"]({source = "(+ 10 20)", path = "/my/dir/foo.fnl"}))
    return nil
  end
  return it("returns false for non-macro source", _5_)
end
describe("macro-source?", _2_)
local function _6_()
  local function _7_()
    return assert.are.same({result = "-- [nfnl] bar.fnl\nreturn (10 + 20)\n", ["source-path"] = "/tmp/foo/bar.fnl", status = "ok"}, compile["into-string"]({["root-dir"] = "/tmp/foo", path = "/tmp/foo/bar.fnl", cfg = config["cfg-fn"]({}, {["root-dir"] = "/tmp/foo"}), ["batch?"] = true, source = "(+ 10 20)"}))
  end
  it("compiles good Fennel to Lua", _7_)
  local function _8_()
    return assert.are.same({["source-path"] = "/my/dir/baz.fnl", status = "path-is-not-in-source-file-patterns"}, compile["into-string"]({["root-dir"] = "/my/dir", path = "/my/dir/baz.fnl", cfg = config["cfg-fn"]({["source-file-patterns"] = {"bar.fnl"}}, {["root-dir"] = "/tmp/foo"}), ["batch?"] = true, source = "(+ 10 20)"}))
  end
  it("skips files that don't match :source-file-patterns", _8_)
  local function _9_()
    return assert.are.same({["source-path"] = "/my/dir/foo.fnl", status = "macros-are-not-compiled"}, compile["into-string"]({["root-dir"] = "/my/dir", path = "/my/dir/foo.fnl", cfg = config["cfg-fn"]({}, {["root-dir"] = "/tmp/foo"}), ["batch?"] = true, source = ("; [nfnl" .. "-" .. "macro]\n(+ 10 20)")}))
  end
  it("skips macro files", _9_)
  local function _10_()
    return assert.are.same({["source-path"] = "/my/dir/.nfnl.fnl", status = "nfnl-config-is-not-compiled"}, compile["into-string"]({["root-dir"] = "/my/dir", path = "/my/dir/.nfnl.fnl", cfg = config["cfg-fn"]({}, {["root-dir"] = "/tmp/foo"}), ["batch?"] = true, source = "(+ 10 20)"}))
  end
  it("won't compile the .nfnl.fnl config file", _10_)
  local function _11_()
    local root_dir = vim.fn.tempname()
    local nested_dir = fs["join-path"]({root_dir, "nested"})
    local path = fs["join-path"]({nested_dir, "foo.fnl"})
    fs.mkdirp(nested_dir)
    core.spit(fs["join-path"]({root_dir, ".nfnl.fnl"}), "{}")
    core.spit(fs["join-path"]({nested_dir, ".nfnl.fnl"}), "{}")
    return assert.are.same({["source-path"] = path, status = "path-is-in-a-nested-nfnl-project"}, compile["into-string"]({["root-dir"] = root_dir, path = path, cfg = config["cfg-fn"]({}, {["root-dir"] = root_dir}), ["batch?"] = true, source = "(+ 10 20)"}))
  end
  it("won't compile files belonging to a nested nfnl project", _11_)
  local function _12_()
    local root_dir = vim.fn.tempname()
    local nested_dir = fs["join-path"]({root_dir, "nested"})
    local path = fs["join-path"]({nested_dir, "baz.fnl"})
    fs.mkdirp(nested_dir)
    core.spit(fs["join-path"]({root_dir, ".nfnl.fnl"}), "{}")
    core.spit(fs["join-path"]({nested_dir, ".nfnl.fnl"}), "{}")
    return assert.are.same({["source-path"] = path, status = "path-is-not-in-source-file-patterns"}, compile["into-string"]({["root-dir"] = root_dir, path = path, cfg = config["cfg-fn"]({["source-file-patterns"] = {"bar.fnl"}}, {["root-dir"] = root_dir}), ["batch?"] = true, source = "(+ 10 20)"}))
  end
  it("reports the pattern mismatch first for a nested file we'd skip anyway", _12_)
  local function _13_()
    return assert.are.same({error = "foo.fnl:1:3: Compile error: tried to reference a special form without calling it\n\n10 / 20\n* Try making sure to use prefix operators, not infix.\n* Try wrapping the special in a function if you need it to be first class.", ["source-path"] = "/my/dir/foo.fnl", status = "compilation-error"}, compile["into-string"]({["root-dir"] = "/my/dir", path = "/my/dir/foo.fnl", cfg = config["cfg-fn"]({}, {["root-dir"] = "/tmp/foo"}), ["batch?"] = true, source = "10 / 20"}))
  end
  return it("returns compilation errors", _13_)
end
describe("into-string", _6_)
local function _14_()
  for _, example in ipairs({{name = "creates missing targets"}, {name = "overwrites empty targets", existing = ""}, {name = "replaces a first-line header", existing = "-- [nfnl] bar.fnl\nreturn 0\n"}, {name = "preserves a shebang above the header", existing = "#!/usr/bin/lua\n-- [nfnl] bar.fnl\nreturn 0\n", prefix = "#!/usr/bin/lua\n"}, {name = "preserves a blank line above the header", existing = "\n-- [nfnl] bar.fnl\nreturn 0\n", prefix = "\n"}, {name = "preserves a comment above the header", existing = "-- Custom comment\n-- [nfnl] bar.fnl\nreturn 0\n", prefix = "-- Custom comment\n"}, {name = "protects handwritten Lua", existing = "return 0\n", ["protected?"] = true}, {name = "protects handwritten scripts with a shebang", existing = "#!/usr/bin/lua\nreturn 0\n", ["protected?"] = true}, {name = "preserves all four lines before a fifth-line header", existing = "#!/usr/bin/lua\n-- One\n\n-- Two\n-- [nfnl] bar.fnl\nreturn 0\n", prefix = "#!/usr/bin/lua\n-- One\n\n-- Two\n"}, {name = "does not search beyond the default five lines", existing = "-- 1\n-- 2\n-- 3\n-- 4\n-- 5\n-- [nfnl] bar.fnl\nreturn 0\n", ["protected?"] = true}, {name = "supports a larger search limit", existing = "-- 1\n-- 2\n-- 3\n-- 4\n-- 5\n-- [nfnl] bar.fnl\nreturn 0\n", prefix = "-- 1\n-- 2\n-- 3\n-- 4\n-- 5\n", ["header-search-lines"] = 6}, {name = "supports requiring a first-line header", existing = "#!/usr/bin/lua\n-- [nfnl] bar.fnl\nreturn 0\n", ["header-search-lines"] = 1, ["protected?"] = true}, {name = "does not search beyond a configured second line", ["header-search-lines"] = 2, existing = "-- One\n-- Two\n-- [nfnl] bar.fnl\nreturn 0\n", ["protected?"] = true}, {name = "keeps header-comment false behaviour", existing = "#!/usr/bin/lua\n-- [nfnl] bar.fnl\nreturn 0\n", ["header-comment"] = false}}) do
    local function _15_()
      local root_dir = vim.fn.tempname()
      local path = fs["join-path"]({root_dir, "bar.fnl"})
      local destination = fs["join-path"]({root_dir, "bar.lua"})
      local opts = {["root-dir"] = root_dir, path = path, ["batch?"] = true, source = "(+ 10 20)", cfg = config["cfg-fn"]({["header-comment"] = example["header-comment"], ["header-search-lines"] = example["header-search-lines"]}, {["root-dir"] = root_dir})}
      fs.mkdirp(root_dir)
      if example.existing then
        core.spit(destination, example.existing)
      else
      end
      for _0 = 1, 2 do
        local _17_
        if example["protected?"] then
          _17_ = "destination-exists"
        else
          _17_ = "ok"
        end
        assert.are.equal(_17_, compile["into-file"](opts).status)
        local _19_
        if example["protected?"] then
          _19_ = example.existing
        elseif (false == example["header-comment"]) then
          _19_ = "return (10 + 20)\n"
        else
          _19_ = ((example.prefix or "") .. "-- [nfnl] bar.fnl\nreturn (10 + 20)\n")
        end
        assert.are.equal(_19_, core.slurp(destination))
      end
      return nil
    end
    it(example.name, _15_)
  end
  return nil
end
describe("into-file", _14_)
local function _21_()
  local function _22_()
    local gc = require("nfnl.gc")
    local root_dir = vim.fn.tempname()
    local source = fs["join-path"]({root_dir, "bar.fnl"})
    local destination = fs["join-path"]({root_dir, "bar.lua"})
    local opts = {["root-dir"] = root_dir, cfg = config["cfg-fn"]({}, {["root-dir"] = root_dir})}
    fs.mkdirp(root_dir)
    core.spit(source, "(+ 10 20)")
    core.spit(destination, "#!/usr/bin/lua\n-- One\n\n-- Two\n-- [nfnl] bar.fnl\nreturn 0\n")
    assert.are.same({}, gc["find-orphan-lua-files"](opts))
    os.remove(source)
    assert.are.same({destination}, gc["find-orphan-lua-files"](opts))
    return assert.are.same({}, gc["find-orphan-lua-files"]({["root-dir"] = root_dir, cfg = config["cfg-fn"]({["header-search-lines"] = 4}, {["root-dir"] = root_dir})}))
  end
  return it("only reports the script when its source is missing", _22_)
end
return describe("orphan detection with a fifth-line header", _21_)
