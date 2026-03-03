package Shop::Domain::Customer;
use v5.40;
use Typist 'Str', 'Undef';
use Shop::Types;
use Shop::Func::HKT;

# ═══════════════════════════════════════════════════
#  Customer — Registration and tier management
#
#  Storage delegated to CustomerStore effect.
#  All mutations go through put_customer; all
#  queries through get_customer/all_customers.
# ═══════════════════════════════════════════════════

# ── Public API ────────────────────────────────

sub register_customer :sig((CustomerId, Str, Str, Str | Undef) -> Customer ![Logger, CustomerStore]) ($id, $name, $email, $phone = undef) {
    my $customer = Customer(
        id    => $id,
        name  => $name,
        email => $email,
        phone => $phone,
        tier  => Regular(),
    );
    CustomerStore::put_customer($customer);
    Logger::log(Info(), "Customer registered: $name");
    $customer;
}

sub find_customer :sig((CustomerId) -> Option[Customer] ![CustomerStore]) ($id) {
    CustomerStore::get_customer($id);
}

sub upgrade_to_premium :sig((CustomerId, Int) -> Result[Customer] ![Logger, CustomerStore]) ($id, $points) {
    my $opt = CustomerStore::get_customer($id);
    match $opt,
        Some => sub ($customer) {
            my $upgraded = $customer->with(tier => Premium($points));
            CustomerStore::put_customer($upgraded);
            Logger::log(Info(), "Customer " . $upgraded->name . " upgraded to Premium ($points pts)");
            Ok($upgraded);
        },
        None => sub () {
            Err("Customer not found");
        };
}

sub contact_info :sig((Customer) -> Str) ($customer) {
    if (defined($customer->phone)) {
        $customer->name . " <" . $customer->phone . ">";
    } else {
        $customer->name . " (no phone)";
    }
}

1;
