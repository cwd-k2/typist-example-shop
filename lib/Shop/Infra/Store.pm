package Shop::Infra::Store;
use v5.40;
use Typist;
use Shop::Types;

use Exporter 'import';
our @EXPORT = ();

# ═══════════════════════════════════════════════════
#  Store — In-memory effect handlers
#
#  Each handler returns a hashref suitable for
#  use in `handle { ... } Effect => handler()`.
#  State is closed over in lexical hashes.
# ═══════════════════════════════════════════════════

my %customers;
my %products;
my %orders;
my %payments;

# ── CustomerStore handler ────────────────────

sub customer_handler  () {
    +{
        get_customer  => sub ($id) {
            my $key = $id->base;
            exists $customers{$key} ? Some($customers{$key}) : None();
        },
        put_customer  => sub ($customer) {
            $customers{$customer->id->base} = $customer;
        },
        all_customers => sub () {
            [values %customers];
        },
    };
}

# ── ProductStore handler ─────────────────────

sub product_handler  () {
    +{
        get_product  => sub ($id) {
            my $key = $id->base;
            exists $products{$key} ? Some($products{$key}) : None();
        },
        put_product  => sub ($product) {
            $products{$product->id->base} = $product;
        },
        all_products => sub () {
            [values %products];
        },
    };
}

# ── OrderStore handler ───────────────────────

sub order_handler  () {
    +{
        get_order  => sub ($id) {
            my $key = $id->base;
            exists $orders{$key} ? Some($orders{$key}) : None();
        },
        put_order  => sub ($order) {
            $orders{$order->id->base} = $order;
        },
        all_orders => sub () {
            [values %orders];
        },
    };
}

# ── PaymentStore handler ─────────────────────

sub payment_handler  () {
    +{
        get_payment => sub ($id) {
            my $key = $id->base;
            exists $payments{$key} ? Some($payments{$key}) : None();
        },
        put_payment => sub ($id, $status) {
            $payments{$id->base} = $status;
        },
    };
}

# ── Reset ────────────────────────────────────

sub clear :sig(() -> Void) () {
    %customers = ();
    %products  = ();
    %orders    = ();
    %payments  = ();
}

1;
