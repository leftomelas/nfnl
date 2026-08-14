(local {: describe : it} (require :plenary.busted))
(local assert (require :luassert.assert))
(local config (require :nfnl.config))
(local compile (require :nfnl.compile))
(local core (require :nfnl.core))
(local fs (require :nfnl.fs))

(describe "macro-source?"
  (fn []
    (it "detects macro source by marker in source"
      (fn []
        (assert.is_true
          (compile.macro-source?
            ;; Funny formatting to prevent this file from being picked up as a macro.
            {:source (.. "; " "[nfnl-macro]\n(+ 10 20)")}))
        nil))
    (it "detects macro source by .fnlm extension"
      (fn []
        (assert.is_true
          (compile.macro-source?
            {:path "/my/dir/foo.fnlm"
             :source "(+ 10 20)"}))
        nil))
    (it "returns false for non-macro source"
      (fn []
        (assert.is_false
          (compile.macro-source?
            {:source "(+ 10 20)"
             :path "/my/dir/foo.fnl"}))
        nil))))

(describe
  "into-string"
  (fn []
    (it "compiles good Fennel to Lua"
        (fn []
          (assert.are.same
            {:result "-- [nfnl] bar.fnl\nreturn (10 + 20)\n"
             :source-path "/tmp/foo/bar.fnl"
             :status "ok"}
            (compile.into-string
              {:root-dir "/tmp/foo"
               :path "/tmp/foo/bar.fnl"
               :cfg (config.cfg-fn {} {:root-dir "/tmp/foo"})
               :batch? true
               :source "(+ 10 20)"}))))

    (it "skips files that don't match :source-file-patterns"
        (fn []
          (assert.are.same
            {:source-path "/my/dir/baz.fnl"
             :status "path-is-not-in-source-file-patterns"}
            (compile.into-string
              {:root-dir "/my/dir"
               :path "/my/dir/baz.fnl"
               :cfg (config.cfg-fn {:source-file-patterns ["bar.fnl"]}
                                   {:root-dir "/tmp/foo"})
               :batch? true
               :source "(+ 10 20)"}))))

    (it "skips macro files"
        (fn []
          (assert.are.same
            {:source-path "/my/dir/foo.fnl"
             :status "macros-are-not-compiled"}
            (compile.into-string
              {:root-dir "/my/dir"
               :path "/my/dir/foo.fnl"
               :cfg (config.cfg-fn {} {:root-dir "/tmp/foo"})
               :batch? true
               :source (.. "; [nfnl" "-" "macro]\n(+ 10 20)")}))))

    (it "won't compile the .nfnl.fnl config file"
        (fn []
          (assert.are.same
            {:source-path "/my/dir/.nfnl.fnl"
             :status "nfnl-config-is-not-compiled"}
            (compile.into-string
              {:root-dir "/my/dir"
               :path "/my/dir/.nfnl.fnl"
               :cfg (config.cfg-fn {} {:root-dir "/tmp/foo"})
               :batch? true
               :source "(+ 10 20)"}))))

    (it "won't compile files belonging to a nested nfnl project"
        (fn []
          ;; Real directories, the nested project check searches the file system.
          (let [root-dir (vim.fn.tempname)
                nested-dir (fs.join-path [root-dir "nested"])
                path (fs.join-path [nested-dir "foo.fnl"])]
            (fs.mkdirp nested-dir)
            (core.spit (fs.join-path [root-dir ".nfnl.fnl"]) "{}")
            (core.spit (fs.join-path [nested-dir ".nfnl.fnl"]) "{}")
            (assert.are.same
              {:source-path path
               :status "path-is-in-a-nested-nfnl-project"}
              (compile.into-string
                {: root-dir
                 : path
                 :cfg (config.cfg-fn {} {: root-dir})
                 :batch? true
                 :source "(+ 10 20)"})))))

    (it "reports the pattern mismatch first for a nested file we'd skip anyway"
        (fn []
          ;; Pins the branch order. This path is both inside a nested project
          ;; and outside :source-file-patterns, and the pattern check has to win.
          (let [root-dir (vim.fn.tempname)
                nested-dir (fs.join-path [root-dir "nested"])
                path (fs.join-path [nested-dir "baz.fnl"])]
            (fs.mkdirp nested-dir)
            (core.spit (fs.join-path [root-dir ".nfnl.fnl"]) "{}")
            (core.spit (fs.join-path [nested-dir ".nfnl.fnl"]) "{}")
            (assert.are.same
              {:source-path path
               :status "path-is-not-in-source-file-patterns"}
              (compile.into-string
                {: root-dir
                 : path
                 :cfg (config.cfg-fn {:source-file-patterns ["bar.fnl"]}
                                     {: root-dir})
                 :batch? true
                 :source "(+ 10 20)"})))))

    (it "returns compilation errors"
        (fn []
          (assert.are.same
            {:error "foo.fnl:1:3: Compile error: tried to reference a special form without calling it\n\n10 / 20\n* Try making sure to use prefix operators, not infix.\n* Try wrapping the special in a function if you need it to be first class."
             :source-path "/my/dir/foo.fnl"
             :status "compilation-error"}
            (compile.into-string
              {:root-dir "/my/dir"
               :path "/my/dir/foo.fnl"
               :cfg (config.cfg-fn {} {:root-dir "/tmp/foo"})
               :batch? true
               :source "10 / 20"}))))))
