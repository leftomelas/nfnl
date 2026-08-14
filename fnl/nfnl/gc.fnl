(local {: autoload : define} (require :nfnl.module))
(local core (autoload :nfnl.core))
(local fs (autoload :nfnl.fs))
(local config (autoload :nfnl.config))
(local header (autoload :nfnl.header))

(local M (define :nfnl.gc))

(fn orphan? [root-dir path]
  "Was the Lua file at the given absolute path compiled by nfnl from a Fennel
  file that no longer exists? The header records the source relative to
  root-dir, so that's what we resolve it against."
  (let [line (fs.read-first-line path)
        source-path (header.source-path line)]
    (and (header.tagged? line)
         (not (fs.exists?
                (when source-path
                  (fs.join-path [root-dir source-path])))))))

(fn M.find-orphan-lua-files [{: cfg : root-dir}]
  "Find Lua files under root-dir that nfnl compiled from a Fennel file that no
  longer exists. Returns absolute paths. Files belonging to a nested nfnl
  project, a subdirectory with its own .nfnl.fnl, are left alone since they're
  that project's responsibility."
  (let [fnl-path->lua-path (cfg [:fnl-path->lua-path])
        ignore-patterns (cfg [:orphan-detection :ignore-patterns])
        owner? (config.owner-filter root-dir)]
    (->> (cfg [:source-file-patterns])
         (core.mapcat
           (fn [fnl-pattern]
             (let [lua-pattern (fnl-path->lua-path fnl-pattern)]
               (fs.relglob root-dir lua-pattern))))
         (core.->set)
         (core.keys)

         ;; ignore-patterns are matched against the root-dir relative path, the
         ;; documented example is "lua/nfnl/", so this has to happen before we
         ;; make the paths absolute.
         (core.filter
           (fn [rel-path]
             (not (core.some
                    (fn [pat]
                      (rel-path:find pat))
                    ignore-patterns))))

         (core.map
           (fn [rel-path]
             (fs.join-path [root-dir rel-path])))

         (core.filter
           (fn [path]
             (and (owner? path)
                  (orphan? root-dir path)))))))

(comment
  (local config (require :nfnl.config))
  (M.find-orphan-lua-files (config.find-and-load ".")))

M
