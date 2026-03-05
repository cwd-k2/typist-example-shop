package Shop::Domain::Inventory;
use v5.40;
use Typist;
use Shop::Types;
use Shop::FP::HKT;

# ═══════════════════════════════════════════════════
#  Inventory — Product and stock management
#
#  Storage delegated to ProductStore effect.
#  HKT integration: product_names via Functor::fmap.
# ═══════════════════════════════════════════════════

# ── Public API ────────────────────────────────

sub add_product :sig((Product) -> Bool ![ProductStore]) ($product) {
    ProductStore::put_product($product);
    1;
}

sub find_product :sig((ProductId) -> Option[Product] ![ProductStore]) ($id) {
    ProductStore::get_product($id);
}

sub in_stock :sig((ProductId, Quantity) -> Bool ![ProductStore]) ($id, $qty) {
    my $opt = ProductStore::get_product($id);
    Shop::FP::HKT::option_or(
        Shop::FP::HKT::option_fmap($opt, sub ($p) { my $s = $p->stock; $s >= $qty }),
        0,
    );
}

sub deduct_stock :sig((ProductId, Quantity) -> Result[Quantity] ![Logger, ProductStore]) ($id, $qty) {
    my $opt = ProductStore::get_product($id);
    match $opt,
        Some => sub ($product) {
            if ($product->stock < $qty) {
                Logger::log(Warn(), "Stock insufficient for " . $product->name . ": need $qty, have " . $product->stock);
                return Err("Insufficient stock for " . $product->name . " (need $qty, have " . $product->stock . ")");
            }
            my $new_stock = $product->stock - $qty;
            ProductStore::put_product(Product::derive($product, stock => $new_stock));
            Logger::log(Info(), "Deducted $qty x " . $product->name . " (remaining: $new_stock)");
            Ok($new_stock);
        },
        None => sub () {
            Err("Product not found");
        };
}

sub restock :sig((ProductId, Quantity) -> Quantity ![Logger, ProductStore]) ($id, $qty) {
    my $opt = ProductStore::get_product($id);
    Shop::FP::HKT::option_or(
        Shop::FP::HKT::option_fmap($opt, sub ($product) {
            my $new_stock = $product->stock + $qty;
            ProductStore::put_product(Product::derive($product, stock => $new_stock));
            Logger::log(Info(), "Restocked $qty x " . $product->name . " (now: $new_stock)");
            $new_stock;
        }),
        0,
    );
}

sub all_products :sig(() -> ArrayRef[Product] ![ProductStore]) () {
    ProductStore::all_products();
}

sub filter_products :sig(((Product) -> Bool, ArrayRef[Product]) -> ArrayRef[Product]) ($pred, $products) {
    Shop::FP::HKT::filter($products, $pred);
}

# HKT integration: Functor::fmap for projection
sub product_names :sig((ArrayRef[Product]) -> ArrayRef[Str]) ($products) {
    Functor::fmap($products, sub ($p) { $p->name });
}

1;
