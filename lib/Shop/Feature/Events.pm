package Shop::Feature::Events;
use v5.40;
use Typist;
use Shop::Types;
use Shop::Domain::Inventory;
use Shop::FP::HKT;

# ═══════════════════════════════════════════════════
#  Events — GADT event processing
#
#  ShopEvent[R] is a GADT: each constructor fixes
#  the return type R.
#    Sale(Order)           -> ShopEvent[Price]
#    Refund(Order, Price)  -> ShopEvent[Price]
#    StockCheck(ProductId) -> ShopEvent[Quantity]
# ═══════════════════════════════════════════════════

sub process_sale_event :sig((Order) -> Price) ($order) {
    $order->total;
}

sub process_refund_event :sig((Order, Price) -> Price) ($order, $amount) {
    $amount;
}

sub process_stock_event :sig((ProductId) -> Quantity ![ProductStore]) ($product_id) {
    my $opt = Shop::Domain::Inventory::find_product($product_id);
    Shop::FP::HKT::option_or(
        Shop::FP::HKT::option_fmap($opt, sub ($p) { $p->stock }),
        0,
    );
}

sub describe_event :sig((ShopEvent[Price]) -> Str) ($event) {
    match $event,
        Sale       => sub ($order)          { "Sale: order #" . $order->id->base . " total " . $order->total },
        Refund     => sub ($order, $amount) { "Refund: order #" . $order->id->base . " amount " . $amount },
        StockCheck => sub ($pid)            { "StockCheck: " . $pid->base };
}

1;
