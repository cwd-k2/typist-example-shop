package Shop::Payment;
use v5.40;
use Typist;
use Shop::Types;

# ── Internal Storage ──────────────────────────

my %payments;  # order_key => PaymentStatus

# ── Payment Processing ────────────────────────

sub process_payment :sig((OrderId, Price, PaymentMethod) -> Result[PaymentStatus] ![Logger, PaymentGateway]) ($order_id, $amount, $method) {
    my $key = $order_id->base;

    my $desc = match $method,
        Cash     => sub ()           { "cash" },
        Card     => sub ($number)    { "card ending " . substr($number, -4) },
        Transfer => sub ($bank, $ac) { "transfer $bank/$ac" };

    Logger::log("Processing payment for order #$key: $amount via $desc");

    my $ok = PaymentGateway::charge($amount, $method);

    if ($ok) {
        $payments{$key} = Completed();
        Logger::log("Payment completed for order #$key: $amount");
        Ok(Completed());
    } else {
        $payments{$key} = Failed();
        Logger::log("Payment failed for order #$key: $amount");
        Err("Payment declined via $desc");
    }
}

# ── Refund Processing ─────────────────────────

sub refund_payment :sig((OrderId, Price) -> Result[PaymentStatus] ![Logger]) ($order_id, $amount) {
    my $key    = $order_id->base;
    my $status = $payments{$key};

    # @typist-ignore — Err<T> free var T unresolvable without expected-type propagation
    match $status,
        Completed => sub () {
            $payments{$key} = Refunded();
            Logger::log("Refunded $amount for order #$key");
            Ok(Refunded());
        },
        Refunded => sub () {
            Logger::log("Cannot refund order #$key: already refunded");
            Err("Already refunded");
        },
        Pending => sub () {
            Logger::log("Cannot refund order #$key: payment is Pending");
            Err("Cannot refund: payment is Pending");
        },
        Failed => sub () {
            Logger::log("Cannot refund order #$key: payment is Failed");
            Err("Cannot refund: payment is Failed");
        };
}

sub show_payment_status :sig((PaymentStatus) -> Str) ($status) {
    match $status,
        Pending   => sub { "Pending" },
        Completed => sub { "Completed" },
        Failed    => sub { "Failed" },
        Refunded  => sub { "Refunded" };
}

sub clear {
    %payments = ();
}

1;
