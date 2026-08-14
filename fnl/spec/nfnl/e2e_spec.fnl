(local {: describe : it : before_each : after_each} (require :plenary.busted))
(local assert (require :luassert.assert))
(local core (require :nfnl.core))
(local fs (require :nfnl.fs))
(local api (require :nfnl.api))

;; These temp directories are auto deleted on Neovim exit.
(local temp-dir (vim.fn.tempname))
(local unrelated-temp-dir (vim.fn.tempname))

(local fnl-dir (fs.join-path [temp-dir "fnl"]))
(local lua-dir (fs.join-path [temp-dir "lua"]))
(local config-path (fs.join-path [temp-dir ".nfnl.fnl"]))
(local fnl-path (fs.join-path [fnl-dir "foo.fnl"]))
(local macro-fnl-path (fs.join-path [fnl-dir "bar.fnl"]))
(local macro-lua-path (fs.join-path [lua-dir "bar.lua"]))
(local lua-path (fs.join-path [lua-dir "foo.lua"]))

(fs.mkdirp fnl-dir)
(fs.mkdirp unrelated-temp-dir)

(fn delete-buf-file [path]
  (pcall vim.cmd (.. "bwipeout! " path))
  (os.remove path))

(fn run-e2e-tests []
  ;; Reset the files between each test run.
  (core.run! delete-buf-file [config-path fnl-path macro-fnl-path lua-path])

  (it "does nothing when there's no .nfnl.fnl configuration"
      (fn []
        (vim.cmd (.. "edit " fnl-path))
        (set vim.o.filetype "fennel")
        (vim.api.nvim_buf_set_lines 0 0 -1 false ["(print \"Hello, World!\")"])
        (vim.cmd "write")
        (assert.is_nil (core.slurp lua-path))))

  (it "compiles when there's a trusted .nfnl.fnl configuration file"
      (fn []
        (vim.cmd (.. "edit " config-path))
        (vim.api.nvim_buf_set_lines 0 0 -1 false ["{}"])
        (vim.cmd "write")
        (vim.cmd "trust")
        (vim.cmd (.. "edit " fnl-path))
        (set vim.o.filetype "fennel")
        (vim.api.nvim_buf_set_lines 0 0 -1 false ["(print \"Hello, World!\")"])
        (vim.cmd "write")
        (assert.are.equal 1 (vim.fn.isdirectory lua-dir))

        (local lua-result (core.slurp lua-path))
        (print "Lua result:" lua-result)

        (assert.are.equal
          "-- [nfnl] fnl/foo.fnl\nreturn print(\"Hello, World!\")\n"
          lua-result)))

  (it "can import-macros and use them, the macros aren't compiled"
      (fn []
        (vim.cmd (.. "edit " macro-fnl-path))
        (set vim.o.filetype "fennel")

        ;; We have to split up the macro marker otherwise this file gets marked as a macro file and won't compile.
        (vim.api.nvim_buf_set_lines 0 0 -1 false [(.. ";; [nfnl" "-" "macro]") "{:infix (fn [a op b] `(,op ,a ,b))}"])
        (vim.cmd "write")

        (vim.cmd (.. "edit " fnl-path))
        (set vim.o.filetype "fennel")
        (vim.api.nvim_buf_set_lines 0 0 -1 false ["(import-macros {: infix} :bar)" "(infix 10 + 20)"])
        (vim.cmd "write")

        (assert.is_nil (core.slurp macro-lua-path))

        (local lua-result (core.slurp lua-path))
        (print "Lua result:" lua-result)

        (assert.are.equal
          "-- [nfnl] fnl/foo.fnl\nreturn (10 + 20)\n"
          lua-result))))

(describe
  "e2e file compiling from a project dir"
  (fn []
    (var initial-cwd nil)

    (before_each
      (fn []
        (set initial-cwd (vim.fn.getcwd))
        (vim.api.nvim_set_current_dir temp-dir)))

    (after_each
      (fn []
        (vim.api.nvim_set_current_dir initial-cwd)))

    (run-e2e-tests)))

(describe
  "e2e file compiling from outside project dir"
  (fn []
    (var initial-cwd nil)

    (before_each
      (fn []
        (set initial-cwd (vim.fn.getcwd))
        (vim.api.nvim_set_current_dir unrelated-temp-dir)))

    (after_each
      (fn []
        (vim.api.nvim_set_current_dir initial-cwd)))

    (run-e2e-tests)))

