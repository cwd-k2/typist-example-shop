package Shop::Func::Reader;
use v5.40;
use Typist 'Int', 'Str';
use Shop::Types;

use Exporter 'import';
our @EXPORT = ();

# ═══════════════════════════════════════════════════
#  Reader — Environment injection monad
#
#  Reader E A  ~=  E -> A
#
#  Thread a read-only environment through a
#  computation without explicit parameter passing.
#  `ask` retrieves the environment, `local` modifies
#  it for a sub-computation.
# ═══════════════════════════════════════════════════

BEGIN {
    struct ShopConfig => (
        tax_rate                => Int,
        free_shipping_threshold => 'Price',
        default_currency        => Str,
    );
}

# ── Core Operations ───────────────────────────
#
# Reader E A is represented as a closure E -> A.
# E is specialized to ShopConfig (the only environment in this module).

# reader : (ShopConfig -> A) -> Reader ShopConfig A
sub reader :sig(<A>((ShopConfig) -> A) -> (ShopConfig) -> A) ($f) { $f }

# run_reader : Reader ShopConfig A -> ShopConfig -> A
sub run_reader :sig(<A>((ShopConfig) -> A, ShopConfig) -> A) ($r, $env) { $r->($env) }

# reader_pure : A -> Reader ShopConfig A
sub reader_pure :sig(<A>(A) -> (ShopConfig) -> A) ($a) {
    sub ($env) { $a };
}

# reader_fmap : Reader ShopConfig A -> (A -> B) -> Reader ShopConfig B
sub reader_fmap :sig(<A, B>((ShopConfig) -> A, (A) -> B) -> (ShopConfig) -> B) ($r, $f) {
    sub ($env) { $f->($r->($env)) };
}

# reader_bind : Reader ShopConfig A -> (A -> Reader ShopConfig B) -> Reader ShopConfig B
sub reader_bind :sig(<A, B>((ShopConfig) -> A, (A) -> (ShopConfig) -> B) -> (ShopConfig) -> B) ($r, $f) {
    sub ($env) { $f->($r->($env))->($env) };
}

# ask : Reader ShopConfig ShopConfig
sub ask :sig(() -> (ShopConfig) -> ShopConfig) () {
    sub ($env) { $env };
}

# asks : (ShopConfig -> A) -> Reader ShopConfig A
sub asks :sig(<A>((ShopConfig) -> A) -> (ShopConfig) -> A) ($f) {
    sub ($env) { $f->($env) };
}

# local : (ShopConfig -> ShopConfig) -> Reader ShopConfig A -> Reader ShopConfig A
sub local :sig(<A>((ShopConfig) -> ShopConfig, (ShopConfig) -> A) -> (ShopConfig) -> A) ($modify, $r) {
    sub ($env) { $r->($modify->($env)) };
}

# ── Shop-specific Readers ────────────────────

# price_with_tax : Price -> Reader ShopConfig Price
sub price_with_tax :sig((Price) -> (ShopConfig) -> Price) ($price) {
    sub ($cfg) { int($price * (100 + $cfg->tax_rate) / 100) };
}

# shipping_cost : Price -> Reader ShopConfig Price
sub shipping_cost :sig((Price) -> (ShopConfig) -> Price) ($subtotal) {
    sub ($cfg) {
        $subtotal >= $cfg->free_shipping_threshold ? 0 : 500;
    };
}

# format_price : Price -> Reader ShopConfig Str
sub format_price :sig((Price) -> (ShopConfig) -> Str) ($price) {
    sub ($cfg) { $cfg->default_currency . $price };
}

# order_total_with_tax_and_shipping : Price -> Reader ShopConfig Price
sub order_total_with_tax_and_shipping :sig((Price) -> (ShopConfig) -> Price) ($subtotal) {
    sub ($cfg) {
        my $with_tax :sig(Price) = price_with_tax($subtotal)->($cfg);
        my $shipping :sig(Price) = shipping_cost($subtotal)->($cfg);
        my $total :sig(Price) = $with_tax + $shipping;
        $total;
    };
}

1;
