(local {: autoload : define} (require :nfnl.module))
(local core (autoload :nfnl.core))
(local str (autoload :nfnl.string))
(local compile (autoload :nfnl.compile))
(local config (autoload :nfnl.config))
(local notify (autoload :nfnl.notify))
(local fs (autoload :nfnl.fs))
(local gc (autoload :nfnl.gc))
(local vim _G.vim)

(local M (define :nfnl.api))

(fn M.find-orphans [{: passive? : dir :config given-config : root-dir : cfg}]
  "Find orphan Lua files that were compiled from a Fennel file that no longer exists. Display them with notify. Set opts.passive? to true if you don't want it to tell you that there are no orphans. Pass config, root-dir, and cfg to skip loading the config again."
  (let [dir (or dir (vim.fn.getcwd))
        {: config : root-dir : cfg} (if given-config
                                      {:config given-config : root-dir : cfg}
                                      (config.find-and-load dir))]
    (if config
      (let [orphan-files (gc.find-orphan-lua-files {: root-dir : cfg})]
        (if (core.empty? orphan-files)
            (when (not passive?)
              (notify.info "No orphan files detected."))
            (notify.warn
              "Orphan files detected, delete them with :NfnlDeleteOrphans.\n"
              (->> orphan-files
                   (core.map
                     (fn [f]
                       (.. " - " f)))
                   (str.join "\n"))))
        orphan-files)
      (do
        (notify.warn "No .nfnl.fnl configuration found.")
        []))))

(fn M.delete-orphans [{: dir}]
  "Delete orphan Lua files that were compiled from a Fennel file that no longer exists."
  (let [dir (or dir (vim.fn.getcwd))
        {: config : root-dir : cfg} (config.find-and-load dir)]
    (if config
      (let [orphan-files (gc.find-orphan-lua-files {: root-dir : cfg})]
        (if (core.empty? orphan-files)
          (notify.info "No orphan files detected.")
          (do
            (notify.info
              "Deleting orphan files:\n"
              (->> orphan-files
                   (core.map
                     (fn [f]
                       (.. " - " f)))
                   (str.join "\n")))
            (core.map os.remove orphan-files)))
        orphan-files)
      (do
        (notify.warn "No .nfnl.fnl configuration found.")
        []))))

(fn M.compile-file [{: path : dir}]
  "Compiles a file into the matching Lua file. Returns the compilation result. Takes an optional `dir` key that overrides where we look for the configuration, by default we look next to the file itself.

  Will do nothing if you execute it on a directory that doesn't contain an nfnl configuration file.

  Also displays all results via the notify system."
  (let [expanded (vim.fn.expand (or path "%"))
        path (fs.absolute-path expanded)

        ;; Look for the configuration next to the file rather than in the
        ;; working directory, so a file inside a nested project is compiled by
        ;; that project just as it would be on write. With no file to go on we
        ;; have nothing better than the working directory.
        {: config : root-dir : cfg}
        (config.find-and-load
          (or dir
              (if (str.blank? expanded)
                (vim.fn.getcwd)
                (fs.basename path))))]
    (if config
      (let [result (compile.into-file
                     {: root-dir
                      : cfg
                      : path
                      :source (core.slurp path)
                      :batch? true})]
        (notify.info "Compilation complete.\n" result)
        result)
      (do
        (notify.warn "No .nfnl.fnl configuration found.")
        []))))

(fn M.compile-all-files [dir]
  "Compiles all files in the given dir (optional), defaulting to the current working directory. Returns a sequential table with each of the files compilation result.

  Will do nothing if you execute it on a directory that doesn't contain an nfnl configuration file.

  Also displays all results via the notify system."
  (let [dir (or dir (vim.fn.getcwd))
        {: config : root-dir : cfg} (config.find-and-load dir)]
    (if config
      (let [results (compile.all-files {: root-dir : cfg})]
        (notify.info "Compilation complete.\n" results)
        results)
      (do
        (notify.warn "No .nfnl.fnl configuration found.")
        []))))

(fn M.dofile [file]
  "Just like :luafile, takes a Fennel file path (optional, defaults to '%', runs it through expand) and executes it from disk. However! This doesn't compile the Fennel! It maps the Fennel path to the matching Lua file already in your file system and executes that with Lua's built in dofile. So you need to have already written your .fnl and had nfnl compile that to a .lua for this to work, it's just a convinience function for you to call directly or through the :NfnlFile command."
  (dofile (fs.fnl-path->lua-path (vim.fn.expand (or file "%")))))

M
