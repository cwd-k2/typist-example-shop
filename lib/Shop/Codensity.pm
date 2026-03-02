package Shop::Codensity;
use v5.40;
use Typist;
use Shop::Types;
use Shop::HKT;

# ═══════════════════════════════════════════════════
#  Codensity — The continuation monad transform
#
#  Codensity F A  ≅  ∀R. (A → F R) → F R
#
#  A suspended computation: "give me a continuation
#  and I'll produce a result in F."
#
#  bind composes by nesting continuations, which
#  automatically right-associates the chain.
#  For the list monad this turns O(n²) left-nested
#  concat-heavy binds into O(n).
# ═══════════════════════════════════════════════════

# ── Core Operations ───────────────────────────

# unit : A → Codensity F A
#
#   Inject a pure value into Codensity.
#   The continuation receives `a` directly — no
#   underlying monad involved yet.
sub unit ($a) {
    sub ($k) { $k->($a) };
}

# bind : Codensity F A → (A → Codensity F B) → Codensity F B
#
#   CPS composition: when the outer computation m
#   yields a value `a`, feed it to `f` to obtain a
#   new Codensity, then thread the final continuation
#   `k` through.
#
#   This is where right-association happens:
#     m >>= f >>= g
#   becomes
#     λk. m (λa. (f a) (λb. (g b) k))
#
#   — the innermost continuation is always applied last.

sub bind ($m, $f) {
    sub ($k) { $m->(sub ($a) { $f->($a)->($k) }) };
}

# ── List Monad Specialization ─────────────────

my $list_bind = \&Monad::bind;

# lift : ArrayRef[A] → Codensity ArrayRef A
#   Suspend a concrete list into CPS.
sub lift_list ($arr) {
    sub ($k) { $list_bind->($arr, $k) };
}

# lower : Codensity ArrayRef A → ArrayRef[A]
#   Run the CPS computation by supplying return
#   (i.e., singleton list) as the continuation.
sub lower_list ($m) {
    $m->(sub ($a) { [$a] });
}

# ── Option Specialization ─────────────────────

# lift : Option[A] → Codensity Option A
sub lift_option ($opt) {
    sub ($k) { Shop::HKT::option_bind($opt, $k) };
}

# lower : Codensity Option A → Option[A]
sub lower_option ($m) {
    $m->(sub ($a) { Some($a) });
}

1;
