use common::sense; use open qw/:std :utf8/; use Test::More 0.98; sub _mkpath_ { my ($p) = @_; length($`) && !-e $`? mkdir($`, 0755) || die "mkdir $`: $!": () while $p =~ m!/!g; $p } BEGIN { use Scalar::Util qw//; use Carp qw//; $SIG{__DIE__} = sub { my ($s) = @_; if(ref $s) { $s->{STACKTRACE} = Carp::longmess "?" if "HASH" eq Scalar::Util::reftype $s; die $s } else {die Carp::longmess defined($s)? $s: "undef" }}; my $t = `pwd`; chop $t; $t .= '/' . __FILE__; my $s = '/tmp/.liveman/perl-aion-sige!aion!sige/'; `rm -fr '$s'` if -e $s; chdir _mkpath_($s) or die "chdir $s: $!"; open my $__f__, "<:utf8", $t or die "Read $t: $!"; read $__f__, $s, -s $__f__; close $__f__; while($s =~ /^#\@> (.*)\n((#>> .*\n)*)#\@< EOF\n/gm) { my ($file, $code) = ($1, $2); $code =~ s/^#>> //mg; open my $__f__, ">:utf8", _mkpath_($file) or die "Write $file: $!"; print $__f__ $code; close $__f__; } } # # NAME
# 
# Aion::Sige - templater (html-like language, it like vue)
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
#>> \ \' ₽
#>> <Product::List list=list />
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

my $result = '
<img src="tiger">
\\ \\\' ₽

<ul>
    <li>first
    <li class="piase1">&lt;dog&gt;
    <li class="piase3">&quot;cat&quot;
</ul>

';

::is scalar do {Product->new(caption => "tiger", list => [[1, '<dog>'], [3, '"cat"']])->render}, scalar do{$result}, 'Product->new(caption => "tiger", list => [[1, \'<dog>\'], [3, \'"cat"\']])->render # -> $result';

# 
# # DESCRIPTION
# 
# Aion::Sige parses html in the \__DATA__ section or in the html file of the same name located next to the module.
# 
# Attribute values ​​enclosed in single quotes are calculated. Attribute values ​​without quotes are also calculated. They must not have spaces.
# 
# Tags with a dash in their name are considered classes and are converted accordingly: `<Product::List list=list>` to `use Product::List; Product::List->new(list => $self->list)->render`.
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
# The template code is located in the `*.html` file of the same name next to the module or in the `__DATA__` section. But not here and there.
# 
# File lib/Ex.pm:
#@> lib/Ex.pm
#>> package Ex;
#>> use Aion;
#>> with Aion::Sige;
#>> 1;
#>> __DATA__
#>> @render
#>> 123
#@< EOF
# 
# File lib/Ex.html:
#@> lib/Ex.html
#>> 123
#@< EOF
# 
done_testing; }; subtest 'SIGE LANGUAGE' => sub { 
eval "require Ex";
::like scalar do {$@}, qr!The sige code in __DATA__ and in \*\.html\!!, '$@   # ~> The sige code in __DATA__ and in \*\.html!';

# 
# ## Subroutine
# 
# From the beginning of the line and the @ symbol, methods begin that can be called on the package:
# 
# File lib/ExHtml.pm:
#@> lib/ExHtml.pm
#>> package ExHtml;
#>> use Aion;
#>> with Aion::Sige;
#>> 1;
#@< EOF
# 
# File lib/ExHtml.html:
#@> lib/ExHtml.html
#>> @render
#>> 567
#>> @mix
#>> 890
#@< EOF
# 
done_testing; }; subtest 'Subroutine' => sub { 
require 'ExHtml.pm';
::is scalar do {ExHtml->render}, scalar do{"567\n"}, 'ExHtml->render # -> "567\n"';
::is scalar do {ExHtml->mix}, scalar do{"890\n"}, 'ExHtml->mix    # -> "890\n"';

# 
# ## Evaluate insertions
# 
# Expression in `{{ }}` evaluate.
# 
# File lib/Ex/Insertions.pm:
#@> lib/Ex/Insertions.pm
#>> package Ex::Insertions;
#>> use Aion;
#>> with Aion::Sige;
#>> 
#>> has x => (is => 'ro');
#>> 
#>> sub plus {
#>> 	my ($self, $x, $y) = @_;
#>> 	$x + $y
#>> }
#>> 
#>> sub x_plus {
#>> 	my ($x, $y) = @_;
#>> 	$x + $y
#>> }
#>> 
#>> 1;
#>> 
#>> __DATA__
#>> @render
#>> {{ x }} {{ x !}}
#>> @math
#>> {{ x + 10 }}
#>> @call
#>> {{ x_plus(x, 3) }}-{{ &x_plus x, 4 }}-{{ self.plus(x, 5) }}
#>> @strings
#>> {{ "\t" . 'hi!' }}
#>> @hash
#>> {{ x:key }}
#>> @array
#>> {{ x[0] }}, {{ x[1] }}
#@< EOF
# 
done_testing; }; subtest 'Evaluate insertions' => sub { 
require Ex::Insertions;
::is scalar do {Ex::Insertions->new(x => "&")->render}, "&amp; &\n", 'Ex::Insertions->new(x => "&")->render       # => &amp; &\n';
::is scalar do {Ex::Insertions->new(x => 10)->math}, "20\n", 'Ex::Insertions->new(x => 10)->math          # => 20\n';
::is scalar do {Ex::Insertions->new(x => 10)->call}, "13-14-15\n", 'Ex::Insertions->new(x => 10)->call          # => 13-14-15\n';
::is scalar do {Ex::Insertions->new->strings}, "\thi!\n", 'Ex::Insertions->new->strings                # => \thi!\n';
::is scalar do {Ex::Insertions->new(x => {key => 5})->hash}, "5\n", 'Ex::Insertions->new(x => {key => 5})->hash  # => 5\n';
::is scalar do {Ex::Insertions->new(x => [10, 20])->array}, "10, 20\n", 'Ex::Insertions->new(x => [10, 20])->array   # => 10, 20\n';

# 
# ## Evaluate attrs
# 
# Attributes with values ​​in `""` are considered a string, while those in `''` or without quotes are considered an expression.
# 
# If value of attribute is `undef`, then attribute is'nt show.
# 
# File lib/Ex/Attrs.pm:
#@> lib/Ex/Attrs.pm
#>> package Ex::Attrs;
#>> use Aion;
#>> with Aion::Sige;
#>> 
#>> has x => (is => 'ro', default => 10);
#>> 
#>> 1;
#>> __DATA__
#>> @render
#>> <a href="link" cat='x + 3' dog=x/2 disabled noshow=undef/>
#@< EOF
# 
done_testing; }; subtest 'Evaluate attrs' => sub { 
require Ex::Attrs;
::is scalar do {Ex::Attrs->new->render}, "<a href=\"link\" cat=\"13\" dog=\"5\" disabled></a>\n", 'Ex::Attrs->new->render       # => <a href="link" cat="13" dog="5" disabled></a>\n';

# 
# ## Attributes if, else-if and else
# 
# File lib/Ex/If.pm:
#@> lib/Ex/If.pm
#>> package Ex::If;
#>> use Aion;
#>> with Aion::Sige;
#>> 
#>> has x => (is => 'ro');
#>> 
#>> 1;
#>> __DATA__
#>> @full
#>> <a if = 'x > 0' />
#>> <b else-if = x<0 />
#>> <i else />
#>> 
#>> @elseif
#>> <a if = 'x > 0' />
#>> <b else-if = x<0 />
#>> 
#>> @ifelse
#>> <a if = 'x > 0' />
#>> <i else>-</i>
#>> 
#>> @many
#>> <a if = x==1><hr if=x><e else>*</e></a>
#>> <b else-if = x==2/>
#>> <c else-if = x==3 >{{x}}</c>
#>> <d else-if = x==4 />
#>> <e else />
#@< EOF
# 
done_testing; }; subtest 'Attributes if, else-if and else' => sub { 
require Ex::If;
::is scalar do {Ex::If->new(x=> 1)->full}, "<a></a>\n", 'Ex::If->new(x=> 1)->full # => <a></a>\n';
::is scalar do {Ex::If->new(x=>-1)->full}, "<b></b>\n", 'Ex::If->new(x=>-1)->full # => <b></b>\n';
::is scalar do {Ex::If->new(x=> 0)->full}, "<i></i>\n\n", 'Ex::If->new(x=> 0)->full # => <i></i>\n\n';

::is scalar do {Ex::If->new(x=> 1)->elseif}, "<a></a>\n", 'Ex::If->new(x=> 1)->elseif # => <a></a>\n';
::is scalar do {Ex::If->new(x=>-1)->elseif}, "<b></b>\n\n", 'Ex::If->new(x=>-1)->elseif # => <b></b>\n\n';
::is scalar do {Ex::If->new(x=> 0)->elseif}, scalar do{""}, 'Ex::If->new(x=> 0)->elseif # -> ""';

::is scalar do {Ex::If->new(x=> 1)->ifelse}, "<a></a>\n", 'Ex::If->new(x=> 1)->ifelse # => <a></a>\n';
::is scalar do {Ex::If->new(x=> 0)->ifelse}, "<i>-</i>\n\n", 'Ex::If->new(x=> 0)->ifelse # => <i>-</i>\n\n';

::is scalar do {Ex::If->new(x=> 1)->many}, "<a><hr></a>\n", 'Ex::If->new(x=> 1)->many # => <a><hr></a>\n';
::is scalar do {Ex::If->new(x=> 2)->many}, "<b></b>\n", 'Ex::If->new(x=> 2)->many # => <b></b>\n';
::is scalar do {Ex::If->new(x=> 3)->many}, "<c>3</c>\n", 'Ex::If->new(x=> 3)->many # => <c>3</c>\n';
::is scalar do {Ex::If->new(x=> 4)->many}, "<d></d>\n", 'Ex::If->new(x=> 4)->many # => <d></d>\n';
::is scalar do {Ex::If->new(x=> 5)->many}, "<e></e>\n", 'Ex::If->new(x=> 5)->many # => <e></e>\n';

# 
# eval { Aion::Sige->_compile_sige("\@x\n<a if=1 if=2 />") }; $@  # ~> The if attribute is already present in the <a>
# 
# eval { Aion::Sige->_compile_sige("\@x\n<a if="1" />") }; $@  # ~> Double quote not supported in attr `if` in the <a>
# 
# ## Attribute for
# 
# ## Tags without close
# 
# ## Comments
# 
# # AUTHOR
# 
# Yaroslav O. Kosmina <dart@cpan.org>
# 
# # LICENSE
# 
# ⚖ **GPLv3**
# 
# # COPYRIGHT
# 
# Aion::Sige is copyright © 2023 by Yaroslav O. Kosmina. Rusland. All rights reserved.

	done_testing;
};

done_testing;
