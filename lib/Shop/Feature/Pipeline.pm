package Shop::Feature::Pipeline;
use v5.40;
use Typist;
use Shop::Types;

# ═══════════════════════════════════════════════════
#  Pipeline — Protocol as Design by Contract
#
#  Demonstrates advanced protocol patterns:
#  - Set-based transitions   : Validated | Enriched -> *
#  - State superposition     : branching creates state union
#  - Invariant annotation    : Pipeline<Validated>
#  - Contract composition    : postcondition chains to precondition
#
#  State machine:
#    * --ingest--> Raw --validate--> Validated --enrich--> Enriched
#                                       ↺ inspect             |
#                                       +---emit--->*<--emit--+
# ═══════════════════════════════════════════════════

BEGIN {
    effect Pipeline => qw/Raw Validated Enriched/ => +{
        ingest   => protocol('(Str) -> Void', '* -> Raw'),
        validate => protocol('() -> Bool',    'Raw -> Validated'),
        enrich   => protocol('(Str) -> Void', 'Validated -> Enriched'),
        inspect  => protocol('() -> Str',     'Validated -> Validated'),
        emit     => protocol('() -> Str',     'Validated | Enriched -> *'),
    };
}

# ── Contract composition ────────────────────────
#
# requires: *   (pipeline inactive)
# ensures:  Validated  (data is verified)
#
# Postcondition of ingest_and_validate serves as
# precondition for all downstream operations.

sub ingest_and_validate :sig((Str) -> Bool ![Pipeline<* -> Validated>, Logger]) ($data) {
    Pipeline::ingest($data);
    Logger::log(Debug(), "Pipeline: data ingested");
    Pipeline::validate();
}

# ── Invariant preservation ──────────────────────
#
# requires: Validated
# ensures:  Validated   (state unchanged)
#
# inspect is an observation — it neither advances
# nor resets the pipeline.

sub peek :sig(() -> Str ![Pipeline<Validated>, Logger]) () {
    my $snapshot = Pipeline::inspect();
    Logger::log(Debug(), "Pipeline: inspected");
    $snapshot;
}

# ── Superposition ───────────────────────────────
#
# After the branch, state is Validated | Enriched.
# emit() resolves the superposition via set-based
# from-state: protocol('Validated | Enriched -> *').

sub process :sig((Str, Bool) -> Str ![Pipeline, Logger]) ($data, $do_enrich) {
    ingest_and_validate($data);
    if ($do_enrich) {
        Pipeline::enrich("auto-enriched");
        Logger::log(Info(), "Pipeline: enriched");
    }
    # state: Validated | Enriched
    Pipeline::emit();
}

# ── Full pipeline ───────────────────────────────

sub run_full :sig((Str, Str) -> Str ![Pipeline, Logger]) ($data, $meta) {
    ingest_and_validate($data);
    Pipeline::enrich($meta);
    Pipeline::emit();
}

# ── Contract handler (fail-fast assertions) ─────
#
# Protocol verifies operation ORDER at compile time.
# This handler verifies data VALUES at runtime.
# die = non-local exit on violation.
#
# Together: complete Design by Contract.
#   compile-time : structural contract  (operation sequence)
#   runtime      : semantic contract    (data validity)

sub contract_handler :sig(() -> Handler[Pipeline]) () {
    my ($buf, $meta) = ("", "");
    +{
        ingest => sub ($d) {
            die "[contract] ingest: data must be non-empty\n" unless length($d);
            $buf = $d; $meta = "";
        },
        validate => sub () {
            die "[contract] validate: malformed (expected pipe-delimited)\n"
                unless $buf =~ /\|/;
            1;
        },
        enrich => sub ($m) {
            die "[contract] enrich: metadata must be non-empty\n" unless length($m);
            $meta = $m;
        },
        inspect => sub () {
            "data='$buf'" . ($meta ? " meta='$meta'" : "");
        },
        emit => sub () {
            my $r = $buf . ($meta ? " [$meta]" : "");
            ($buf, $meta) = ("", "");
            $r;
        },
    };
}

1;
