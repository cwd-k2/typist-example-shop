package Shop::FP::Codensity;
use v5.40;
use Typist;
use Shop::Types;
use Shop::FP::HKT;

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

# ── Core Operations ───────────────────────────

# unit : A -> Codensity F A
sub unit :sig(<F: * -> *, A>(A) -> forall R. (A -> F[R]) -> F[R]) ($a) {
    sub ($k) { $k->($a) };
}

# bind : Codensity F A -> (A -> Codensity F B) -> Codensity F B
sub bind :sig(<F: * -> *, A, B>(forall R. (A -> F[R]) -> F[R], (A) -> forall R. (B -> F[R]) -> F[R]) -> forall R. (B -> F[R]) -> F[R]) ($m, $f) {
    sub ($k) { $m->(sub ($a) { $f->($a)->($k) }) };
}

# ── List Monad Specialization ─────────────────

my $list_bind = \&Monad::bind;

sub lift_list :sig(<A>(ArrayRef[A]) -> forall R. (A -> ArrayRef[R]) -> ArrayRef[R]) ($arr) {
    sub ($k) { $list_bind->($arr, $k) };
}

sub lower_list :sig(<A>(forall R. (A -> ArrayRef[R]) -> ArrayRef[R]) -> ArrayRef[A]) ($m) {
    $m->(sub ($a) { [$a] });
}

# ── Option Specialization ─────────────────────

sub lift_option :sig(<A>(Option[A]) -> forall R. (A -> Option[R]) -> Option[R]) ($opt) {
    sub ($k) { Shop::FP::HKT::option_bind($opt, $k) };
}

sub lower_option :sig(<A>(forall R. (A -> Option[R]) -> Option[R]) -> Option[A]) ($m) {
    $m->(sub ($a) { Some($a) });
}

1;
