use common::sense; use open qw/:std :utf8/; use Test::More 0.98; sub _mkpath_ { my ($p) = @_; length($`) && !-e $`? mkdir($`, 0755) || die "mkdir $`: $!": () while $p =~ m!/!g; $p } BEGIN { use Scalar::Util qw//; use Carp qw//; $SIG{__DIE__} = sub { my ($s) = @_; if(ref $s) { $s->{STACKTRACE} = Carp::longmess "?" if "HASH" eq Scalar::Util::reftype $s; die $s } else {die Carp::longmess defined($s)? $s: "undef" }}; my $t = `pwd`; chop $t; $t .= '/' . __FILE__; my $s = '/tmp/.liveman/perl-aion-sige!aion!sige/'; `rm -fr '$s'` if -e $s; chdir _mkpath_($s) or die "chdir $s: $!"; open my $__f__, "<:utf8", $t or die "Read $t: $!"; read $__f__, $s, -s $__f__; close $__f__; while($s =~ /^#\@> (.*)\n((#>> .*\n)*)#\@< EOF\n/gm) { my ($file, $code) = ($1, $2); $code =~ s/^#>> //mg; open my $__f__, ">:utf8", _mkpath_($file) or die "Write $file: $!"; print $__f__ $code; close $__f__; } } # # NAME
# 
# Aion::Sige - .
# 
# # VERSION
# 
# 0.0.0-prealpha
# 
# # SYNOPSIS
# 
# File lib/Product.pm:
#@> lib/Product.pm
#>> package Product;
#>> use Aion;
#>> 
#>> with 'Aion::Sige';
#>> 
#>> has caption => (is => 'ro', isa => Maybe[Str]);
#>> has list => (is => 'ro', isa => ArrayRef[Tuple[Int, Str]]);
#>> 
#>> 1;
#>> __DATA__
#>> @render
#>> 
#>> <img if=caption src=caption>
#>> '
#>> <product-list list=list>
#@< EOF
# 
# File lib/Product/List.pm:
#@> lib/Product/List.pm
#>> package Product::List;
#>> use Aion;
#>> 
#>> with 'Aion::Sige';
#>> 
#>> has caption => (is => 'ro', isa => Maybe[Str]);
#>> has list => (is => 'ro', isa => ArrayRef[Tuple[Int, Str]]);
#>> 
#>> 1;
#>> __DATA__
#>> @render
#>> 
#>> <ul>
#>>     <li>first
#>>     <li for='element in list' class="piase{{ element[0] }}">{{ element[1] }}
#>> </ul>
#@< EOF
# 
subtest 'SYNOPSIS' => sub { 
use lib "lib";
use Product;

my $result = "";

::is scalar do {Product->new(caption => "tiger", list => [[1, '<dog>'], [3, '"cat"']])->render}, scalar do{$result}, 'Product->new(caption => "tiger", list => [[1, \'<dog>\'], [3, \'"cat"\']])->render  # -> $result';

# 
# # DESCRIPTION
# 
# Aion::Sige parses html in the \__DATA__ section or in the html file of the same name located next to the module.
# 
# Attribute values ​​enclosed in single quotes are calculated. Attribute values ​​without quotes are also calculated. They must not have spaces.
# 
# Tags with a dash in their name are considered classes and are converted accordingly: `<product-list list=list>` to `use Product::List; Product::List->new(list => $self->list)->render`.
# 
# # SUBROUTINES
# 
# ## sige ($pkg, $template)
# 
# Compile the template to perl-code and evaluate it into the package.
# 
# 
# # SIGE LANGUAGE
# 
# ## Routine
# 
# ## Attribute if
# ## Attribute else-if
# ## Attribute else
# ## Attribute for
# 
# ## Tags without close
# 
# ## Comments
# 
# ## Evaluate attrs
# 
# ## Evaluate insertions
# 
# # AUTHOR
# 
# Yaroslav O. Kosmina <dart@cpan.org>
# 
# # COPYRIGHT AND LICENSE
# This software is copyright (c) 2023 by Yaroslav O. Kosmina.
# 
# This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.
# 
# ⚖ **GPLv3**
	done_testing;
};

done_testing;
