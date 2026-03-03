# typist-example-shop

A shop application demonstrating [Typist](https://github.com/cwd-k2/typist) — a static type system for Perl 5.

Features exercised: newtypes, structs, generic structs (`ReportNode[T]`), ADTs, parametric ADTs (including `Pair[A, B]` for tuple encoding), GADTs, enums, literal unions, optional fields, union types, recursive types, type classes (Functor, Foldable, Monad, Applicative, Traversable), higher-kinded types, natural transformations, Kleisli composition, Codensity monad, Validation (accumulating errors), Reader monad, State monad, Writer monad, rank-2 polymorphism, algebraic effects with handlers, protocol-driven effects, and structured logging.

## Setup

Requires Perl 5.40+ and [cpanm](https://metacpan.org/pod/App::cpanminus).

```
mise run setup         # install from GitHub
mise run setup-local   # or copy from ../typist (local development)
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

`mise run setup` (or `setup-local`) automatically creates `.vscode/settings.json`
from the committed template `.vscode/settings.default.json`.
The generated file is gitignored, so local overrides (e.g. `typist.server.path`)
stay private.

## Directory Structure

```
lib/Shop/
  Types.pm              # Central type definitions (structs, ADTs, effects)
  Instances.pm          # Cross-file typeclass instances
  Func/                 # Functional abstractions
    HKT.pm              #   Typeclasses (Functor, Foldable, Monad, Applicative, Traversable)
    Codensity.pm        #   CPS monad transformer
    Validation.pm       #   Accumulating error Applicative
    Reader.pm           #   Environment injection monad
    State.pm            #   State threading monad
    Writer.pm           #   Audit trail monad
  Infra/                # Infrastructure
    Display.pm          #   ANSI CLI output layer
    Store.pm            #   In-memory effect handlers
  Domain/               # Business domain
    Customer.pm         #   Customer management
    Inventory.pm        #   Product and stock management
    Order.pm            #   Order lifecycle
    Payment.pm          #   Payment processing
    Pricing.pm          #   Pricing calculations
  Feature/              # Cross-cutting features
    Report.pm           #   Daily reports
    Events.pm           #   GADT event processing
    Checkout.pm         #   Register checkout protocol
    Analytics.pm        #   Inference stress testing
```

## Known Type Limitations

Both checking layers — static (`typist-check`) and runtime CHECK-phase
(`use Typist`) — pass with **0 diagnostics** and **0 `@typist-ignore`
suppressions**. 5 named functions remain unannotated due to structural
limitations of `:sig()`.

### Unannotated Functions (5)

| Function | Reason |
|---|---|
| `Store::*_handler` (4) | Returns `+{...}` HashRef — no HashRef type in `:sig()` |
| `Display::logger_handler` | Same — returns handler HashRef |

### Pair[A, B] Tuple Type

`State S A` and `Writer W A` use a pair encoding to thread state/log alongside
values. The `Pair[A, B]` datatype (defined in `Shop::Types`) replaces the
original anonymous `[$a, $s]` ArrayRef encoding, enabling full `:sig()`
annotations on all State and Writer operations. Reader (`Reader E A = E -> A`)
is a plain function type and requires no tuple encoding.
