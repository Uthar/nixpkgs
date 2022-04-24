# lisp-modules

Utilities for packaging ASDF systems using Nix.

## Quick start

#### Build an ASDF system:

```
nix-build -E 'with import ./. {}; sbclPackages.bordeaux-threads'
ls result/src
```

#### Build an `sbclWithPackages`:

```
nix-build -E 'with import ./. {}; sbclWithPackages (p: [ p.hunchentoot p.sqlite ])'
result/bin/sbcl
```

#### Re-import Quicklisp packages:

```
nix-shell --run 'sbcl --script ql-import.lisp'
```

## Documentation

See `doc` directory.
