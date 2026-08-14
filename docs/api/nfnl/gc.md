# Gc.fnl

**Table of contents**

- [`find-orphan-lua-files`](#find-orphan-lua-files)

## `find-orphan-lua-files`
Function signature:

```
(find-orphan-lua-files {:cfg cfg :root-dir root-dir})
```

Find Lua files under root-dir that nfnl compiled from a Fennel file that no
  longer exists. Returns absolute paths. Files belonging to a nested nfnl
  project, a subdirectory with its own .nfnl.fnl, are left alone since they're
  that project's responsibility.


<!-- Generated with Fenneldoc v1.0.1
     https://gitlab.com/andreyorst/fenneldoc -->
