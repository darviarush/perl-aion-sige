package Aion::Sige;
use common::sense;

use Aion::Format qw/matches/;
use Aion::Format::Html qw/in_tag is_single_tag out_tag to_html/;
use Aion::Fs qw/from_pkg cat lay mkpath/;

use config DEBUG => 0;

use Aion -role;

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

# Компилирует шаблоны в код perl
sub _compile_sige {
	my ($self, $code, $pkg) = @_;

    # Без пробелов при вставке в строки массивов
    local $" = "";

    # Локальные переменные для for
    my %VAR;

    # Возвращает номер строки и символа
    my $on = sub {
        my $line;
        $line++ while $` =~ /\n/g;
        my $char = $';
        "$pkg#$line/$char:"
    };

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
            \b (ge|le|gt|lt|ne|eq|and|or|not|undef) \b
            | \b (?<self> self) \b
            | (?<call> [a-z_]\w+ \( )
            | (?<who> [&:.])? (?<var> [a-z_]\w* ) (?<sk> \[ )?
            | "(\\"|[^"])*"
            | '(\\'|[^'])*'
        }{
            $res->()
        }axinge;
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

        if(DEBUG) { require "DDP.pm";
            my ($pkg, $file, $line) = caller(0);
            DDP::p(my $x=["end_tags $pkg at $line", @_]); 
        }

        for(@_) {
            my $stash = $_->[1];

            if(exists $stash->{if}) {
                push @add, "'): (), '";
            }
            elsif(exists $stash->{elseif}) {
                push @add, "'): (), '";
            }
            elsif(exists $stash->{else}) {
                push @add, "'), '";
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
    my $close_tag;  # Закрывающий тег – для атрибутов if и for
    my $routine;    # Текущая подпрограмма

    matches $code,
        qr{ (?<space> [\ \t]+ )?
            <(?<tag> [a-z_][\w:-]*) (?<attrs> (
              ' (\\'|[^'])* '
            | " (\\"|[^"])* "
            | {{ .*? }}
            | [^>]
        )*) >}ainx => sub {
            my ($before_space, $tag, $attrs) = @+{qw/space tag attrs/};
            my $inline = $attrs =~ s/\/\z//;
            $attrs =~ s!\s*$!!;

            my $is_pkg = $tag =~ /::/;
            $tag = lc $tag unless $is_pkg;
            my @attrs;
            my $if;
            my $elseif;
            my $else;
            my $for;
            my $last;

            if(DEBUG) { require 'DDP.pm'; DDP::p(my $x=["<$tag>", {attrs => $attrs, inline => $inline}]); }

            while($attrs =~ m{ \G
                (?<space> \s*)
                (?<attr>[a-z_-][\w:-]*) ( \s* = \s*
                    ( ' (?<onequote> (\\'|[^'])* ) '
                    | " (?<dblquote> (\\"|[^"])* ) "
                    | (?<noquote> [^\s>]+ )
                    ) )?
                | \{\{ (?<ins> .*?) \}\}
            }axng) {
                $last = length $';
                my ($space, $attr) = @+{qw/space attr/};

                if(DEBUG) { require 'DDP.pm'; DDP::p(my $x=["attr", $space, $attr]); }

                die "${\$on->()} Double quote not supported in attr $attr" if exists $+{dblquote} and $attr ~~ [qw/if else-if for/];

                if($attr eq "if") {
                    die "${\ $on->()} The if attribute is already present in the <$tag>" if defined $if;

                    $if = $exp->($+{onequote} // $+{noquote});
                }
                elsif($attr eq "else-if") {
                    die "${\ $on->()} The else-if attribute is already present in the <$tag>" if defined $elseif;

                    $elseif = $exp->($+{onequote} // $+{noquote});
                }
                elsif($attr eq "else") {
                    die "${\ $on->()} The else attribute is already present in the <$tag>" if defined $else;

                    $else = 1;
                }
                elsif($attr eq "for") {
                    die "${\ $on->()} The for attribute is already present in the <$tag>" if defined $for;

                    die "${\ $on->()} The if-attribute must be placed after for-attribute in the <$tag>" if defined $if;

                    $for = $+{onequote} // $+{noquote};
                    my ($var, $data) = $for =~ /^\s*([a-z]\w*)\s*in\s*(.*)\s*$/ais;
                    die "${\ $on->()} Use for='variable in ...'!" unless defined $var;
                    die "${\ $on->()} This variable $var is used!" if exists $VAR{$var};
                    $VAR{$var} = 1;
                    $for = [$var, $data];
                }
                elsif(exists $+{ins}) {
                    my $ins = $exp->($+{ins});
                    if($is_pkg) {
                        push @attrs, "${space}do {$ins}, "
                    } else {
                        push @attrs, "$space', Aion::Format::Html::to_html(do {$ins}), '"
                    }
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
                else {
                    if($is_pkg) {
                        push @attrs, "$space$attr => undef, ";
                    } else {
                        push @attrs, "$space$attr";
                    }
                }
            }

            die join '', "<$tag$attrs>\n", (' ' x (1 + length($tag) + length($attrs) - $last)), "^\n---" if $last;

            die "${\ $on->()} Attributes for and else is ambigous" if $for && $else;
            die "${\ $on->()} Attributes for and else-if is ambigous" if $for && $elseif;
            die "${\ $on->()} Attributes if and else-if is ambigous" if $if && $elseif;
            die "${\ $on->()} Attributes if and else is ambigous" if $if && $else;

            my @close_tag_end;
            if($close_tag) {
                if($else || $elseif) {
                    my $stash = $close_tag->[1];
                    if($stash->{if}) {delete $stash->{if}}
                    elsif($stash->{elseif}) {delete $stash->{elseif}}
                }
                @close_tag_end = $end_tags->($close_tag);
                undef $close_tag;
            }

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
            my @add;
            if($if) {
                push @add, "', do{$if}? ('";
                $stash->{if} = 1;
            }
            elsif($elseif) {
                push @add, "'): do{$elseif}? ('";
                $stash->{elseif} = 1;
            }
            elsif($else) {
                push @add, "'): ('";
                $stash->{else} = 1;
            }

            if($for) {
                my ($var, $data) = @$for;
                push @add, "', (map { my \$_$var = \$_; '";
                $stash->{"for"} = [$var, $exp->($data)];
            }

            if(DEBUG) { require "DDP.pm"; DDP::p(my $x=["S, tag, stash", \@S, $tag, $stash]); }

            my @intags = $end_tags->(in_tag @S, $tag, $stash);
            my $etag;
            if(is_single_tag($tag)) {
                $close_tag = [$tag, $stash];
            }
            elsif($inline) {
                $close_tag = pop @S;
                $etag = $stash->{end_tag};
            }

            "@intags@close_tag_end@add$before_space$atag$etag"
        },
        qr!(?<space> [\ \t]+ )? </ (?<tag> [a-z_][\w:-]*) \s*>!ainx => sub {
            my ($space, $tag) = @+{qw/space tag/};
            my $is_pkg = $tag =~ /::/;
            $tag = lc $tag unless $is_pkg;

            my @close_tag_end = $close_tag? $end_tags->($close_tag): ();

            my @out = out_tag @S, $tag;
            $close_tag = pop @out;
            @out = $end_tags->(@out);
            "@out@close_tag_end$space$close_tag->[1]->{end_tag}"
        },
        qr! \{\{ (?<ins> .*?) (?<nohtml> \!)? (?<space> \s*) \}\} !xsn => sub {
            my $ins = $exp->($+{ins});
            exists $+{nohtml} ? "', do {$ins}, '": "', Aion::Format::Html::to_html(do {$ins$+{space}}), '"
        },
        qr{<!--.*?-->}s => sub {
            my @close = $close_tag? $end_tags->($close_tag): ();
            undef $close_tag;
            @close
        },
        qr!['\\]! => sub {
            "\\$&"
        },
        qr{ ^ \@(?<name> \w+) [ \t]* \n }amnx => sub {
            die "${\ $on->()} There are still unclosed tags: " . join "", map "<$_->[0]>", @S if @S;

            my @close_tag = $close_tag? $end_tags->($close_tag): ();
            undef $close_tag;

            join "", @close_tag,
            $routine? "'}" : (),
            "sub ", $routine = $+{name}, " {\n\tmy (\$self) = \@_; return join '', '"
        },
        qr!\A! => sub {
            "package $pkg; use common::sense; "
        },
        qr!\z! => sub {
            die "${\ $on->()} Not methods in sige!" unless $routine;
            die "${\ $on->()} There are still unclosed tags: " . join "", map "<$_->[0]>", @S if @S;
            join "", $close_tag? $end_tags->($close_tag): (), "' } 1;"
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
	    <li class="piase1">&lt;dog&gt;
	    <li class="piase3">&quot;cat&quot;
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

Attributes with values ​​in C<""> are considered a string, while those in C<''> or without quotes are considered an expression.

If value of attribute is C<undef>, then attribute is'nt show.

File lib/Ex/Attrs.pm:

	package Ex::Attrs;
	use Aion;
	with Aion::Sige;
	
	has x => (is => 'ro', default => 10);
	
	1;
	__DATA__
	@render
	<a href="link" cat='x + 3' dog=x/2 disabled noshow=undef/>



	require Ex::Attrs;
	Ex::Attrs->new->render       # => <a href="link" cat="13" dog="5" disabled></a>\n

=head2 Attributes if, else-if and else

File lib/Ex/If.pm:

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

eval { Aion::Sige->I<compile>sige("\@x\n<a if=1 if=2 />") }; $@  # ~> The if attribute is already present in the <a>

eval { Aion::Sige->I<compile>sige("\@x\n<a if="1" />") }; $@  # ~> Double quote not supported in attr C<if> in the <a>

=head2 Attribute for

=head2 Tags without close

=head2 Comments

=head1 AUTHOR

Yaroslav O. Kosmina L<mailto:dart@cpan.org>

=head1 LICENSE

⚖ B<GPLv3>

=head1 COPYRIGHT

Aion::Sige is copyright © 2023 by Yaroslav O. Kosmina. Rusland. All rights reserved.
