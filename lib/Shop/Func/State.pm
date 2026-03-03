package Shop::Func::State;
use v5.40;
use Typist 'Int', 'Str';
use Shop::Types;

use Exporter 'import';
our @EXPORT = ();

# ═══════════════════════════════════════════════════
#  State — Pure state-threading monad
#
#  State S A  ~=  S -> (A, S)
#
#  Thread mutable state through a computation purely.
#  `get` reads the current state, `put` replaces it,
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
# State S A is represented as a closure S -> [A, S].
# Core combinators are polymorphic over S and A;
# these remain untyped as the closure-pair representation
# cannot be expressed in :sig().
# Shop-specific operations below are concretely typed.

# state : (S -> [A, S]) -> State S A
sub state ($f) { $f }

# run_state : State S A -> S -> [A, S]
sub run_state ($st, $s) { $st->($s) }

# eval_state : State S A -> S -> A
sub eval_state ($st, $s) { ($st->($s))->[0] }

# exec_state : State S A -> S -> S
sub exec_state ($st, $s) { ($st->($s))->[1] }

# state_pure : A -> State S A
sub state_pure ($a) {
    sub ($s) { [$a, $s] };
}

# state_fmap : State S A -> (A -> B) -> State S B
sub state_fmap ($st, $f) {
    sub ($s) {
        my $pair = $st->($s);
        [$f->($pair->[0]), $pair->[1]];
    };
}

# state_bind : State S A -> (A -> State S B) -> State S B
sub state_bind ($st, $f) {
    sub ($s) {
        my $pair = $st->($s);
        $f->($pair->[0])->($pair->[1]);
    };
}

# get : State S S
sub get () {
    sub ($s) { [$s, $s] };
}

# put : S -> State S ()
sub put ($s) {
    sub ($) { [undef, $s] };
}

# modify : (S -> S) -> State S ()
sub modify ($f) {
    sub ($s) { [undef, $f->($s)] };
}

# gets : (S -> A) -> State S A
sub gets ($f) {
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
# @typist-ignore — returns closure (CartState -> [(), CartState])
sub add_to_cart ($item) {
    modify(sub ($cart) {
        my $line_total = $item->unit_price * $item->quantity;
        # @typist-ignore — array spread produces ArrayRef[Any]
        CartState(
            items         => [@{$cart->items}, $item],
            running_total => $cart->running_total + $line_total,
            item_count    => $cart->item_count + $item->quantity,
        );
    });
}

# cart_summary : State CartState Str
# @typist-ignore — returns closure (CartState -> [Str, CartState])
sub cart_summary () {
    gets(sub ($cart) {
        my $n     = $cart->item_count;
        my $total = $cart->running_total;
        "${n} items, total: \$${total}";
    });
}

1;
