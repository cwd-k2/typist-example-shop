package Shop::Instances;
use v5.40;
use Typist 'Int', 'Str';
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

1;
