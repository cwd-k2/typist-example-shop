package Shop::Feature::Classify;
use v5.40;
use Typist 'Str';
use Shop::Types;

# ═══════════════════════════════════════════════════
#  Classify — Typeclass constraint patterns
#
#  Demonstrates:
#    typeclass constraint on generic (Printable)
#    superclass hierarchy exercise   (Ord → Eq)
#    multi-parameter typeclass       (Convertible)
# ═══════════════════════════════════════════════════

# ── Typeclass constraint on generic ──────────

sub show_all :sig(<T: Printable>(ArrayRef[T], Str) -> Str) ($items, $sep) {
    join($sep, map { Printable::display($_) } @$items);
}

# ── Ord constraint (superclass: Eq) ──────────

sub sort_by :sig(<T: Ord>(ArrayRef[T]) -> ArrayRef[T]) ($items) {
    [sort { Ord::compare($a, $b) } @$items];
}

sub max_by :sig(<T: Ord>(ArrayRef[T]) -> Option[T]) ($items) {
    return None() unless @$items;
    my $best = $items->[0];
    for my $x (@$items[1 .. $#$items]) {
        $best = $x if Ord::compare($x, $best) > 0;
    }
    Some($best);
}

# ── Compound constraint: Printable + Ord ─────

sub display_sorted :sig(<T: Printable + Ord>(ArrayRef[T]) -> Str) ($items) {
    my $sorted = [sort { Ord::compare($a, $b) } @$items];
    join(", ", map { Printable::display($_) } @$sorted);
}

# ── Multi-param typeclass: concrete conversion ──
#
# Convertible[T, U] dispatch requires both type parameters at
# the call site; the second parameter (U) cannot be inferred
# from a single argument.  Concrete wrappers call through the
# typeclass dispatch, fixing U = Str.

sub convert_product :sig((Product) -> Str) ($p) {
    $p->name . " (\$" . $p->price . ")";
}

sub convert_order :sig((Order) -> Str) ($o) {
    "Order #" . $o->id->base . " total=\$" . $o->total;
}

1;
