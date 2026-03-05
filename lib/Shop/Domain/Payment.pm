package Shop::Domain::Payment;
use v5.40;
use Typist;
use Shop::Types;
use Shop::FP::HKT;

# ═══════════════════════════════════════════════════
#  Payment — Payment processing with effects
#
#  Storage delegated to PaymentStore effect.
# ═══════════════════════════════════════════════════

# ── Payment Processing ────────────────────────

sub process_payment :sig((OrderId, Price, PaymentMethod) -> Result[PaymentStatus] ![Logger, PaymentGateway, PaymentStore]) ($order_id, $amount, $method) {
    my $key = OrderId::coerce($order_id);

    my $desc = match $method,
        Cash     => sub ()           { "cash" },
        Card     => sub ($number)    { "card ending " . substr($number, -4) },
        Transfer => sub ($bank, $ac) { "transfer $bank/$ac" };

    Logger::log(Info(), "Processing payment for order #$key: $amount via $desc");

    my $ok = PaymentGateway::charge($amount, $method);

    if ($ok) {
        PaymentStore::put_payment($order_id, Completed());
        Logger::log(Info(), "Payment completed for order #$key: $amount");
        Ok(Completed());
    } else {
        PaymentStore::put_payment($order_id, Failed());
        Logger::log(Error(), "Payment failed for order #$key: $amount");
        Err("Payment declined via $desc");
    }
}

# ── Refund Processing ─────────────────────────

sub refund_payment :sig((OrderId, Price) -> Result[PaymentStatus] ![Logger, PaymentStore]) ($order_id, $amount) {
    my $key = OrderId::coerce($order_id);
    my $opt = PaymentStore::get_payment($order_id);

    match $opt,
        Some => sub ($status) {
            match $status,
                Completed => sub () {
                    PaymentStore::put_payment($order_id, Refunded());
                    Logger::log(Info(), "Refunded $amount for order #$key");
                    Ok(Refunded());
                },
                Refunded => sub () {
                    Logger::log(Warn(), "Cannot refund order #$key: already refunded");
                    Err("Already refunded");
                },
                Pending => sub () {
                    Logger::log(Warn(), "Cannot refund order #$key: payment is Pending");
                    Err("Cannot refund: payment is Pending");
                },
                Failed => sub () {
                    Logger::log(Warn(), "Cannot refund order #$key: payment is Failed");
                    Err("Cannot refund: payment is Failed");
                };
        },
        None => sub () {
            Err("Payment not found for order #$key");
        };
}

sub show_payment_status :sig((PaymentStatus) -> Str) ($status) {
    match $status,
        Pending   => sub { "Pending" },
        Completed => sub { "Completed" },
        Failed    => sub { "Failed" },
        Refunded  => sub { "Refunded" };
}

1;
