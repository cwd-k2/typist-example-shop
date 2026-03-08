package Shop::App::Scenario;
use v5.40;
use Typist;
use Shop::Types;
use Shop::Infra::Display;
use Shop::Domain::Customer;
use Shop::Domain::Inventory;
use Shop::Domain::Order;
use Shop::Domain::Payment;
use Shop::Domain::Pricing;
use Shop::Feature::Report;
use Shop::FP::HKT;

# ═══════════════════════════════════════════════════
#  Scenario — The business narrative
#
#  A day at the shop: setup, orders, payments,
#  refunds, stock checks, and reporting.
#  All functions execute within the caller's
#  effect handler scope.
# ═══════════════════════════════════════════════════

# ── Orchestration ───────────────────────────

sub run_all :sig(() -> Tuple[Customer, DiscountPct, ArrayRef[OrderItem]]) () {
    my ($alice, $alice_disc) = morning_setup();
    my $alice_items          = alice_order($alice_disc);
    bob_order();
    charlie_order();
    alice_refund();
    stock_check();
    end_of_day_report();
    [$alice, $alice_disc, $alice_items];
}

# ── Morning Setup ───────────────────────────

sub morning_setup {
    Shop::Infra::Display::section("08:00  Morning Setup");

    Shop::Domain::Inventory::add_product(Product(
        id => ProductId("WIDGET"), name => "Widget", price => 1500, stock => 50,
        description => "Essential multipurpose widget",
    ));
    Shop::Domain::Inventory::add_product(Product(
        id => ProductId("GADGET"), name => "Gadget", price => 3200, stock => 20,
        category => "electronics",
    ));
    Shop::Domain::Inventory::add_product(Product(
        id => ProductId("GIZMO"), name => "Gizmo", price => 8000, stock => 5,
    ));
    Shop::Infra::Display::list([
        'Widget ($1,500 x50) -- has description (optional field)',
        'Gadget ($3,200 x20) -- has category',
        'Gizmo  ($8,000 x5)  -- bare',
    ]);
    Shop::Infra::Display::blank();

    my $alice   = Shop::Domain::Customer::register_customer(CustomerId(1), "Alice",   "alice\@example.com", "090-1234-5678");
    my $bob     = Shop::Domain::Customer::register_customer(CustomerId(2), "Bob",     "bob\@example.com", undef);
    my $charlie = Shop::Domain::Customer::register_customer(CustomerId(3), "Charlie", "charlie\@example.com", "080-9999-0000");
    Shop::Domain::Customer::upgrade_to_premium(CustomerId(1), 1200);

    my $alice_opt = Shop::Domain::Customer::find_customer(CustomerId(1));
    my $alice_tier;
    match $alice_opt,
        Some => sub ($c) { $alice_tier = $c->tier },
        None => sub ()   { };
    my $alice_disc = Shop::Domain::Pricing::discount_rate($alice_tier);
    Shop::Infra::Display::kv("Alice",   "Premium (1200pts, discount: $alice_disc%)");
    Shop::Infra::Display::kv("Bob",     "Regular (discount: 0%)");
    Shop::Infra::Display::kv("Charlie", "Regular (discount: 0%)");

    Shop::Infra::Display::kv("Contact", Shop::Domain::Customer::contact_info($alice));
    Shop::Infra::Display::kv("Contact", Shop::Domain::Customer::contact_info($bob));

    Shop::Infra::Display::section_end();

    return ($alice, $alice_disc);
}

# ── Alice's Order ───────────────────────────

