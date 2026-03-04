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

### Typist Upstream Issues

The following workarounds are applied due to current typist limitations.

#### Constraint conjunction in bounds (`+` syntax)

The bound expression parser does not accept `+` for combining multiple
typeclass constraints on a single type variable.

| | |
|---|---|
| **Ideal** | `sub display_sorted :sig(<T: Printable + Ord>(ArrayRef[T]) -> Str)` |
| **Workaround** | Function removed; single-constraint signatures (`<T: Printable>`, `<T: Ord>`) are used instead |
| **Root cause** | `Typist::Parser` rejects `+` as an unexpected character in bound expressions |

#### Multi-parameter typeclass runtime dispatch on struct types

Runtime instance resolution for multi-parameter typeclasses cannot
dispatch on struct types. Structs are blessed hashrefs; the runtime
resolves them as `HashRef[Any]` rather than the registered struct name,
so instance lookup for e.g. `Convertible => 'Product, Str'` fails.
Additionally, the second type parameter `U` cannot be inferred from
the call site alone (analogous to Haskell's need for functional
dependencies or type applications).

| | |
|---|---|
| **Ideal** | `sub convert_all :sig(<T>(ArrayRef[T]) -> ArrayRef[Str])` calling `Convertible::convert` with runtime dispatch |
| **Workaround** | Concrete wrappers `convert_product`/`convert_order` that inline the conversion logic (`Classify.pm`). Typeclass and instance definitions are retained for static checking. |
| **Root cause** | (1) Runtime type classifier maps blessed hashrefs to `HashRef[Any]` instead of their struct name; (2) multi-param dispatch requires caller-side type application or functional dependencies to resolve output type `U` |

#### Recursive type alias inference for variable annotations

Variable annotations with recursive type aliases (`CategoryTree`,
`Json`) fail at CHECK-time when the initializer is a plain Perl literal.
The inference engine resolves the literal as `ArrayRef[Any]` or a
concrete record type and rejects the annotation.

| | |
|---|---|
| **Ideal** | `my $tree :sig(CategoryTree) = ["Electronics", ["Phones", "Tablets"], "Clothing"]` |
| **Workaround** | Omit `:sig()` annotation; the recursive typedef is still registered and available for use in function signatures |
| **Root cause** | Literal inference does not attempt to unify against recursive type alias expansions |

### Tuple Types

`State S A` and `Writer W A` use `Tuple[A, S]` / `Tuple[A, ArrayRef[W]]`
to thread state/log alongside values. `price_breakdown` returns
`Tuple[Int, Int, Int]`.

Array literals `[...]` are now inferred as `Tuple[T, ...]` when the element
types are heterogeneous, making plain arrayrefs a natural encoding for
fixed-size tuples.

Reader (`Reader E A = E -> A`) is a plain function type and requires no
tuple encoding.
