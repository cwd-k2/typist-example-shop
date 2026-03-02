package Shop::Report;
use v5.40;
use Typist;
use Shop::Types;
use Shop::Order;

# ── Report Generation ─────────────────────────

sub build_daily_report :sig(() -> ReportNode ![Logger]) () {
    my $orders = Shop::Order::all_orders();
    Logger::log("Generating daily report for " . scalar(@$orders) . " orders");

    my @order_summaries = map { Shop::Order::summarize_order($_) } @$orders;

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

    Logger::log("Report complete: revenue=$total_revenue");

    ReportNode(
        label    => "End of Day Report",
        value    => $total_revenue,
        children => [$summary, @order_nodes],
    );
}

sub revenue_orders :sig((ArrayRef[Order]) -> ArrayRef[Order]) ($orders) {
    my @result;
    for my $o (@$orders) {
        my $include = match $o->status,
            Confirmed => sub          { 1 },
            Fulfilled => sub          { 1 },
            Created   => sub          { 0 },
            Cancelled => sub ($reason) { 0 };
        push @result, $o if $include;
    }
    \@result;
}

sub order_totals :sig((ArrayRef[Order]) -> ArrayRef[Int]) ($orders) {
    my @totals;
    for my $o (@$orders) {
        push @totals, $o->total;
    }
    \@totals;
}

# ── Rank-2 Polymorphism ───────────────────────
#
# transform_all takes a function that works on ANY type (forall A. A -> A)
# and applies it to every order. The rank-2 type ensures the transformation
# is truly polymorphic — a monomorphic (Int -> Int) would be rejected.

sub transform_all :sig((forall A. A -> A, ArrayRef[Order]) -> ArrayRef[Order]) ($f, $orders) {
    my @result = map { $f->($_) } @$orders;
    \@result;
}

# ── Report Formatting ─────────────────────────

sub format_report :sig((ReportNode, Int) -> Str) ($node, $indent) {
    my $pad  = "  " x $indent;
    my $line = $pad . $node->label . ": " . $node->value;

    my $result = $line;
    for my $child ($node->children->@*) {
        $result .= "\n" . format_report($child, $indent + 1);
    }
    $result;
}

1;
