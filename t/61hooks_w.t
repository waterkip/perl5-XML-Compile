#!/usr/bin/perl
# hooks in XmlWriter

use warnings;
use strict;

use lib 'lib','t';
use TestTools;
use Data::Dumper;

use XML::Compile::Schema;

use Test::More tests => 37 + ($skip_dumper ? 0 : 9);

my $schema   = XML::Compile::Schema->new( <<__SCHEMA__ );
<schema targetNamespace="$TestNS"
        xmlns="$SchemaNS"
        xmlns:me="$TestNS">

<element name="test1" id="top">
  <complexType>
    <sequence>
      <element name="byType" type="string"         />
      <element name="byId"   type="int" id="my_id" minOccurs="0" />
      <element name="byPath" type="int"            />
    </sequence>
  </complexType>
</element>

</schema>
__SCHEMA__

ok(defined $schema);

my @errors;
push @run_opts, invalid => sub {no warnings; push @errors, "$_[2] ($_[1])"};

my $xml1 = <<__XML;
<test1>
  <byType>aap</byType>
  <byId>2</byId>
  <byPath>3</byPath>
</test1>
__XML

# test without hooks

my %f1 = (byType => 'aap', byId => 2, byPath => 3);
test_rw($schema, test1 => $xml1, \%f1);
ok(!@errors);

# try all selectors and hook types

my (@out, @out2);
my $w2 = writer
 ( $schema, test1 => "{$TestNS}test1"
 , hook => { type   => 'string'
           , id     => 'my_id'
           , path   => qr/byPath/
           , before => sub { push @out,  $_[2]; $_[1] }
           , after  => sub { push @out2, $_[2]; $_[1] }
           }
 );
ok(defined $w2);
isa_ok($w2, 'CODE');

my $h2 = writer_test($w2, \%f1);
ok(defined $h2);

cmp_ok(scalar @out,  '==', 3, '3 objects logged before');
cmp_ok(scalar @out2, '==', 3, '3 objects logged after');
compare_xml($h2, <<__EXPECT);
<test1>
   <byType>aap</byType>
   <byId>2</byId>
   <byPath>3</byPath>
</test1>
__EXPECT

# test predefined and multiple "after"s

my $output;
open BUF, '>', \$output;
my $oldout = select BUF;

my $w3 = writer
 ( $schema, test1 => "{$TestNS}test1"
 , hook => { id    => 'top'
           , after => [ 'PRINT_PATH' ]
           }
 );
my $h3 = writer_test($w3, \%f1);
ok(defined $h3, 'multiple after predefined');

select $oldout;
close BUF;

like($output, qr/^[^\n]*el\(test1\)\n$/, 'PRINT_PATH');
compare_xml($h3, <<__EXPECT);
<test1>
   <byType>aap</byType>
   <byId>2</byId>
   <byPath>3</byPath>
</test1>
__EXPECT

# test skip

my $w4 = writer
 ( $schema, test1 => "{$TestNS}test1"
 , hook => { id      => 'my_id'
           , replace => 'SKIP'
           }
 );
my $h4 = writer_test($w4, \%f1);
ok(defined $h4, 'test skip');
compare_xml($h4, <<__EXPECT);
<test1>
   <byType>aap</byType>
   <byPath>3</byPath>
</test1>
__EXPECT