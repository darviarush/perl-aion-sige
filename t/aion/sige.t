use common::sense; use open qw/:std :utf8/;  use Carp qw//; use File::Basename qw//; use File::Slurper qw//; use File::Spec qw//; use File::Path qw//; use Scalar::Util qw//;  use Test::More 0.98;  BEGIN {     $SIG{__DIE__} = sub {         my ($s) = @_;         if(ref $s) {             $s->{STACKTRACE} = Carp::longmess "?" if "HASH" eq Scalar::Util::reftype $s;             die $s;         } else {             die Carp::longmess defined($s)? $s: "undef"         }     };      my $t = File::Slurper::read_text(__FILE__);     my $s =  '/tmp/.liveman/perl-aion-sige/aion!sige'    ;     File::Path::rmtree($s) if -e $s;     File::Path::mkpath($s);     chdir $s or die "chdir $s: $!";      while($t =~ /^#\@> (.*)\n((#>> .*\n)*)#\@< EOF\n/gm) {         my ($file, $code) = ($1, $2);         $code =~ s/^#>> //mg;         File::Path::mkpath(File::Basename::dirname($file));         File::Slurper::write_text($file, $code);     }  } # 
# # NAME
# 
# Aion::Sige - шаблонизатор html, для подключения к vue.js
# 
# # VERSION
# 
# 0.0.0-prealpha
# 
# # SYNOPSIS
# 
# Файл lib/Product.pm:
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
# Файл lib/Product/List.pm:
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
# Aion::Sige анализирует html в разделе \__DATA__ или в одноименном html-файле, расположенном рядом с модулем.
# 
# Вычисляются значения атрибутов, заключенные в одинарные кавычки. Значения атрибутов без кавычек также рассчитываются. В них не должно быть пробелов.
# 
# Теги с дефисом в названии считаются классами и соответствующим образом преобразуются: `<Product::List list=list>` в `use Product::List; Product::List->new(list => $self->list)->render`.
# 
# # SUBROUTINES
# 
# ## import_with ($pkg)
# 
# Срабатывает, когда роль прикреплена к классу. Компилирует код sige в код Perl, чтобы `@routine` стал методом класса.
# 
# ## compile_sige ($template, $pkg)
# 
# Компилирует шаблон (`$template`) в Perl-код и подключает его подпрограммы к пакету (`$pkg`).
# 
# ## require_sige ($pkg)
# 
# Компилирует sige в указанном пакете.
# 
# Если у вас достаточно прав, он создает файл рядом с файлом $pkg-module и расширением `.pm$sige`, затем подключает этот файл с помощью `require` и удаляет его. Это сделано для обеспечения адекватной трассировки стека.
# 
# Если прав недостаточно, то просто выполнится `eval`.
# 
# Файл lib/RequireSige.pm:
#@> lib/RequireSige.pm
#>> package RequireSige;
#>> use Aion;
#>> with Aion::Sige;
#>> 1;
#>> __DATA__
#>> @render
#>> {{ &die "---" }}
#@< EOF
# 
done_testing; }; subtest 'require_sige ($pkg)' => sub { 
use feature qw/defer/;
my $perm = (stat "lib")[2] & 07777;
defer { chmod $perm, "lib" or die "chmod -w lib: $!" }

use Fcntl qw/:mode/;
chmod $perm & ~(S_IWUSR | S_IWGRP | S_IWOTH), "lib" or die "chmod -w lib: $!";

require './lib/RequireSige.pm';
::like scalar do {eval { RequireSige->render }; $@}, qr!^--- at \(eval \d+\)!, 'eval { RequireSige->render }; $@   # ~> ^--- at \(eval \d+\)';

# 
# # SIGE LANGUAGE
# 
# Код шаблона находится в одноименном файле `*.html` рядом с модулем или в разделе `__DATA__`. Но не одновременно.
# 
# Файл lib/Ex.pm:
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
# Файл lib/Ex.html:
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
# С начала строки и символа @ начинаются методы, которые можно вызвать из пакета:
# 
# Файл lib/ExHtml.pm:
#@> lib/ExHtml.pm
#>> package ExHtml;
#>> use Aion;
#>> with Aion::Sige;
#>> 1;
#@< EOF
# 
# Файл lib/ExHtml.html:
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
# Выражение в `{{ }}` вычисляется.
# 
# Файл lib/Ex/Insertions.pm:
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
# Атрибуты со значениями в `""` считаются строкой, а атрибуты в `''` или без кавычек считаются выражением.
# 
# Если значение атрибута — `undef`, то атрибут не рендерится.
# 
# Файл lib/Ex/Attrs.pm:
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
# Файл lib/Ex/If.pm:
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
# ## Attribute for
# 
done_testing; }; subtest 'Attribute for' => sub { 
eval Aion::Sige->compile_sige("\@for\n<li for = 'i in [1,2]'>{{i}}</li>", "A");
::is scalar do {A->for}, "<li>1</li><li>2</li>", 'A->for  # => <li>1</li><li>2</li>';

# 
# ## Tags without close
# 
# 1. Теги area, base, br, col, embed, hr, img, input, link, мета, param, source, track и wbr отображаются без закрывающего тега или косой черты.
# 2. К тегам HTML добавляется закрывающий тег.
# 3. Свойство `content => ...` не передается в теги perl-модуля.
# 
# ## Tags as Perl-module
# 
# Теги с `::` используют другие модули Perl.
# 
# Файл lib/Hello.pm:
#@> lib/Hello.pm
#>> package Hello;
#>> use Aion;
#>> with qw/Aion::Sige/;
#>> has world => (is => 'ro');
#>> 1;
#>> __DATA__
#>> @render
#>> Hello, {{world}}
#@< EOF
# 
# Файл lib/Hello/World.pm:
#@> lib/Hello/World.pm
#>> package Hello::World;
#>> use Aion;
#>> with qw/Aion::Sige/;
#>> 1;
#>> __DATA__
#>> @render
#>> <Hello:: world = "{{'World'}}!"   />
#>> <Hello:: world = "six"   />
#@< EOF
# 
done_testing; }; subtest 'Tags as Perl-module' => sub { 
require Hello::World;
::is scalar do {Hello::World->render}, "Hello, World!\n\nHello, six\n\n", 'Hello::World->render  # => Hello, World!\n\nHello, six\n\n';

::is scalar do {Hello->new(world => "mister")->render}, "Hello, mister\n", 'Hello->new(world => "mister")->render  # => Hello, mister\n';

# 
# ## Comments
# 
# HTML-комментарии (`<!-- ... -->`) удаляются из текста.
# 
done_testing; }; subtest 'Comments' => sub { 
eval Aion::Sige->compile_sige("\@remark\n1<!-- x -->2", "A");
::is scalar do {A->remark}, "12", 'A->remark  # => 12';

# 
# ## Exceptions
# 
done_testing; }; subtest 'Exceptions' => sub { 
::like scalar do {eval { Aion::Sige->compile_sige("\@x\n<a if=1 if=2 />\n\n", "A") }; $@}, qr!A 2:9 The if attribute is already present in the <a>!, 'eval { Aion::Sige->compile_sige("\@x\n<a if=1 if=2 />\n\n", "A") }; $@  # ~> A 2:9 The if attribute is already present in the <a>';

::like scalar do {eval { Aion::Sige->compile_sige("\@x\n<a if=\"1\" />", "A") }; $@}, qr!A 2:4 Double quote not supported in attr if in the <a>!, 'eval { Aion::Sige->compile_sige("\@x\n<a if=\"1\" />", "A") }; $@  # ~> A 2:4 Double quote not supported in attr if in the <a>';

::like scalar do {eval { Aion::Sige->compile_sige("\@x\n<x if=1><a else-if=\"1\" />", "A") }; $@}, qr!Double quote not supported in attr else-if in the <a>!, 'eval { Aion::Sige->compile_sige("\@x\n<x if=1><a else-if=\"1\" />", "A") }; $@  # ~> Double quote not supported in attr else-if in the <a>';

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
# Aion::Sige is copyright (c) 2023 by Yaroslav O. Kosmina. Rusland. All rights reserved.

	done_testing;
};

done_testing;
