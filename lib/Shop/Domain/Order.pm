package Shop::Domain::Order;
use v5.40;
use Typist;
use Shop::Types;
use Shop::Domain::Inventory;
use Shop::Domain::Pricing;
use Shop::FP::HKT;

# ═══════════════════════════════════════════════════
#  Order — Order lifecycle management
#
#  Storage delegated to OrderStore effect.
#  HKT integration: process_results via cat_results.
# ═══════════════════════════════════════════════════

# ── Order Creation ────────────────────────────

sub create_order :sig((OrderId, CustomerId, ArrayRef[OrderItem], DiscountPct) -> Result[Order] ![Logger, OrderStore]) ($id, $customer_id, $items, $discount) {
    my $subtotal = Shop::Domain::Pricing::order_subtotal($items);
    my $total    = Shop::Domain::Pricing::apply_discount($subtotal, $discount);

    my $order = Order(
        id          => $id,
        customer_id => $customer_id,
        items       => $items,
        total       => $total,
        status      => Created(),
        discount    => $discount,
    );

    OrderStore::put_order($order);
    Logger::log(Info(), "Order #" . $id->base . " created (subtotal: $subtotal, discount: $discount%, total: $total)");
    Ok($order);
}

# ── Order Confirmation ────────────────────────

sub confirm_order :sig((OrderId) -> Result[Order] ![Logger, OrderStore, ProductStore]) ($id) {
    my $opt = OrderStore::get_order($id);
    match $opt,
        Some => sub ($order) {
            my $key = $id->base;
            for my $item ($order->items->@*) {
                my $result = Shop::Domain::Inventory::deduct_stock($item->product_id, $item->quantity);
                my $error;
                match $result,
                    Err => sub ($msg) { $error = $msg },
                    Ok  => sub ($remaining) { };
                if ($error) {
                    my $cancelled = $order->with(status => Cancelled($error));
                    OrderStore::put_order($cancelled);
                    Logger::log(Warn(), "Order #$key cancelled: $error");
                    return Err($error);
                }
            }

            my $confirmed = $order->with(status => Confirmed());
            OrderStore::put_order($confirmed);
            Logger::log(Info(), "Order #$key confirmed");
            Ok($confirmed);
        },
        None => sub () {
            Err("Order not found");
        };
}

# ── Order Fulfillment ─────────────────────────

sub fulfill_order :sig((OrderId) -> Result[Order] ![Logger, OrderStore]) ($id) {
    my $opt = OrderStore::get_order($id);
    match $opt,
        Some => sub ($order) {
            my $key = $id->base;
            my $fulfilled = $order->with(status => Fulfilled());
            OrderStore::put_order($fulfilled);
            Logger::log(Info(), "Order #$key fulfilled");
            Ok($fulfilled);
        },
        None => sub () {
            Err("Order not found");
        };
}

# ── Order Cancellation ────────────────────────

sub cancel_order :sig((OrderId, Str) -> Result[Order] ![Logger, OrderStore]) ($id, $reason) {
    my $opt = OrderStore::get_order($id);
    match $opt,
        Some => sub ($order) {
            my $key = $id->base;
            my $cancelled = $order->with(status => Cancelled($reason));
            OrderStore::put_order($cancelled);
            Logger::log(Info(), "Order #$key cancelled: $reason");
            Ok($cancelled);
        },
        None => sub () {
            Err("Order not found");
        };
}

# ── Queries ───────────────────────────────────

sub find_order :sig((OrderId) -> Option[Order] ![OrderStore]) ($id) {
    OrderStore::get_order($id);
}

sub all_orders :sig(() -> ArrayRef[Order] ![OrderStore]) () {
    OrderStore::all_orders();
}

sub summarize_order :sig((Order) -> Str) ($order) {
    my $id = $order->id->base;
    my $status_str :sig(Str) = match $order->status,
        Created   => sub { "created" },
        Confirmed => sub { "confirmed" },
        Fulfilled => sub { "fulfilled" },
        Cancelled => sub ($reason) { "cancelled: $reason" };
    "Order#$id: " . $order->total . " [$status_str]";
}

# HKT integration: cat_results for batch processing
sub process_results :sig((ArrayRef[Result[Order]]) -> ArrayRef[Order] ![Logger]) ($results) {
    my $ok_orders = Shop::FP::HKT::cat_results($results);
    # Log skipped errors
    for my $r (@$results) {
        match $r,
            Ok  => sub ($order) { },
            Err => sub ($msg)   { Logger::log(Warn(), "Skipped: $msg") };
    }
    $ok_orders;
}

1;
