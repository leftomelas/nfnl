(local {: autoload : define} (require :nfnl.module))
(local core (autoload :nfnl.core))
(local fs (autoload :nfnl.fs))
(local str (autoload :nfnl.string))
(local fennel (autoload :nfnl.fennel))
(local notify (autoload :nfnl.notify))
(local vim _G.vim)

(local M (define :nfnl.config))

(local config-file-name ".nfnl.fnl")

(fn M.find [dir]
  "Find the nearest .nfnl.fnl file to the given directory, searching upwards.
  Returns nil when there isn't one. We use vim.fs.find rather than findfile
  because findfile takes a Vim 'path' string, in which a comma separates entries
  and spaces have to be escaped, so directories containing either would silently
  be searched for relative to the current working directory instead."
  (-> (vim.fs.find config-file-name {:path dir :upward true :type :file})
      (core.first)
      (fs.full-path)))

(fn under? [parent dir]
  "Is dir the parent directory itself, or somewhere beneath it?"
  (let [prefix (.. parent (fs.path-sep))]
    (or (= parent dir)
        (= prefix (string.sub dir 1 (string.len prefix))))))

(fn M.owner-filter [root-dir]
  "Returns a predicate that takes an absolute path and returns true when the
  nearest .nfnl.fnl to that path is the one in root-dir. A directory containing
  its own .nfnl.fnl is a separate project, so this lets us leave its files alone
  rather than compiling them with the wrong configuration. We only exclude a
  path when we're confident it belongs to a project nested under us, anything
  else is included. Memoised per directory so a batch operation searches the
  file system once per directory rather than once per file."
  (let [cache {}]
    (fn [path]
      (let [dir (fs.basename path)]
        (when (core.nil? (. cache dir))
          (tset cache dir
                (let [config-dir (fs.basename (M.find dir))]
                  (if
                    ;; No config above this path at all, no other project to
                    ;; defer to.
                    (core.nil? config-dir) true

                    ;; Ours.
                    (= root-dir config-dir) true

                    ;; A project nested under us that really does contain this
                    ;; directory, it looks after its own files. Both halves
                    ;; matter, see below.
                    (and (under? root-dir config-dir)
                         (under? config-dir dir)) false

                    ;; A config that's neither ours nor above this directory,
                    ;; which happens when root-dir isn't a real project root.
                    ;; config.default lets you pass any root-dir you like. Fail
                    ;; open, compiling a file we didn't need to is far better
                    ;; than silently skipping one.
                    true))))
        (. cache dir)))))

