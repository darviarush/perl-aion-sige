# NAME

Aion::Sige - .

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
<product-list list=list>
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

my $result = "";

Product->new(caption => "tiger", list => [[1, '<dog>'], [3, '"cat"']])->render  # -> $result
```

# DESCRIPTION

Aion::Sige parses html in the \__DATA__ section or in the html file of the same name located next to the module.

Attribute values ​​enclosed in single quotes are calculated. Attribute values ​​without quotes are also calculated. They must not have spaces.

Tags with a dash in their name are considered classes and are converted accordingly: `<product-list list=list>` to `use Product::List; Product::List->new(list => $self->list)->render`.

# SUBROUTINES

## sige ($pkg, $template)

Compile the template to perl-code and evaluate it into the package.


# SIGE LANGUAGE

## Routine

## Attribute if
## Attribute else-if
## Attribute else
## Attribute for

## Tags without close

## Comments

## Evaluate attrs

## Evaluate insertions

# AUTHOR

Yaroslav O. Kosmina <dart@cpan.org>

# COPYRIGHT AND LICENSE
This software is copyright (c) 2023 by Yaroslav O. Kosmina.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.

⚖ **GPLv3**