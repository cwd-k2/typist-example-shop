package Shop::Feature::Analytics;
use v5.40;
use Typist;
use Shop::Types;
use Shop::FP::HKT;

use Exporter 'import';
our @EXPORT = ();

# ═══════════════════════════════════════════════════
#  Analytics — Aggregate shop data
#
#  HKT integration:
#    product_prices via Functor::fmap
#    total_value    via Foldable::foldr + Functor::fmap
#    filter_valid   via cat_results
# ═══════════════════════════════════════════════════

# ── Safe lookups (Option-returning wrappers) ─────

sub safe_find :sig((ArrayRef[Product], ProductId) -> Option[Product]) ($products, $id) {
    my $target = ProductId::coerce($id);
    for my $p (@$products) {
        return Some($p) if ProductId::coerce($p->id) eq $target;
    }
    None();
}

sub safe_head :sig((ArrayRef[Product]) -> Option[Product]) ($products) {
    return None() unless @$products;
    Some($products->[0]);
}

# ── Result pipelines ─────────────────────────────

sub validate_price :sig((Int) -> Result[Int]) ($price) {
    return Err("Price must be positive, got $price") unless $price > 0;
    Ok($price);
}

sub validate_quantity :sig((Int) -> Result[Int]) ($qty) {
    return Err("Quantity must be positive, got $qty") unless $qty > 0;
    Ok($qty);
}

sub validate_name :sig((Str) -> Result[Str]) ($name) {
    return Err("Name must not be empty") unless length($name) > 0;
    Ok($name);
}

sub find_or_error :sig((ArrayRef[Product], ProductId) -> Result[Product]) ($products, $id) {
    match safe_find($products, $id),
        Some => sub ($p) { Ok($p) },
        None => sub ()   { Err("Product not found: " . ProductId::coerce($id)) };
}

# ── Aggregation (HKT patterns) ───────────────────

# HKT: Functor::fmap + fold_sum
sub total_value :sig((ArrayRef[Product]) -> Int) ($products) {
    my $values = Functor::fmap($products, sub ($p) { $p->price * $p->stock });
    Shop::FP::HKT::fold_sum($values);
}

# HKT: Functor::fmap for projection
sub product_prices :sig((ArrayRef[Product]) -> ArrayRef[Int]) ($products) {
    Functor::fmap($products, sub ($p) { $p->price });
}

# HKT: cat_results for filtering
sub filter_valid :sig(<A>(ArrayRef[A], (A) -> Result[A]) -> ArrayRef[A]) ($items, $validate) {
    my $results = Functor::fmap($items, $validate);
    Shop::FP::HKT::cat_results($results);
}

# ── Statistics ───────────────────────────────────

sub price_stats :sig((ArrayRef[Product]) -> Option[ArrayRef[Int]]) ($products) {
    return None() unless @$products;
    my $min = $products->[0]->price;
    my $max = $min;
    for my $p (@$products) {
        $min = $p->price if $p->price < $min;
        $max = $p->price if $p->price > $max;
    }
    Some([$min, $max]);
}

sub average_price :sig((ArrayRef[Product]) -> Option[Int]) ($products) {
    return None() unless @$products;
    my $sum :sig(Int) = 0;
    $sum += $_->price for @$products;
    my $avg :sig(Int) = int($sum / scalar @$products);
    Some($avg);
}

# ── Category grouping ───────────────────────────

sub by_category :sig((ArrayRef[Product]) -> HashRef[ArrayRef[Product]]) ($products) {
    my %groups;
    for my $p (@$products) {
        my $cat = $p->category // "uncategorized";
        push @{$groups{$cat}}, $p;
    }
    \%groups;
}

sub categorize :sig((Product) -> Option[Str]) ($product) {
    return None() unless defined($product->category);
    Some($product->category);
}

# ── Pipeline composition ─────────────────────────

sub checked_product :sig((ArrayRef[Product], ProductId, Int) -> Result[Product]) ($products, $id, $min_stock) {
    my $found = find_or_error($products, $id);
    match $found,
        Ok  => sub ($p) {
            return Err("Low stock: " . $p->name) unless $p->stock >= $min_stock;
            Ok($p);
        },
        Err => sub ($e) { Err($e) };
}

1;
