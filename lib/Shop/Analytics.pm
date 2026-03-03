package Shop::Analytics;
use v5.40;
use Typist 'Int', 'Str';
use Shop::Types;

use Exporter 'import';
our @EXPORT = ();

# ═══════════════════════════════════════════════════
#  Analytics — Aggregate shop data
#
#  Exercises inference across several patterns:
#  Result/Option chaining, nested generics, HOFs
#  with ADT returns, match-based pipelines.
# ═══════════════════════════════════════════════════

# ── Safe lookups (Option-returning wrappers) ─────

sub safe_find :sig((ArrayRef[Product], ProductId) -> Option[Product]) ($products, $id) {
    my $target = $id->base;
    for my $p (@$products) {
        return Some($p) if $p->id->base eq $target;
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

# Unannotated: exercises guard-return + ADT constructor inference
sub validate_name ($name) {
    return Err("Name must not be empty") unless length($name) > 0;
    Ok($name);
}

# Unannotated: exercises match on imported ADT (Option → Result conversion)
sub find_or_error ($products, $id) {
    match safe_find($products, $id),
        Some => sub ($p) { Ok($p) },
        None => sub ()   { Err("Product not found: " . $id->base) };
}

# ── Aggregation (map/fold patterns) ──────────────

sub total_value :sig((ArrayRef[Product]) -> Int) ($products) {
    my $sum :sig(Int) = 0;
    for my $p (@$products) {
        $sum += $p->price * $p->stock;
    }
    $sum;
}

# Unannotated: exercises accumulator + accessor inference
sub product_prices ($products) {
    my @prices;
    for my $p (@$products) {
        push @prices, $p->price;
    }
    \@prices;
}

# Unannotated: higher-order filter with Result match
sub filter_valid ($items, $validate) {
    my @ok;
    for my $item (@$items) {
        my $result = $validate->($item);
        match $result,
            Ok  => sub ($v) { push @ok, $v },
            Err => sub ($e) { };
    }
    \@ok;
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

# Unannotated: exercises Option constructor with nested computation
sub average_price ($products) {
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

# Unannotated: exercises defined-narrowing + early-return Option
sub categorize ($product) {
    return None() unless defined($product->category);
    Some($product->category);
}

# ── Pipeline composition ─────────────────────────

# Unannotated: exercises chained match (Result → Result)
sub checked_product ($products, $id, $min_stock) {
    my $found = find_or_error($products, $id);
    match $found,
        Ok  => sub ($p) {
            return Err("Low stock: " . $p->name) unless $p->stock >= $min_stock;
            Ok($p);
        },
        Err => sub ($e) { Err($e) };
}

1;
