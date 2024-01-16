# NAME

Aion::Sige - templater (html-like language, it like vue)

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

Aion::Sige parses html in the \__DATA__ section or in the html file of the same name located next to the module.

Attribute values ​​enclosed in single quotes are calculated. Attribute values ​​without quotes are also calculated. They must not have spaces.

Tags with a dash in their name are considered classes and are converted accordingly: `<Product::List list=list>` to `use Product::List; Product::List->new(list => $self->list)->render`.

# SUBROUTINES

## import_with ($pkg)

Fires when a role is attached to a class. Compiles sige code into perl code so that `@routine` becomes class methods.

## compile_sige ($template, $pkg)

Compile the template to perl-code and evaluate it into the package.

## require_sige ($pkg)

Compiles sige in the specified package.

If you have enough rights, it creates a file next to the $pkg-module file and the `.pm$sige` extension, then connects this file using `require` and deletes it. This is done to provide an adequate stack trace.

If there are not enough rights, then `eval` will simply be executed.

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

The template code is located in the `*.html` file of the same name next to the module or in the `__DATA__` section. But not here and there.

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

From the beginning of the line and the @ symbol, methods begin that can be called on the package:

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

Expression in `{{ }}` evaluate.

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
{{ x_plus(x, 3) }}-{{ &x_plus x, 4 }}-{{ self.plus(x, 5) }}
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
Ex::Insertions->new(x => 10)->call          # => 13-14-15\n
Ex::Insertions->new->strings                # => \thi!\n
Ex::Insertions->new(x => {key => 5})->hash  # => 5\n
Ex::Insertions->new(x => [10, 20])->array   # => 10, 20\n
```

## Evaluate attrs

Attributes with values ​​in `""` are considered a string, while those in `''` or without quotes are considered an expression.

If value of attribute is `undef`, then attribute is'nt show.

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

1. Tags area, base, br, col, embed, hr, img, input, link, meta, param, source, track and wbr are displayed without a closing tag or slash.
2. A closing tag is added to HTML tags.
3. The `content => ...` property is not passed to perl-module tags.

## Tags as Perl-module

Tags with `::` use other perl-modules.

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

Html comments as is `<!-- ... -->` removes from text.

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

Aion::Sige is copyright © 2023 by Yaroslav O. Kosmina. Rusland. All rights reserved.
