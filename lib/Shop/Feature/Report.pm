package Shop::Feature::Report;
use v5.40;
use Typist;
use Shop::Types;
use Shop::Domain::Order;
use Shop::Func::HKT;

# ═══════════════════════════════════════════════════
#  Report — Daily report generation and analytics
#
#  HKT integration:
#    order_totals via Functor::fmap
#    revenue_orders via filter
# ═══════════════════════════════════════════════════

# ── Report Generation ─────────────────────────

sub build_daily_report :sig(() -> ReportNode[Int] ![Logger, OrderStore]) () {
    my $orders = Shop::Domain::Order::all_orders();
    Logger::log(Info(), "Generating daily report for " . scalar(@$orders) . " orders");

    my $total_revenue   :sig(Int) = 0;
    my $confirmed_count :sig(Int) = 0;
    my $cancelled_count :sig(Int) = 0;
    my $fulfilled_count :sig(Int) = 0;
    my @order_nodes;

    for my $order (@$orders) {
        my $order_key = $order->id->base;
        my $value     = $order->total;

        my $label = match $order->status,
            Created   => sub {
                "Created";
            },
            Confirmed => sub {
                $total_revenue += $value;
                $confirmed_count++;
                "Confirmed";
            },
            Fulfilled => sub {
                $total_revenue += $value;
                $fulfilled_count++;
                "Fulfilled";
            },
            Cancelled => sub ($reason) {
                $cancelled_count++;
                "Cancelled";
            };

        push @order_nodes, ReportNode(
            label    => "Order #$order_key ($label)",
            value    => $value,
            children => [],
        );
    }

    my $summary = ReportNode(
        label    => "Daily Summary",
        value    => $total_revenue,
        children => [
            ReportNode(label => "Confirmed",  value => $confirmed_count, children => []),
            ReportNode(label => "Fulfilled",  value => $fulfilled_count, children => []),
            ReportNode(label => "Cancelled",  value => $cancelled_count, children => []),
        ],
    );

    Logger::log(Info(), "Report complete: revenue=$total_revenue");

    ReportNode(
        label    => "End of Day Report",
        value    => $total_revenue,
        children => [$summary, @order_nodes],
    );
}

# HKT integration: filter for revenue orders
sub revenue_orders :sig((ArrayRef[Order]) -> ArrayRef[Order]) ($orders) {
    Shop::Func::HKT::filter($orders, sub ($o) {
        match $o->status,
            Confirmed => sub          { 1 },
            Fulfilled => sub          { 1 },
            Created   => sub          { 0 },
            Cancelled => sub ($reason) { 0 };
    });
}

# HKT integration: Functor::fmap for projection
sub order_totals :sig((ArrayRef[Order]) -> ArrayRef[Int]) ($orders) {
    Functor::fmap($orders, sub ($o) { $o->total });
}

# ── Rank-2 Polymorphism ───────────────────────

sub transform_all :sig((forall A. A -> A, ArrayRef[Order]) -> ArrayRef[Order]) ($f, $orders) {
    my @result = map { $f->($_) } @$orders;
    \@result;
}

# ── Report Formatting ─────────────────────────

sub format_report :sig(<T>(ReportNode[T], Int) -> Str) ($node, $indent) {
    my $pad  = "  " x $indent;
    my $line = $pad . $node->label . ": " . $node->value;

    my $result = $line;
    for my $child ($node->children->@*) {
        $result .= "\n" . format_report($child, $indent + 1);
    }
    $result;
}

1;
