package Shop::FP::HKT;
use v5.40;
use Typist 'Int', 'Str';
use Shop::Types;

use Exporter 'import';
our @EXPORT = ();

# ═══════════════════════════════════════════════════
#  HKT — Higher-Kinded Type Classes & Operations
#
#  F: * -> * denotes a type constructor — a type
#  that takes a type and yields a type.
#
#  Functor     : structure-preserving map
#  Foldable    : collapse structure to a value
#  Monad       : sequenced computation with context
#  Applicative : parallel application
#  Traversable : effectful structure traversal
# ═══════════════════════════════════════════════════

BEGIN {
    # ── Functor ───────────────────────────────
    #
    # fmap : (F[A], (A) -> B) -> F[B]
    #
    # Lift a function into a structure.
    # Laws:
    #   fmap(x, id)          ≡ x
    #   fmap(fmap(x, g), f)  ≡ fmap(x, f . g)

    typeclass Functor => 'F: * -> *', +{
        fmap => '(F[A], CodeRef[A -> B]) -> F[B]',
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
        foldr => '(F[A], B, CodeRef[A, B -> B]) -> B',
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
        bind => '(F[A], CodeRef[A -> F[B]]) -> F[B]',
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

    # ── Applicative ──────────────────────────
    #
    # pure : (A) -> F[A]
    # ap   : (F[(A) -> B], F[A]) -> F[B]
    #
    # Lift values and apply wrapped functions.
    # Weaker than Monad — enables parallel/static analysis.

    typeclass Applicative => 'F: * -> *', +{
        pure => '(A) -> F[A]',
        ap   => '(F[CodeRef[A -> B]], F[A]) -> F[B]',
    };

    instance Applicative => 'ArrayRef', +{
        pure => sub ($a) { [$a] },
        ap   => sub ($fs, $xs) {
            my @result;
            for my $f (@$fs) {
                for my $x (@$xs) {
                    push @result, $f->($x);
                }
            }
            \@result;
        },
    };

    # ── Traversable ──────────────────────────
    #
    # traverse : (T[A], (A) -> F[B]) -> F[T[B]]
    #
    # Map each element to an applicative action,
    # then collect the results.

    typeclass Traversable => 'T: * -> *', +{
        traverse => '(T[A], CodeRef[A -> F[B]]) -> F[T[B]]',
    };

    # Bare namespace aliases for ergonomic use
    no strict 'refs';
    *{"Functor::fmap"}           = \&Shop::FP::HKT::Functor::fmap;
    *{"Foldable::foldr"}         = \&Shop::FP::HKT::Foldable::foldr;
    *{"Monad::bind"}             = \&Shop::FP::HKT::Monad::bind;
    *{"Applicative::pure"}       = \&Shop::FP::HKT::Applicative::pure;
    *{"Applicative::ap"}         = \&Shop::FP::HKT::Applicative::ap;
    *{"Traversable::traverse"}   = \&Shop::FP::HKT::Traversable::traverse;
}

# Canonical dispatch aliases
my $fmap  = \&Functor::fmap;
my $foldr = \&Foldable::foldr;
my $bind  = \&Monad::bind;

# ── Functor / Foldable Derived ────────────────

sub fmap2 :sig(<A, B, C>(ArrayRef[A], (B) -> C, (A) -> B) -> ArrayRef[C]) ($container, $f, $g) {
    $fmap->($fmap->($container, $g), $f);
}

sub map_reduce :sig(<A, B, C>(ArrayRef[A], (A) -> B, C, (B, C) -> C) -> C) ($container, $map_fn, $init, $reduce_fn) {
    $foldr->($fmap->($container, $map_fn), $init, $reduce_fn);
}

sub fold_sum :sig((ArrayRef[Int]) -> Int) ($container) {
    $foldr->($container, 0, sub ($x, $acc) { $x + $acc });
}

sub fold_count :sig(<A>(ArrayRef[A], (A) -> Bool) -> Int) ($container, $pred) {
    $foldr->($container, 0, sub ($x, $acc) { $pred->($x) ? $acc + 1 : $acc });
}

sub fold_any :sig(<A>(ArrayRef[A], (A) -> Bool) -> Bool) ($container, $pred) {
    my $init :sig(Bool) = 0;
    $foldr->($container, $init, sub ($x, $acc) { $pred->($x) || $acc });
}

sub fold_all :sig(<A>(ArrayRef[A], (A) -> Bool) -> Bool) ($container, $pred) {
    my $init :sig(Bool) = 1;
    $foldr->($container, $init, sub ($x, $acc) { $pred->($x) && $acc });
}

# ── Monad Derived ─────────────────────────────

sub mjoin :sig(<A>(ArrayRef[ArrayRef[A]]) -> ArrayRef[A]) ($nested) {
    $bind->($nested, sub ($x) { $x });
}

sub kleisli :sig(<A, B, C>((A) -> ArrayRef[B], (B) -> ArrayRef[C]) -> (A) -> ArrayRef[C]) ($f, $g) {
    sub ($x) { $bind->($f->($x), $g) };
}

# ── Natural Transformations ───────────────────
#
# A natural transformation  eta : F ~> G  converts
# F[A] -> G[A] for all A, preserving structure.

sub head_option :sig(<A>(ArrayRef[A]) -> Option[A]) ($arr) {
    @$arr ? Some($arr->[0]) : None();
}

sub option_to_list :sig(<A>(Option[A]) -> ArrayRef[A]) ($opt) {
    match $opt,
        Some => sub ($v) { [$v] },
        None => sub ()   { [] };
}

# ── Option Operations ─────────────────────────
#
# Option[T] is an ADT (Some(T) | None) — its runtime
# representation doesn't go through type class dispatch.

sub option_pure :sig(<A>(A) -> Option[A]) ($v) {
    Some($v);
}

sub option_fmap :sig(<A, B>(Option[A], (A) -> B) -> Option[B]) ($opt, $f) {
    match $opt,
        Some => sub ($v) { Some($f->($v)) },
        None => sub ()   { None() };
}

sub option_bind :sig(<A, B>(Option[A], (A) -> Option[B]) -> Option[B]) ($opt, $f) {
    match $opt,
        Some => sub ($v) { $f->($v) },
        None => sub ()   { None() };
}

sub option_ap :sig(<A, B>(Option[(A) -> B], Option[A]) -> Option[B]) ($opt_f, $opt_a) {
    match $opt_f,
        Some => sub ($f) { option_fmap($opt_a, $f) },
        None => sub ()   { None() };
}

sub option_or :sig(<A>(Option[A], A) -> A) ($opt, $default) {
    match $opt,
        Some => sub ($v) { $v },
        None => sub ()   { $default };
}

sub show_option :sig(<A>(Option[A]) -> Str) ($opt) {
    match $opt,
        Some => sub ($v) { "Some($v)" },
        None => sub ()   { "None" };
}

# ── Result Operations ─────────────────────────
#
# Result[T] = Ok(T) | Err(Str)

sub result_pure :sig(<A>(A) -> Result[A]) ($v) {
    Ok($v);
}

sub result_fmap :sig(<A, B>(Result[A], (A) -> B) -> Result[B]) ($r, $f) {
    match $r,
        Ok  => sub ($v) { Ok($f->($v)) },
        Err => sub ($e) { Err($e) };
}

sub result_bind :sig(<A, B>(Result[A], (A) -> Result[B]) -> Result[B]) ($r, $f) {
    match $r,
        Ok  => sub ($v) { $f->($v) },
        Err => sub ($e) { Err($e) };
}

sub result_ap :sig(<A, B>(Result[(A) -> B], Result[A]) -> Result[B]) ($rf, $ra) {
    match $rf,
        Ok  => sub ($f) { result_fmap($ra, $f) },
        Err => sub ($e) { Err($e) };
}

sub result_or :sig(<A>(Result[A], A) -> A) ($r, $default) {
    match $r,
        Ok  => sub ($v) { $v },
        Err => sub ($e) { $default };
}

sub show_result :sig(<A>(Result[A]) -> Str) ($r) {
    match $r,
        Ok  => sub ($v) { "Ok($v)" },
        Err => sub ($e) { "Err($e)" };
}

# ── Traversable: sequence / traverse ──────────
#
# sequence : [Result[A]] -> Result[[A]]
# traverse : [A] -> (A -> Result[B]) -> Result[[B]]

sub sequence_result :sig(<A>(ArrayRef[Result[A]]) -> Result[ArrayRef[A]]) ($results) {
    my @acc;
    for my $r (@$results) {
        my $err;
        match $r,
            Ok  => sub ($v) { push @acc, $v },
            Err => sub ($e) { $err = $e };
        return Err($err) if defined $err;
    }
    Ok(\@acc);
}

sub sequence_option :sig(<A>(ArrayRef[Option[A]]) -> Option[ArrayRef[A]]) ($options) {
    my @acc;
    for my $o (@$options) {
        my $none = 0;
        match $o,
            Some => sub ($v) { push @acc, $v },
            None => sub ()   { $none = 1 };
        return None() if $none;
    }
    Some(\@acc);
}

sub traverse_result :sig(<A, B>(ArrayRef[A], (A) -> Result[B]) -> Result[ArrayRef[B]]) ($items, $f) {
    sequence_result([map { $f->($_) } @$items]);
}

sub traverse_option :sig(<A, B>(ArrayRef[A], (A) -> Option[B]) -> Option[ArrayRef[B]]) ($items, $f) {
    sequence_option([map { $f->($_) } @$items]);
}

# ── Combinators ───────────────────────────────

sub filter :sig(<A>(ArrayRef[A], (A) -> Bool) -> ArrayRef[A]) ($arr, $pred) {
    [grep { $pred->($_) } @$arr];
}

sub cat_results :sig(<A>(ArrayRef[Result[A]]) -> ArrayRef[A]) ($results) {
    my @ok;
    for my $r (@$results) {
        match $r,
            Ok  => sub ($v) { push @ok, $v },
            Err => sub ($e) { };
    }
    \@ok;
}

sub cat_options :sig(<A>(ArrayRef[Option[A]]) -> ArrayRef[A]) ($options) {
    my @vals;
    for my $o (@$options) {
        match $o,
            Some => sub ($v) { push @vals, $v },
            None => sub ()   { };
    }
    \@vals;
}

sub filter_map :sig(<A, B>(ArrayRef[A], (A) -> Option[B]) -> ArrayRef[B]) ($arr, $f) {
    cat_options([map { $f->($_) } @$arr]);
}

sub lift_a2_result :sig(<A, B, C>((A, B) -> C, Result[A], Result[B]) -> Result[C]) ($f, $ra, $rb) {
    result_ap(result_fmap($ra, sub ($a) { sub ($b) { $f->($a, $b) } }), $rb);
}

1;
