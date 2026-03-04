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

# ── Triple (Tuple Encoding) ──────────────────
#
# Triple[Int, Int, Int] = (subtotal, discount_amount, final)

sub price_breakdown :sig((ArrayRef[OrderItem], DiscountPct) -> Triple[Int, Int, Int]) ($items, $pct) {
    my $subtotal :sig(Int) = Shop::Domain::Pricing::order_subtotal($items);
    my $final    :sig(Int) = Shop::Domain::Pricing::apply_discount($subtotal, $pct);
    my $discount :sig(Int) = $subtotal - $final;
    Triple($subtotal, $discount, $final);
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
    if ($val >= $range->lo && $val <= $range->hi) { 1 } else { 0 }
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

1;