(fn M.path-dirs [{: rtp-patterns : runtimepath : base-dirs}]
  "Takes the current runtimepath and a sequential table of rtp-patterns. Those
  patterns are used to filter down all of the runtimepath directories. Returns
  the runtime path items that match at least one of the rtp-patterns.

  Also accepts a base-dirs table that it'll concatenate onto the end of then
  run through core.distinct to de-duplicate."
  (->> (str.split runtimepath ",")
       (core.filter
         (fn [path]
           (core.some #(string.find path $) rtp-patterns)))
       (core.concat base-dirs)
       (core.distinct)))

(fn M.default [opts]
  "Returns the default configuration that you should base your custom
  configuration on top of. Feel free to call this with no arguments and merge
  your changes on top. You can override opts.root-dir (which defaults to the dir of your .nfnl.fnl project root and the CWD as a backup) to whatever you need. The defaults with no arguments should be correct for most situations though.

  opts.rtp-patterns is a sequential table of Lua patterns that match
  runtimepath directories you wish to include in your fennel-path and
  fennel-macro-path. It defaults to just [\"/nfnl$\"] which matches any
  runtimepath directory ending in /nfnl. Add any Neovim plugins you wish to use
  at compile or runtime here. You can also just replace it with a catch all
  pattern to include all directories.

   - All plugins: [\".*\"]
   - nfnl + my-cool-plugin: [\"/nfnl$\" \"/my-cool-plugin$\"]

  Make sure you update the README whenever you change the default
  configuration!"

  (let [;; Base this config's paths on...
        root-dir (or
                   ;; The given root-dir option.
                   (core.get opts :root-dir)

                   ;; The closest .nfnl.fnl file parent directory to the cwd.
                   (-?> (vim.fn.getcwd)
                        (M.find) ; returns nil if .nfnl.fnl is not found
                        (fs.full-path)
                        (fs.basename))

                   ;; The cwd, just in case nothing else works.
                   (vim.fn.getcwd))

        dirs (M.path-dirs
               {:runtimepath vim.o.runtimepath
                :rtp-patterns (core.get opts :rtp-patterns [(.. (fs.path-sep) "nfnl$")])
                :base-dirs [root-dir]})]

    {:verbose false
     :header-comment true
     :compiler-options {:error-pinpoint false}
     :orphan-detection {:auto? true
                        :ignore-patterns []}

     :root-dir root-dir

     :fennel-path
     (str.join
       ";"
       (core.mapcat
         (fn [root-dir]
           (core.map
             fs.join-path
             [[root-dir "?.fnl"]
              [root-dir "?" "init.fnl"]
              [root-dir "fnl" "?.fnl"]
              [root-dir "fnl" "?" "init.fnl"]]))
         dirs))

     ;; Original string from Fennel v1.6.0
     ;; "./?.fnlm;./?/init.fnlm;./?.fnl;./?/init-macros.fnl;./?/init.fnl"
     :fennel-macro-path
     (str.join
       ";"
       (core.mapcat
         (fn [root-dir]
           (core.map
             fs.join-path
             [[root-dir "?.fnlm"]
              [root-dir "?" "init.fnlm"]
              [root-dir "?" "init-macros.fnlm"]
              [root-dir "fnl" "?.fnlm"]
              [root-dir "fnl" "?" "init.fnlm"]
              [root-dir "fnl" "?" "init-macros.fnlm"]

              [root-dir "?.fnl"]
              [root-dir "?" "init.fnl"]
              [root-dir "?" "init-macros.fnl"]
              [root-dir "fnl" "?.fnl"]
              [root-dir "fnl" "?" "init.fnl"]
              [root-dir "fnl" "?" "init-macros.fnl"]]))
         dirs))

     :source-file-patterns [".*.fnl" "*.fnl" (fs.join-path ["**" "*.fnl"])]
     :fnl-path->lua-path fs.fnl-path->lua-path}))

(fn M.cfg-fn [t opts]
  "Builds a cfg fetcher for the config table t. Returns a function that takes a
  path sequential table, it looks up the value from the config with core.get-in
  and falls back to a matching value in (default) if not found."

  (let [default-cfg (M.default opts)]
    (fn [path]
      (core.get-in
        t path
        (core.get-in default-cfg path)))))

(local notified {})

(fn M.config-file-path? [path]
  (= config-file-name (fs.filename path)))

(fn M.find-and-load [dir]
  "Attempt to find and load the .nfnl.fnl config file relative to the given dir.
  Returns an empty table when there's issues or if there isn't a config file.
  If there's some valid config you'll get table containing config, cfg (fn) and
  root-dir back."

  (or
    (let [config-file-path (M.find dir)]
      (when config-file-path
        (let [root-dir (fs.basename config-file-path)
              config-source (vim.secure.read config-file-path)

              (ok config)
              (if
                (core.nil? config-source)
                (do
                  (when (not (. notified config-file-path))
                    (tset notified config-file-path true)
                    (notify.info config-file-path " is not trusted yet. Open it and :trust to enable nfnl."))
                  (values false nil))

                (or (str.blank? config-source)
                    (= "{}" (str.trim config-source)))
                (values true {})

                (pcall
                  fennel.eval
                  config-source
                  {:filename config-file-path}))]
          (if ok
            {: config
             : root-dir
             :cfg (M.cfg-fn config {: root-dir})}
            (when config
              (notify.error config))))))

    ;; Always default to an empty table for destructuring.
    {}))

M
