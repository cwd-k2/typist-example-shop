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
# Core combinators are polymorphic over E and A;
# Typist's :sig() cannot express (E -> A) as a
# first-class type parameter, so these remain untyped.
# Shop-specific readers below are concretely typed.

# reader : (E -> A) -> Reader E A
sub reader ($f) { $f }

# run_reader : Reader E A -> E -> A
sub run_reader ($r, $env) { $r->($env) }

# reader_pure : A -> Reader E A
sub reader_pure ($a) {
    sub ($env) { $a };
}

# reader_fmap : Reader E A -> (A -> B) -> Reader E B
sub reader_fmap ($r, $f) {
    sub ($env) { $f->($r->($env)) };
}

# reader_bind : Reader E A -> (A -> Reader E B) -> Reader E B
sub reader_bind ($r, $f) {
    sub ($env) { $f->($r->($env))->($env) };
}

# ask : Reader E E
sub ask () {
    sub ($env) { $env };
}

# asks : (E -> A) -> Reader E A
sub asks ($f) {
    sub ($env) { $f->($env) };
}

# local : (E -> E) -> Reader E A -> Reader E A
sub local ($modify, $r) {
    sub ($env) { $r->($modify->($env)) };
}

# ── Shop-specific Readers ────────────────────

# price_with_tax : Price -> Reader ShopConfig Price
sub price_with_tax :sig((Price) -> (ShopConfig) -> Price) ($price) {
    asks(sub ($cfg) { int($price * (100 + $cfg->tax_rate) / 100) });
}

# shipping_cost : Price -> Reader ShopConfig Price
sub shipping_cost :sig((Price) -> (ShopConfig) -> Price) ($subtotal) {
    asks(sub ($cfg) {
        $subtotal >= $cfg->free_shipping_threshold ? 0 : 500;
    });
}

# format_price : Price -> Reader ShopConfig Str
sub format_price :sig((Price) -> (ShopConfig) -> Str) ($price) {
    asks(sub ($cfg) { $cfg->default_currency . $price });
}

# order_total_with_tax_and_shipping : Price -> Reader ShopConfig Price
sub order_total_with_tax_and_shipping ($subtotal) {
    reader_bind(price_with_tax($subtotal), sub ($with_tax) {
        reader_bind(shipping_cost($subtotal), sub ($shipping) {
            reader_pure($with_tax + $shipping);
        });
    });
}

1;
