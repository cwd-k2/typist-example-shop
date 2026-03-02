package Shop::Pricing;
use v5.40;
use Typist;
use Shop::Types;

# ── Discount Calculation ──────────────────────

sub discount_rate :sig((CustomerTier) -> DiscountPct) ($tier) {
    # @typist-ignore — ternary chain widens literals to Int, losing DiscountPct precision
    match $tier,
        Regular => sub ()     { 0 },
        Premium => sub ($pts) { $pts >= 1000 ? 15 : $pts >= 500 ? 10 : 5 };
}

sub apply_discount :sig(<T: Num>(T, DiscountPct) -> T) ($price, $pct) {
    int($price * (100 - $pct) / 100);
}

# ── Order Subtotal ────────────────────────────

sub order_subtotal :sig((ArrayRef[OrderItem]) -> Price) ($items) {
    my $total = 0;
    for my $item (@$items) {
        $total += $item->unit_price * $item->quantity;
    }
    $total;
}

1;
