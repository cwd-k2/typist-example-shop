package Shop::Types;
use v5.40;
use Typist 'Int', 'Str', 'optional';

use Exporter 'import';
our @EXPORT = qw(
  ProductId OrderId CustomerId unwrap
  Product OrderItem Order ReportNode
  Cash Card Transfer
  Pending Completed Failed Refunded
  Regular Premium
  Ok Err
  Created Confirmed Fulfilled Cancelled
  Sale Refund StockCheck
  Some None
);

# ── Newtypes ──────────────────────────────────

BEGIN {
    newtype ProductId  => Str;
    newtype OrderId    => Int;
    newtype CustomerId => Int;
}

# ── Type Aliases ──────────────────────────────

BEGIN {
    typedef Price    => Int;
    typedef Quantity => Int;

    typedef DiscountPct => '0 | 5 | 10 | 15 | 20';
}

# ── Structs ───────────────────────────────────

BEGIN {
    struct Product => (
        id          => 'ProductId',
        name        => Str,
        price       => 'Price',
        stock       => 'Quantity',
        description => optional(Str),
        category    => optional(Str),
    );

    struct OrderItem => (
        product_id => 'ProductId',
        quantity   => 'Quantity',
        unit_price => 'Price',
    );

    struct Order => (
        id          => 'OrderId',
        customer_id => 'CustomerId',
        items       => 'ArrayRef[OrderItem]',
        total       => 'Price',
        status      => 'OrderStatus',
        discount    => 'DiscountPct',
    );

    struct ReportNode => (
        label    => Str,
        value    => 'Price',
        children => 'ArrayRef[ReportNode]',
    );
}

# ── ADTs ──────────────────────────────────────

BEGIN {
    datatype 'Result[T]' => (
        Ok  => '(T)',
        Err => '(Str)'
    );

    datatype OrderStatus => (
        Created   => '()',
        Confirmed => '()',
        Fulfilled => '()',
        Cancelled => '(Str)'
    );

    datatype PaymentMethod => (
        Cash     => '()',
        Card     => '(Str)',
        Transfer => '(Str, Str)'
    );

    enum PaymentStatus => qw(Pending Completed Failed Refunded);

    datatype 'Option[T]' => (
        Some => '(T)',
        None => '()'
    );

    datatype CustomerTier => (
        Regular => '()',
        Premium => '(Int)'
    );

    datatype 'ShopEvent[R]' => (
        Sale       => '(Order)            -> ShopEvent[Price]',
        Refund     => '(Order, Price)     -> ShopEvent[Price]',
        StockCheck => '(ProductId)        -> ShopEvent[Quantity]'
    );
}

# ── Effects ───────────────────────────────────

BEGIN {
    effect Logger => +{ log => '(Str) -> Void', };

    effect PaymentGateway => +{ charge => '(Int, PaymentMethod) -> Bool', };
}

# ── Type Classes ──────────────────────────────

BEGIN {
    typeclass
      Printable => 'T',
      +{ display => '(T) -> Str', };

    instance
      Printable => Int,
      +{ display => sub ($v) { "Int<$v>" }, };

    instance
      Printable => Str,
      +{ display => sub ($v) { qq[Str<$v>] }, };

    typeclass
      Summarize => 'T',
      +{ summarize => '(T) -> Str', };

    instance
      Summarize => Int,
      +{ summarize => sub ($v) { "numeric: $v" }, };

    instance
      Summarize => Str,
      +{ summarize => sub ($v) { "text: $v" }, };

    # Bare namespace aliases for ergonomic use
    no strict 'refs';
    *{"Printable::display"}   = \&Shop::Types::Printable::display;
    *{"Summarize::summarize"} = \&Shop::Types::Summarize::summarize;
}

1;
