package Shop::Feature::Classify;
use v5.40;
use Typist;
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

# ── Multi-param typeclass: direct dispatch ───
#
# Convertible[T, U] now supports prefix matching: convert(T) -> U
# resolves to the unique instance whose first parameter matches T.

sub convert_product :sig((Product) -> Str) ($p) {
    Convertible::convert($p);
}

sub convert_order :sig((Order) -> Str) ($o) {
    Convertible::convert($o);
}

# ── Struct Printable instance dispatch ─────

sub display_product :sig((Product) -> Str) ($p) { Printable::display($p) }
sub display_customer :sig((Customer) -> Str) ($c) { Printable::display($c) }

# ── Labeled[T: Printable] — monomorphic (T=Int) ──

sub display_labeled :sig((Labeled[Int]) -> Str) ($l) {
    $l->label . " = " . Printable::display($l->value);
}

# ── Wildcard match (P1 probe) ─────────────

sub describe_payment :sig((PaymentMethod) -> Str) ($method) {
    match $method,
        Cash => sub ()       { "cash payment" },
        _    => sub (@args)  { "non-cash payment" };
}

1;
