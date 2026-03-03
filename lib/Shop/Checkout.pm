package Shop::Checkout;
use v5.40;
use Typist;
use Shop::Types;

# ═══════════════════════════════════════════════════
#  Checkout — Protocol-enabled effect for register sessions
#
#  Demonstrates effect protocols: the register must follow
#  a strict lifecycle of scan → pay → complete.
#
#  State machine:
#    Idle ──scan──→ Scanning ──pay──→ Paying ──complete──→ Done
#                    ↑──scan──┘
# ═══════════════════════════════════════════════════

BEGIN {
    effect 'Register', [qw(Idle Scanning Paying Done)] => +{
        scan     => [ '(ProductId, Quantity) -> Void', protocol('Scanning -> Scanning') ],
        open_reg => [ '() -> Void', protocol('Idle -> Scanning') ],
        pay      => [ '(PaymentMethod) -> Bool', protocol('Scanning -> Paying') ],
        complete => [ '() -> Price', protocol('Paying -> Done') ],
      };
}

# ── Session Operations ────────────────────────

# Open + scan items
sub start_checkout :sig((ArrayRef[OrderItem]) -> Void ![Register<Idle -> Scanning>, Logger]) ($items) {
    Register::open_reg();
    Logger::log("Register opened");

    for my $item ( $items->@* ) {
        Register::scan( $item->product_id, $item->quantity );
        Logger::log(
            "Scanned " . $item->product_id->base . " x" . $item->quantity );
    }
}

# Pay and complete
sub finalize_checkout :sig((PaymentMethod) -> Price ![Register<Scanning -> Done>, Logger]) ($method) {
    my $ok = Register::pay($method);
    Logger::log( "Payment " . ( $ok ? "accepted" : "rejected" ) );

    my $total = Register::complete();
    Logger::log("Checkout complete: total \$$total");
    $total;
}

# Full session: Idle → Done
sub run_checkout :sig((ArrayRef[OrderItem], PaymentMethod) -> Price ![Register<Idle -> Done>, Logger]) ($items, $method) {
    start_checkout($items);
    finalize_checkout($method);
}

1;
