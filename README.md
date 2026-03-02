# typist-example-shop

A shop application demonstrating [Typist](https://github.com/cwd-k2/typist) — a static type system for Perl 5.

Features exercised: newtypes, structs, ADTs, type classes (Functor, Foldable, Monad), GADTs, higher-kinded types, rank-2 polymorphism, and protocol-driven effects.

## Setup

Requires Perl 5.40+ and [cpanm](https://metacpan.org/pod/App::cpanminus).

```
mise run setup     # cpanm -L local https://github.com/cwd-k2/typist.git
```

## Run

```
mise run run
```

## Verify (static analysis)

```
mise run verify
```

## Editor Integration (VSCode)

Install the [Typist extension](https://github.com/cwd-k2/typist/tree/main/editors/vscode) (`typist-0.0.1.vsix`).
The extension auto-detects `local/bin/typist-lsp` installed by the setup task.

[PerlNavigator](https://marketplace.visualstudio.com/items?itemName=bscan.perlnavigator) settings are included in `.vscode/settings.json`.