sub alice_order ($alice_disc) {
    Shop::Infra::Display::section("10:00  Alice's Order");

    my $alice_items :sig(ArrayRef[OrderItem]) = [
        OrderItem(product_id => ProductId("WIDGET"), quantity => 3, unit_price => 1500),
        OrderItem(product_id => ProductId("GADGET"), quantity => 1, unit_price => 3200),
    ];

    my $order1_result = Shop::Domain::Order::create_order(
        OrderId(1), CustomerId(1), $alice_items, $alice_disc,
    );

    match $order1_result,
        Ok => sub ($order) {
            Shop::Infra::Display::success("Order #1 created: subtotal=\$7,700, discount=$alice_disc%, total=\$" . $order->total);

            my $confirm = Shop::Domain::Order::confirm_order(OrderId(1));
            match $confirm,
                Ok  => sub ($o) { Shop::Infra::Display::success("Order #1 confirmed (stock deducted)") },
                Err => sub ($e) { Shop::Infra::Display::error_msg("Order #1 confirm failed: $e") };

            my $payment = Shop::Domain::Payment::process_payment(OrderId(1), $order->total, Card("4111-1111-1111-1234"));
            match $payment,
                Ok  => sub ($status) { Shop::Infra::Display::success("Payment: " . Shop::Domain::Payment::show_payment_status($status)) },
                Err => sub ($e)      { Shop::Infra::Display::error_msg("Payment failed: $e") };

            Shop::Domain::Order::fulfill_order(OrderId(1));
            Shop::Infra::Display::success("Order #1 fulfilled");
        },
        Err => sub ($e) { Shop::Infra::Display::error_msg("Order #1 failed: $e") };

    Shop::Infra::Display::section_end();

    return $alice_items;
}

# ── Bob's Order ─────────────────────────────

sub bob_order {
    Shop::Infra::Display::section("11:30  Bob's Order");

    my $bob_items_v1 :sig(ArrayRef[OrderItem]) = [
        OrderItem(product_id => ProductId("GIZMO"), quantity => 10, unit_price => 8000),
    ];

    my $order2_result = Shop::Domain::Order::create_order(
        OrderId(2), CustomerId(2), $bob_items_v1, 0,
    );

    match $order2_result,
        Ok => sub ($order) {
            Shop::Infra::Display::info("Order #2 created: \$" . $order->total . " (10 x Gizmo)");

            my $confirm = Shop::Domain::Order::confirm_order(OrderId(2));
            match $confirm,
                Ok  => sub ($o) { Shop::Infra::Display::success("Order #2 confirmed") },
                Err => sub ($e) { Shop::Infra::Display::error_msg("Order #2 confirm failed: $e") };
        },
        Err => sub ($e) { Shop::Infra::Display::error_msg("Order #2 failed: $e") };

    Shop::Infra::Display::blank();
    Shop::Infra::Display::warn_msg("Bob retries with smaller quantity...");
    Shop::Infra::Display::blank();

    my $bob_items_v2 :sig(ArrayRef[OrderItem]) = [
        OrderItem(product_id => ProductId("GIZMO"), quantity => 3, unit_price => 8000),
    ];

    my $order3_result = Shop::Domain::Order::create_order(
        OrderId(3), CustomerId(2), $bob_items_v2, 0,
    );

    match $order3_result,
        Ok => sub ($order) {
            Shop::Infra::Display::success("Order #3 created: \$" . $order->total . " (3 x Gizmo)");

            my $confirm = Shop::Domain::Order::confirm_order(OrderId(3));
            match $confirm,
                Ok  => sub ($o) { Shop::Infra::Display::success("Order #3 confirmed") },
                Err => sub ($e) { Shop::Infra::Display::error_msg("Order #3 confirm failed: $e") };

            my $payment = Shop::Domain::Payment::process_payment(OrderId(3), $order->total, Cash());
            match $payment,
                Ok  => sub ($status) { Shop::Infra::Display::success("Payment: " . Shop::Domain::Payment::show_payment_status($status) . " (cash)") },
                Err => sub ($e)      { Shop::Infra::Display::error_msg("Payment failed: $e") };

            Shop::Domain::Order::fulfill_order(OrderId(3));
            Shop::Infra::Display::success("Order #3 fulfilled");
        },
        Err => sub ($e) { Shop::Infra::Display::error_msg("Order #3 failed: $e") };

    Shop::Infra::Display::section_end();
}

# ── Charlie's Order ─────────────────────────

