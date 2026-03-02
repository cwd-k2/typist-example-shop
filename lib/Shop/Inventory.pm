package Shop::Inventory;
use v5.40;
use Typist;
use Shop::Types;

# ── Internal Storage ──────────────────────────

my %products;

# ── Public API ────────────────────────────────

sub add_product :sig((Product) -> Bool) ($product) {
    my $id = $product->id->base;
    $products{$id} = $product;
    1;
}

sub find_product :sig((ProductId) -> Product) ($id) {
    my $key = $id->base;
    $products{$key};
}

sub in_stock :sig((ProductId, Quantity) -> Bool) ($id, $qty) {
    my $key = $id->base;
    my $product = $products{$key} // return 0;
    $product->stock >= $qty ? 1 : 0;
}

sub deduct_stock :sig((ProductId, Quantity) -> Result[Quantity] ![Logger]) ($id, $qty) {
    my $key = $id->base;
    my $product = $products{$key};
    if ($product->stock < $qty) {
        Logger::log("Stock insufficient for " . $product->name . ": need $qty, have " . $product->stock);
        return Err("Insufficient stock for " . $product->name . " (need $qty, have " . $product->stock . ")");
    }
    my $new_stock = $product->stock - $qty;
    $products{$key} = $product->with(stock => $new_stock);
    Logger::log("Deducted $qty × " . $product->name . " (remaining: $new_stock)");
    Ok($new_stock);
}

sub restock :sig((ProductId, Quantity) -> Quantity ![Logger]) ($id, $qty) {
    my $key = $id->base;
    my $product = $products{$key};
    my $new_stock = $product->stock + $qty;
    $products{$key} = $product->with(stock => $new_stock);
    Logger::log("Restocked $qty × " . $product->name . " (now: $new_stock)");
    $new_stock;
}

sub all_products :sig(() -> ArrayRef[Product]) () {
    [values %products];
}

sub filter_products :sig(((Product) -> Bool, ArrayRef[Product]) -> ArrayRef[Product]) ($pred, $products) {
    my @result;
    for my $p (@$products) {
        push @result, $p if $pred->($p);
    }
    \@result;
}

sub product_names :sig((ArrayRef[Product]) -> ArrayRef[Str]) ($products) {
    my @names;
    for my $p (@$products) {
        push @names, $p->name;
    }
    \@names;
}

sub clear {
    %products = ();
}

1;