(fn make-nested-project []
  "Builds an outer project with a second, independent project nested inside it.
  Both .nfnl.fnl files are trusted so nfnl will actually read them. Returns a
  table of every path the tests care about."
  (let [outer-dir (vim.fn.tempname)
        nested-dir (fs.join-path [outer-dir "pack" "nested"])
        paths {: outer-dir
               : nested-dir
               :outer-config (fs.join-path [outer-dir ".nfnl.fnl"])
               :nested-config (fs.join-path [nested-dir ".nfnl.fnl"])
               :outer-fnl (fs.join-path [outer-dir "fnl" "outer.fnl"])
               :outer-lua (fs.join-path [outer-dir "lua" "outer.lua"])
               :nested-fnl (fs.join-path [nested-dir "fnl" "inner.fnl"])
               :nested-lua (fs.join-path [nested-dir "lua" "inner.lua"])}]
    (fs.mkdirp (fs.join-path [outer-dir "fnl"]))
    (fs.mkdirp (fs.join-path [outer-dir "lua"]))
    (fs.mkdirp (fs.join-path [nested-dir "fnl"]))
    (fs.mkdirp (fs.join-path [nested-dir "lua"]))
    (core.spit paths.outer-config "{}")
    (core.spit paths.nested-config "{}")
    (vim.secure.trust {:action "allow" :path paths.outer-config})
    (vim.secure.trust {:action "allow" :path paths.nested-config})
    paths))

(describe
  "e2e nested project boundaries"
  (fn []
    (it "compiles the outer project without descending into the nested one"
        (fn []
          (let [{: outer-dir : outer-fnl : outer-lua : nested-fnl : nested-lua}
                (make-nested-project)]
            (core.spit outer-fnl "(print :outer)")
            (core.spit nested-fnl "(print :inner)")

            (api.compile-all-files outer-dir)

            (assert.are.equal
              "-- [nfnl] fnl/outer.fnl\nreturn print(\"outer\")\n"
              (core.slurp outer-lua))
            (assert.is_nil (core.slurp nested-lua)))))

    (it "finds orphans when it isn't handed a config"
        (fn []
          ;; :NfnlFindOrphans passes a dir and nothing else.
          (let [{: outer-dir} (make-nested-project)]
            (assert.are.same
              []
              (api.find-orphans {:dir outer-dir :passive? true})))))

    (it "ignores orphan Lua files inside the nested project"
        (fn []
          (let [{: outer-dir : nested-lua} (make-nested-project)]
            ;; Tagged by nfnl, and its Fennel source doesn't exist. An orphan by
            ;; every measure except that it belongs to the nested project.
            (core.spit nested-lua "-- [nfnl] fnl/gone.fnl\nreturn nil\n")
            (assert.are.same
              []
              (api.find-orphans {:dir outer-dir :passive? true})))))

    (it "finds orphans as absolute paths when the cwd isn't the project root"
        (fn []
          (let [{: outer-dir : outer-lua} (make-nested-project)
                initial-cwd (vim.fn.getcwd)]
            (core.spit outer-lua "-- [nfnl] fnl/gone.fnl\nreturn nil\n")

            ;; Pin the cwd somewhere that isn't outer-dir rather than relying on
            ;; wherever the suite happens to run from. Relative paths would
            ;; resolve against this directory and the orphan would go unnoticed,
            ;; which is the whole regression.
            (vim.api.nvim_set_current_dir unrelated-temp-dir)
            (let [orphans (api.find-orphans {:dir outer-dir :passive? true})]
              (vim.api.nvim_set_current_dir initial-cwd)
              (assert.are.same [outer-lua] orphans)))))

    (it "compiles a nested file with its own project's config"
        (fn []
          ;; :NfnlCompileFile on a file that belongs to a nested project should
          ;; compile it the way writing it would, not refuse it and not use the
          ;; outer project's configuration.
          (let [{: outer-dir : nested-fnl : nested-lua} (make-nested-project)
                initial-cwd (vim.fn.getcwd)]
            (core.spit nested-fnl "(print :inner)")
            (vim.api.nvim_set_current_dir outer-dir)
            (api.compile-file {:path nested-fnl})
            (vim.api.nvim_set_current_dir initial-cwd)

            ;; The header path is relative to the nested project's root, which
            ;; is how we know the nested config was the one used.
            (assert.are.equal
              "-- [nfnl] fnl/inner.fnl\nreturn print(\"inner\")\n"
              (core.slurp nested-lua)))))

    (it "still compiles and garbage collects the nested project on its own"
        (fn []
          ;; The other direction: we must not over-exclude. Pointed at the
          ;; nested project directly, everything works as normal.
          (let [{: nested-dir : nested-fnl : nested-lua} (make-nested-project)
                orphan-lua (fs.join-path [nested-dir "lua" "gone.lua"])]
            (core.spit nested-fnl "(print :inner)")
            (core.spit orphan-lua "-- [nfnl] fnl/gone.fnl\nreturn nil\n")

            (api.compile-all-files nested-dir)

            (assert.are.equal
              "-- [nfnl] fnl/inner.fnl\nreturn print(\"inner\")\n"
              (core.slurp nested-lua))
            (assert.are.same
              [orphan-lua]
              (api.find-orphans {:dir nested-dir :passive? true})))))))
