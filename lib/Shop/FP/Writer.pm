package Shop::FP::Writer;
use v5.40;
use Typist 'Int', 'Str';
use Shop::Types;

use Exporter 'import';
our @EXPORT = ();

# ═══════════════════════════════════════════════════
#  Writer — Audit trail monad
#
#  Writer W A  ~=  Tuple[A, ArrayRef[W]]
#
#  Accumulate a log alongside a computation.
#  `tell` appends to the log, `listen` exposes it,
#  `censor` transforms it.
#
#  Contrast with Logger effect: Logger is an
#  algebraic effect handled at runtime; Writer is
#  a pure value-level monad with no side effects.
# ═══════════════════════════════════════════════════

# W is specialized to Str throughout this module.

# ── Core Operations ───────────────────────────

# writer : (A, ArrayRef[Str]) -> Writer Str A
sub writer :sig(<A>(A, ArrayRef[Str]) -> Tuple[A, ArrayRef[Str]]) ($a, $log) {
    [$a, $log];
}

# run_writer : Writer Str A -> Tuple[A, ArrayRef[Str]]
sub run_writer :sig(<A>(Tuple[A, ArrayRef[Str]]) -> Tuple[A, ArrayRef[Str]]) ($w) { $w }

# writer_pure : A -> Writer Str A
sub writer_pure :sig(<A>(A) -> Tuple[A, ArrayRef[Str]]) ($a) {
    my $empty :sig(ArrayRef[Str]) = [];
    [$a, $empty];
}

# writer_fmap : Writer Str A -> (A -> B) -> Writer Str B
sub writer_fmap :sig(<A, B>(Tuple[A, ArrayRef[Str]], (A) -> B) -> Tuple[B, ArrayRef[Str]]) ($w, $f) {
    my ($a, $log) = @$w;
    [$f->($a), $log];
}

# writer_bind : Writer Str A -> (A -> Writer Str B) -> Writer Str B
sub writer_bind :sig(<A, B>(Tuple[A, ArrayRef[Str]], (A) -> Tuple[B, ArrayRef[Str]]) -> Tuple[B, ArrayRef[Str]]) ($w, $f) {
    my ($a, $log) = @$w;
    my ($b, $log2) = @{$f->($a)};
    [$b, [@$log, @$log2]];
}

# tell : Str -> Writer Str Str
sub tell :sig((Str) -> Tuple[Str, ArrayRef[Str]]) ($msg) {
    ["", [$msg]];
}

# listen : Writer Str A -> Writer Str Tuple[A, ArrayRef[Str]]
sub listen :sig(<A>(Tuple[A, ArrayRef[Str]]) -> Tuple[Tuple[A, ArrayRef[Str]], ArrayRef[Str]]) ($w) {
    my ($a, $log) = @$w;
    [[$a, $log], $log];
}

# censor : (ArrayRef[Str] -> ArrayRef[Str]) -> Writer Str A -> Writer Str A
sub censor :sig(<A>((ArrayRef[Str]) -> ArrayRef[Str], Tuple[A, ArrayRef[Str]]) -> Tuple[A, ArrayRef[Str]]) ($f, $w) {
    my ($a, $log) = @$w;
    [$a, $f->($log)];
}

# ── Shop-specific Writer operations ──────────

# price_line : Str -> Price -> Writer Str Price
sub price_line :sig((Str, Price) -> Tuple[Price, ArrayRef[Str]]) ($label, $price) {
    [$price, ["  $label: \$$price"]];
}

# subtotal_with_audit : ArrayRef[OrderItem] -> Writer Str Price
sub subtotal_with_audit :sig((ArrayRef[OrderItem]) -> Tuple[Price, ArrayRef[Str]]) ($items) {
    my $log :sig(ArrayRef[Str]) = [];
    my $total :sig(Int) = 0;
    for my $item (@$items) {
        my $line = $item->unit_price * $item->quantity;
        $total += $line;
        push @$log, "  " . ProductId::coerce($item->product_id) . " x" . $item->quantity . " @ \$" . $item->unit_price . " = \$$line";
    }
    [$total, $log];
}

# discount_with_audit : Price -> DiscountPct -> Writer Str Price
sub discount_with_audit :sig((Price, DiscountPct) -> Tuple[Price, ArrayRef[Str]]) ($subtotal, $pct) {
    my $discounted = int($subtotal * (100 - $pct) / 100);
    my $saved      = $subtotal - $discounted;
    [$discounted, ["  Discount $pct%: -\$$saved", "  After discount: \$$discounted"]];
}

1;
