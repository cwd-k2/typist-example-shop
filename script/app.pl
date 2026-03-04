#!/usr/bin/env perl
use v5.40;
use Typist;
use Shop::Types;
use Shop::Instances;
use Shop::Infra::Display;
use Shop::Infra::Store;
use Shop::Domain::Customer;
use Shop::Domain::Inventory;
use Shop::Domain::Order;
use Shop::Domain::Payment;
use Shop::Domain::Pricing;
use Shop::Feature::Report;
use Shop::Feature::Events;
use Shop::Feature::Checkout;
use Shop::Feature::Analytics;
use Shop::Feature::Summary;
use Shop::FP::HKT;
use Shop::FP::Codensity;
use Shop::FP::Validation;
use Shop::FP::Reader;
use Shop::FP::State;
use Shop::FP::Writer;

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
#  natural transformation, Codensity,
#  Applicative, Traversable, Validation,
#  Reader, State, Writer,
#  effect-based Store, structured Logger.
# ═══════════════════════════════════════════════════

handle {

    Shop::Infra::Display::banner("A Day at the Shop");

    # ── Morning Setup (08:00) ─────────────────

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

    # Maybe[Str] + type narrowing
    Shop::Infra::Display::kv("Contact", Shop::Domain::Customer::contact_info($alice));
    Shop::Infra::Display::kv("Contact", Shop::Domain::Customer::contact_info($bob));

    Shop::Infra::Display::section_end();

    # ── 10:00  Alice's Order ──────────────────

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

    # ── 11:30  Bob's Order ────────────────────

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

    # ── 14:00  Charlie's Order ────────────────

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

    # ── 15:00  Alice's Refund ─────────────────

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

    # ── 16:00  Stock Check ────────────────────

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

    # ── 17:00  End of Day Report ──────────────

    Shop::Infra::Display::section("17:00  End of Day Report");

    my $report = Shop::Feature::Report::build_daily_report();
    Shop::Infra::Display::info(Shop::Feature::Report::format_report($report, 0));

    Shop::Infra::Display::section_end();

    # ── 18:00  Inventory Analysis ─────────────
    #
    #  Functor  — lift extraction into a container
    #  Foldable — collapse structure to summary stats
    #  Monad    — generate combinations (nondeterminism)

    Shop::Infra::Display::section("18:00  Inventory Analysis (Functor / Foldable / Monad)");

    my $all_products = Shop::Domain::Inventory::all_products();

    # Functor::fmap — project out product attributes
    my $prod_names  = Functor::fmap($all_products, sub ($p) { $p->name });
    my $prod_prices = Functor::fmap($all_products, sub ($p) { $p->price });
    Shop::Infra::Display::kv("fmap(->name)",  join(", ", @$prod_names));
    Shop::Infra::Display::kv("fmap(->price)", join(", ", @$prod_prices));

    # fmap^2 (Functor composition): price -> end-of-day 10% discount
    my $eod_prices = Shop::FP::HKT::fmap2(
        $all_products,
        sub ($price) { int($price * 90 / 100) },
        sub ($p)     { $p->price },
    );
    Shop::Infra::Display::kv("fmap2(->price, 10% off)", join(", ", @$eod_prices));

    # Foldable — aggregate inventory statistics
    my $total_value = Shop::FP::HKT::fold_sum($prod_prices);
    my $n_premium   = Shop::FP::HKT::fold_count($prod_prices, sub ($p) { $p >= 3000 });
    my $has_budget  = Shop::FP::HKT::fold_any($prod_prices, sub ($p) { $p < 2000 });
    my $all_stocked = Shop::FP::HKT::fold_all($all_products, sub ($p) { $p->stock > 0 });

    Shop::Infra::Display::kv("Total list value",       "\$$total_value");
    Shop::Infra::Display::kv("Premium items (>=\$3000)", "$n_premium");
    Shop::Infra::Display::kv("Budget items  (<\$2000)",  ($has_budget  ? "yes" : "no"));
    Shop::Infra::Display::kv("All in stock",             ($all_stocked ? "yes" : "no"));

    # map_reduce (Functor + Foldable): build product catalog
    my $catalog = Shop::FP::HKT::map_reduce(
        $all_products,
        sub ($p) { $p->name . "(\$" . $p->price . ")" },
        "",
        sub ($s, $acc) { $acc eq "" ? $s : "$acc, $s" },
    );
    Shop::Infra::Display::kv("Catalog", $catalog);

    # List Monad — restock candidate generation (nondeterminism)
    my $restock_pids = [ProductId("WIDGET"), ProductId("GADGET")];
    my $restock_qtys = [10, 25];

    my $restock_plan = Monad::bind($restock_pids, sub ($pid) {
        Monad::bind($restock_qtys, sub ($qty) {
            [ $pid->base . " x$qty" ];
        });
    });
    Shop::Infra::Display::info("Restock candidates:");
    Shop::Infra::Display::list($restock_plan);

    Shop::Infra::Display::section_end();

    # ── 19:00  Night Audit ────────────────────
    #
    #  Natural Transformation — ArrayRef ~> Option
    #  Option Monad           — chain nullable lookups
    #  Kleisli Composition    — compose monadic functions
    #  Codensity              — CPS right-association

    Shop::Infra::Display::section("19:00  Night Audit (Nat Trans / Kleisli / Codensity)");

    # Natural transformation: ArrayRef ~> Option (head_option)
    my $expensive = [grep { $_->price >= 5000 } @$all_products];
    my $cheap     = [grep { $_->price <  1000 } @$all_products];

    my $top_item  = Shop::FP::HKT::head_option($expensive);
    my $cheap_hit = Shop::FP::HKT::head_option($cheap);
    Shop::Infra::Display::kv("head_option(expensive)", Shop::FP::HKT::show_option(
        Shop::FP::HKT::option_fmap($top_item, sub ($p) { $p->name })));
    Shop::Infra::Display::kv("head_option(cheap)", Shop::FP::HKT::show_option($cheap_hit));

    # Option monad: chain nullable stock check
    my $stock_msg = Shop::FP::HKT::option_bind($top_item, sub ($p) {
        $p->stock > 0 ? Some($p->name . ": " . $p->stock . " left") : None();
    });
    Shop::Infra::Display::kv("option_bind(stock)", Shop::FP::HKT::show_option($stock_msg));

    # Natural transformation round-trip: ArrayRef ~> Option ~> ArrayRef
    my $roundtrip = Shop::FP::HKT::option_to_list(
        Shop::FP::HKT::option_fmap($top_item, sub ($p) { $p->name }),
    );
    Shop::Infra::Display::kv("option_to_list . head", "[" . join(", ", @$roundtrip) . "]");

    # Kleisli composition: find -> classify pipeline
    my $find_and_classify = Shop::FP::HKT::kleisli(
        sub ($pid) {
            my $opt = Shop::Domain::Inventory::find_product($pid);
            Shop::FP::HKT::option_to_list(
                Shop::FP::HKT::option_fmap($opt, sub ($p) { $p }),
            );
        },
        sub ($p) { [$p->price >= 5000 ? "premium" : "standard"] },
    );
    Shop::Infra::Display::info("Kleisli (find -> classify):");
    for my $pid (ProductId("WIDGET"), ProductId("GADGET"), ProductId("GIZMO")) {
        my $r = $find_and_classify->($pid);
        Shop::Infra::Display::kv("  " . $pid->base, "" . $r->[0]);
    }

    # Codensity: right-associate bind chains via CPS
    my $products_c = Shop::FP::Codensity::lift_list($all_products);
    my $quarters   = Shop::FP::Codensity::lift_list([qw(Q1 Q2 Q3 Q4)]);

    my $projection = Shop::FP::Codensity::bind($products_c, sub ($p) {
        Shop::FP::Codensity::bind($quarters, sub ($q) {
            Shop::FP::Codensity::unit($p->name . "/" . $q);
        });
    });
    my $projected = Shop::FP::Codensity::lower_list($projection);
    Shop::Infra::Display::info("Codensity (product x quarter):");
    Shop::Infra::Display::list($projected);

    # mjoin: flatten nested audit data
    my $nested_audit = [[1, 2], [3], [4, 5, 6]];
    my $flat_audit = Shop::FP::HKT::mjoin($nested_audit);
    Shop::Infra::Display::kv("mjoin([[1,2],[3],[4,5,6]])", "[" . join(", ", @$flat_audit) . "]");

    Shop::Infra::Display::section_end();

    # ── 19:30  Closing Summary ──────────────────
    #
    #  Bounded quantification, bounded generic struct,
    #  record types, intersection types, variadic functions,
    #  row polymorphism, tuple types, ref() narrowing

    Shop::Infra::Display::section("19:30  Closing Summary (New Features)");

    # Row polymorphism: log_section wraps a body with Logger, passing other effects through
    Shop::Feature::Summary::log_section(sub ($title) {
        Shop::Infra::Display::info("Inside log_section: $title");
    }, "Summary Demo");
    Shop::Infra::Display::blank();

    # Tuple: price_breakdown returns Tuple[Int, Int, Int]
    my $breakdown = Shop::Feature::Summary::price_breakdown($alice_items, $alice_disc);
    my ($bd_sub, $bd_disc, $bd_final) = @$breakdown;
    Shop::Infra::Display::kv("Price breakdown (sub, disc, final)",
        "\$$bd_sub, -\$$bd_disc, = \$$bd_final");

    # Intersection types: format_displayable takes HasName & HasPrice
    my $displayable = +{ name => "Widget", price => 1500 };
    Shop::Infra::Display::kv("Displayable", Shop::Feature::Summary::format_displayable($displayable));

    # Record types: build_summary returns ProductQuery
    my $query = Shop::Feature::Summary::build_summary(1000, 5000);
    Shop::Infra::Display::kv("ProductQuery", "min=$query->{min_price}, max=$query->{max_price}, in_stock=$query->{in_stock}");

    # Bounded generic struct: Range[Int] + in_range
    my $price_range = Range(lo => 1000, hi => 5000);
    Shop::Infra::Display::kv("Range[Int]", "lo=" . $price_range->lo . ", hi=" . $price_range->hi);
    if (Shop::Feature::Summary::in_range(1500, $price_range)) {
        Shop::Infra::Display::kv("1500 in range?", "yes");
    } else {
        Shop::Infra::Display::kv("1500 in range?", "no");
    }
    if (Shop::Feature::Summary::in_range(8000, $price_range)) {
        Shop::Infra::Display::kv("8000 in range?", "yes");
    } else {
        Shop::Infra::Display::kv("8000 in range?", "no");
    }

    # Bounded generic struct: filter_by_price_range
    my $in_range_products = Shop::Feature::Summary::filter_by_price_range($all_products, $price_range);
    my $in_range_names = Functor::fmap($in_range_products, sub ($p) { $p->name . "(\$" . $p->price . ")" });
    Shop::Infra::Display::kv("Products in range", "[" . join(", ", @$in_range_names) . "]");

    # Bounded quantification: clamp, max_of, min_of
    Shop::Infra::Display::kv("clamp(9999, 0, 5000)", "" . Shop::Domain::Pricing::clamp(9999, 0, 5000));
    Shop::Infra::Display::kv("max_of(1500, 3200)",   "" . Shop::Domain::Pricing::max_of(1500, 3200));
    Shop::Infra::Display::kv("min_of(1500, 3200)",   "" . Shop::Domain::Pricing::min_of(1500, 3200));

    # Variadic function: labeled_list
    Shop::Infra::Display::labeled_list("Today's highlights:",
        "Alice: Premium customer, 15% discount",
        "Bob: Retry success with 3 Gizmos",
        "Charlie: Payment rejected, order cancelled",
    );

    # ref() narrowing: describe_value on different types
    Shop::Infra::Display::kv("describe(42)",       Shop::Feature::Summary::describe_value(42));
    Shop::Infra::Display::kv("describe([1,2,3])",  Shop::Feature::Summary::describe_value([1, 2, 3]));
    Shop::Infra::Display::kv("describe({a => 1})", Shop::Feature::Summary::describe_value({a => 1}));

    Shop::Infra::Display::section_end();

    # ── GADT: Shop Events ─────────────────────

    Shop::Infra::Display::section("GADT: Shop Events");

    my $order1_opt = Shop::Domain::Order::find_order(OrderId(1));
    match $order1_opt,
        Some => sub ($order1) {
            my $sale_event = Sale($order1);
            Shop::Infra::Display::info(Shop::Feature::Events::describe_event($sale_event));
            Shop::Infra::Display::kv("Revenue from sale", "" . Shop::Feature::Events::process_sale_event($order1));

            my $refund_event = Refund($order1, 3000);
            Shop::Infra::Display::info(Shop::Feature::Events::describe_event($refund_event));
        },
        None => sub () { Shop::Infra::Display::error_msg("Order #1 not found") };

    my $stock_qty = Shop::Feature::Events::process_stock_event(ProductId("GIZMO"));
    Shop::Infra::Display::kv("Stock check (Gizmo)", "$stock_qty remaining");

    Shop::Infra::Display::section_end();

    # ── Rank-2: Polymorphic Transform ─────────

    Shop::Infra::Display::section("Rank-2: Polymorphic Transform");

    my $identity = sub ($x) { $x };
    my $all_orders = Shop::Domain::Order::all_orders();
    my $transformed = Shop::Feature::Report::transform_all($identity, $all_orders);
    Shop::Infra::Display::info("transform_all(identity, orders): " . scalar(@$transformed) . " orders unchanged");

    Shop::Infra::Display::section_end();

    # ── TypeClass Showcase ────────────────────

    Shop::Infra::Display::section("TypeClass Showcase");

    Shop::Infra::Display::kv("Printable(42)",      Printable::display(42));
    Shop::Infra::Display::kv("Printable('hello')", Printable::display("hello"));
    Shop::Infra::Display::kv("Summarize(6545)",    Summarize::summarize(6545));
    Shop::Infra::Display::kv("Summarize('hello')", Summarize::summarize("hello"));

    match $order1_opt,
        Some => sub ($o1) { Shop::Infra::Display::kv("Order summary", Shop::Domain::Order::summarize_order($o1)) },
        None => sub ()    { };

    Shop::Infra::Display::section_end();

    # ── Protocol: Register Checkout ───────────

    Shop::Infra::Display::section("Protocol: Register Checkout");

    my $checkout_items :sig(ArrayRef[OrderItem]) = [
        OrderItem(product_id => ProductId("WIDGET"), quantity => 2, unit_price => 1500),
        OrderItem(product_id => ProductId("GADGET"), quantity => 1, unit_price => 3200),
    ];

    my $checkout_total = handle {
        Shop::Feature::Checkout::run_checkout($checkout_items, Cash());
    } Register => +{
        open_reg => sub ()           { Shop::Infra::Display::info("[reg] Register opened") },
        scan     => sub ($pid, $qty) { Shop::Infra::Display::info("[reg] Scan: " . $pid->base . " x$qty") },
        pay      => sub ($method)    { Shop::Infra::Display::info("[reg] Processing payment..."); 1 },
        complete => sub ()           {
            my $sum = 0;
            for my $item ($checkout_items->@*) {
                $sum += $item->unit_price * $item->quantity;
            }
            Shop::Infra::Display::success("[reg] Total: \$$sum");
            $sum;
        },
    };

    Shop::Infra::Display::kv("Checkout total", "\$$checkout_total");

    Shop::Infra::Display::section_end();

    # ── 20:00  Validation (累積エラー) ────────

    Shop::Infra::Display::section("20:00  Validation (Accumulating Errors)");

    # Validate individual product data
    my $v_name  = Shop::FP::Validation::result_to_validation(Shop::Feature::Analytics::validate_name("Widget Pro"));
    my $v_price = Shop::FP::Validation::result_to_validation(Shop::Feature::Analytics::validate_price(2500));
    my $v_qty   = Shop::FP::Validation::result_to_validation(Shop::Feature::Analytics::validate_quantity(10));

    my $v_product = Shop::FP::Validation::validation_lift_a3(
        sub ($name, $price, $qty) { "$name: \$$price x$qty" },
        $v_name, $v_price, $v_qty,
    );
    Shop::Infra::Display::kv("Valid product", Shop::FP::Validation::show_validation($v_product));

    # Now with multiple errors
    my $v_bad_name  = Shop::FP::Validation::result_to_validation(Shop::Feature::Analytics::validate_name(""));
    my $v_bad_price = Shop::FP::Validation::result_to_validation(Shop::Feature::Analytics::validate_price(-100));
    my $v_bad_qty   = Shop::FP::Validation::result_to_validation(Shop::Feature::Analytics::validate_quantity(-5));

    my $v_bad_product = Shop::FP::Validation::validation_lift_a3(
        sub ($name, $price, $qty) { "$name: \$$price x$qty" },
        $v_bad_name, $v_bad_price, $v_bad_qty,
    );
    Shop::Infra::Display::kv("Invalid product", Shop::FP::Validation::show_validation($v_bad_product));

    # Batch validation
    my $prices = [100, -50, 200, 0, 300];
    my $v_batch = Shop::FP::Validation::validate_all($prices, sub ($p) {
        $p > 0 ? Valid($p) : Invalid(["Invalid price: $p"]);
    });
    Shop::Infra::Display::kv("Batch validate prices", Shop::FP::Validation::show_validation(
        Shop::FP::Validation::validation_fmap($v_batch, sub ($arr) { "[" . join(", ", @$arr) . "]" }),
    ));

    # Validation <-> Result conversion
    my $back_to_result = Shop::FP::Validation::validation_to_result($v_bad_product);
    Shop::Infra::Display::kv("validation_to_result", Shop::FP::HKT::show_result($back_to_result));

    Shop::Infra::Display::section_end();

    # ── 20:30  Reader (設定注入) ──────────────

    Shop::Infra::Display::section("20:30  Reader (Environment Injection)");

    my $config = Shop::FP::Reader::ShopConfig(
        tax_rate                => 10,
        free_shipping_threshold => 5000,
        default_currency        => "\$",
    );

    # Simple readers
    my $widget_taxed = Shop::FP::Reader::run_reader(
        Shop::FP::Reader::price_with_tax(1500), $config,
    );
    Shop::Infra::Display::kv("Widget + tax(10%)", "\$$widget_taxed");

    my $ship_small = Shop::FP::Reader::run_reader(
        Shop::FP::Reader::shipping_cost(3000), $config,
    );
    my $ship_large = Shop::FP::Reader::run_reader(
        Shop::FP::Reader::shipping_cost(6000), $config,
    );
    Shop::Infra::Display::kv("Shipping (\$3,000 order)", "\$$ship_small");
    Shop::Infra::Display::kv("Shipping (\$6,000 order)", "\$$ship_large (free!)");

    # Composed reader: full order total
    my $order_total = Shop::FP::Reader::run_reader(
        Shop::FP::Reader::order_total_with_tax_and_shipping(7700), $config,
    );
    Shop::Infra::Display::kv("Order total (tax + shipping)", "\$$order_total");

    # local: temporarily override config
    my $high_tax_total = Shop::FP::Reader::run_reader(
        Shop::FP::Reader::local(
            sub ($cfg) { $cfg->with(tax_rate => 20) },
            Shop::FP::Reader::price_with_tax(1500),
        ),
        $config,
    );
    Shop::Infra::Display::kv("Widget + high tax(20%)", "\$$high_tax_total");

    # format_price
    my $formatted = Shop::FP::Reader::run_reader(
        Shop::FP::Reader::format_price(7700), $config,
    );
    Shop::Infra::Display::kv("Formatted price", $formatted);

    Shop::Infra::Display::section_end();

    # ── 21:00  State (純粋カート積み上げ) ────

    Shop::Infra::Display::section("21:00  State (Pure Cart Accumulation)");

    my $cart_computation = Shop::FP::State::state_bind(
        Shop::FP::State::add_to_cart(
            OrderItem(product_id => ProductId("WIDGET"), quantity => 3, unit_price => 1500),
        ),
        sub ($) {
            Shop::FP::State::state_bind(
                Shop::FP::State::add_to_cart(
                    OrderItem(product_id => ProductId("GADGET"), quantity => 2, unit_price => 3200),
                ),
                sub ($) {
                    Shop::FP::State::state_bind(
                        Shop::FP::State::add_to_cart(
                            OrderItem(product_id => ProductId("GIZMO"), quantity => 1, unit_price => 8000),
                        ),
                        sub ($) { Shop::FP::State::cart_summary() },
                    );
                },
            );
        },
    );

    my $summary_text = Shop::FP::State::eval_state($cart_computation, Shop::FP::State::empty_cart());
    Shop::Infra::Display::kv("Cart summary", $summary_text);

    my $final_cart = Shop::FP::State::exec_state($cart_computation, Shop::FP::State::empty_cart());
    Shop::Infra::Display::kv("Items in cart", scalar @{$final_cart->items});
    Shop::Infra::Display::kv("Running total", "\$" . $final_cart->running_total);
    Shop::Infra::Display::kv("Item count", "" . $final_cart->item_count);

    Shop::Infra::Display::section_end();

    # ── 21:30  Writer (価格監査証跡) ──────────

    Shop::Infra::Display::section("21:30  Writer (Price Audit Trail)");

    my $audit = Shop::FP::Writer::writer_bind(
        Shop::FP::Writer::subtotal_with_audit($alice_items),
        sub ($subtotal) {
            Shop::FP::Writer::writer_bind(
                Shop::FP::Writer::discount_with_audit($subtotal, $alice_disc),
                sub ($final) {
                    Shop::FP::Writer::writer_bind(
                        Shop::FP::Writer::tell("  Final price: \$$final"),
                        sub ($) { Shop::FP::Writer::writer_pure($final) },
                    );
                },
            );
        },
    );

    my ($audit_result, $audit_log) = @{Shop::FP::Writer::run_writer($audit)};
    Shop::Infra::Display::info("Audit trail for Alice's order:");
    for my $line (@$audit_log) {
        Shop::Infra::Display::info($line);
    }
    Shop::Infra::Display::kv("Audited total", "\$$audit_result");

    # Demonstrate censor: redact discount details
    my $censored = Shop::FP::Writer::censor(
        sub ($log) { [grep { $_ !~ /Discount/ } @$log] },
        $audit,
    );
    my ($_val, $censored_log) = @{Shop::FP::Writer::run_writer($censored)};
    Shop::Infra::Display::info("Censored trail (no discount lines):");
    for my $line (@$censored_log) {
        Shop::Infra::Display::info($line);
    }

    Shop::Infra::Display::section_end();

    # ── 22:00  Traversable (バッチ処理) ───────

    Shop::Infra::Display::section("22:00  Traversable (Batch Processing)");

    # sequence_result: all-or-nothing
    my $all_ok = Shop::FP::HKT::sequence_result([Ok(1), Ok(2), Ok(3)]);
    Shop::Infra::Display::kv("sequence [Ok 1..3]", Shop::FP::HKT::show_result(
        Shop::FP::HKT::result_fmap($all_ok, sub ($arr) { "[" . join(", ", @$arr) . "]" }),
    ));

    my $has_err = Shop::FP::HKT::sequence_result([Ok(1), Err("boom"), Ok(3)]);
    Shop::Infra::Display::kv("sequence [Ok,Err,Ok]", Shop::FP::HKT::show_result($has_err));

    # traverse_result: validate + collect
    my $valid_ids = Shop::FP::HKT::traverse_result(
        [ProductId("WIDGET"), ProductId("GADGET"), ProductId("GIZMO")],
        sub ($pid) {
            my $opt = Shop::Domain::Inventory::find_product($pid);
            match $opt,
                Some => sub ($p) { Ok($p->name . ": \$" . $p->price) },
                None => sub ()   { Err("Not found: " . $pid->base) };
        },
    );
    Shop::Infra::Display::kv("traverse products", Shop::FP::HKT::show_result(
        Shop::FP::HKT::result_fmap($valid_ids, sub ($arr) { "[" . join(", ", @$arr) . "]" }),
    ));

    # traverse with a missing product
    my $with_missing = Shop::FP::HKT::traverse_result(
        [ProductId("WIDGET"), ProductId("UNKNOWN"), ProductId("GIZMO")],
        sub ($pid) {
            my $opt = Shop::Domain::Inventory::find_product($pid);
            match $opt,
                Some => sub ($p) { Ok($p->name) },
                None => sub ()   { Err("Not found: " . $pid->base) };
        },
    );
    Shop::Infra::Display::kv("traverse w/ missing", Shop::FP::HKT::show_result($with_missing));

    # sequence_option
    my $all_some = Shop::FP::HKT::sequence_option([Some(10), Some(20), Some(30)]);
    Shop::Infra::Display::kv("sequence [Some 10..30]", Shop::FP::HKT::show_option(
        Shop::FP::HKT::option_fmap($all_some, sub ($arr) { "[" . join(", ", @$arr) . "]" }),
    ));

    my $has_none = Shop::FP::HKT::sequence_option([Some(10), None(), Some(30)]);
    Shop::Infra::Display::kv("sequence [Some,None,Some]", Shop::FP::HKT::show_option($has_none));

    # lift_a2_result: combine two results
    my $combined = Shop::FP::HKT::lift_a2_result(
        sub ($a, $b) { $a + $b },
        Ok(100), Ok(200),
    );
    Shop::Infra::Display::kv("lift_a2(+, Ok 100, Ok 200)", Shop::FP::HKT::show_result($combined));

    my $combined_err = Shop::FP::HKT::lift_a2_result(
        sub ($a, $b) { $a + $b },
        Err("no A"), Ok(200),
    );
    Shop::Infra::Display::kv("lift_a2(+, Err, Ok 200)", Shop::FP::HKT::show_result($combined_err));

    Shop::Infra::Display::section_end();

    Shop::Infra::Display::banner("Shop Closed");

} Logger         => Shop::Infra::Display::logger_handler(),
  PaymentGateway => +{
    charge => sub ($amount, $method) {
        match $method,
            Transfer => sub ($bank, $ac) { $bank ne "Shady Bank" ? 1 : 0 },
            Cash     => sub ()           { 1 },
            Card     => sub ($number)    { 1 };
    },
  },
  CustomerStore  => Shop::Infra::Store::customer_handler(),
  ProductStore   => Shop::Infra::Store::product_handler(),
  OrderStore     => Shop::Infra::Store::order_handler(),
  PaymentStore   => Shop::Infra::Store::payment_handler();
