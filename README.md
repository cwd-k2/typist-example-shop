# typist-example-shop

A shop application demonstrating [Typist](https://github.com/cwd-k2/typist) — a static type system for Perl 5.

Features exercised: newtypes, structs, generic structs (`ReportNode[T]`), bounded generic structs (`Range[T: Num]`), ADTs, parametric ADTs, GADTs, enums, literal unions, optional fields, union types, recursive types, recursive type aliases (`CategoryTree`, `Json`), record types, intersection types, tuple types (`Tuple[A, B]`, `Tuple[A, B, C]`), type classes (Functor, Foldable, Monad, Applicative, Traversable), typeclass superclass hierarchy (`Ord: Eq`), typeclass constraints (`<T: Printable>`, `<T: Ord>`), multi-parameter typeclass (`Convertible T U`), higher-kinded types, natural transformations, Kleisli composition, Codensity monad, Validation (accumulating errors), Reader monad, State monad, Writer monad, bounded quantification (`<T: Num>`), rank-2 polymorphism, variadic functions (`...Str`), row polymorphism (`r: Row`), `ref()` narrowing, `isa` narrowing, early return narrowing, `declare`, `Never` (bottom type), nested effect handlers, algebraic effects with handlers, protocol-driven effects, and structured logging.

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
  FP/                   # Functional abstractions
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
    Summary.pm          #   Closing summary (new features demo)
    Classify.pm         #   Typeclass constraint patterns
```

## Known Type Limitations

Both static analysis (`typist-check`) and runtime CHECK-phase (`use Typist`)
pass with **0 diagnostics** and **0 `@typist-ignore` suppressions**.
5 named functions remain unannotated due to structural limitations of
`:sig()`.

### Unannotated Functions (5)

| Function | Reason |
|---|---|
| `Store::*_handler` (4) | Returns `+{...}` HashRef — no HashRef type in `:sig()` |
| `Display::logger_handler` | Same — returns handler HashRef |

### Resolved Upstream Issues

The following limitations were present in earlier typist versions and are now resolved:

- **Constraint conjunction** (`+` syntax): `<T: Printable + Ord>` compound constraints now work in `:sig()` (`Classify::display_sorted`)
- **Struct runtime inference**: `Inference::infer_value` recognizes blessed structs by their nominal type
- **Recursive type alias inference**: `:sig(CategoryTree)` and `:sig(Json)` variable annotations now work with literal initializers
- **Record <: HashRef subtyping**: hash literal records are now recognized as subtypes of `HashRef[Str, V]`

### Remaining Upstream Issues

#### Multi-parameter typeclass: second parameter inference

Multi-parameter typeclass dispatch (e.g., `Convertible[Product, Str]`)
requires both type parameters at the call site. The second parameter `U`
cannot be inferred from a single argument — analogous to Haskell's need
for functional dependencies or type applications.

| | |
|---|---|
| **Ideal** | `Convertible::convert($product)` dispatching with `U = Str` |
| **Workaround** | Concrete wrappers `convert_product`/`convert_order` (`Classify.pm`) |

### Tuple Types

`State S A` and `Writer W A` use `Tuple[A, S]` / `Tuple[A, ArrayRef[W]]`
to thread state/log alongside values. `price_breakdown` returns
`Tuple[Int, Int, Int]`.

Array literals `[...]` are now inferred as `Tuple[T, ...]` when the element
types are heterogeneous, making plain arrayrefs a natural encoding for
fixed-size tuples.

Reader (`Reader E A = E -> A`) is a plain function type and requires no
tuple encoding.
