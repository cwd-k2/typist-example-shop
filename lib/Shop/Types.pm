package Shop::Types;
use v5.40;
use Typist 'Int', 'Str', 'optional';

use Exporter 'import';
our @EXPORT = qw(
  ProductId OrderId CustomerId unwrap
  Product OrderItem Order ReportNode Customer
  Cash Card Transfer
  Pending Completed Failed Refunded
  Regular Premium
  Ok Err
  Created Confirmed Fulfilled Cancelled
  Sale Refund StockCheck
  Some None
  Debug Info Warn Error
  LogEntry
  Pair
  Valid Invalid
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

    struct 'ReportNode[T]' => (
        label    => Str,
        value    => 'T',
        children => 'ArrayRef[ReportNode[T]]',
    );

    struct Customer => (
        id    => 'CustomerId',
        name  => Str,
        email => Str,
        phone => Str | 'Undef',
        tier  => 'CustomerTier',
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

# ── Log ───────────────────────────────────────

BEGIN {
    enum LogLevel => qw(Debug Info Warn Error);

    struct LogEntry => (
        level   => 'LogLevel',
        message => Str,
        source  => optional(Str),
    );
}

# ── Pair (Tuple) ─────────────────────────────

BEGIN {
    datatype 'Pair[A, B]' => (
        Pair => '(A, B)'
    );
}

# ── Validation ADT ────────────────────────────

BEGIN {
    datatype 'Validation[E, T]' => (
        Valid   => '(T)',
        Invalid => '(ArrayRef[E])'
    );
}

# ── Effects ───────────────────────────────────

BEGIN {
    effect Logger => +{
        log       => '(LogLevel, Str) -> Void',
        log_entry => '(LogEntry) -> Void',
    };

    effect PaymentGateway => +{ charge => '(Int, PaymentMethod) -> Bool', };

    effect CustomerStore => +{
        get_customer  => '(CustomerId) -> Option[Customer]',
        put_customer  => '(Customer) -> Void',
        all_customers => '() -> ArrayRef[Customer]',
    };

    effect ProductStore => +{
        get_product  => '(ProductId) -> Option[Product]',
        put_product  => '(Product) -> Void',
        all_products => '() -> ArrayRef[Product]',
    };

    effect OrderStore => +{
        get_order  => '(OrderId) -> Option[Order]',
        put_order  => '(Order) -> Void',
        all_orders => '() -> ArrayRef[Order]',
    };

    effect PaymentStore => +{
        get_payment => '(OrderId) -> Option[PaymentStatus]',
        put_payment => '(OrderId, PaymentStatus) -> Void',
    };
}

# ── Type Classes ──────────────────────────────
#
# Definitions only — instances live in Shop::Instances
# (cross-file typeclass instance pattern).

BEGIN {
    typeclass Printable => 'T', +{
        display => '(T) -> Str',
    };

    typeclass Summarize => 'T', +{
        summarize => '(T) -> Str',
    };

    # Bare namespace aliases for ergonomic use
    no strict 'refs';
    *{"Printable::display"}   = \&Shop::Types::Printable::display;
    *{"Summarize::summarize"} = \&Shop::Types::Summarize::summarize;
}

1;
