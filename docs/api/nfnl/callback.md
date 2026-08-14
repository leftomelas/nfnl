# Callback.fnl

**Table of contents**

- [`setup-buffer`](#setup-buffer)
- [`supported-path?`](#supported-path)

## `setup-buffer`
Function signature:

```
(setup-buffer ev)
```

Called by ftplugin/fennel.fnl for every fennel buffer. Registers the
  BufWritePost autocmd and all :Nfnl* buffer-local commands. Trust is checked
  at write time, not here.

## `supported-path?`
Function signature:

```
(supported-path? file-path)
```

Returns true if we can work with the given path. Right now we support a path if it's a string and it doesn't start with a protocol segment like fugitive://...


<!-- Generated with Fenneldoc v1.0.1
     https://gitlab.com/andreyorst/fenneldoc -->
