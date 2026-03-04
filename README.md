# typist-example-shop

A shop application demonstrating [Typist](https://github.com/cwd-k2/typist) — a static type system for Perl 5.

Features exercised: newtypes, structs, generic structs (`ReportNode[T]`), bounded generic structs (`Range[T: Num]`), ADTs, parametric ADTs (including `Pair[A, B]` for tuple encoding), GADTs, enums, literal unions, optional fields, union types, recursive types, record types, intersection types, triple tuples (`Triple[A, B, C]`), type classes (Functor, Foldable, Monad, Applicative, Traversable), higher-kinded types, natural transformations, Kleisli composition, Codensity monad, Validation (accumulating errors), Reader monad, State monad, Writer monad, bounded quantification (`<T: Num>`), rank-2 polymorphism, variadic functions (`...Str`), row polymorphism (`r: Row`), `ref()` narrowing, algebraic effects with handlers, protocol-driven effects, and structured logging.

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
```

## Known Type Limitations

Static analysis (`typist-check`) passes with **0 diagnostics** and
**0 `@typist-ignore` suppressions**. Runtime CHECK-phase (`use Typist`)
reports **3 diagnostics** — all from the same root cause documented below.
5 named functions remain unannotated due to structural limitations of
`:sig()`.

### Unannotated Functions (5)

| Function | Reason |
|---|---|
| `Store::*_handler` (4) | Returns `+{...}` HashRef — no HashRef type in `:sig()` |
| `Display::logger_handler` | Same — returns handler HashRef |

### Pair[A, B] / Triple[A, B, C] Tuple Encoding

`State S A` and `Writer W A` use `Pair[A, B]` to thread state/log alongside
values. `Triple[A, B, C]` extends this pattern for three-element tuples
(e.g. `price_breakdown` returns `Triple[Int, Int, Int]`).

Both datatypes exist because the built-in `Tuple[T, ...]` type has a static
inference limitation: array literals `[...]` are always inferred as
`ArrayRef[T]`, and there is no coercion path from `ArrayRef` to `Tuple` in
`typist-check`. ADT constructors (`Pair(a, b)`, `Triple(a, b, c)`) are
fully tracked through the static checker, making them a reliable alternative.

Reader (`Reader E A = E -> A`) is a plain function type and requires no
tuple encoding.

### Runtime CHECK-phase: Generic Struct Arguments (3 diagnostics)

The runtime checker cannot unify a type-variable parameter `T` in a generic
struct with its concrete instantiation when the struct appears as a function
argument. For example, `format_report` expects `ReportNode[T]` but receives
`ReportNode[Int]`; `in_range` expects `Range[T]` but receives `Range[Int]`.

| Call site | Signature | Runtime sees |
|---|---|---|
| `format_report($report, 0)` | `<T>(ReportNode[T], Int) -> Str` | `ReportNode[T]` vs `ReportNode[Int]` |
| `in_range(1500, $range)` | `<T: Num>(T, Range[T]) -> Bool` | `Range[T]` vs `Range[Int]` |
| `in_range(8000, $range)` | (same) | (same) |

Static analysis (`typist-check`) handles these correctly; only the runtime
CHECK-phase lacks the unification step for parametric struct arguments.

### Static Inference Workarounds

The following patterns required alternative formulations to satisfy the
static checker.

**Ternary on `Bool` → runtime infers condition type, not branch type**

`in_range(...) ? "yes" : "no"` is typed as `Bool` (the condition type)
rather than `Str` (the branch type) by the runtime CHECK-phase.
Workaround: use `if/else` blocks.

```perl
# NG: runtime sees Bool, not Str
Shop::Infra::Display::kv("in range?", in_range($v, $r) ? "yes" : "no");

# OK: each branch is independently typed as Str
if (in_range($v, $r)) { Shop::Infra::Display::kv("in range?", "yes") }
else                   { Shop::Infra::Display::kv("in range?", "no")  }
```

**Comparison chains → `Num`, not `Bool`**

`$a >= $b && $a <= $c` is inferred as `Num` by the static checker.
Workaround: wrap in `if (...) { 1 } else { 0 }`.

```perl
# NG: static checker infers Num
sub in_range :sig(... -> Bool) ($val, $range) {
    $val >= $range->lo && $val <= $range->hi;
}

# OK: each branch is a literal Int, coerced to Bool
sub in_range :sig(... -> Bool) ($val, $range) {
    if ($val >= $range->lo && $val <= $range->hi) { 1 } else { 0 }
}
```

**Arithmetic on typedef aliases → `Num`, not the alias**

`$subtotal - $final` where both are `Price` (typedef for `Int`) is inferred
as `Num`. Workaround: annotate intermediate variables with `:sig(Int)`.

```perl
# NG: Triple[Price, Num, Price]
my $discount = $subtotal - $final;

# OK: Triple[Int, Int, Int]
my $discount :sig(Int) = $subtotal - $final;
```

**Array literals → `ArrayRef[T]`, not `Tuple[T, ...]`**

Documented above under "Pair / Triple Tuple Encoding". The static checker
always infers `[...]` as `ArrayRef[T]` with no coercion to `Tuple`.
Workaround: use ADT constructors (`Pair`, `Triple`).
