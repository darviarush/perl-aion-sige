!ru:en
# NAME

Aion::Sige - шаблонизатор html-подобного языка vue

# VERSION

0.0.0-prealpha

# SYNOPSIS

File lib/Product.pm:
```perl
package Product;
use Aion;

with 'Aion::Sige';

has caption => (is => 'ro', isa => Maybe[Str]);
has list => (is => 'ro', isa => ArrayRef[Tuple[Int, Str]]);

1;
__DATA__
@render

<img if=caption src=caption>
\ \' ₽
<Product::List list=list />
```

File lib/Product/List.pm:
```perl
package Product::List;
use Aion;

with 'Aion::Sige';

has caption => (is => 'ro', isa => Maybe[Str]);
has list => (is => 'ro', isa => ArrayRef[Tuple[Int, Str]]);

1;
__DATA__
@render

<ul>
    <li>first
    <li for='element in list' class="piase{{ element[0] }}">{{ element[1] }}
</ul>
```

```perl
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

Product->new(caption => "tiger", list => [[1, '<dog>'], [3, '"cat"']])->render # -> $result
```

# DESCRIPTION

Aion::Sige анализирует html в разделе \__DATA__ или в одноименном html-файле, расположенном рядом с модулем.

Вычисляются значения атрибутов, заключенные в одинарные кавычки. Также рассчитываются значения атрибутов без кавычек. В них не должно быть пробелов.

Теги с дефисом в названии считаются классами и соответствующим образом преобразуются: `<Product::List list=list>` в `use Product::List; Product::List->new(list => $self->list)->render`.

# SUBROUTINES

## import_with ($pkg)

Срабатывает, когда роль прикреплена к классу. Компилирует код sige в код Perl, чтобы `@routine` стали методами класса.

## compile_sige ($template, $pkg)

Компилирует шаблон в Perl-код и выполняет его в пакете.

## require_sige ($pkg)

Компилирует sige в указанный пакет.

Если достаточно прав, он создает одноимённый файл рядом с файлом $pkg-module и расширением `.pm$sige`, затем подключает этот файл с помощью `require` и удаляет его. Это делается для обеспечения адекватной трассировки стека.

Если прав недостаточно, то просто выполнится `eval`.

File lib/RequireSige.pm:
```perl
package RequireSige;
use Aion;
with Aion::Sige;
1;
__DATA__
@render
{{ &die "---" }}
```

```perl
use feature qw/defer/;
my $perm = (stat "lib")[2] & 07777;
defer { chmod $perm, "lib" or die "chmod -w lib: $!" }

use Fcntl qw/:mode/;
chmod $perm & ~(S_IWUSR | S_IWGRP | S_IWOTH), "lib" or die "chmod -w lib: $!";

require './lib/RequireSige.pm';
eval { RequireSige->render }; $@   # ~> ^--- at \(eval \d+\)
```

# SIGE LANGUAGE

Код шаблона находится в одноименном файле `*.html` рядом с модулем или в разделе `__DATA__`. Но в каком-то одном месте.

File lib/Ex.pm:
```perl
package Ex;
use Aion;
with Aion::Sige;
1;
__DATA__
@render
123
```

File lib/Ex.html:
```html
123
```

```perl
eval "require Ex";
$@   # ~> The sige code in __DATA__ and in \*\.html!
```

## Subroutine

С начала строки и символа @ начинаются методы, которые можно вызвать из текущего пакета:

File lib/ExHtml.pm:
```perl
package ExHtml;
use Aion;
with Aion::Sige;
1;
```

File lib/ExHtml.html:
```html
@render
567
@mix
890
```

```perl
require 'ExHtml.pm';
ExHtml->render # -> "567\n"
ExHtml->mix    # -> "890\n"
```

## Evaluate insertions

Выражение в `{{ }}` вычисляются.

File lib/Ex/Insertions.pm:
```perl
package Ex::Insertions;
use Aion;
with Aion::Sige;

has x => (is => 'ro');

sub plus {
	my ($self, $x, $y) = @_;
	$x + $y
}

sub x_plus {
	my ($x, $y) = @_;
	$x + $y
}

1;

__DATA__
@render
{{ x }} {{ x !}}
@math
{{ x + 10 }}
@call
{{ x_plus(x, 3) }}-{ this.plus(x, 5) }}
@strings
{{ "\t" . 'hi!' }}
@hash
{{ x:key }}
@array
{{ x[0] }}, {{ x[1] }}
```

