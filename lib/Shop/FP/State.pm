package Shop::FP::State;
use v5.40;
use Typist 'Int', 'Str';
use Shop::Types;

use Exporter 'import';
our @EXPORT = ();

# ═══════════════════════════════════════════════════
#  State — Pure state-threading monad
#
#  State S A  ~=  S -> Tuple[A, S]
#
#  Thread mutable state through a computation purely.
#  `get` retrieves the current state, `put` replaces it,
#  `modify` applies a transformation.
# ═══════════════════════════════════════════════════

BEGIN {
    struct CartState => (
        items         => 'ArrayRef[OrderItem]',
        running_total => 'Price',
        item_count    => Int,
    );
}

# ── Core Operations ───────────────────────────
#
# State S A is represented as a closure S -> Tuple[A, S].
# S is specialized to CartState for :sig() annotations.

# state : (CartState -> Tuple[A, CartState]) -> State CartState A
sub state :sig(<A>((CartState) -> Tuple[A, CartState]) -> (CartState) -> Tuple[A, CartState]) ($f) { $f }

# run_state : State CartState A -> CartState -> Tuple[A, CartState]
sub run_state :sig(<A>((CartState) -> Tuple[A, CartState], CartState) -> Tuple[A, CartState]) ($st, $s) { $st->($s) }

# eval_state : State CartState A -> CartState -> A
sub eval_state :sig(<A>((CartState) -> Tuple[A, CartState], CartState) -> A) ($st, $s) {
    my ($a, $_s) = @{$st->($s)};
    $a;
}

# exec_state : State CartState A -> CartState -> CartState
sub exec_state :sig(<A>((CartState) -> Tuple[A, CartState], CartState) -> CartState) ($st, $s) {
    my ($_a, $s2) = @{$st->($s)};
    $s2;
}

# state_pure : A -> State CartState A
sub state_pure :sig(<A>(A) -> (CartState) -> Tuple[A, CartState]) ($a) {
    sub ($s) { [$a, $s] };
}

# state_fmap : State CartState A -> (A -> B) -> State CartState B
sub state_fmap :sig(<A, B>((CartState) -> Tuple[A, CartState], (A) -> B) -> (CartState) -> Tuple[B, CartState]) ($st, $f) {
    sub ($s) {
        my ($a, $s2) = @{$st->($s)};
        [$f->($a), $s2];
    };
}

# state_bind : State CartState A -> (A -> State CartState B) -> State CartState B
sub state_bind :sig(<A, B>((CartState) -> Tuple[A, CartState], (A) -> (CartState) -> Tuple[B, CartState]) -> (CartState) -> Tuple[B, CartState]) ($st, $f) {
    sub ($s) {
        my ($a, $s2) = @{$st->($s)};
        $f->($a)->($s2);
    };
}

# get : State CartState CartState
sub get :sig(() -> (CartState) -> Tuple[CartState, CartState]) () {
    sub ($s) { [$s, $s] };
}

# put : CartState -> State CartState ()
sub put :sig((CartState) -> (CartState) -> Tuple[Str, CartState]) ($s) {
    sub ($) { ["", $s] };
}

# modify : (CartState -> CartState) -> State CartState ()
sub modify :sig(((CartState) -> CartState) -> (CartState) -> Tuple[Str, CartState]) ($f) {
    sub ($s) { my $s2 :sig(CartState) = $f->($s); ["", $s2] };
}

# gets : (CartState -> A) -> State CartState A
sub gets :sig(<A>((CartState) -> A) -> (CartState) -> Tuple[A, CartState]) ($f) {
    sub ($s) { [$f->($s), $s] };
}

# ── Shop-specific State operations ───────────

sub empty_cart :sig(() -> CartState) () {
    my $items :sig(ArrayRef[OrderItem]) = [];
    CartState(
        items         => $items,
        running_total => 0,
        item_count    => 0,
    );
}

# add_to_cart : OrderItem -> State CartState ()
sub add_to_cart :sig((OrderItem) -> (CartState) -> Tuple[Str, CartState]) ($item) {
    modify(sub ($cart) {
        my $line_total = $item->unit_price * $item->quantity;
        CartState(
            items         => [@{$cart->items}, $item],
            running_total => $cart->running_total + $line_total,
            item_count    => $cart->item_count + $item->quantity,
        );
    });
}

# cart_summary : State CartState Str
sub cart_summary :sig(() -> (CartState) -> Tuple[Str, CartState]) () {
    sub ($cart) {
        my $n     = $cart->item_count;
        my $total = $cart->running_total;
        ["${n} items, total: \$${total}", $cart];
    };
}

1;
