package Shop::App::Demo;
use v5.40;
use Typist;
use Shop::Types;
use Shop::Instances;
use Shop::Infra::Display;
use Shop::Infra::Store;
use Shop::Domain::Inventory;
use Shop::Domain::Order;
use Shop::Domain::Payment;
use Shop::Domain::Pricing;
use Shop::Feature::Analytics;
use Shop::Feature::Checkout;
use Shop::Feature::Classify;
use Shop::Feature::Events;
use Shop::Feature::Pipeline;
use Shop::Feature::Report;
use Shop::Feature::ScopedEffects;
use Shop::Feature::Summary;
use Shop::FP::HKT;
use Shop::FP::Validation;
use Shop::FP::Reader;
use Shop::FP::State;
use Shop::FP::Writer;

# ═══════════════════════════════════════════════════
#  Demo — Feature showcase functions
#
#  Each demo_* function exercises a specific type
#  system or FP feature.  All execute within the
#  caller's effect handler scope.
# ═══════════════════════════════════════════════════

# ── Orchestration ───────────────────────────

sub run_all ($alice, $alice_disc, $alice_items, $all_products) {
    demo_gadt_events();
    demo_rank2_transform();
    demo_typeclass_showcase();
    demo_protocol_checkout();
    demo_validation();
    demo_reader();
    demo_state();
    demo_writer($alice_items, $alice_disc);
    demo_traversable();
    demo_typeclass_hierarchy();
    demo_type_narrowing($alice);
    demo_advanced_patterns();
    demo_multi_param_generics();
    demo_type_annotations($all_products, $alice);
    demo_protocol_pipeline();
    demo_scoped_effects();
}

# ── GADT: Shop Events ──────────────────────

sub demo_gadt_events {
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
}

# ── Rank-2: Polymorphic Transform ──────────

sub demo_rank2_transform {
    Shop::Infra::Display::section("Rank-2: Polymorphic Transform");

    my $identity :sig(forall A. (A) -> A) = sub ($x) { $x };
    my $all_orders = Shop::Domain::Order::all_orders();
    my $transformed = Shop::Feature::Report::transform_all($identity, $all_orders);
    Shop::Infra::Display::info("transform_all(identity, orders): " . scalar(@$transformed) . " orders unchanged");

    Shop::Infra::Display::section_end();
}

# ── TypeClass Showcase ─────────────────────

sub demo_typeclass_showcase {
    Shop::Infra::Display::section("TypeClass Showcase");

    Shop::Infra::Display::kv("Printable(42)",      Printable::display(42));
    Shop::Infra::Display::kv("Printable('hello')", Printable::display("hello"));
    Shop::Infra::Display::kv("Summarize(6545)",    Summarize::summarize(6545));
    Shop::Infra::Display::kv("Summarize('hello')", Summarize::summarize("hello"));

    my $order1_opt = Shop::Domain::Order::find_order(OrderId(1));
    match $order1_opt,
        Some => sub ($o1) { Shop::Infra::Display::kv("Order summary", Shop::Domain::Order::summarize_order($o1)) },
        None => sub ()    { };

    Shop::Infra::Display::section_end();
}

# ── Protocol: Register Checkout ─────────────

