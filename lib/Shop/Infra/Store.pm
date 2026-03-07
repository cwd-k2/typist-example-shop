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

sub customer_handler :sig(() -> Handler[CustomerStore]) () {
    +{
        get_customer  => sub ($id) {
            my $key = CustomerId::coerce($id);
            exists $customers{$key} ? Some($customers{$key}) : None();
        },
        put_customer  => sub ($customer) {
            $customers{CustomerId::coerce($customer->id)} = $customer;
        },
        all_customers => sub () {
            [values %customers];
        },
    };
}

# ── ProductStore handler ─────────────────────

sub product_handler :sig(() -> Handler[ProductStore]) () {
    +{
        get_product  => sub ($id) {
            my $key = ProductId::coerce($id);
            exists $products{$key} ? Some($products{$key}) : None();
        },
        put_product  => sub ($product) {
            $products{ProductId::coerce($product->id)} = $product;
        },
        all_products => sub () {
            [values %products];
        },
    };
}

# ── OrderStore handler ───────────────────────

sub order_handler :sig(() -> Handler[OrderStore]) () {
    +{
        get_order  => sub ($id) {
            my $key = OrderId::coerce($id);
            exists $orders{$key} ? Some($orders{$key}) : None();
        },
        put_order  => sub ($order) {
            $orders{OrderId::coerce($order->id)} = $order;
        },
        all_orders => sub () {
            [values %orders];
        },
    };
}

# ── PaymentStore handler ─────────────────────

sub payment_handler :sig(() -> Handler[PaymentStore]) () {
    +{
        get_payment => sub ($id) {
            my $key = OrderId::coerce($id);
            exists $payments{$key} ? Some($payments{$key}) : None();
        },
        put_payment => sub ($id, $status) {
            $payments{OrderId::coerce($id)} = $status;
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