```perl
require Ex::Insertions;
Ex::Insertions->new(x => "&")->render       # => &amp; &\n
Ex::Insertions->new(x => 10)->math          # => 20\n
Ex::Insertions->new(x => 10)->call          # => 13-15\n
Ex::Insertions->new->strings                # => \thi!\n
Ex::Insertions->new(x => {key => 5})->hash  # => 5\n
Ex::Insertions->new(x => [10, 20])->array   # => 10, 20\n
```

## Evaluate attrs

Атрибуты со значениями в `""` считаются строкой, а атрибуты в `''` или без кавычек считаются выражением.

Если значение атрибута — `undef`, то атрибут не рендерится.

File lib/Ex/Attrs.pm:
```perl
package Ex::Attrs;
use Aion;
with Aion::Sige;

has x => (is => 'ro', default => 10);

1;
__DATA__
@render
<a href="link" cat='x + 3' dog=x/2 disabled noshow=undef/>
```

```perl
require Ex::Attrs;
Ex::Attrs->new->render       # => <a href="link" cat="13" dog="5" disabled></a>\n
```

## Attributes if, else-if and else

File lib/Ex/If.pm:
```perl
package Ex::If;
use Aion;
with Aion::Sige;

has x => (is => 'ro');

1;
__DATA__
@full
<a if = 'x > 0' />
<b else-if = x<0 />
<i else />

@elseif
<a if = 'x > 0' />
<b else-if = x<0 />

@ifelse
<a if = 'x > 0' />
<i else>-</i>

@many
<a if = x==1><hr if=x><e else>*</e></a>
<b else-if = x==2/>
<c else-if = x==3 >{{x}}</c>
<d else-if = x==4 />
<e else />
```

```perl
require Ex::If;
Ex::If->new(x=> 1)->full # => <a></a>\n
Ex::If->new(x=>-1)->full # => <b></b>\n
Ex::If->new(x=> 0)->full # => <i></i>\n\n

Ex::If->new(x=> 1)->elseif # => <a></a>\n
Ex::If->new(x=>-1)->elseif # => <b></b>\n\n
Ex::If->new(x=> 0)->elseif # -> ""

Ex::If->new(x=> 1)->ifelse # => <a></a>\n
Ex::If->new(x=> 0)->ifelse # => <i>-</i>\n\n

Ex::If->new(x=> 1)->many # => <a><hr></a>\n
Ex::If->new(x=> 2)->many # => <b></b>\n
Ex::If->new(x=> 3)->many # => <c>3</c>\n
Ex::If->new(x=> 4)->many # => <d></d>\n
Ex::If->new(x=> 5)->many # => <e></e>\n
```

## Attribute for

```perl
eval Aion::Sige->compile_sige("\@for\n<li for = 'i in [1,2]'>{{i}}</li>", "A");
A->for  # => <li>1</li><li>2</li>
```

## Tags without close

1. Теги area, base, br, col, embed, hr, img, input, link, meta, param, source, track and wbr рендерятся без закрывающего тега или косой черты.
2. К тегам HTML добавляется закрывающий тег.
3. `content => ...` свойство не передаётся в perl-теги.

## Tags as Perl-module

Теги с `::` используют другие модули Perl.

File lib/Hello.pm:
```perl
package Hello;
use Aion;
with qw/Aion::Sige/;
has world => (is => 'ro');
1;
__DATA__
@render
Hello, {{world}}
```

File lib/Hello/World.pm:
```perl
package Hello::World;
use Aion;
with qw/Aion::Sige/;
1;
__DATA__
@render
<Hello:: world = "{{'World'}}!"   />
<Hello:: world = "six"   />
```

```perl
require Hello::World;
Hello::World->render  # => Hello, World!\n\nHello, six\n\n

Hello->new(world => "mister")->render  # => Hello, mister\n
```

## Comments

HTML-комментарии, такие как `<!-- ... -->` – удаляются из текста.

```perl
eval Aion::Sige->compile_sige("\@remark\n1<!-- x -->2", "A");
A->remark  # => 12
```

## Exceptions

```perl
eval { Aion::Sige->compile_sige("\@x\n<a if=1 if=2 />\n\n", "A") }; $@  # ~> A 2:9 The if attribute is already present in the <a>

eval { Aion::Sige->compile_sige("\@x\n<a if=\"1\" />", "A") }; $@  # ~> A 2:4 Double quote not supported in attr if in the <a>
eval { Aion::Sige->compile_sige("\@x\n<x if=1><a else-if=\"1\" />", "A") }; $@  # ~> Double quote not supported in attr else-if in the <a>
```

# AUTHOR

Yaroslav O. Kosmina <dart@cpan.org>

# LICENSE

⚖ **GPLv3**

# COPYRIGHT

Aion::Sige is copyright (c) 2023 by Yaroslav O. Kosmina. Rusland. All rights reserved.
