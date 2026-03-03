package Shop::Func::Validation;
use v5.40;
use Typist 'Str';
use Shop::Types;

use Exporter 'import';
our @EXPORT = ();

# ═══════════════════════════════════════════════════
#  Validation — Accumulating error applicative
#
#  Validation[E, T] = Valid(T) | Invalid(ArrayRef[E])
#
#  Unlike Result's monadic bind (which short-circuits
#  on the first error), Validation's `ap` collects
#  ALL errors. This makes it ideal for form validation,
#  config checking, and batch rule enforcement.
# ═══════════════════════════════════════════════════

# ── Core Operations ───────────────────────────

sub validation_pure :sig(<A>(A) -> Validation[Str, A]) ($v) {
    Valid($v);
}

sub validation_fmap :sig(<E, A, B>(Validation[E, A], (A) -> B) -> Validation[E, B]) ($va, $f) {
    match $va,
        Valid   => sub ($v) { Valid($f->($v)) },
        Invalid => sub ($e) { Invalid($e) };
}

sub validation_ap :sig(<E, A, B>(Validation[E, (A) -> B], Validation[E, A]) -> Validation[E, B]) ($vf, $va) {
    match $vf,
        Valid => sub ($f) {
            match $va,
                Valid   => sub ($a) { Valid($f->($a)) },
                Invalid => sub ($e) { Invalid($e) };
        },
        Invalid => sub ($ef) {
            match $va,
                Valid   => sub ($a)  { Invalid($ef) },
                Invalid => sub ($ea) { Invalid([@$ef, @$ea]) };
        };
}

# ── Lifted application ────────────────────────

sub validation_lift_a2 :sig(<E, A, B, C>((A, B) -> C, Validation[E, A], Validation[E, B]) -> Validation[E, C]) ($f, $va, $vb) {
    # @typist-ignore — curried closure: validation_fmap returns Validation[E, B] in checker
    validation_ap(validation_fmap($va, sub ($a) { sub ($b) { $f->($a, $b) } }), $vb);
}

sub validation_lift_a3 :sig(<E, A, B, C, D>((A, B, C) -> D, Validation[E, A], Validation[E, B], Validation[E, C]) -> Validation[E, D]) ($f, $va, $vb, $vc) {
    # @typist-ignore — curried closure: nested validation_ap
    validation_ap(
        # @typist-ignore — curried closure: inner validation_ap
        validation_ap(
            validation_fmap($va, sub ($a) { sub ($b) { sub ($c) { $f->($a, $b, $c) } } }),
            $vb,
        ),
        $vc,
    );
}

# ── Batch validation ─────────────────────────

sub validate_all :sig(<E, A>(ArrayRef[A], (A) -> Validation[E, A]) -> Validation[E, ArrayRef[A]]) ($items, $validator) {
    my @valid;
    my @errors;
    for my $item (@$items) {
        my $result = $validator->($item);
        match $result,
            Valid   => sub ($v) { push @valid,  $v },
            Invalid => sub ($e) { push @errors, @$e };
    }
    @errors ? Invalid(\@errors) : Valid(\@valid);
}

# ── Conversions ───────────────────────────────

sub result_to_validation :sig(<A>(Result[A]) -> Validation[Str, A]) ($r) {
    match $r,
        Ok  => sub ($v) { Valid($v) },
        Err => sub ($e) { Invalid([$e]) };
}

sub validation_to_result :sig(<E, A>(Validation[E, A]) -> Result[A]) ($va) {
    match $va,
        Valid   => sub ($v) { Ok($v) },
        Invalid => sub ($e) { Err(join("; ", @$e)) };
}

# ── Display ───────────────────────────────────

sub show_validation :sig(<E, A>(Validation[E, A]) -> Str) ($va) {
    match $va,
        Valid   => sub ($v) { "Valid($v)" },
        Invalid => sub ($e) { "Invalid(" . join(", ", @$e) . ")" };
}

1;
