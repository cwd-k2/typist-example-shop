package Shop::Feature::ScopedEffects;
use v5.40;
use Typist;
use Shop::Types;
use Shop::Infra::Display;

# ═══════════════════════════════════════════════════
#  Scoped Effects — Identity-based handler dispatch
#
#  Name-based effects (State::get()) share a single
#  handler stack.  Scoped effects use capability tokens
#  for independent, identity-based dispatch:
#
#    my $a = scoped 'Accumulator[Int]';
#    my $b = scoped 'Accumulator[Int]';
#    # $a and $b are independent — each gets its own handler
# ═══════════════════════════════════════════════════

# ── Per-category sales tracking ──────────────────
#
# Simulate tracking sales totals for different product
# categories independently during a batch of orders.

sub run_category_tracking :sig(() -> Void ![Logger]) () {
    my $electronics = scoped 'Accumulator[Int]';
    my $clothing    = scoped 'Accumulator[Int]';
    my $food        = scoped 'Accumulator[Int]';

    my ($e_total, $c_total, $f_total) = (0, 0, 0);

    handle {
        handle {
            handle {
                # Process a batch of sales
                _process_sale($electronics, "Laptop",   89900);
                _process_sale($clothing,    "T-Shirt",   2500);
                _process_sale($electronics, "Mouse",     3500);
                _process_sale($food,        "Coffee",     800);
                _process_sale($clothing,    "Jeans",     5900);
                _process_sale($food,        "Sandwich",   650);
                _process_sale($electronics, "Keyboard",  7200);

                Shop::Infra::Display::kv("Electronics total",
                    "\$" . $electronics->read());
                Shop::Infra::Display::kv("Clothing total",
                    "\$" . $clothing->read());
                Shop::Infra::Display::kv("Food total",
                    "\$" . $food->read());

            } $food => +{
                read  => sub ()   { $f_total },
                add   => sub ($v) { $f_total += $v },
                reset => sub ()   { $f_total = 0 },
            };
        } $clothing => +{
            read  => sub ()   { $c_total },
            add   => sub ($v) { $c_total += $v },
            reset => sub ()   { $c_total = 0 },
        };
    } $electronics => +{
        read  => sub ()   { $e_total },
        add   => sub ($v) { $e_total += $v },
        reset => sub ()   { $e_total = 0 },
    };

    Shop::Infra::Display::info(
        "Grand total: \$" . ($e_total + $c_total + $f_total)
    );
}

sub _process_sale ($acc, $item, $price) {
    $acc->add($price);
    Logger::log(Info(), "  Sale: $item \$$price");
}

# ── Scoped + name-based coexistence ──────────────
#
# Scoped handlers and name-based handlers in one block.

sub run_mixed_dispatch :sig(() -> Void ![Logger]) () {
    my $counter = scoped 'Accumulator[Int]';
    my $state = 0;

    handle {
        Logger::log(Info(), "Processing 3 items...");

        $counter->add(100);
        $counter->add(200);
        $counter->add(300);

        Logger::log(Info(), "Running total: \$" . $counter->read());
    } $counter => +{
        read  => sub ()   { $state },
        add   => sub ($v) { $state += $v },
        reset => sub ()   { $state = 0 },
    };
    # Logger handler comes from the outer scope — coexistence

    Shop::Infra::Display::kv("Final accumulator", "\$$state");
}

# ── Exception safety ─────────────────────────────
#
# Scoped handlers are cleaned up even on exceptions.

sub run_exception_safety :sig(() -> Void ![Logger]) () {
    my $acc = scoped 'Accumulator[Int]';
    my $state = 0;

    my $result = handle {
        $acc->add(500);
        $acc->add(300);
        die "payment failed\n";
        $acc->add(200);    # unreachable
    } $acc => +{
        read  => sub ()   { $state },
        add   => sub ($v) { $state += $v },
        reset => sub ()   { $state = 0 },
    },
    Exn => +{
        throw => sub ($err) {
            Logger::log(Warn(), "Caught: $err");
            "recovered (partial: \$$state)";
        },
    };

    Shop::Infra::Display::kv("Recovery result", "$result");
    Shop::Infra::Display::kv("State before error", "\$$state");
}

1;