sub charlie_order {
    Shop::Infra::Display::section("14:00  Charlie's Order");

    my $charlie_items :sig(ArrayRef[OrderItem]) = [
        OrderItem(product_id => ProductId("WIDGET"), quantity => 5, unit_price => 1500),
    ];

    my $order4_result = Shop::Domain::Order::create_order(
        OrderId(4), CustomerId(3), $charlie_items, 0,
    );

    match $order4_result,
        Ok => sub ($order) {
            Shop::Infra::Display::info("Order #4 created: \$" . $order->total . " (5 x Widget)");

            my $confirm = Shop::Domain::Order::confirm_order(OrderId(4));
            match $confirm,
                Ok  => sub ($o) { Shop::Infra::Display::success("Order #4 confirmed") },
                Err => sub ($e) { Shop::Infra::Display::error_msg("Order #4 confirm failed: $e") };

            my $payment = Shop::Domain::Payment::process_payment(OrderId(4), $order->total, Transfer("Shady Bank", "000-666"));
            match $payment,
                Ok => sub ($status) {
                    Shop::Infra::Display::success("Payment: " . Shop::Domain::Payment::show_payment_status($status));
                    Shop::Domain::Order::fulfill_order(OrderId(4));
                },
                Err => sub ($e) {
                    Shop::Infra::Display::error_msg("Payment rejected: $e");
                    Shop::Domain::Order::cancel_order(OrderId(4), "Payment declined");
                    Shop::Infra::Display::warn_msg("Order #4 cancelled -- restocking items");
                    for my $item ($charlie_items->@*) {
                        Shop::Domain::Inventory::restock($item->product_id, $item->quantity);
                    }
                };
        },
        Err => sub ($e) { Shop::Infra::Display::error_msg("Order #4 failed: $e") };

    Shop::Infra::Display::section_end();
}

# ── Refund ──────────────────────────────────

sub alice_refund {
    Shop::Infra::Display::section("15:00  Alice's Refund");

    my $refund1 = Shop::Domain::Payment::refund_payment(OrderId(1), 6545);
    match $refund1,
        Ok  => sub ($status) { Shop::Infra::Display::success("Refund #1: " . Shop::Domain::Payment::show_payment_status($status)) },
        Err => sub ($e)      { Shop::Infra::Display::error_msg("Refund #1 failed: $e") };

    my $refund2 = Shop::Domain::Payment::refund_payment(OrderId(1), 6545);
    match $refund2,
        Ok  => sub ($status) { Shop::Infra::Display::success("Refund #2: " . Shop::Domain::Payment::show_payment_status($status)) },
        Err => sub ($e)      { Shop::Infra::Display::error_msg("Refund #2 failed: $e") };

    Shop::Infra::Display::section_end();
}

# ── Stock Check ─────────────────────────────

sub stock_check {
    Shop::Infra::Display::section("16:00  Stock Check");

    my $gizmo_opt = Shop::Domain::Inventory::find_product(ProductId("GIZMO"));
    match $gizmo_opt,
        Some => sub ($g) { Shop::Infra::Display::kv("Gizmo stock", $g->stock . " (started with 5, Bob bought 3)") },
        None => sub ()   { Shop::Infra::Display::error_msg("Gizmo not found") };

    my $widget_opt = Shop::Domain::Inventory::find_product(ProductId("WIDGET"));
    match $widget_opt,
        Some => sub ($w) { Shop::Infra::Display::kv("Widget stock", $w->stock . " (started with 50, Alice bought 3, Charlie's 5 restocked)") },
        None => sub ()   { Shop::Infra::Display::error_msg("Widget not found") };

    Shop::Infra::Display::section_end();
}

# ── End of Day Report ───────────────────────

sub end_of_day_report {
    Shop::Infra::Display::section("17:00  End of Day Report");

    my $report = Shop::Feature::Report::build_daily_report();
    Shop::Infra::Display::info(Shop::Feature::Report::format_report($report, 0));

    Shop::Infra::Display::section_end();
}

1;
