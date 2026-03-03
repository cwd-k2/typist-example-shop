package Shop::Func::Writer;
use v5.40;
use Typist 'Int', 'Str';
use Shop::Types;

use Exporter 'import';
our @EXPORT = ();

# ═══════════════════════════════════════════════════
#  Writer — Audit trail monad
#
#  Writer W A  ~=  Pair[A, ArrayRef[W]]
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
sub writer :sig(<A>(A, ArrayRef[Str]) -> Pair[A, ArrayRef[Str]]) ($a, $log) {
    Pair($a, $log);
}

# run_writer : Writer Str A -> Pair[A, ArrayRef[Str]]
sub run_writer :sig(<A>(Pair[A, ArrayRef[Str]]) -> Pair[A, ArrayRef[Str]]) ($w) { $w }

# writer_pure : A -> Writer Str A
sub writer_pure :sig(<A>(A) -> Pair[A, ArrayRef[Str]]) ($a) {
    my $empty :sig(ArrayRef[Str]) = [];
    Pair($a, $empty);
}

# writer_fmap : Writer Str A -> (A -> B) -> Writer Str B
sub writer_fmap :sig(<A, B>(Pair[A, ArrayRef[Str]], (A) -> B) -> Pair[B, ArrayRef[Str]]) ($w, $f) {
    match $w,
        Pair => sub ($a, $log) { Pair($f->($a), $log) };
}

# writer_bind : Writer Str A -> (A -> Writer Str B) -> Writer Str B
sub writer_bind :sig(<A, B>(Pair[A, ArrayRef[Str]], (A) -> Pair[B, ArrayRef[Str]]) -> Pair[B, ArrayRef[Str]]) ($w, $f) {
    match $w,
        Pair => sub ($a, $log) {
            match $f->($a),
                Pair => sub ($b, $log2) { Pair($b, [@$log, @$log2]) };
        };
}

# tell : Str -> Writer Str Str
sub tell :sig((Str) -> Pair[Str, ArrayRef[Str]]) ($msg) {
    Pair("", [$msg]);
}

# listen : Writer Str A -> Writer Str Pair[A, ArrayRef[Str]]
sub listen :sig(<A>(Pair[A, ArrayRef[Str]]) -> Pair[Pair[A, ArrayRef[Str]], ArrayRef[Str]]) ($w) {
    match $w,
        Pair => sub ($a, $log) { Pair(Pair($a, $log), $log) };
}

# censor : (ArrayRef[Str] -> ArrayRef[Str]) -> Writer Str A -> Writer Str A
sub censor :sig(<A>((ArrayRef[Str]) -> ArrayRef[Str], Pair[A, ArrayRef[Str]]) -> Pair[A, ArrayRef[Str]]) ($f, $w) {
    match $w,
        Pair => sub ($a, $log) { Pair($a, $f->($log)) };
}

# ── Shop-specific Writer operations ──────────

# price_line : Str -> Price -> Writer Str Price
sub price_line :sig((Str, Price) -> Pair[Price, ArrayRef[Str]]) ($label, $price) {
    Pair($price, ["  $label: \$$price"]);
}

# subtotal_with_audit : ArrayRef[OrderItem] -> Writer Str Price
sub subtotal_with_audit :sig((ArrayRef[OrderItem]) -> Pair[Price, ArrayRef[Str]]) ($items) {
    my $log :sig(ArrayRef[Str]) = [];
    my $total :sig(Int) = 0;
    for my $item (@$items) {
        my $line = $item->unit_price * $item->quantity;
        $total += $line;
        push @$log, "  " . $item->product_id->base . " x" . $item->quantity . " @ \$" . $item->unit_price . " = \$$line";
    }
    Pair($total, $log);
}

# discount_with_audit : Price -> DiscountPct -> Writer Str Price
sub discount_with_audit :sig((Price, DiscountPct) -> Pair[Price, ArrayRef[Str]]) ($subtotal, $pct) {
    my $discounted = int($subtotal * (100 - $pct) / 100);
    my $saved      = $subtotal - $discounted;
    Pair($discounted, ["  Discount $pct%: -\$$saved", "  After discount: \$$discounted"]);
}

1;
