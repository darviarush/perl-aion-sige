package Aion::Sige;
use common::sense;

use Aion::Format qw/matches/;
use Aion::Format::Html qw/in_tag is_single_tag out_tag to_html/;
use Aion::Fs qw/from_pkg cat lay mkpath/;

use config DEBUG => 0;

use Aion -role;

# Шаблоны js
has sige => (is => 'ro', isa => Str);

# Срабатывает при использовании роли
sub import_with {
	my ($self, $pkg) = @_;

	$self->_require_sige($pkg)
}

# Определяет, где находится код шаблона: в __DATA__ или в соседнем *.html, компилит и присоединяет к своему пакету его функции
sub _require_sige {
	my ($self, $pkg) = @_;
    my $pm = "lib/" . from_pkg $pkg;
    my $html = $pm =~ s/\.(\w+)$/.html/r;
    my ($prev, $data) = (cat $pm) =~ m!\A(.*?)^__DATA__\n(.*?)(?:^__END__|\z)!ms;

    die "The sige code in __DATA__ and in *.html!" if -e $html and defined $data;

    my $code = defined $data? do {
        # Добавляем переводы строк,
        # чтобы при ошибке показывала соответствующую строку
        my $c = 1;
        $c++ while $prev =~ /\n/g;
        ("\n" x $c) . $data
    }: cat $html;

    my $sige = $self->_compile_sige($code, $pkg);

    print STDERR "\n\n$sige\n\n" if DEBUG;

    my $sig = './' . ($pm =~ s/\.(\w+)$/.sige/r);
    $sig = eval { mkpath $sig };
    if(defined $sig and open my $f, ">:utf8", $sig) {
        print $f $sige;
        close $f;
        require $sig;
        unlink $sig or die "unlink $sig: $!";
    } else {
        eval $sige;
        die if $@;
    }
}

