#!/usr/bin/env perl
use v5.40;
use Typist;
use Shop::Types;
use Shop::Instances;
use Shop::Customer;
use Shop::Inventory;
use Shop::Order;
use Shop::Payment;
use Shop::Pricing;
use Shop::Report;
use Shop::Events;
use Shop::Checkout;
use Shop::HKT;
use Shop::Codensity;

# ═══════════════════════════════════════════════════
#  typist-shop — A Day at the Shop
#
#  Demonstrates: newtype, typedef, struct, ADT,
#  parametric ADT, GADT, enum, literal types,
#  recursive types, bounded quantification,
#  rank-2 polymorphism, match, effect/handle,
#  typeclass, cross-file instance,
#  optional struct fields,
#  Maybe + type narrowing, higher-kinded types,
#  natural transformation, Codensity.
# ═══════════════════════════════════════════════════

handle {

    say "═══ A Day at the Shop ════════════════════════════";
    say "";

    # ── Morning Setup (08:00) ─────────────────

    say "── 08:00  Morning Setup ──────────────────────────";
    say "";

    Shop::Inventory::add_product(Product(
        id => ProductId("WIDGET"), name => "Widget", price => 1500, stock => 50,
        description => "Essential multipurpose widget",
    ));
    Shop::Inventory::add_product(Product(
        id => ProductId("GADGET"), name => "Gadget", price => 3200, stock => 20,
        category => "electronics",
    ));
    Shop::Inventory::add_product(Product(
        id => ProductId("GIZMO"), name => "Gizmo", price => 8000, stock => 5,
    ));
    say "  Products registered: Widget (\$1500 ×50), Gadget (\$3200 ×20), Gizmo (\$8000 ×5)";
    say "    Widget has description (optional field), Gadget has category, Gizmo has neither";

    my $alice   = Shop::Customer::register_customer(CustomerId(1), "Alice",   "alice\@example.com", "090-1234-5678");
    my $bob     = Shop::Customer::register_customer(CustomerId(2), "Bob",     "bob\@example.com");
    my $charlie = Shop::Customer::register_customer(CustomerId(3), "Charlie", "charlie\@example.com", "080-9999-0000");
    Shop::Customer::upgrade_to_premium(CustomerId(1), 1200);

    my $alice_tier = Shop::Customer::find_customer(CustomerId(1))->tier;
    my $alice_disc = Shop::Pricing::discount_rate($alice_tier);
    say "  Alice: Premium (1200pts, discount: $alice_disc%)";
    say "  Bob:   Regular (discount: 0%)";
    say "  Charlie: Regular (discount: 0%)";

    # Maybe[Str] + type narrowing showcase
    say "  Contact: ", Shop::Customer::contact_info($alice);
    say "  Contact: ", Shop::Customer::contact_info($bob);

    say "";

    # ── 10:00  Alice's Order ──────────────────

    say "── 10:00  Alice's Order ──────────────────────────";
    say "";

    my $alice_items = [
        OrderItem(product_id => ProductId("WIDGET"), quantity => 3, unit_price => 1500),
        OrderItem(product_id => ProductId("GADGET"), quantity => 1, unit_price => 3200),
    ];

    my $order1_result = Shop::Order::create_order(
        OrderId(1), CustomerId(1), $alice_items, $alice_disc,
    );

    match $order1_result,
        Ok => sub ($order) {
            say "  Order #1 created: subtotal=\$7700, discount=$alice_disc%, total=\$" . $order->total;

            my $confirm = Shop::Order::confirm_order(OrderId(1));
            match $confirm,
                Ok  => sub ($o) { say "  Order #1 confirmed (stock deducted)" },
                Err => sub ($e) { say "  Order #1 confirm failed: $e" };

            my $payment = Shop::Payment::process_payment(OrderId(1), $order->total, Card("4111-1111-1111-1234"));
            match $payment,
                Ok  => sub ($status) { say "  Payment: " . Shop::Payment::show_payment_status($status) },
                Err => sub ($e)      { say "  Payment failed: $e" };

            Shop::Order::fulfill_order(OrderId(1));
            say "  Order #1 fulfilled";
        },
        Err => sub ($e) { say "  Order #1 failed: $e" };

    say "";

    # ── 11:30  Bob's Order ────────────────────

    say "── 11:30  Bob's Order ────────────────────────────";
    say "";

    my $bob_items_v1 = [
        OrderItem(product_id => ProductId("GIZMO"), quantity => 10, unit_price => 8000),
    ];

    my $order2_result = Shop::Order::create_order(
        OrderId(2), CustomerId(2), $bob_items_v1, 0,
    );

    match $order2_result,
        Ok => sub ($order) {
            say "  Order #2 created: \$" . $order->total . " (10 × Gizmo)";

            my $confirm = Shop::Order::confirm_order(OrderId(2));
            match $confirm,
                Ok  => sub ($o) { say "  Order #2 confirmed" },
                Err => sub ($e) { say "  Order #2 confirm failed: $e" };
        },
        Err => sub ($e) { say "  Order #2 failed: $e" };

    say "";
    say "  Bob retries with smaller quantity...";
    say "";

    my $bob_items_v2 = [
        OrderItem(product_id => ProductId("GIZMO"), quantity => 3, unit_price => 8000),
    ];

    my $order3_result = Shop::Order::create_order(
        OrderId(3), CustomerId(2), $bob_items_v2, 0,
    );

    match $order3_result,
        Ok => sub ($order) {
            say "  Order #3 created: \$" . $order->total . " (3 × Gizmo)";

            my $confirm = Shop::Order::confirm_order(OrderId(3));
            match $confirm,
                Ok  => sub ($o) { say "  Order #3 confirmed" },
                Err => sub ($e) { say "  Order #3 confirm failed: $e" };

            my $payment = Shop::Payment::process_payment(OrderId(3), $order->total, Cash());
            match $payment,
                Ok  => sub ($status) { say "  Payment: " . Shop::Payment::show_payment_status($status) . " (cash)" },
                Err => sub ($e)      { say "  Payment failed: $e" };

            Shop::Order::fulfill_order(OrderId(3));
            say "  Order #3 fulfilled";
        },
        Err => sub ($e) { say "  Order #3 failed: $e" };

    say "";

    # ── 14:00  Charlie's Order ────────────────

    say "── 14:00  Charlie's Order ────────────────────────";
    say "";

    my $charlie_items = [
        OrderItem(product_id => ProductId("WIDGET"), quantity => 5, unit_price => 1500),
    ];

    my $order4_result = Shop::Order::create_order(
        OrderId(4), CustomerId(3), $charlie_items, 0,
    );

    match $order4_result,
        Ok => sub ($order) {
            say "  Order #4 created: \$" . $order->total . " (5 × Widget)";

            my $confirm = Shop::Order::confirm_order(OrderId(4));
            match $confirm,
                Ok  => sub ($o) { say "  Order #4 confirmed" },
                Err => sub ($e) { say "  Order #4 confirm failed: $e" };

            my $payment = Shop::Payment::process_payment(OrderId(4), $order->total, Transfer("Shady Bank", "000-666"));
            match $payment,
                Ok => sub ($status) {
                    say "  Payment: " . Shop::Payment::show_payment_status($status);
                    Shop::Order::fulfill_order(OrderId(4));
                },
                Err => sub ($e) {
                    say "  Payment rejected: $e";
                    Shop::Order::cancel_order(OrderId(4), "Payment declined");
                    say "  Order #4 cancelled — restocking items";
                    for my $item ($charlie_items->@*) {
                        Shop::Inventory::restock($item->product_id, $item->quantity);
                    }
                };
        },
        Err => sub ($e) { say "  Order #4 failed: $e" };

    say "";

    # ── 15:00  Alice's Refund ─────────────────

    say "── 15:00  Alice's Refund ─────────────────────────";
    say "";

    my $refund1 = Shop::Payment::refund_payment(OrderId(1), 6545);
    match $refund1,
        Ok  => sub ($status) { say "  Refund #1: " . Shop::Payment::show_payment_status($status) },
        Err => sub ($e)      { say "  Refund #1 failed: $e" };

    my $refund2 = Shop::Payment::refund_payment(OrderId(1), 6545);
    match $refund2,
        Ok  => sub ($status) { say "  Refund #2: " . Shop::Payment::show_payment_status($status) },
        Err => sub ($e)      { say "  Refund #2 failed: $e" };

    say "";

    # ── 16:00  Stock Check ────────────────────

    say "── 16:00  Stock Check ────────────────────────────";
    say "";

    my $gizmo = Shop::Inventory::find_product(ProductId("GIZMO"));
    say "  Gizmo stock remaining: " . $gizmo->stock . " (started with 5, Bob bought 3)";

    my $widget = Shop::Inventory::find_product(ProductId("WIDGET"));
    say "  Widget stock remaining: " . $widget->stock . " (started with 50, Alice bought 3, Charlie's 5 restocked)";

    say "";

    # ── 17:00  End of Day Report ──────────────

    say "── 17:00  End of Day Report ──────────────────────";
    say "";

    my $report = Shop::Report::build_daily_report();
    say Shop::Report::format_report($report, 1);

    say "";

    # ── 18:00  Inventory Analysis ─────────────
    #
    #  Functor  — lift extraction into a container
    #  Foldable — collapse structure to summary stats
    #  Monad    — generate combinations (nondeterminism)

    say "── 18:00  Inventory Analysis ─────────────────────";
    say "";

    my $all_products = Shop::Inventory::all_products();

    # Functor::fmap — project out product attributes
    my $prod_names  = Functor::fmap($all_products, sub ($p) { $p->name });
    my $prod_prices = Functor::fmap($all_products, sub ($p) { $p->price });
    say "  fmap(→name):  ", join(", ", @$prod_names);
    say "  fmap(→price): ", join(", ", @$prod_prices);

    # fmap² (Functor composition): price → end-of-day 10% discount
    my $eod_prices = Shop::HKT::fmap2(
        $all_products,
        sub ($price) { int($price * 90 / 100) },
        sub ($p)     { $p->price },
    );
    say "  fmap²(→price, 10% off): ", join(", ", @$eod_prices);

    # Foldable — aggregate inventory statistics
    my $total_value = Shop::HKT::fold_sum($prod_prices);
    my $n_premium   = Shop::HKT::fold_count($prod_prices, sub ($p) { $p >= 3000 });
    my $has_budget  = Shop::HKT::fold_any($prod_prices, sub ($p) { $p < 2000 });
    my $all_stocked = Shop::HKT::fold_all($all_products, sub ($p) { $p->stock > 0 });

    say "  Total list value: \$$total_value";
    say "  Premium items (≥\$3000): $n_premium";
    say "  Budget items  (<\$2000): ", ($has_budget  ? "yes" : "no");
    say "  All in stock:            ", ($all_stocked ? "yes" : "no");

    # map_reduce (Functor + Foldable): build product catalog
    my $catalog = Shop::HKT::map_reduce(
        $all_products,
        sub ($p) { $p->name . "(\$" . $p->price . ")" },
        "",
        sub ($s, $acc) { $acc eq "" ? $s : "$acc, $s" },
    );
    say "  Catalog: $catalog";

    # List Monad — restock candidate generation (nondeterminism)
    my $restock_pids = [ProductId("WIDGET"), ProductId("GADGET")];
    my $restock_qtys = [10, 25];

    my $restock_plan = Monad::bind($restock_pids, sub ($pid) {
        Monad::bind($restock_qtys, sub ($qty) {
            [ $pid->base . " ×$qty" ];
        });
    });
    say "  Restock candidates:";
    say "    $_" for @$restock_plan;

    say "";

    # ── 19:00  Night Audit ────────────────────
    #
    #  Natural Transformation — ArrayRef ↝ Option
    #  Option Monad           — chain nullable lookups
    #  Kleisli Composition    — compose monadic functions
    #  Codensity              — CPS right-association

    say "── 19:00  Night Audit ────────────────────────────";
    say "";

    # Natural transformation: ArrayRef ↝ Option (head_option)
    my $expensive = [grep { $_->price >= 5000 } @$all_products];
    my $cheap     = [grep { $_->price <  1000 } @$all_products];

    my $top_item  = Shop::HKT::head_option($expensive);
    my $cheap_hit = Shop::HKT::head_option($cheap);
    say "  head_option(expensive): ", Shop::HKT::show_option(
        Shop::HKT::option_fmap($top_item, sub ($p) { $p->name }));
    say "  head_option(cheap):     ", Shop::HKT::show_option($cheap_hit);

    # Option monad: chain nullable stock check
    my $stock_msg = Shop::HKT::option_bind($top_item, sub ($p) {
        $p->stock > 0 ? Some($p->name . ": " . $p->stock . " left") : None();
    });
    say "  option_bind(stock): ", Shop::HKT::show_option($stock_msg);

    # Natural transformation round-trip: ArrayRef ↝ Option ↝ ArrayRef
    my $roundtrip = Shop::HKT::option_to_list(
        Shop::HKT::option_fmap($top_item, sub ($p) { $p->name }),
    );
    say "  option_to_list ∘ head: [", join(", ", @$roundtrip), "]";

    # Kleisli composition: find → classify pipeline
    my $find_and_classify = Shop::HKT::kleisli(
        sub ($pid) {
            my $p = Shop::Inventory::find_product($pid);
            $p ? [$p] : [];
        },
        sub ($p) { [$p->price >= 5000 ? "premium" : "standard"] },
    );
    say "  Kleisli (find → classify):";
    for my $pid (ProductId("WIDGET"), ProductId("GADGET"), ProductId("GIZMO")) {
        my $r = $find_and_classify->($pid);
        say "    ", $pid->base, " → ", $r->[0];
    }

    # Codensity: right-associate bind chains via CPS
    my $products_c = Shop::Codensity::lift_list($all_products);
    my $quarters   = Shop::Codensity::lift_list([qw(Q1 Q2 Q3 Q4)]);

    my $projection = Shop::Codensity::bind($products_c, sub ($p) {
        Shop::Codensity::bind($quarters, sub ($q) {
            Shop::Codensity::unit($p->name . "/" . $q);
        });
    });
    my $projected = Shop::Codensity::lower_list($projection);
    say "  Codensity (product × quarter):";
    say "    $_" for @$projected;

    # mjoin: flatten nested audit data
    my $nested_audit = [[1, 2], [3], [4, 5, 6]];
    my $flat_audit = Shop::HKT::mjoin($nested_audit);
    say "  mjoin([[1,2],[3],[4,5,6]]): [", join(", ", @$flat_audit), "]";

    say "";

    # ── GADT: Shop Events ─────────────────────

    say "── GADT: Shop Events ─────────────────────────────";
    say "";

    my $order1 = Shop::Order::find_order(OrderId(1));
    my $sale_event = Sale($order1);
    say "  ", Shop::Events::describe_event($sale_event);
    say "  Revenue from sale: ", Shop::Events::process_sale_event($order1);

    my $refund_event = Refund($order1, 3000);
    say "  ", Shop::Events::describe_event($refund_event);

    my $stock_qty = Shop::Events::process_stock_event(ProductId("GIZMO"));
    say "  Stock check (Gizmo): $stock_qty remaining";

    say "";

    # ── Rank-2: Polymorphic Transform ─────────

    say "── Rank-2: Polymorphic Transform ─────────────────";
    say "";

    my $identity = sub ($x) { $x };
    my $all_orders = Shop::Order::all_orders();
    my $transformed = Shop::Report::transform_all($identity, $all_orders);
    say "  transform_all(identity, orders): ", scalar(@$transformed), " orders unchanged";

    say "";

    # ── TypeClass Showcase ────────────────────

    say "── TypeClass Showcase ────────────────────────────";
    say "";
    say "  Printable(42):      ", Printable::display(42);
    say "  Printable('hello'): ", Printable::display("hello");

    # Summarize typeclass (dispatch on primitive types)
    say "  Summarize(6545):    ", Summarize::summarize(6545);
    say "  Summarize('hello'): ", Summarize::summarize("hello");

    # Domain-specific order summary (via direct function, not typeclass dispatch on hashref)
    say "  Order summary:      ", Shop::Order::summarize_order($order1);

    say "";

    # ── Protocol: Register Checkout ───────────

    say "── Protocol: Register Checkout ───────────────────";
    say "";

    my $checkout_items = [
        OrderItem(product_id => ProductId("WIDGET"), quantity => 2, unit_price => 1500),
        OrderItem(product_id => ProductId("GADGET"), quantity => 1, unit_price => 3200),
    ];

    my $checkout_total = handle {
        Shop::Checkout::run_checkout($checkout_items, Cash());
    } Register => +{
        open_reg => sub ()           { say "  [reg] Register opened" },
        scan     => sub ($pid, $qty) { say "  [reg] Scan: " . $pid->base . " x$qty" },
        pay      => sub ($method)    { say "  [reg] Processing payment..."; 1 },
        complete => sub ()           {
            my $sum = 0;
            for my $item ($checkout_items->@*) {
                $sum += $item->unit_price * $item->quantity;
            }
            say "  [reg] Total: \$$sum";
            $sum;
        },
    };

    say "  Checkout total: \$$checkout_total";

    say "";
    say "═══ Shop Closed ══════════════════════════════════";

} Logger => +{
    log => sub ($msg) { say "[LOG] $msg" },
},
  PaymentGateway => +{
    charge => sub ($amount, $method) {
        match $method,
            Transfer => sub ($bank, $ac) { $bank ne "Shady Bank" ? 1 : 0 },
            Cash     => sub ()           { 1 },
            Card     => sub ($number)    { 1 };
    },
};
