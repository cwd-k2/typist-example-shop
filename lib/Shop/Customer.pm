package Shop::Customer;
use v5.40;
use Typist 'Str', 'Undef';
use Shop::Types;

# ── Struct ────────────────────────────────────

struct Customer => (
    id    => 'CustomerId',
    name  => Str,
    email => Str,
    phone => Str | Undef,
    tier  => 'CustomerTier',
);

# ── Internal Storage ──────────────────────────

my %customers;

# ── Public API ────────────────────────────────

sub register_customer :sig((CustomerId, Str, Str, Str | Undef) -> Customer ![Logger]) ($id, $name, $email, $phone = undef) {
    my $customer = Customer(
        id    => $id,
        name  => $name,
        email => $email,
        phone => $phone,
        tier  => Regular(),
    );
    $customers{$id->base} = $customer;
    Logger::log("Customer registered: $name");
    $customer;
}

sub find_customer :sig((CustomerId) -> Customer) ($id) {
    $customers{$id->base};
}

sub upgrade_to_premium :sig((CustomerId, Int) -> Customer ![Logger]) ($id, $points) {
    my $key = $id->base;
    my $customer = $customers{$key};
    $customer = $customer->with(tier => Premium($points));
    $customers{$key} = $customer;
    Logger::log("Customer " . $customer->name . " upgraded to Premium ($points pts)");
    $customer;
}

sub contact_info :sig((Customer) -> Str) ($customer) {
    if (defined($customer->phone)) {
        $customer->name . " <" . $customer->phone . ">";
    } else {
        $customer->name . " (no phone)";
    }
}

sub clear {
    %customers = ();
}

1;