# Компилирует шаблон в код perl
my $RE_ATTR = qr{
    (?<space> \s*)
    (?<attr>\w+) \s* = \s*
        ( ' (?<onequote> (\\'|[^'])* ) '
        | " (?<dblquote> (\\"|[^"])* ) "
        | (?<noquote> [^\s>]+ )
        )
    | \{\{ (?<ins> .*?) \}\}
}xn;

# Компилирует шаблоны в код perl
sub _compile_sige {
	my ($self, $code, $pkg) = @_;

    # Без пробелов при вставке в строки массивов
    local $" = "";

    # Локальные переменные для for
    my %VAR;

    # Переводит выражение шаблонизатора в выражение perl
    my $exp = sub {
        my ($y) = @_;

        my $res = sub {
            exists $+{var}? ((
                    $+{who} eq "&"? $+{var}:
                    $+{who} eq "."? "->$+{var}":
                    $+{who} eq ":"? "->{$+{var}}":
                    (exists $VAR{$+{var}}? "\$_$+{var}": "\$self->$+{var}")
                ) . (exists $+{sk}? "->[": "")
            ):
            exists $+{call}? $+{call}:
            exists $+{self}? '$self':
            $&
        };

        $y =~ s{
            \b (ge|le|gt|lt|ne|eq|and|or|not) \b
            | \b (?<self> self) \b
            | (?<call> [a-z_]\w+ \( )
            | (?<who> [&:.])? (?<var> [a-z_]\w* ) (?<sk> \[ )?
            | "(\\"|[^"])*"
            | '(\\'|[^'])*'
        }{
            $res->()
        }xinge;
        $y
    };

    # Переводит выражения {{ ... }} в тексте в выражение perl
    my $text = sub {
        my ($y, $perl) = @_;
        my $is = $y =~ s/\{\{(.*?)(!)?\}\}/ join "",
            $perl || $2? ("', do {", $exp->($1), "}, '")
            : ("', Aion::Format::Html::to_html(do {", $exp->($1), "}), '")
        /ge;
        $perl? (
            $is? "join('', '$y')": "'$y'"
        ): $y
    };

    my $end_tags = sub {
        my @add;

        if(DEBUG) { require "DDP.pm"; DDP::p(my $x=["end_tags", @_]); }

        for(@_) {
            my $stash = $_->[1];

            if(exists $stash->{if}) {
                push @add, "'): (), '";
            }
            elsif(exists $stash->{elseif}) {
                push @add, "'): do{$stash->{elseif}} ? ('";
            }
            elsif(exists $stash->{else}) {
                push @add, "'): ('";
            }

            if(my $for = $stash->{for}) {
                my ($var, $val) = @$for;
                delete $VAR{$var};
                push @add, "' } \@{$val}), '";
            }
        }

        @add
    };

    my @S;          # Стек тегов
    my $close_tag;  # Закрывающий тег
    my $routine;    # Текущая подпрограмма

    matches $code,
        qr{<(?<tag> [a-z][\w:-]*) (?<attrs> ($RE_ATTR)*) \s* (?<inline> /)? >}xino => sub {
            my ($tag, $attrs, $inline) = @+{qw/tag attrs inline/};

            my $is_pkg = $tag =~ /::/;
            $tag = lc $tag unless $is_pkg;
            my @attrs;
            my $if;
            my $elseif;
            my $else;
            my $for;

            while($attrs =~ m{ $RE_ATTR }xngo) {
                my ($space, $attr) = @+{qw/space attr/};

                if(DEBUG) { require 'DDP.pm'; DDP::p(my $x=["attr", $space, $attr]); }

                if($attr eq "if") {
                    die "The if attribute is already present in the <$tag>" if defined $if;

                    $if = $exp->($+{onequote} // $+{noquote} // $+{dblquote});
                }
                elsif($attr eq "else-if") {
                    die "The else-if attribute is already present in the <$tag>" if defined $elseif;

                    $elseif = $exp->($+{onequote} // $+{noquote} // $+{dblquote});
                }
                elsif($attr eq "else") {
                    die "The else attribute is already present in the <$tag>" if defined $else;

                    $else = 1;
                }
                elsif($attr eq "for") {
                    die "The for attribute is already present in the <$tag>" if defined $for;

                    die "The if-attribute must be placed after for-attribute in the <$tag>" if defined $if;

                    $for = $+{onequote} // $+{noquote} // $+{dblquote};
                    my ($var, $data) = $for =~ /^\s*([a-z]\w*)\s*in\s*(.*)\s*$/is;
                    die "Use for='variable in ...'!" unless defined $var;
                    die "This variable $var is used!" if exists $VAR{$var};
                    $VAR{$var} = 1;
                    $for = [$var, $data];
                }
                elsif(defined(my $x = $+{onequote} // $+{noquote})) {
                    $x = $exp->($x);
                    if($is_pkg) {
                        push @attrs, "${space}do { my \$r = do {$x}; defined(\$r)? ($attr => \$r): () },";
                    } else {
                        push @attrs, "', do { my \$r = do {$x}; defined(\$r)? ('$space$attr=\"', Aion::Format::Html::to_html(\$r), '\"'): () }, '";
                    }
                }
                elsif(exists $+{dblquote}) {
                    if($is_pkg) {
                        push @attrs, "$space$attr => ", $text->($+{dblquote}, 1), ', ';
                    } else {
                        push @attrs, "$space$attr=\"", $text->($+{dblquote}), '"';
                    }
                }
                elsif(exists $+{ins}) {
                    my $ins = $exp->($+{ins});
                    if($is_pkg) {
                        push @attrs, "${space}do {$ins}, "
                    } else {
                        push @attrs, "$space', Aion::Format::Html::to_html(do {$ins}), '"
                    }
                }
                else { die "?" }
            }


            die "Attributes for and else is ambigous" if $for && $else;
            die "Attributes for and else-if is ambigous" if $for && $elseif;
            die "Attributes if and else-if is ambigous" if $if && $elseif;
            die "Attributes if and else is ambigous" if $if && $else;

            my $close_tag_end = $close_tag? $end_tags->($close_tag): undef;
            undef $close_tag;

            my $stash;

            my $atag = $is_pkg? do {
                my $tpkg = $tag =~ s!::$!!r;
                my $begin = "', Aion::Fs::include('$tpkg')->new(@attrs";
                if($inline) {
                    $stash->{end_tag} = ")->render, '";
                    $begin
                } else {
                    $stash->{end_tag} = "'))->render, '";
                    "$begin, content => join('', '"
                }
            }: do { $stash->{end_tag} = "</$tag>"; "<$tag@attrs>" };

            # Вначале if, чтобы если есть и for - построить в for if
            if($if) {
                $atag = "', do{$if}? ('$atag";
                $stash->{if} = 1;
            }
            elsif($elseif) {
                $stash->{elseif} = $elseif;
            }
            elsif($else) {
                $stash->{else} = 1;
            }

            if($for) {
                my ($var, $data) = @$for;
                $atag = "', (map { my \$_$var = \$_; '$atag";
                $stash->{"for"} = [$var, $exp->($data)];
            }

            if(DEBUG) { require "DDP.pm"; DDP::p(my $x=["S, tag, stash", \@S, $tag, $stash]); }

            my @add = $end_tags->(in_tag @S, $tag, $stash);
            my @single_tag_close;
            if(is_single_tag($tag)) {
                @single_tag_close = $end_tags->([$tag, $stash]);
            }
            elsif($inline) {
                pop @S;
                push @single_tag_close,
                    $stash->{end_tag},
                    $end_tags->([$tag, $stash]);
            }
            "@add$close_tag_end$atag@single_tag_close"
        },
        qr!(?<space> \s*)</ (?<tag> [a-z][\w:-]*) \s*>!ix => sub {
            my ($space, $tag) = @+{qw/space tag/};
            my $is_pkg = $tag =~ /::/;
            $tag = lc $tag unless $is_pkg;
            my @out = out_tag @S, $tag;
            $close_tag = pop @out;
            @out = $end_tags->(@out);
            "@out$space$close_tag->[1]->{end_tag}"
        },
        qr! \{\{ (?<ins> .*?) (?<nohtml> \!)? (?<space> \s*) \}\} !xs => sub {
            my $ins = $exp->($+{ins});
            exists $+{nohtml} ? "', do {$ins}, '": "', Aion::Format::Html::to_html(do {$ins$+{space}}), '"
        },
        qr{<!--.*?-->}s => sub {
            my $close = $close_tag? $end_tags->($close_tag): "";
            undef $close_tag;
            $close
        },
        qr!['\\]! => sub {
            "\\$&"
        },
        qr{^\@(?<name> \w+)[ \t]*\n}mnx => sub {
            join "", $routine? "'}" : (),
            "sub ", $routine = $+{name}, " {\n\tmy (\$self) = \@_; return join '', '"
        },
        qr!\A! => sub {
            "package $pkg; use common::sense; "
        },
        qr!\z! => sub {
            die "Not methods in sige!" unless $routine;
            my @end_tags = $end_tags->(@S, $close_tag? $close_tag: ());
            die "There are still unclosed tags: " . join "", map "<$_->[0]>", @S if @S;
            join "", @end_tags, "' } 1;"
        },
    ;
}

1;

__END__

=encoding utf-8

=head1 NAME

Aion::Sige - templater (html-like language, it like vue)

=head1 VERSION

0.0.0-prealpha

=head1 SYNOPSIS

File lib/Product.pm:

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

File lib/Product/List.pm:

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

=head1 DESCRIPTION

Aion::Sige parses html in the __DATA__ section or in the html file of the same name located next to the module.

Attribute values ​​enclosed in single quotes are calculated. Attribute values ​​without quotes are also calculated. They must not have spaces.

Tags with a dash in their name are considered classes and are converted accordingly: C<< E<lt>Product::List list=listE<gt> >> to C<< use Product::List; Product::List-E<gt>new(list =E<gt> $self-E<gt>list)-E<gt>render >>.

=head1 SUBROUTINES

=head2 sige ($pkg, $template)

Compile the template to perl-code and evaluate it into the package.

=head1 SIGE LANGUAGE

The template code is located in the C<*.html> file of the same name next to the module or in the C<__DATA__> section. But not here and there.

File lib/Ex.pm:

	package Ex;
	use Aion;
	with Aion::Sige;
	1;
	__DATA__
	@render
	123

File lib/Ex.html:

	123



	eval "require Ex";
	$@   # ~> The sige code in __DATA__ and in \*\.html!

=head2 Subroutine

From the beginning of the line and the @ symbol, methods begin that can be called on the package:

File lib/ExHtml.pm:

	package ExHtml;
	use Aion;
	with Aion::Sige;
	1;

File lib/ExHtml.html:

	@render
	567
	@mix
	890



	require 'ExHtml.pm';
	ExHtml->render # -> "567\n"
	ExHtml->mix    # -> "890\n"

=head2 Evaluate insertions

Expression in C<{{ }}> evaluate.

File lib/Ex/Insertions.pm:

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



	require Ex::Insertions;
	Ex::Insertions->new(x => "&")->render       # => &amp; &\n
	Ex::Insertions->new(x => 10)->math          # => 20\n
	Ex::Insertions->new(x => 10)->call          # => 13-14-15\n
	Ex::Insertions->new->strings                # => \thi!\n
	Ex::Insertions->new(x => {key => 5})->hash  # => 5\n
	Ex::Insertions->new(x => [10, 20])->array   # => 10, 20\n

=head2 Evaluate attrs

=head2 Attribute if

=head2 Attribute else-if

=head2 Attribute else

=head2 Attribute for

=head2 Tags without close

=head2 Comments

=head1 AUTHOR

Yaroslav O. Kosmina L<mailto:dart@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2023 by Yaroslav O. Kosmina.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.

⚖ B<GPLv3>
