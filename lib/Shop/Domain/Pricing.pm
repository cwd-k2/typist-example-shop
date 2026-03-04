package Shop::Domain::Pricing;
use v5.40;
use Typist;
use Shop::Types;
use Shop::FP::HKT;

# ═══════════════════════════════════════════════════
#  Pricing — Discount and subtotal calculations
#
#  HKT integration: order_subtotal via
#  Foldable::foldr + Functor::fmap.
# ═══════════════════════════════════════════════════

# ── Discount Calculation ──────────────────────

sub discount_rate :sig((CustomerTier) -> DiscountPct) ($tier) {
    match $tier,
        Regular => sub ()     { 0 },
        Premium => sub ($pts) { $pts >= 1000 ? 15 : $pts >= 500 ? 10 : 5 };
}

sub apply_discount :sig(<T: Num>(T, DiscountPct) -> T) ($price, $pct) {
    int($price * (100 - $pct) / 100);
}

# ── Bounded Quantification Utilities ─────────

sub clamp :sig(<T: Num>(T, T, T) -> T) ($val, $lo, $hi) {
    $val < $lo ? $lo : $val > $hi ? $hi : $val;
}

sub max_of :sig(<T: Num>(T, T) -> T) ($a, $b) {
    $a > $b ? $a : $b;
}

sub min_of :sig(<T: Num>(T, T) -> T) ($a, $b) {
    $a < $b ? $a : $b;
}

# ── Order Subtotal (HKT) ─────────────────────
#
# Foldable::foldr over Functor::fmap — compute line
# totals then sum them.

sub order_subtotal :sig((ArrayRef[OrderItem]) -> Price) ($items) {
    my $line_totals = Functor::fmap($items, sub ($item) {
        $item->unit_price * $item->quantity;
    });
    Shop::FP::HKT::fold_sum($line_totals);
}

1;
