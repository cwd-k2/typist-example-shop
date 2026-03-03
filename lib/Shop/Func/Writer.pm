package Shop::Func::Writer;
use v5.40;
use Typist 'Int', 'Str';
use Shop::Types;

use Exporter 'import';
our @EXPORT = ();

# ═══════════════════════════════════════════════════
#  Writer — Audit trail monad
#
#  Writer W A  ~=  (A, ArrayRef[W])
#
#  Accumulate a log alongside a computation.
#  `tell` appends to the log, `listen` exposes it,
#  `censor` transforms it.
#
#  Contrast with Logger effect: Logger is an
#  algebraic effect handled at runtime; Writer is
#  a pure value-level monad with no side effects.
# ═══════════════════════════════════════════════════

# Representation: [$value, $log]  where $log is ArrayRef[Str]
#
# Core combinators remain untyped: the pair encoding
# [$value, ArrayRef[Str]] is parametric over $value's type,
# and Typist's :sig() cannot express existential pairs.
# Shop-specific operations below are concretely typed.

# ── Core Operations ───────────────────────────

# writer : (A, ArrayRef[Str]) -> Writer Str A
sub writer ($a, $log) { [$a, $log] }

# run_writer : Writer Str A -> (A, ArrayRef[Str])
sub run_writer ($w) { ($w->[0], $w->[1]) }

# writer_pure : A -> Writer Str A
sub writer_pure ($a) { [$a, []] }

# writer_fmap : Writer Str A -> (A -> B) -> Writer Str B
sub writer_fmap ($w, $f) {
    [$f->($w->[0]), $w->[1]];
}

# writer_bind : Writer Str A -> (A -> Writer Str B) -> Writer Str B
sub writer_bind ($w, $f) {
    my $next = $f->($w->[0]);
    [$next->[0], [@{$w->[1]}, @{$next->[1]}]];
}

# tell : Str -> Writer Str ()
sub tell ($msg) { [undef, [$msg]] }

# listen : Writer Str A -> Writer Str (A, ArrayRef[Str])
sub listen ($w) {
    [[$w->[0], $w->[1]], $w->[1]];
}

# censor : (ArrayRef[Str] -> ArrayRef[Str]) -> Writer Str A -> Writer Str A
sub censor ($f, $w) {
    [$w->[0], $f->($w->[1])];
}

# ── Shop-specific Writer operations ──────────

# price_line : Str -> Price -> Writer Str Price
sub price_line ($label, $price) {
    writer($price, ["  $label: \$$price"]);
}

# subtotal_with_audit : ArrayRef[OrderItem] -> Writer Str Price
sub subtotal_with_audit ($items) {
    my $log :sig(ArrayRef[Str]) = [];
    my $total :sig(Int) = 0;
    for my $item (@$items) {
        my $line = $item->unit_price * $item->quantity;
        $total += $line;
        push @$log, "  " . $item->product_id->base . " x" . $item->quantity . " @ \$" . $item->unit_price . " = \$$line";
    }
    writer($total, $log);
}

# discount_with_audit : Price -> DiscountPct -> Writer Str Price
sub discount_with_audit ($subtotal, $pct) {
    my $discounted = int($subtotal * (100 - $pct) / 100);
    my $saved      = $subtotal - $discounted;
    writer($discounted, ["  Discount $pct%: -\$$saved", "  After discount: \$$discounted"]);
}

1;
