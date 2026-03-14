package Shop::Types;
use v5.40;
use Typist;

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
  Valid Invalid
  Range
  Pair Labeled PriceBand
);

# ── Newtypes ──────────────────────────────────

BEGIN {
    newtype ProductId  => 'Str';
    newtype OrderId    => 'Int';
    newtype CustomerId => 'Int';
}

# ── Type Aliases ──────────────────────────────

BEGIN {
    typedef Price    => 'Int';
    typedef Quantity => 'Int';

    typedef DiscountPct => '0 | 5 | 10 | 15 | 20';
}

# ── Structs ───────────────────────────────────

BEGIN {
    struct Product => (
        id          => 'ProductId',
        name        => 'Str',
        price       => 'Price',
        stock       => 'Quantity',
        optional(description => 'Str'),
        optional(category    => 'Str'),
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
        label    => 'Str',
        value    => 'T',
        children => 'ArrayRef[ReportNode[T]]',
    );

    struct Customer => (
        id    => 'CustomerId',
        name  => 'Str',
        email => 'Str',
        phone => 'Str | Undef',
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

    datatype PaymentStatus => (
        Pending   => '()',
        Completed => '()',
        Failed    => '()',
        Refunded  => '()',
    );

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
    datatype LogLevel => (
        Debug => '()',
        Info  => '()',
        Warn  => '()',
        Error => '()',
    );

    struct LogEntry => (
        level   => 'LogLevel',
        message => 'Str',
        optional(source => 'Str'),
    );
}

# ── Validation ADT ────────────────────────────

BEGIN {
    datatype 'Validation[E, T]' => (
        Valid   => '(T)',
        Invalid => '(ArrayRef[E])'
    );
}

# ── Bounded Generic Struct ────────────────────

BEGIN {
    struct 'Range[T: Num]' => (lo => 'T', hi => 'T');
}

# ── Record Types & Intersection ──────────────

BEGIN {
    typedef ProductQuery => 'Record(min_price => Int, max_price => Int, in_stock? => Bool)';
    typedef HasName      => 'Record(name => Str)';
    typedef HasPrice     => 'Record(price => Int)';
    typedef Displayable  => 'HasName & HasPrice';
}

# ── Effects ───────────────────────────────────

BEGIN {
    effect Logger => +{
        log       => '(LogLevel, Str) -> Void',
        log_entry => '(LogEntry) -> Void',
    };

    effect PaymentGateway => +{ charge => '(Int, PaymentMethod) -> Bool' };

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

    # Parameterized effect for scoped capabilities
    effect 'Accumulator[S]' => +{
        read  => '() -> S',
        add   => '(S) -> Void',
        reset => '() -> Void',
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
}

# ── Typeclass Hierarchy ──────────────────────

BEGIN {
    typeclass Eq  => 'T',      +{ eq_     => '(T, T) -> Bool' };
    typeclass Ord => 'T: Eq',  +{ compare => '(T, T) -> Int'  };
}

# ── Multi-parameter Typeclass ────────────────

BEGIN {
    typeclass Convertible => 'T, U', +{ convert => '(T) -> U' };
}

# ── Recursive Type Aliases ───────────────────

BEGIN {
    typedef CategoryTree => 'Str | ArrayRef[CategoryTree]';
    typedef Json         => 'Str | Int | Double | Bool | Undef | ArrayRef[Json] | HashRef[Str, Json]';
}

# ── Multi-parameter Generic Struct ───────────

BEGIN { struct 'Pair[A, B]' => (fst => 'A', snd => 'B') }

# ── Typeclass-Bounded Generic Struct ─────────

BEGIN { struct 'Labeled[T: Printable]' => (label => 'Str', value => 'T') }

# ── Struct with Tuple-typed Field ─────────────

BEGIN { struct PriceBand => (name => 'Str', bounds => 'Tuple[Price, Price]') }

1;
