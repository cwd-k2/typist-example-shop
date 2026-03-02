package Shop::Events;
use v5.40;
use Typist;
use Shop::Types;
use Shop::Inventory;

# ── GADT Event Processing ─────────────────────
#
# ShopEvent[R] is a GADT: each constructor fixes the return type R.
#   Sale(Order)           -> ShopEvent[Price]
#   Refund(Order, Price)  -> ShopEvent[Price]
#   StockCheck(ProductId) -> ShopEvent[Quantity]

sub process_sale_event :sig((Order) -> Price) ($order) {
    $order->total;
}

sub process_refund_event :sig((Order, Price) -> Price) ($order, $amount) {
    $amount;
}

sub process_stock_event :sig((ProductId) -> Quantity) ($product_id) {
    my $product = Shop::Inventory::find_product($product_id);
    $product->stock;
}

sub describe_event :sig((ShopEvent[Price]) -> Str) ($event) {
    match $event,
        Sale       => sub ($order)          { "Sale: order #" . $order->id->base . " total " . $order->total },
        Refund     => sub ($order, $amount) { "Refund: order #" . $order->id->base . " amount " . $amount },
        StockCheck => sub ($pid)            { "StockCheck: " . $pid->base };
}

1;
