# typist-example-shop

A shop application demonstrating [Typist](https://github.com/cwd-k2/typist) — a static type system for Perl 5.

Features exercised: newtypes, structs, ADTs, parametric ADTs, GADTs, enums, literal unions, optional fields, union types, recursive types, type classes (Functor, Foldable, Monad, Applicative, Traversable), higher-kinded types, natural transformations, Kleisli composition, Codensity monad, Validation (accumulating errors), Reader monad, State monad, Writer monad, rank-2 polymorphism, algebraic effects with handlers, protocol-driven effects, and structured logging.

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

The static checker (`mise run verify`) passes with 0 diagnostics. The runtime
CHECK-phase checker (`use Typist`) reports some diagnostics that stem from
Typist's current type inference limitations. These are suppressed at runtime
via `TYPIST_CHECK_QUIET=1`.

### IO Effect

`IO` is a standard effect label registered by Typist's Prelude. The static
checker (`typist-check`) recognizes it automatically. However the runtime
CHECK-phase checker resolves effects within the package's own registry and
does not see Prelude labels. `Shop::Types` therefore re-declares
`effect IO => +{}` to satisfy both checkers.

### ArrayRef Literal Inference

Array literals `[...]` are inferred as `ArrayRef[Any]` by the runtime checker.
Even with explicit `:sig(ArrayRef[OrderItem])` annotations on variables,
the literal's element types are not propagated. This affects `script/app.pl`
where `OrderItem` arrays are constructed inline.

### Parametric Type Variable Resolution

Functions with parametric signatures (e.g., `<A>(Option[A]) -> A`) return
the type variable `A` rather than the concrete type at the call site. This
causes mismatches like `Option[T][Product]` vs `Option[A]` or `ArrayRef[A]`
vs `ArrayRef[Order]`. Affected call sites use `@typist-ignore` comments
in the static checker.

### Curried Function Types

Higher-order functions that return curried closures (e.g., `sub ($a) { sub ($b) { ... } }`)
cannot be typed within `:sig()` annotations because Typist does not support
`CodeRef` in `:sig()` — only in typeclass definition strings. Functions like
`validation_lift_a2`, `lift_a2_result`, and the monadic core operations of
Reader/State/Writer are affected. Their `:sig()` annotations describe the
outer function but `@typist-ignore` suppresses diagnostics on the inner
curried application.
