package Shop::Instances;
use v5.40;
use Typist;
use Typist::DSL qw(Int Str);
use Shop::Types;

# ═══════════════════════════════════════════════════
#  Instances — Cross-file typeclass instances
#
#  Typeclass definitions live in Shop::Types;
#  instances are registered here, demonstrating
#  that typeclass and instance can reside in
#  separate modules.  The LSP workspace and
#  typist-check resolve these across files.
# ═══════════════════════════════════════════════════

# ── Printable ────────────────────────────────────

BEGIN {
    instance Printable => Int, +{
        display => sub ($v) { "Int<$v>" },
    };

    instance Printable => Str, +{
        display => sub ($v) { qq[Str<$v>] },
    };
}

# ── Summarize ────────────────────────────────────

BEGIN {
    instance Summarize => Int, +{
        summarize => sub ($v) { "numeric: $v" },
    };

    instance Summarize => Str, +{
        summarize => sub ($v) { "text: $v" },
    };
}

# ── Eq ───────────────────────────────────────────

BEGIN {
    instance Eq => Int, +{ eq_ => sub ($a, $b) { $a == $b ? 1 : 0 } };
    instance Eq => Str, +{ eq_ => sub ($a, $b) { $a eq $b ? 1 : 0 } };
}

# ── Ord (superclass: Eq) ────────────────────────

BEGIN {
    instance Ord => Int, +{ compare => sub ($a, $b) { $a <=> $b } };
    instance Ord => Str, +{ compare => sub ($a, $b) { $a cmp $b } };
}

# ── Convertible (multi-param) ────────────────────

BEGIN {
    instance Convertible => 'Product, Str', +{
        convert => sub ($p) { $p->name . " (\$" . $p->price . ")" },
    };
    instance Convertible => 'Order, Str', +{
        convert => sub ($o) { "Order #" . OrderId::coerce($o->id) . " total=\$" . $o->total },
    };
}

# ── Printable for struct types ───────────────

BEGIN {
    instance Printable => 'Product', +{
        display => sub ($p) { $p->name . " (\$" . $p->price . ")" },
    };
    instance Printable => 'Customer', +{
        display => sub ($c) { $c->name . " <" . $c->email . ">" },
    };
}

1;
