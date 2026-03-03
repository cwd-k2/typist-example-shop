package Shop::Infra::Display;
use v5.40;
use Typist 'Str';
use Shop::Types;

use Exporter 'import';
our @EXPORT = ();

# ═══════════════════════════════════════════════════
#  Display — ANSI CLI output layer
#
#  Replaces raw `say` with structured, color-aware
#  display primitives. Respects $NO_COLOR convention.
#  All public functions perform IO (say).
# ═══════════════════════════════════════════════════

my $NO_COLOR = $ENV{NO_COLOR};

# ── ANSI helpers ─────────────────────────────

sub _c :sig((Str, Str) -> Str) ($code, $text) {
    $NO_COLOR ? $text : "\e[${code}m${text}\e[0m";
}

sub _bold    :sig((Str) -> Str) ($t) { _c('1',    $t) }
sub _dim     :sig((Str) -> Str) ($t) { _c('2',    $t) }
sub _red     :sig((Str) -> Str) ($t) { _c('31',   $t) }
sub _green   :sig((Str) -> Str) ($t) { _c('32',   $t) }
sub _yellow  :sig((Str) -> Str) ($t) { _c('33',   $t) }
sub _cyan    :sig((Str) -> Str) ($t) { _c('36',   $t) }
sub _bold_cyan :sig((Str) -> Str) ($t) { _c('1;36', $t) }

# ── Public display primitives ────────────────

my $WIDTH = 56;

sub banner :sig((Str) -> Void ![IO]) ($text) {
    my $inner = " $text ";
    my $pad   = $WIDTH - length($inner) - 2;
    $pad = 0 if $pad < 0;
    my $left  = int($pad / 2);
    my $right = $pad - $left;
    say "";
    say _bold("+" . ("=" x ($WIDTH - 2)) . "+");
    say _bold("|" . (" " x $left) . $inner . (" " x $right) . "|");
    say _bold("+" . ("=" x ($WIDTH - 2)) . "+");
    say "";
}

sub section :sig((Str) -> Void ![IO]) ($text) {
    my $dashes = $WIDTH - length($text) - 6;
    $dashes = 2 if $dashes < 2;
    say _bold_cyan("--- $text " . ("-" x $dashes));
    say "";
}

sub section_end :sig(() -> Void ![IO]) () {
    say _dim("-" x $WIDTH);
    say "";
}

sub info :sig((Str) -> Void ![IO]) ($text) {
    say "  $text";
}

sub success :sig((Str) -> Void ![IO]) ($text) {
    say "  " . _green("v") . " $text";
}

sub error_msg :sig((Str) -> Void ![IO]) ($text) {
    say "  " . _red("x") . " $text";
}

sub warn_msg :sig((Str) -> Void ![IO]) ($text) {
    say "  " . _yellow("!") . " $text";
}

sub kv :sig((Str, Str) -> Void ![IO]) ($key, $value) {
    say "  " . _dim("$key: ") . $value;
}

sub list (@items) {
    for my $item (@items) {
        say "  - $item";
    }
}

sub blank :sig(() -> Void ![IO]) () {
    say "";
}

# ── Log display ──────────────────────────────

my %LEVEL_COLOR = (
    Debug => \&_dim,
    Info  => \&_cyan,
    Warn  => \&_yellow,
    Error => \&_red,
);

my %LEVEL_TAG = (
    Debug => 'DBG ',
    Info  => 'INFO',
    Warn  => 'WARN',
    Error => 'ERR ',
);

sub _level_name :sig((LogLevel) -> Str) ($level) {
    match $level,
        Debug => sub { "Debug" },
        Info  => sub { "Info" },
        Warn  => sub { "Warn" },
        Error => sub { "Error" };
}

sub log_line :sig((LogLevel, Str) -> Void ![IO]) ($level, $msg) {
    my $name   = _level_name($level);
    my $tag    = $LEVEL_TAG{$name};
    my $color  = $LEVEL_COLOR{$name};
    say "  " . $color->("[${tag}]") . " $msg";
}

sub log_entry_line :sig((LogEntry) -> Void ![IO]) ($entry) {
    my $name   = _level_name($entry->level);
    my $tag    = $LEVEL_TAG{$name};
    my $color  = $LEVEL_COLOR{$name};
    my $source = defined($entry->source) ? _dim(" (" . $entry->source . ")") : "";
    say "  " . $color->("[${tag}]") . " " . $entry->message . $source;
}

# ── Logger handler factory ───────────────────

sub logger_handler () {
    +{
        log       => sub ($level, $msg)  { log_line($level, $msg) },
        log_entry => sub ($entry)        { log_entry_line($entry) },
    };
}

1;
