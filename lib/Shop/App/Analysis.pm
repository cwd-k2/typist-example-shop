package Shop::App::Analysis;
use v5.40;
use Typist;
use Shop::Types;
use Shop::Infra::Display;
use Shop::Domain::Inventory;
use Shop::Domain::Pricing;
use Shop::Feature::Summary;
use Shop::FP::HKT;
use Shop::FP::Codensity;

# ═══════════════════════════════════════════════════
#  Analysis — HKT, FP, and summary demonstrations
#
#  Exercises Functor, Foldable, Monad, Codensity,
#  natural transformations, Kleisli composition,
#  bounded quantification, intersection types,
#  record types, and ref() narrowing.
# ═══════════════════════════════════════════════════

# ── Orchestration ───────────────────────────

sub run_all :sig((Customer, DiscountPct, ArrayRef[OrderItem]) -> ArrayRef[Product]) ($alice, $alice_disc, $alice_items) {
    my $all_products = inventory_analysis();
    night_audit($all_products);
    closing_summary($alice_items, $alice_disc, $all_products);
    $all_products;
}

# ── Inventory Analysis ──────────────────────

sub inventory_analysis {
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
            [ ProductId::coerce($pid) . " x$qty" ];
        });
    });
    Shop::Infra::Display::info("Restock candidates:");
    Shop::Infra::Display::list($restock_plan);

    Shop::Infra::Display::section_end();

    return $all_products;
}

# ── Night Audit ─────────────────────────────

sub night_audit ($all_products) {
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
        Shop::Infra::Display::kv("  " . ProductId::coerce($pid), "" . $r->[0]);
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
}

# ── Closing Summary ─────────────────────────

sub closing_summary ($alice_items, $alice_disc, $all_products) {
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
    Shop::Infra::Display::kv("1500 in range?",
        Shop::Feature::Summary::in_range(1500, $price_range) ? "yes" : "no");
    Shop::Infra::Display::kv("8000 in range?",
        Shop::Feature::Summary::in_range(8000, $price_range) ? "yes" : "no");

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
}

1;
