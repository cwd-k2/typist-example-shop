package Shop::Func::State;
use v5.40;
use Typist 'Int', 'Str';
use Shop::Types;

use Exporter 'import';
our @EXPORT = ();

# ═══════════════════════════════════════════════════
#  State — Pure state-threading monad
#
#  State S A  ~=  S -> Pair[A, S]
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
# State S A is represented as a closure S -> Pair[A, S].
# S is specialized to CartState for :sig() annotations.

# state : (CartState -> Pair[A, CartState]) -> State CartState A
sub state :sig(<A>((CartState) -> Pair[A, CartState]) -> (CartState) -> Pair[A, CartState]) ($f) { $f }

# run_state : State CartState A -> CartState -> Pair[A, CartState]
sub run_state :sig(<A>((CartState) -> Pair[A, CartState], CartState) -> Pair[A, CartState]) ($st, $s) { $st->($s) }

# eval_state : State CartState A -> CartState -> A
sub eval_state :sig(<A>((CartState) -> Pair[A, CartState], CartState) -> A) ($st, $s) {
    match $st->($s),
        Pair => sub ($a, $) { $a };
}

# exec_state : State CartState A -> CartState -> CartState
sub exec_state :sig(<A>((CartState) -> Pair[A, CartState], CartState) -> CartState) ($st, $s) {
    match $st->($s),
        Pair => sub ($, $s2) { $s2 };
}

# state_pure : A -> State CartState A
sub state_pure :sig(<A>(A) -> (CartState) -> Pair[A, CartState]) ($a) {
    sub ($s) { Pair($a, $s) };
}

# state_fmap : State CartState A -> (A -> B) -> State CartState B
sub state_fmap :sig(<A, B>((CartState) -> Pair[A, CartState], (A) -> B) -> (CartState) -> Pair[B, CartState]) ($st, $f) {
    sub ($s) {
        match $st->($s),
            Pair => sub ($a, $s2) { Pair($f->($a), $s2) };
    };
}

# state_bind : State CartState A -> (A -> State CartState B) -> State CartState B
sub state_bind :sig(<A, B>((CartState) -> Pair[A, CartState], (A) -> (CartState) -> Pair[B, CartState]) -> (CartState) -> Pair[B, CartState]) ($st, $f) {
    sub ($s) {
        match $st->($s),
            Pair => sub ($a, $s2) { $f->($a)->($s2) };
    };
}

# get : State CartState CartState
sub get :sig(() -> (CartState) -> Pair[CartState, CartState]) () {
    sub ($s) { Pair($s, $s) };
}

# put : CartState -> State CartState ()
sub put :sig((CartState) -> (CartState) -> Pair[Str, CartState]) ($s) {
    sub ($) { Pair("", $s) };
}

# modify : (CartState -> CartState) -> State CartState ()
sub modify :sig(((CartState) -> CartState) -> (CartState) -> Pair[Str, CartState]) ($f) {
    sub ($s) { Pair("", $f->($s)) };
}

# gets : (CartState -> A) -> State CartState A
sub gets :sig(<A>((CartState) -> A) -> (CartState) -> Pair[A, CartState]) ($f) {
    sub ($s) { Pair($f->($s), $s) };
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
sub add_to_cart :sig((OrderItem) -> (CartState) -> Pair[Str, CartState]) ($item) {
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
sub cart_summary :sig(() -> (CartState) -> Pair[Str, CartState]) () {
    sub ($cart) {
        my $n     = $cart->item_count;
        my $total = $cart->running_total;
        Pair("${n} items, total: \$${total}", $cart);
    };
}

1;
