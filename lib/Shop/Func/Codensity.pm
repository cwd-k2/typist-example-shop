package Shop::Func::Codensity;
use v5.40;
use Typist;
use Shop::Types;
use Shop::Func::HKT;

# ═══════════════════════════════════════════════════
#  Codensity — The continuation monad transform
#
#  Codensity F A  ~=  forall R. (A -> F R) -> F R
#
#  A suspended computation: "give me a continuation
#  and I'll produce a result in F."
#
#  bind composes by nesting continuations, which
#  automatically right-associates the chain.
#  For the list monad this turns O(n^2) left-nested
#  concat-heavy binds into O(n).
# ═══════════════════════════════════════════════════

# @typist-ignore — Codensity representation (forall R. (A -> F R) -> F R)
#   exceeds :sig() expressiveness for rank-2 continuation types.

# ── Core Operations ───────────────────────────

# unit : A -> Codensity F A
sub unit ($a) {
    sub ($k) { $k->($a) };
}

# bind : Codensity F A -> (A -> Codensity F B) -> Codensity F B
sub bind ($m, $f) {
    sub ($k) { $m->(sub ($a) { $f->($a)->($k) }) };
}

# ── List Monad Specialization ─────────────────

my $list_bind = \&Monad::bind;

# lift_list : ArrayRef[A] -> Codensity ArrayRef A
sub lift_list ($arr) {
    sub ($k) { $list_bind->($arr, $k) };
}

# lower_list : Codensity ArrayRef A -> ArrayRef[A]
sub lower_list ($m) {
    $m->(sub ($a) { [$a] });
}

# ── Option Specialization ─────────────────────

# lift_option : Option[A] -> Codensity Option A
sub lift_option ($opt) {
    sub ($k) { Shop::Func::HKT::option_bind($opt, $k) };
}

# lower_option : Codensity Option A -> Option[A]
sub lower_option ($m) {
    $m->(sub ($a) { Some($a) });
}

1;
