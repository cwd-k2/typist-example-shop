package Shop::Order;
use v5.40;
use Typist;
use Shop::Types;
use Shop::Inventory;
use Shop::Pricing;

# ── Internal Storage ──────────────────────────

my %orders;

# ── Order Creation ────────────────────────────

sub create_order :sig((OrderId, CustomerId, ArrayRef[OrderItem], DiscountPct) -> Result[Order] ![Logger]) ($id, $customer_id, $items, $discount) {
    my $subtotal = Shop::Pricing::order_subtotal($items);
    my $total    = Shop::Pricing::apply_discount($subtotal, $discount);

    my $order = Order(
        id          => $id,
        customer_id => $customer_id,
        items       => $items,
        total       => $total,
        status      => Created(),
        discount    => $discount,
    );

    $orders{$id->base} = $order;
    Logger::log("Order #" . $id->base . " created (subtotal: $subtotal, discount: $discount%, total: $total)");
    Ok($order);
}

# ── Order Confirmation ────────────────────────

sub confirm_order :sig((OrderId) -> Result[Order] ![Logger]) ($id) {
    my $key   = $id->base;
    my $order = $orders{$key};

    for my $item ($order->items->@*) {
        my $result = Shop::Inventory::deduct_stock($item->product_id, $item->quantity);
        my $error;
        match $result,
            Err => sub ($msg) { $error = $msg },
            Ok  => sub ($remaining) { };
        if ($error) {
            $order = $order->with(status => Cancelled($error));
            $orders{$key} = $order;
            Logger::log("Order #$key cancelled: $error");
            return Err($error);
        }
    }

    $order = $order->with(status => Confirmed());
    $orders{$key} = $order;
    Logger::log("Order #$key confirmed");
    Ok($order);
}

# ── Order Fulfillment ─────────────────────────

sub fulfill_order :sig((OrderId) -> Result[Order] ![Logger]) ($id) {
    my $key   = $id->base;
    my $order = $orders{$key};

    $order = $order->with(status => Fulfilled());
    $orders{$key} = $order;
    Logger::log("Order #$key fulfilled");
    Ok($order);
}

# ── Order Cancellation ────────────────────────

sub cancel_order :sig((OrderId, Str) -> Result[Order] ![Logger]) ($id, $reason) {
    my $key   = $id->base;
    my $order = $orders{$key};

    $order = $order->with(status => Cancelled($reason));
    $orders{$key} = $order;
    Logger::log("Order #$key cancelled: $reason");
    Ok($order);
}

# ── Queries ───────────────────────────────────

sub find_order :sig((OrderId) -> Order) ($id) {
    $orders{$id->base};
}

sub all_orders :sig(() -> ArrayRef[Order]) () {
    [values %orders];
}

sub summarize_order :sig((Order) -> Str) ($order) {
    my $id = $order->id->base;
    my $status_str :sig(Str) = match $order->status,
        Created   => sub { "created" },
        Confirmed => sub { "confirmed" },
        Fulfilled => sub { "fulfilled" },
        Cancelled => sub ($reason) { "cancelled: $reason" };
    "Order#$id: " . $order->total . "円 [$status_str]";
}

sub process_results :sig((ArrayRef[Result[Order]]) -> ArrayRef[Order] ![Logger]) ($results) {
    my @orders;
    for my $r (@$results) {
        match $r,
            Ok  => sub ($order) { push @orders, $order },
            Err => sub ($msg)   { Logger::log("Skipped: $msg") };
    }
    \@orders;
}

sub clear {
    %orders = ();
}

1;
