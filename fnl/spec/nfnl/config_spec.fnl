(local {: describe : it} (require :plenary.busted))
(local assert (require :luassert.assert))
(local config (require :nfnl.config))
(local core (require :nfnl.core))
(local fs (require :nfnl.fs))

(describe
  "default"
  (fn []
    (it "is a function that returns a table"
        (fn []
          (assert.equals :function (type config.default))
          (assert.equals :table (type (config.default {:root-dir "/tmp/foo"})))
          (assert.equals (vim.fn.getcwd) (. (config.default {}) :root-dir))))))

(describe
  "cfg-fn"
  (fn []
    (it "builds a function that looks up values in a table falling back to defaults"
        (fn []
          (local opts {:root-dir "/tmp/foo"})
          (assert.is_string ((config.cfg-fn {} opts) [:fennel-macro-path]))
          (assert.is_nil ((config.cfg-fn {} opts) [:nope]))
          (assert.equals :yep ((config.cfg-fn {:nope :yep} opts) [:nope]))
          (assert.equals :yep ((config.cfg-fn {:fennel-macro-path :yep} opts) [:fennel-macro-path]))))))

(describe
  "config-file-path?"
  (fn []
    (it "returns true for config file paths"
        (fn []
          (assert.is_true (config.config-file-path? "./foo/.nfnl.fnl"))
          (assert.is_true (config.config-file-path? ".nfnl.fnl"))
          (assert.is_false (config.config-file-path? ".fnl.fnl"))))))

(describe
  "find-and-load"
  (fn []
    (it "loads the repo config file"
        (fn []
          (let [{: cfg : root-dir : config}
                (config.find-and-load ".")]
            (assert.are.same {:verbose true} config)
            (assert.equals (vim.fn.getcwd) root-dir)
            (assert.equals :function (type cfg)))))

    (it "returns an empty table if a config file isn't found"
        (fn []
          (assert.are.same {} (config.find-and-load "/some/made/up/dir"))))))

(fn sorted [xs]
  (table.sort xs)
  xs)

(describe
  "path-dirs"
  (fn []
    (it "builds path dirs from runtimepath, deduplicates the base-dirs"
        (fn []
          (assert.are.same
            ["/foo/bar/nfnl" "/foo/baz/my-proj"]
            (sorted
              (config.path-dirs
                {:runtimepath "/foo/bar/nfnl,/foo/bar/other-thing"
                 :rtp-patterns [(.. (fs.path-sep) "nfnl$")]
                 :base-dirs ["/foo/baz/my-proj"]})))

          (assert.are.same
            ["/foo/bar/nfnl" "/foo/baz/my-proj"]
            (sorted
              (config.path-dirs
                {:runtimepath "/foo/bar/nfnl,/foo/bar/other-thing"
                 :rtp-patterns [(.. (fs.path-sep) "nfnl$")]
                 :base-dirs ["/foo/baz/my-proj" "/foo/bar/nfnl"]})))))))

(describe
  "find"
  (fn []
    (local root-dir (vim.fn.tempname))
    (local config-path (fs.join-path [root-dir ".nfnl.fnl"]))
    (local plain-dir (fs.join-path [root-dir "fnl" "plain"]))
    (local spacey-dir (fs.join-path [root-dir "fnl" "my dir"]))
    (local comma-dir (fs.join-path [root-dir "fnl" "comma,dir"]))

    (fs.mkdirp plain-dir)
    (fs.mkdirp spacey-dir)
    (fs.mkdirp comma-dir)
    (core.spit config-path "{}")

    (it "finds the config above a directory"
        (fn []
          (assert.equals config-path (config.find plain-dir))))

    (it "finds the config above a directory containing a space"
        (fn []
          (assert.equals config-path (config.find spacey-dir))))

    (it "finds the config above a directory containing a comma"
        (fn []
          (assert.equals config-path (config.find comma-dir))))

    (it "returns nil when there's no config above the directory"
        (fn []
          (assert.is_nil (config.find "/some/made/up/dir"))))))

(describe
  "owner-filter"
  (fn []
    ;; A project containing a nested project, on a real temp directory since
    ;; owner-filter has to search the file system.
    (local root-dir (vim.fn.tempname))
    (local plain-dir (fs.join-path [root-dir "fnl" "deep"]))
    (local spacey-dir (fs.join-path [root-dir "fnl" "my dir"]))
    (local nested-dir (fs.join-path [root-dir "pack" "nested"]))
    (local nested-sub-dir (fs.join-path [nested-dir "fnl"]))

    (fs.mkdirp plain-dir)
    (fs.mkdirp spacey-dir)
    (fs.mkdirp nested-sub-dir)
    (core.spit (fs.join-path [root-dir ".nfnl.fnl"]) "{}")
    (core.spit (fs.join-path [nested-dir ".nfnl.fnl"]) "{}")

    (it "includes files directly under the root dir"
        (fn []
          (assert.is_true
            ((config.owner-filter root-dir)
             (fs.join-path [root-dir "foo.fnl"])))))

    (it "includes files under a subdirectory with no config of its own"
        (fn []
          (assert.is_true
            ((config.owner-filter root-dir)
             (fs.join-path [plain-dir "foo.fnl"])))))

    (it "excludes files inside a nested project"
        (fn []
          (assert.is_false
            ((config.owner-filter root-dir)
             (fs.join-path [nested-dir "foo.fnl"])))))

    (it "excludes files under a nested project"
        (fn []
          (assert.is_false
            ((config.owner-filter root-dir)
             (fs.join-path [nested-sub-dir "foo.fnl"])))))

    (it "includes paths with no config file above them at all"
        (fn []
          (assert.is_true
            ((config.owner-filter "/some/made/up/dir")
             "/some/made/up/dir/foo.fnl"))))

    (it "includes files under a directory with a space in its name"
        (fn []
          (assert.is_true
            ((config.owner-filter root-dir)
             (fs.join-path [spacey-dir "foo.fnl"])))))

    (it "includes those files even when the cwd is inside a nested project"
        (fn []
          ;; A regression guard. Any upward search that resolves against the cwd
          ;; rather than the directory we asked about hands back the nested
          ;; project's config, which really is under root-dir and so looks like a
          ;; legitimate exclusion. It isn't, that config is nowhere near this
          ;; file, and treating it as one would silently stop compiling.
          (let [initial-cwd (vim.fn.getcwd)]
            (vim.api.nvim_set_current_dir nested-dir)
            (let [owner? (config.owner-filter root-dir)
                  result (owner? (fs.join-path [spacey-dir "foo.fnl"]))]
              (vim.api.nvim_set_current_dir initial-cwd)
              (assert.is_true result)))))

    (it "includes files when root-dir isn't a real project root"
        (fn []
          ;; config.default lets you pass any root-dir, so it isn't always a
          ;; directory containing a .nfnl.fnl. The config we find then belongs
          ;; neither to us nor to a project beneath us, so we fail open.
          (assert.is_true
            ((config.owner-filter (fs.join-path [root-dir "not-a-project"]))
             (fs.join-path [plain-dir "foo.fnl"])))))

    (it "gives the same answer for repeated calls on one directory"
        (fn []
          (let [owner? (config.owner-filter root-dir)]
            (assert.is_false (owner? (fs.join-path [nested-dir "a.fnl"])))
            (assert.is_false (owner? (fs.join-path [nested-dir "b.fnl"])))
            (assert.is_true (owner? (fs.join-path [plain-dir "a.fnl"])))
            (assert.is_true (owner? (fs.join-path [plain-dir "b.fnl"]))))))))
