# typist-example-shop

A shop application demonstrating [Typist](https://github.com/cwd-k2/typist) — a static type system for Perl 5.

Features exercised: newtypes, structs, ADTs, parametric ADTs (including `Pair[A, B]` for tuple encoding), GADTs, enums, literal unions, optional fields, union types, recursive types, type classes (Functor, Foldable, Monad, Applicative, Traversable), higher-kinded types, natural transformations, Kleisli composition, Codensity monad, Validation (accumulating errors), Reader monad, State monad, Writer monad, rank-2 polymorphism, algebraic effects with handlers, protocol-driven effects, and structured logging.

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

Both checking layers — static (`typist-check`) and runtime CHECK-phase
(`use Typist`) — pass with **0 diagnostics**. 20 call sites use
`# @typist-ignore` to suppress static diagnostics that arise from inference
limitations rather than actual type errors.

### match Implicit Return → Result[Any] (5 sites)

When a `match` expression returns `Ok(...)` in one branch and `Err(...)` in
another, the static checker infers `Result[Any]` instead of the declared
concrete `Result[T]`. Affects `upgrade_to_premium`, `confirm_order`,
`fulfill_order`, `cancel_order`, and `refund_payment`.

### Functor::fmap → F[Any] (3 sites)

Typeclass dispatch through `Functor::fmap` returns the parametric `F[Any]`
rather than the concrete `ArrayRef[Int]`. Downstream consumers like
`fold_sum` and `cat_results` then report a type mismatch.

### Array Literal Inference (5 sites)

Array literals `[map { ... } @$arr]` and spread expressions
`[@{$arr}, $item]` / `[@$log, @$log2]` are inferred as `ArrayRef[Any]`.
Affects `traverse_result`, `traverse_option`, `filter_map`, `add_to_cart`,
and `writer_bind`.

### Curried Closure Types (4 sites)

Higher-order functions that build curried closures
(`sub ($a) { sub ($b) { ... } }`) produce `Result[B]` or `Validation[E, B]`
where the checker expects `Result[(A)->B]` or `Validation[E, (A)->B]`.
Affects `lift_a2_result`, `validation_lift_a2`, and `validation_lift_a3`.

### Other (3 sites)

- `cat_results` returns `ArrayRef[A]` (parametric) vs declared `ArrayRef[Order]`
- `option_or` returns `Quantity` (from fmap context) vs declared `Bool`
- Ternary chain widens literal union `0|5|10|15|20` to `Int`

### Unannotated Core Functions

**Codensity**: `unit` and `bind` are parametric in the functor `F`, which
cannot be expressed in `:sig()` — HKT type variables (`F: * -> *`) are only
available inside `typeclass` definitions. The specializations
(`lift_list`/`lower_list`, `lift_option`/`lower_option`) carry full `:sig()`
annotations using `forall R` for the continuation parameter.

### Pair[A, B] Tuple Type

`State S A` and `Writer W A` use a pair encoding to thread state/log alongside
values. The `Pair[A, B]` datatype (defined in `Shop::Types`) replaces the
original anonymous `[$a, $s]` ArrayRef encoding, enabling full `:sig()`
annotations on all State and Writer operations. Reader (`Reader E A = E -> A`)
is a plain function type and requires no tuple encoding.
