package Shop::HKT;
use v5.40;
use Typist;
use Shop::Types;

use Exporter 'import';
our @EXPORT = ();

# ═══════════════════════════════════════════════════
#  HKT — Higher-Kinded Type Classes
#
#  F: * -> * denotes a type constructor — a type
#  that takes a type and yields a type.
#
#  Functor  : structure-preserving map
#  Foldable : collapse structure to a value
#  Monad    : sequenced computation with context
# ═══════════════════════════════════════════════════

BEGIN {
    # ── Functor ───────────────────────────────
    #
    # fmap : (F[A], (A) -> B) -> F[B]
    #
    # Lift a function into a structure.
    # Laws:
    #   fmap(x, id)          ≡ x
    #   fmap(fmap(x, g), f)  ≡ fmap(x, f ∘ g)

    typeclass Functor => 'F: * -> *', +{
        fmap => 'CodeRef[F[A], CodeRef[A -> B] -> F[B]]',
    };

    instance Functor => 'ArrayRef', +{
        fmap => sub ($arr, $f) { [map { $f->($_) } @$arr] },
    };

    # ── Foldable ──────────────────────────────
    #
    # foldr : (F[A], B, (A, B) -> B) -> B
    #
    # Right fold: tear down a structure from the right.

    typeclass Foldable => 'F: * -> *', +{
        foldr => 'CodeRef[F[A], B, CodeRef[A, B -> B] -> B]',
    };

    instance Foldable => 'ArrayRef', +{
        foldr => sub ($arr, $init, $f) {
            my $acc = $init;
            for my $item (reverse @$arr) {
                $acc = $f->($item, $acc);
            }
            $acc;
        },
    };

    # ── Monad ─────────────────────────────────
    #
    # bind : (F[A], (A) -> F[B]) -> F[B]
    #
    # Chain computations that produce wrapped results.
    # Laws:
    #   bind(return(a), f)          ≡ f(a)
    #   bind(m, return)             ≡ m
    #   bind(bind(m, f), g)         ≡ bind(m, \a -> bind(f(a), g))

    typeclass Monad => 'F: * -> *', +{
        bind => 'CodeRef[F[A], CodeRef[A -> F[B]] -> F[B]]',
    };

    instance Monad => 'ArrayRef', +{
        bind => sub ($arr, $f) {
            my @result;
            for my $item (@$arr) {
                push @result, @{ $f->($item) };
            }
            \@result;
        },
    };

    # Bare namespace aliases for ergonomic use
    no strict 'refs';
    *{"Functor::fmap"}   = \&Shop::HKT::Functor::fmap;
    *{"Foldable::foldr"} = \&Shop::HKT::Foldable::foldr;
    *{"Monad::bind"}     = \&Shop::HKT::Monad::bind;
}

# Canonical dispatch aliases
my $fmap  = \&Functor::fmap;
my $foldr = \&Foldable::foldr;
my $bind  = \&Monad::bind;

# ── Functor / Foldable Derived ────────────────

sub fmap2 ($container, $f, $g) {
    $fmap->($fmap->($container, $g), $f);
}

sub map_reduce ($container, $map_fn, $init, $reduce_fn) {
    $foldr->($fmap->($container, $map_fn), $init, $reduce_fn);
}

sub fold_sum ($container) {
    $foldr->($container, 0, sub ($x, $acc) { $x + $acc });
}

sub fold_count ($container, $pred) {
    $foldr->($container, 0, sub ($x, $acc) { $pred->($x) ? $acc + 1 : $acc });
}

sub fold_any ($container, $pred) {
    $foldr->($container, 0, sub ($x, $acc) { $pred->($x) || $acc });
}

sub fold_all ($container, $pred) {
    $foldr->($container, 1, sub ($x, $acc) { $pred->($x) && $acc });
}

# ── Monad Derived ─────────────────────────────

sub mjoin ($nested) {
    $bind->($nested, sub ($x) { $x });
}

sub kleisli ($f, $g) {
    sub ($x) { $bind->($f->($x), $g) };
}

# ── Natural Transformations ───────────────────
#
# A natural transformation  η : F ~> G  converts
# F[A] → G[A] for all A, preserving structure.
# These are the "adapters" between containers.

sub head_option ($arr) {
    @$arr ? Some($arr->[0]) : None();
}

sub option_to_list ($opt) {
    match $opt,
        Some => sub ($v) { [$v] },
        None => sub ()   { [] };
}

# ── Option Monad ──────────────────────────────
#
# Option[T] is an ADT (Some(T) | None) — its runtime
# representation doesn't go through type class dispatch.
# We implement the monadic interface explicitly, showing
# the same pattern Functor/Monad follow internally.

sub option_fmap ($opt, $f) {
    match $opt,
        Some => sub ($v) { Some($f->($v)) },
        None => sub ()   { None() };
}

sub option_bind ($opt, $f) {
    match $opt,
        Some => sub ($v) { $f->($v) },
        None => sub ()   { None() };
}

sub option_or ($opt, $default) {
    match $opt,
        Some => sub ($v) { $v },
        None => sub ()   { $default };
}

sub show_option ($opt) {
    match $opt,
        Some => sub ($v) { "Some($v)" },
        None => sub ()   { "None" };
}

1;
