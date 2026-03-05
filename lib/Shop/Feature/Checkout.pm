package Shop::Feature::Checkout;
use v5.40;
use Typist;
use Shop::Types;

# ═══════════════════════════════════════════════════
#  Checkout — Protocol-enabled effect for register sessions
#
#  Demonstrates effect protocols: the register must follow
#  a strict lifecycle of scan -> pay -> complete.
#
#  State machine:
#    * --open--> Scanning --pay--> Paying --complete--> *
#                 ^--scan--/
# ═══════════════════════════════════════════════════

BEGIN {
    effect Register => qw/Scanning Paying/ => +{
        scan     => protocol('(ProductId, Quantity) -> Void', 'Scanning -> Scanning'),
        open_reg => protocol('() -> Void', '* -> Scanning'),
        pay      => protocol('(PaymentMethod) -> Bool', 'Scanning -> Paying'),
        complete => protocol('() -> Price', 'Paying -> *'),
    };
}

# ── Session Operations ────────────────────────

sub start_checkout :sig((ArrayRef[OrderItem]) -> Void ![Register<* -> Scanning>, Logger]) ($items) {
    Register::open_reg();
    Logger::log(Info(), "Register opened");

    for my $item ( $items->@* ) {
        Register::scan( $item->product_id, $item->quantity );
        Logger::log(Debug(), "Scanned " . ProductId::coerce($item->product_id) . " x" . $item->quantity);
    }
}

sub finalize_checkout :sig((PaymentMethod) -> Price ![Register<Scanning -> *>, Logger]) ($method) {
    my $ok = Register::pay($method);
    Logger::log(Info(), "Payment " . ( $ok ? "accepted" : "rejected" ));

    my $total = Register::complete();
    Logger::log(Info(), "Checkout complete: total \$$total");
    $total;
}

sub run_checkout :sig((ArrayRef[OrderItem], PaymentMethod) -> Price ![Register, Logger]) ($items, $method) {
    start_checkout($items);
    finalize_checkout($method);
}

1;