sub demo_protocol_checkout {
    Shop::Infra::Display::section("Protocol: Register Checkout");

    my $checkout_items :sig(ArrayRef[OrderItem]) = [
        OrderItem(product_id => ProductId("WIDGET"), quantity => 2, unit_price => 1500),
        OrderItem(product_id => ProductId("GADGET"), quantity => 1, unit_price => 3200),
    ];

    my $checkout_total = handle {
        Shop::Feature::Checkout::run_checkout($checkout_items, Cash());
    } Register => +{
        open_reg => sub ()           { Shop::Infra::Display::info("[reg] Register opened") },
        scan     => sub ($pid, $qty) { Shop::Infra::Display::info("[reg] Scan: " . ProductId::coerce($pid) . " x$qty") },
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
}

# ── Validation ─────────────────────────────

sub demo_validation {
    Shop::Infra::Display::section("20:00  Validation (Accumulating Errors)");

    my $v_name  = Shop::FP::Validation::result_to_validation(Shop::Feature::Analytics::validate_name("Widget Pro"));
    my $v_price = Shop::FP::Validation::result_to_validation(Shop::Feature::Analytics::validate_price(2500));
    my $v_qty   = Shop::FP::Validation::result_to_validation(Shop::Feature::Analytics::validate_quantity(10));

    my $v_product = Shop::FP::Validation::validation_lift_a3(
        sub ($name, $price, $qty) { "$name: \$$price x$qty" },
        $v_name, $v_price, $v_qty,
    );
    Shop::Infra::Display::kv("Valid product", Shop::FP::Validation::show_validation($v_product));

    my $v_bad_name  = Shop::FP::Validation::result_to_validation(Shop::Feature::Analytics::validate_name(""));
    my $v_bad_price = Shop::FP::Validation::result_to_validation(Shop::Feature::Analytics::validate_price(-100));
    my $v_bad_qty   = Shop::FP::Validation::result_to_validation(Shop::Feature::Analytics::validate_quantity(-5));

    my $v_bad_product = Shop::FP::Validation::validation_lift_a3(
        sub ($name, $price, $qty) { "$name: \$$price x$qty" },
        $v_bad_name, $v_bad_price, $v_bad_qty,
    );
    Shop::Infra::Display::kv("Invalid product", Shop::FP::Validation::show_validation($v_bad_product));

    my $prices = [100, -50, 200, 0, 300];
    my $v_batch = Shop::FP::Validation::validate_all($prices, sub ($p) {
        $p > 0 ? Valid($p) : Invalid(["Invalid price: $p"]);
    });
    Shop::Infra::Display::kv("Batch validate prices", Shop::FP::Validation::show_validation(
        Shop::FP::Validation::validation_fmap($v_batch, sub ($arr) { "[" . join(", ", @$arr) . "]" }),
    ));

    my $back_to_result = Shop::FP::Validation::validation_to_result($v_bad_product);
    Shop::Infra::Display::kv("validation_to_result", Shop::FP::HKT::show_result($back_to_result));

    Shop::Infra::Display::section_end();
}

# ── Reader ─────────────────────────────────

sub demo_reader {
    Shop::Infra::Display::section("20:30  Reader (Environment Injection)");

    my $config = Shop::FP::Reader::ShopConfig(
        tax_rate                => 10,
        free_shipping_threshold => 5000,
        default_currency        => "\$",
    );

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

    my $order_total = Shop::FP::Reader::run_reader(
        Shop::FP::Reader::order_total_with_tax_and_shipping(7700), $config,
    );
    Shop::Infra::Display::kv("Order total (tax + shipping)", "\$$order_total");

    my $high_tax_total = Shop::FP::Reader::run_reader(
        Shop::FP::Reader::local(
            sub ($cfg) { ShopConfig::derive($cfg, tax_rate => 20) },
            Shop::FP::Reader::price_with_tax(1500),
        ),
        $config,
    );
    Shop::Infra::Display::kv("Widget + high tax(20%)", "\$$high_tax_total");

    my $formatted = Shop::FP::Reader::run_reader(
        Shop::FP::Reader::format_price(7700), $config,
    );
    Shop::Infra::Display::kv("Formatted price", $formatted);

    Shop::Infra::Display::section_end();
}

# ── State ──────────────────────────────────

sub demo_state {
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
}

# ── Writer ─────────────────────────────────

sub demo_writer ($alice_items, $alice_disc) {
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
}

# ── Traversable ────────────────────────────

sub demo_traversable {
    Shop::Infra::Display::section("22:00  Traversable (Batch Processing)");

    my $all_ok = Shop::FP::HKT::sequence_result([Ok(1), Ok(2), Ok(3)]);
    Shop::Infra::Display::kv("sequence [Ok 1..3]", Shop::FP::HKT::show_result(
        Shop::FP::HKT::result_fmap($all_ok, sub ($arr) { "[" . join(", ", @$arr) . "]" }),
    ));

    my $has_err = Shop::FP::HKT::sequence_result([Ok(1), Err("boom"), Ok(3)]);
    Shop::Infra::Display::kv("sequence [Ok,Err,Ok]", Shop::FP::HKT::show_result($has_err));

    my $valid_ids = Shop::FP::HKT::traverse_result(
        [ProductId("WIDGET"), ProductId("GADGET"), ProductId("GIZMO")],
        sub ($pid) {
            my $opt = Shop::Domain::Inventory::find_product($pid);
            match $opt,
                Some => sub ($p) { Ok($p->name . ": \$" . $p->price) },
                None => sub ()   { Err("Not found: " . ProductId::coerce($pid)) };
        },
    );
    Shop::Infra::Display::kv("traverse products", Shop::FP::HKT::show_result(
        Shop::FP::HKT::result_fmap($valid_ids, sub ($arr) { "[" . join(", ", @$arr) . "]" }),
    ));

    my $with_missing = Shop::FP::HKT::traverse_result(
        [ProductId("WIDGET"), ProductId("UNKNOWN"), ProductId("GIZMO")],
        sub ($pid) {
            my $opt = Shop::Domain::Inventory::find_product($pid);
            match $opt,
                Some => sub ($p) { Ok($p->name) },
                None => sub ()   { Err("Not found: " . ProductId::coerce($pid)) };
        },
    );
    Shop::Infra::Display::kv("traverse w/ missing", Shop::FP::HKT::show_result($with_missing));

    my $all_some = Shop::FP::HKT::sequence_option([Some(10), Some(20), Some(30)]);
    Shop::Infra::Display::kv("sequence [Some 10..30]", Shop::FP::HKT::show_option(
        Shop::FP::HKT::option_fmap($all_some, sub ($arr) { "[" . join(", ", @$arr) . "]" }),
    ));

    my $has_none = Shop::FP::HKT::sequence_option([Some(10), None(), Some(30)]);
    Shop::Infra::Display::kv("sequence [Some,None,Some]", Shop::FP::HKT::show_option($has_none));

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
}

# ── Typeclass Hierarchy & Constraints ──────

sub demo_typeclass_hierarchy {
    Shop::Infra::Display::section("22:30  Typeclass Hierarchy & Constraints");

    my $sorted_prices = Shop::Feature::Classify::sort_by([3200, 1500, 8000]);
    Shop::Infra::Display::kv("sort_by([3200,1500,8000])", "[" . join(", ", @$sorted_prices) . "]");

    my $max_price = Shop::Feature::Classify::max_by([3200, 1500, 8000]);
    match $max_price,
        Some => sub ($v) { Shop::Infra::Display::kv("max_by(prices)", "$v") },
        None => sub ()   { Shop::Infra::Display::kv("max_by(prices)", "empty") };

    Shop::Infra::Display::kv("show_all(ints)", Shop::Feature::Classify::show_all([42, 7, 256], ", "));
    Shop::Infra::Display::kv("show_all(strs)", Shop::Feature::Classify::show_all(["hello", "world"], " | "));

    Shop::Infra::Display::kv("display_sorted", Shop::Feature::Classify::display_sorted([256, 7, 42]));

    my $widget_opt2 = Shop::Domain::Inventory::find_product(ProductId("WIDGET"));
    my $gadget_opt  = Shop::Domain::Inventory::find_product(ProductId("GADGET"));

    match $widget_opt2,
        Some => sub ($p) { Shop::Infra::Display::info("Convertible: " . Shop::Feature::Classify::convert_product($p)) },
        None => sub ()   { };
    match $gadget_opt,
        Some => sub ($p) { Shop::Infra::Display::info("Convertible: " . Shop::Feature::Classify::convert_product($p)) },
        None => sub ()   { };

    my $order1_opt = Shop::Domain::Order::find_order(OrderId(1));
    match $order1_opt,
        Some => sub ($o1) { Shop::Infra::Display::info("Convertible: " . Shop::Feature::Classify::convert_order($o1)) },
        None => sub ()    { };

    Shop::Infra::Display::section_end();
}

# ── Type Narrowing Patterns ─────────────────

sub demo_type_narrowing ($alice) {
    Shop::Infra::Display::section("23:00  Type Narrowing Patterns");

    my $widget_opt2 = Shop::Domain::Inventory::find_product(ProductId("WIDGET"));
    my $widget_for_isa;
    match $widget_opt2,
        Some => sub ($p) { $widget_for_isa = $p },
        None => sub ()   { };

    Shop::Infra::Display::kv("describe(Product)", Shop::Feature::Summary::describe_entity($widget_for_isa));
    Shop::Infra::Display::kv("describe(Customer)", Shop::Feature::Summary::describe_entity($alice));

    Shop::Infra::Display::kv("require(Widget)", Shop::Feature::Summary::require_product_name($widget_for_isa));

    my $gizmo_for_narrow;
    my $gizmo_opt2 = Shop::Domain::Inventory::find_product(ProductId("GIZMO"));
    match $gizmo_opt2,
        Some => sub ($p) { $gizmo_for_narrow = $p },
        None => sub ()   { };
    Shop::Infra::Display::kv("require(Gizmo)", Shop::Feature::Summary::require_product_name($gizmo_for_narrow));

    Shop::Infra::Display::section_end();
}

# ── Advanced Patterns ──────────────────────

sub demo_advanced_patterns {
    Shop::Infra::Display::section("23:30  Advanced Patterns");

    declare format_currency => '(Int) -> Str';
    sub format_currency :sig((Int) -> Str) ($amount) {
        "\$" . int($amount / 100) . "." . sprintf("%02d", $amount % 100);
    }
    Shop::Infra::Display::kv("format_currency(15999)", format_currency(15999));

    sub unreachable :sig(() -> Never) () { die "unreachable" }
    Shop::Infra::Display::info("Never type: unreachable() declared (not called)");

    # Nested handlers: inner handler shadows outer
    my $outer_log = "";
    my $inner_log = "";
    handle {
        Logger::log(Info(), "outer message");
        handle {
            Logger::log(Info(), "inner message");
        } Logger => +{
            log       => sub ($level, $msg) { $inner_log .= "[inner] $msg; " },
            log_entry => sub ($entry)       { $inner_log .= "[inner] " . $entry->message . "; " },
        };
        Logger::log(Info(), "back to outer");
    } Logger => +{
        log       => sub ($level, $msg) { $outer_log .= "[outer] $msg; " },
        log_entry => sub ($entry)       { $outer_log .= "[outer] " . $entry->message . "; " },
    };
    Shop::Infra::Display::kv("Outer handler", $outer_log);
    Shop::Infra::Display::kv("Inner handler", $inner_log);
    Shop::Infra::Display::blank();

    my $tree :sig(CategoryTree) = ["Electronics", ["Phones", "Tablets"], "Clothing"];
    Shop::Infra::Display::kv("CategoryTree", "nested structure with :sig(CategoryTree)");

    my $json :sig(Json) = +{
        name  => "Widget",
        price => 1500,
        tags  => ["sale", "popular"],
        meta  => +{ active => 1 },
    };
    Shop::Infra::Display::kv("Json", "native Perl data with :sig(Json)");

    Shop::Infra::Display::section_end();
}

# ── Multi-Param Generics ──────────────────

sub demo_multi_param_generics {
    Shop::Infra::Display::section("00:30  Multi-Param Generics");

    my $pair_ss = Pair(fst => "color", snd => "blue");
    Shop::Infra::Display::kv("Pair[Str,Str]", $pair_ss->fst . " = " . $pair_ss->snd);

    my $pair_si = Pair(fst => "weight", snd => 150);
    Shop::Infra::Display::kv("Pair[Str,Int]", $pair_si->fst . " = " . $pair_si->snd);

    my $labeled_int = Labeled(label => "unit_price", value => 1500);
    Shop::Infra::Display::kv("Labeled[Int]", Shop::Feature::Classify::display_labeled($labeled_int));

    my $band = Shop::Feature::Summary::make_price_band("mid-range", 1000, 5000);
    Shop::Infra::Display::kv("PriceBand", $band->name . " [" . $band->bounds->[0] . ", " . $band->bounds->[1] . "]");
    Shop::Infra::Display::kv("1500 in band?",
        Shop::Feature::Summary::in_price_band(1500, $band) ? "yes" : "no");
    Shop::Infra::Display::kv("8000 in band?",
        Shop::Feature::Summary::in_price_band(8000, $band) ? "yes" : "no");

    Shop::Infra::Display::section_end();
}

# ── Type Annotation Extensions ─────────────

sub demo_type_annotations ($all_products, $alice) {
    Shop::Infra::Display::section("01:00  Type Annotation Extensions");

    my $p_index = Shop::Feature::Summary::price_index($all_products);
    my @idx_entries = map { "$_=\$$p_index->{$_}" } sort keys %$p_index;
    Shop::Infra::Display::kv("price_index", join(", ", @idx_entries));

    my $record_str = Shop::Feature::Summary::format_item_record(
        +{ name => "Widget", qty => 3, price => 1500 },
    );
    Shop::Infra::Display::kv("format_item_record", $record_str);

    my $widget_opt2 = Shop::Domain::Inventory::find_product(ProductId("WIDGET"));
    match $widget_opt2,
        Some => sub ($p) { Shop::Infra::Display::kv("display(Product)", Shop::Feature::Classify::display_product($p)) },
        None => sub ()   { };
    Shop::Infra::Display::kv("display(Customer)", Shop::Feature::Classify::display_customer($alice));

    Shop::Infra::Display::kv("describe(Cash)", Shop::Feature::Classify::describe_payment(Cash()));
    Shop::Infra::Display::kv("describe(Card)", Shop::Feature::Classify::describe_payment(Card("1234")));

    my $num_id :sig(forall A: Num. (A) -> A) = sub ($x) { $x };
    Shop::Infra::Display::kv("bounded forall(42)", "" . $num_id->(42));
    Shop::Infra::Display::kv("bounded forall(3.14)", "" . $num_id->(3.14));

    match $widget_opt2,
        Some => sub ($p) { Shop::Infra::Display::kv("stock_level(Widget)", "" . Shop::Feature::Summary::stock_level($p)) },
        None => sub ()   { };
    my $gizmo_opt2 = Shop::Domain::Inventory::find_product(ProductId("GIZMO"));
    match $gizmo_opt2,
        Some => sub ($p) { Shop::Infra::Display::kv("stock_level(Gizmo)", "" . Shop::Feature::Summary::stock_level($p)) },
        None => sub ()   { };

    Shop::Infra::Display::section_end();
}

# ── Protocol: Contracts & Superposition ─────

sub demo_protocol_pipeline {
    Shop::Infra::Display::section("01:30  Protocol: Contracts & Superposition");

    my $make_pipeline = sub () {
        my ($buf, $meta) = ("", "");
        +{
            ingest   => sub ($d) { $buf = $d; $meta = "" },
            validate => sub ()   { length($buf) > 0 },
            enrich   => sub ($m) { $meta = $m },
            inspect  => sub ()   { "data='$buf'" . ($meta ? " meta='$meta'" : "") },
            emit     => sub ()   {
                my $r = $buf . ($meta ? " [$meta]" : "");
                ($buf, $meta) = ("", "");
                $r;
            },
        };
    };

    my $full_result = handle {
        Shop::Feature::Pipeline::run_full("Widget Pro|2500|50", "electronics");
    } Pipeline => $make_pipeline->();
    Shop::Infra::Display::kv("Full pipeline", $full_result);

    my $with_enrich = handle {
        Shop::Feature::Pipeline::process("Gadget X|5000|10", 1);
    } Pipeline => $make_pipeline->();
    Shop::Infra::Display::kv("Superposition (enriched)", $with_enrich);

    my $without_enrich = handle {
        Shop::Feature::Pipeline::process("Gadget X|5000|10", 0);
    } Pipeline => $make_pipeline->();
    Shop::Infra::Display::kv("Superposition (plain)", $without_enrich);

    my $invariant_result = handle {
        Shop::Feature::Pipeline::ingest_and_validate("Gizmo Z|9000|3");
        my $snap = Shop::Feature::Pipeline::peek();
        Shop::Infra::Display::info("  peek (invariant): $snap");
        Shop::Feature::Pipeline::peek();
    } Pipeline => $make_pipeline->();
    Shop::Infra::Display::kv("Invariant peek x2", $invariant_result);

    my $composed_result = handle {
        Shop::Feature::Pipeline::ingest_and_validate("Sensor|4200|8");
        Shop::Feature::Pipeline::peek();
        Pipeline::emit();
    } Pipeline => $make_pipeline->();
    Shop::Infra::Display::kv("Composed (validate -> peek -> emit)", $composed_result);
    Shop::Infra::Display::blank();

    my $contract_ok = handle {
        Shop::Feature::Pipeline::process("Widget|2500|50", 1);
    } Pipeline => Shop::Feature::Pipeline::contract_handler();
    Shop::Infra::Display::kv("Contract (pass)", $contract_ok);

    my $contract_fail = handle {
        Shop::Feature::Pipeline::process("bad data", 0);
    } Pipeline => Shop::Feature::Pipeline::contract_handler(),
      Exn      => +{
        throw => sub ($err) { chomp $err; "FAILED: $err" },
    };
    Shop::Infra::Display::error_msg("Contract (fail): $contract_fail");

    Shop::Infra::Display::section_end();
}

# ── Scoped Effects ───────────────────────────

sub demo_scoped_effects {
    Shop::Infra::Display::section("Scoped Effects: Identity-Based Dispatch");

    Shop::Infra::Display::info("── Per-category sales tracking ──");
    Shop::Feature::ScopedEffects::run_category_tracking();

    say "";
    Shop::Infra::Display::info("── Mixed dispatch (scoped + name-based) ──");
    Shop::Feature::ScopedEffects::run_mixed_dispatch();

    say "";
    Shop::Infra::Display::info("── Exception safety ──");
    Shop::Feature::ScopedEffects::run_exception_safety();

    Shop::Infra::Display::section_end();
}

1;
