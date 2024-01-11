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
    <li class="piase1">&lt;dog&gt;<li class="piase3">&quot;cat&quot;
</ul>

';

Product->new(caption => "tiger", list => [[1, '<dog>'], [3, '"cat"']])->render # -> $result
```

# DESCRIPTION

Aion::Sige parses html in the \__DATA__ section or in the html file of the same name located next to the module.

Attribute values ​​enclosed in single quotes are calculated. Attribute values ​​without quotes are also calculated. They must not have spaces.

Tags with a dash in their name are considered classes and are converted accordingly: `<Product::List list=list>` to `use Product::List; Product::List->new(list => $self->list)->render`.

# SUBROUTINES

## sige ($pkg, $template)

Compile the template to perl-code and evaluate it into the package.


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
<i else>-</i>

@elseif
<a if = 'x > 0' />
<b else-if = x<0 />

@ifelse
<a if = 'x > 0' />
<i else>-</i>

@many
<a if = 'x == 1' />
<b else-if = x==2 />
<с else-if = x==3 >{{x}}</c>
<d else-if = x==4 />
<e else />
```

```perl
require Ex::If;
Ex::If->new(x=> 1)->full # => <a></a>\n\n
Ex::If->new(x=>-1)->full # => <b></b>\n\n
Ex::If->new(x=> 0)->full # => <i>-</i>\n\n

Ex::If->new(x=> 1)->ifelse # => <a></a>\n\n
Ex::If->new(x=> 0)->ifelse # => <i></i>\n\n

Ex::If->new(x=> 1)->many # => <a></a>\n\n
Ex::If->new(x=> 2)->many # => <b></b>\n\n
Ex::If->new(x=> 3)->many # => <c>3</c>\n\n
Ex::If->new(x=> 4)->many # => <d></d>\n\n
Ex::If->new(x=> 5)->many # => <e></e>\n\n
```

## Attribute for

## Tags without close

## Comments

# AUTHOR

Yaroslav O. Kosmina <dart@cpan.org>

# LICENSE

⚖ **GPLv3**

# COPYRIGHT

Aion::Sige is copyright © 2023 by Yaroslav O. Kosmina. Rusland. All rights reserved.
