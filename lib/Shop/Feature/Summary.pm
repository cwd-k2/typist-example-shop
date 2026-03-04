package Shop::Feature::Summary;
use v5.40;
use Typist;
use Shop::Types;
use Shop::Domain::Pricing;
use Shop::Infra::Display;
use Shop::FP::HKT;

# ═══════════════════════════════════════════════════
#  Summary — Demonstrates new typist features:
#    row polymorphism, tuples, intersection types,
#    record types, bounded generic structs, ref narrowing
# ═══════════════════════════════════════════════════

# ── Row Polymorphism ─────────────────────────
#
# Logger is required; additional effects `r` are
# passed through transparently.

sub log_section :sig(<A, r: Row>((Str) -> A ![r], Str) -> A ![Logger, r]) ($body, $title) {
    Logger::log(Info(), ">>> $title");
    my $result = $body->($title);
    Logger::log(Info(), "<<< $title done");
    $result;
}

# ── Tuple ─────────────────────────────────────
#
# Tuple[Int, Int, Int] = (subtotal, discount_amount, final)

sub price_breakdown :sig((ArrayRef[OrderItem], DiscountPct) -> Tuple[Int, Int, Int]) ($items, $pct) {
    my $subtotal :sig(Int) = Shop::Domain::Pricing::order_subtotal($items);
    my $final    :sig(Int) = Shop::Domain::Pricing::apply_discount($subtotal, $pct);
    my $discount = $subtotal - $final;
    [$subtotal, $discount, $final];
}

# ── Intersection Types ──────────────────────
#
# Displayable = HasName & HasPrice

sub format_displayable :sig((Displayable) -> Str) ($item) {
    $item->{name} . ": " . $item->{price} . " yen";
}

# ── Record Types ─────────────────────────────
#
# ProductQuery = Record(min_price => Int, max_price => Int, in_stock? => Bool)

sub build_summary :sig((Int, Int) -> ProductQuery) ($min, $max) {
    +{ min_price => $min, max_price => $max, in_stock => 1 };
}

# ── Bounded Generic Struct ───────────────────
#
# Range[T: Num] — constrain T to Num

sub in_range :sig(<T: Num>(T, Range[T]) -> Bool) ($val, $range) {
    $val >= $range->lo && $val <= $range->hi;
}

sub filter_by_price_range :sig((ArrayRef[Product], Range[Int]) -> ArrayRef[Product]) ($products, $range) {
    Shop::FP::HKT::filter($products, sub ($p) {
        in_range($p->price, $range);
    });
}

# ── ref() Narrowing ─────────────────────────
#
# Pattern match on runtime ref() to narrow Any

sub describe_value :sig((Any) -> Str) ($val) {
    if (!ref($val)) {
        "scalar: $val";
    } elsif (ref($val) eq 'ARRAY') {
        "array of " . scalar(@$val) . " elements";
    } elsif (ref($val) eq 'HASH') {
        "hash with keys: " . join(", ", sort keys %$val);
    } else {
        "ref: " . ref($val);
    }
}

# ── isa Narrowing ──────────────────────────
#
# Union type narrowed by isa check on blessed struct name

sub describe_entity :sig((Product | Customer) -> Str) ($entity) {
    if ($entity isa Typist::Struct::Product) {
        $entity->name . " (\$" . $entity->price . ")";
    } else {
        $entity->name . " <" . $entity->email . ">";
    }
}

# ── Early Return Narrowing ─────────────────
#
# Optional field narrowed after early return guard

sub require_product_name :sig((Product) -> Str) ($product) {
    return "unnamed" unless defined($product->description);
    "Product: " . $product->name . " — " . $product->description;
}

# ── HashRef[Str, Int] in :sig() ───────────

sub price_index :sig((ArrayRef[Product]) -> HashRef[Str, Int]) ($products) {
    my %index;
    for my $p (@$products) {
        $index{$p->name} = $p->price;
    }
    \%index;
}

# ── Inline Record in :sig() (probe) ──────

sub format_item_record :sig((Record(name => Str, qty => Int, price => Int)) -> Str) ($item) {
    $item->{name} . " x" . $item->{qty} . " @ \$" . $item->{price};
}

# ── PriceBand (Tuple field) ──────────────

sub make_price_band :sig((Str, Price, Price) -> PriceBand) ($name, $lo, $hi) {
    PriceBand(name => $name, bounds => [$lo, $hi]);
}

sub in_price_band :sig((Price, PriceBand) -> Bool) ($price, $band) {
    my ($lo, $hi) = @{$band->bounds};
    $price >= $lo && $price <= $hi;
}

# ── Literal union return (probe) ─────────

sub stock_level :sig((Product) -> 0 | 1 | 2) ($product) {
    my $s = $product->stock;
    $s == 0 ? 0 : $s < 10 ? 1 : 2;
}

1;
