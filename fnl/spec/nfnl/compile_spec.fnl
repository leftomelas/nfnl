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

(describe "into-file"
  (fn []
    (each [_ example (ipairs
                    [{:name "creates missing targets"}
                     {:name "overwrites empty targets" :existing ""}
                     {:name "replaces a first-line header"
                      :existing "-- [nfnl] bar.fnl\nreturn 0\n"}
                     {:name "preserves a shebang above the header"
                      :existing "#!/usr/bin/lua\n-- [nfnl] bar.fnl\nreturn 0\n"
                      :prefix "#!/usr/bin/lua\n"}
                     {:name "preserves a blank line above the header"
                      :existing "\n-- [nfnl] bar.fnl\nreturn 0\n"
                      :prefix "\n"}
                     {:name "preserves a comment above the header"
                      :existing "-- Custom comment\n-- [nfnl] bar.fnl\nreturn 0\n"
                      :prefix "-- Custom comment\n"}
                     {:name "protects handwritten Lua"
                      :existing "return 0\n" :protected? true}
                     {:name "protects handwritten scripts with a shebang"
                      :existing "#!/usr/bin/lua\nreturn 0\n" :protected? true}
                     {:name "preserves all four lines before a fifth-line header"
                      :existing "#!/usr/bin/lua\n-- One\n\n-- Two\n-- [nfnl] bar.fnl\nreturn 0\n"
                      :prefix "#!/usr/bin/lua\n-- One\n\n-- Two\n"}
                     {:name "does not search beyond the default five lines"
                      :existing "-- 1\n-- 2\n-- 3\n-- 4\n-- 5\n-- [nfnl] bar.fnl\nreturn 0\n"
                      :protected? true}
                     {:name "supports a larger search limit"
                      :existing "-- 1\n-- 2\n-- 3\n-- 4\n-- 5\n-- [nfnl] bar.fnl\nreturn 0\n"
                      :prefix "-- 1\n-- 2\n-- 3\n-- 4\n-- 5\n"
                      :header-search-lines 6}
                     {:name "supports requiring a first-line header"
                      :existing "#!/usr/bin/lua\n-- [nfnl] bar.fnl\nreturn 0\n"
                      :header-search-lines 1 :protected? true}
                     {:name "does not search beyond a configured second line"
                      :header-search-lines 2
                      :existing "-- One\n-- Two\n-- [nfnl] bar.fnl\nreturn 0\n"
                      :protected? true}
                     {:name "keeps header-comment false behaviour"
                      :existing "#!/usr/bin/lua\n-- [nfnl] bar.fnl\nreturn 0\n"
                      :header-comment false}])]
      (it example.name
        (fn []
          (let [root-dir (vim.fn.tempname)
                path (fs.join-path [root-dir "bar.fnl"])
                destination (fs.join-path [root-dir "bar.lua"])
                opts {: root-dir : path :batch? true :source "(+ 10 20)"
                      :cfg (config.cfg-fn {:header-comment example.header-comment
                                           :header-search-lines example.header-search-lines} {: root-dir})}]
            (fs.mkdirp root-dir)
            (when example.existing (core.spit destination example.existing))
            ;; A second compilation must not duplicate or lose the prefix.
            (for [_ 1 2]
              (assert.are.equal (if example.protected? :destination-exists :ok)
                                (. (compile.into-file opts) :status))
              (assert.are.equal
                (if example.protected? example.existing
                    (= false example.header-comment) "return (10 + 20)\n"
                    (.. (or example.prefix "") "-- [nfnl] bar.fnl\nreturn (10 + 20)\n"))
                (core.slurp destination)))))))))

(describe "orphan detection with a fifth-line header"
  (fn []
    (it "only reports the script when its source is missing"
      (fn []
        (let [gc (require :nfnl.gc)
              root-dir (vim.fn.tempname)
              source (fs.join-path [root-dir "bar.fnl"])
              destination (fs.join-path [root-dir "bar.lua"])
              opts {: root-dir :cfg (config.cfg-fn {} {: root-dir})}]
          (fs.mkdirp root-dir)
          (core.spit source "(+ 10 20)")
          (core.spit destination "#!/usr/bin/lua\n-- One\n\n-- Two\n-- [nfnl] bar.fnl\nreturn 0\n")
          (assert.are.same [] (gc.find-orphan-lua-files opts))
          (os.remove source)
          (assert.are.same [destination] (gc.find-orphan-lua-files opts))
          (assert.are.same []
            (gc.find-orphan-lua-files
              {: root-dir :cfg (config.cfg-fn {:header-search-lines 4} {: root-dir})})))))))
