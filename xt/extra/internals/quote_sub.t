use warnings;
use strict;

use Test::More;
use Test::Warn;

use DBIx::Class::_Util 'quote_sub';

### Test for strictures leakage
my $q = do {
  no strict 'vars';
  quote_sub 'DBICTest::QSUB::nostrict'
    => '$x = $x . "buh"; $x += 42';
};

warnings_exist {
  is $q->(), 42, 'Expected result after uninit and string/num conversion'
} [
  qr/Use of uninitialized value/i,
  qr/isn't numeric in addition/,
], 'Expected warnings, strict did not leak inside the qsub'
  or do {
    require B::Deparse;
    diag( B::Deparse->new->coderef2text( Sub::Quote::unquote_sub($q) ) )
  }
;

my $no_nothing_q = sub {
  no strict;
  no warnings;
  quote_sub 'DBICTest::QSUB::nowarn', <<'EOC';
    BEGIN { warn "-->${^WARNING_BITS}<--\n" };
    my $n = "Test::Warn::warnings_exist";
    warn "-->@{[ *{$n}{CODE} ]}<--\n";
EOC
};

my $we_cref = Test::Warn->can('warnings_exist');

warnings_exist { $no_nothing_q->()->() } [
  qr/^\-\-\>\0+\<\-\-$/m,
  qr/^\Q-->$we_cref<--\E$/m,
], 'Expected warnings, strict did not leak inside the qsub'
  or do {
    require B::Deparse;
    diag( B::Deparse->new->coderef2text( Sub::Quote::unquote_sub($no_nothing_q) ) )
  }
;

### Test the upcoming attributes support
require DBIx::Class;
@DBICTest::QSUB::ISA  = 'DBIx::Class';

my $var = \42;
my $s = quote_sub(
  'DBICTest::QSUB::attr',
  '$v',
  { '$v' => $var },
  {
    # use grandfathered 'ResultSet' attribute for starters
    attributes => [qw( ResultSet )],
    package => 'DBICTest::QSUB',
  },
);

is $s, \&DBICTest::QSUB::attr, 'Same cref installed';

is DBICTest::QSUB::attr(), 42, 'Sub properly installed and callable';

is_deeply
  [ attributes::get( $s ) ],
  [ 'ResultSet' ],
  'Attribute installed',
unless $^V =~ /c/; # FIXME work around https://github.com/perl11/cperl/issues/147

done_testing;
