#!/usr/bin/env perl
use v5.40;
use Typist;
use Shop::Types;
use Shop::Instances;
use Shop::Infra::Display;
use Shop::Infra::Store;
use Shop::App::Scenario;
use Shop::App::Analysis;
use Shop::App::Demo;

# ═══════════════════════════════════════════════════
#  typist-shop — A Day at the Shop
#
#  Showcases the full breadth of Typist features:
#    types    — newtype, typedef, struct, ADT, GADT,
#               enum, literal, recursive, bounded,
#               rank-2, intersection, record, tuple
#    effects  — effect/handle, protocol, row poly
#    classes  — typeclass, instance, hierarchy, HKT
#    patterns — match, narrowing, gradual typing
#    FP       — Functor, Foldable, Monad, Applicative,
#               Traversable, Codensity, Validation,
#               Reader, State, Writer
#    OO       — method dispatch with :sig()
# ═══════════════════════════════════════════════════

handle {
    Shop::Infra::Display::banner("A Day at the Shop");

    # ── Business Scenario ──
    my ($alice, $alice_disc, $alice_items) = @{Shop::App::Scenario::run_all()};

    # ── Analysis ──
    my $all_products = Shop::App::Analysis::run_all($alice, $alice_disc, $alice_items);

    # ── Feature Demos ──
    Shop::App::Demo::run_all($alice, $alice_disc, $alice_items, $all_products);

    Shop::Infra::Display::banner("Shop Closed");

} Logger         => Shop::Infra::Display::logger_handler(),
  PaymentGateway => +{
    charge => sub ($amount, $method) {
        match $method,
            Transfer => sub ($bank, $ac) { $bank ne "Shady Bank" ? 1 : 0 },
            Cash     => sub ()           { 1 },
            Card     => sub ($number)    { 1 };
    },
  },
  CustomerStore  => Shop::Infra::Store::customer_handler(),
  ProductStore   => Shop::Infra::Store::product_handler(),
  OrderStore     => Shop::Infra::Store::order_handler(),
  PaymentStore   => Shop::Infra::Store::payment_handler();
