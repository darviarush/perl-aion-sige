package Aion::Sige;
use common::sense;

use Aion::Format qw/matches/;
use Aion::Format::Html qw/in_tag out_tag/;

use Aion;

# Шаблоны js
has sige => (is => 'ro', isa => Str);

# Компилирует шаблон в код perl
my $RE_ATTR = qr{
    (?<attr>\w+) \s* = \s*
        ( ' (?<onequote> (\\'|[^'])* ) '
        | " (?<dblquote> (\\"|[^"])* ) "
        | (?<noquote> [^\s>]+ )
        )
    | \{\{ (?<ins> .*?) \}\}
}xn;
my $RE_ATTRS = qr{ ( (?<space> \s*) $RE_ATTR )* }xn;

# Компилирует шаблоны
sub _compile_sige {
	my ($self, $code, $pkg) = @_;

    # Переводит выражение шаблонизатора в выражение perl
    my $exp = sub {
        my ($y) = @_;

        my $res = sub {
            exists $+{var}? ((
                $+{who} eq "&"? $+{var}:
                $+{who} eq "."? "->$+{var}":
                $+{who} eq ":"? "->{$+{var}}":
                "(exists \$kw{$+{var}}? \$kw{$+{var}}: \$self->$+{var})") . (exists $+{sk}? "->[": "")
            ):
            exists $+{call}? $+{call}:
            $&
        };

        $y =~ s{
            \b (ge|le|gt|lt|ne|eq|and|or|not) \b
            | (?<call> [a-z_] \( )
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
        my ($y) = @_;
        $y =~ s/\{\{(.*?)\}\}/join "", "', do {", $exp->($1), "},'"/ge;
        $y
    };

    # Стек тегов
    my @S;

    matches $code,
        qr{<(?<tag> [a-z]\w*) (?<attrs> $RE_ATTRS) \s* >}xino => sub {
            my ($tag, $attrs) = @+{qw/tag attrs/};

            my @attrs;

            while($attrs =~ m{ $RE_ATTR }xngo) {
                my ($space, $attr) = @+{qw/space attr/};

                push @attrs, "$space$attr=', ", $exp->($+{onequote}), ", '" when exists $+{onequote};
                push @attrs, "$space$+{attr}=', do {", $exp->($+{noquote}), "}, '" when exists $+{noquote};
                push @attrs, "$space$+{attr}=\"", $text->($+{dblquote}), "\"" when exists $+{dblquote};
                push @attrs, "$space', do {", $exp->($+{ins}), "}, '" when exists $+{ins};
            }

            my $atag = "<tag@attrs>";
            in_tag @S, $tag, $atag;
            $atag
        },
        qr!</ (?<tag> [a-z]\w*) \s*>!ix => sub {
            my $tag = $+{tag};
            out_tag @S, $tag;
            "</$tag>"
        },
        qr! \{\{ (?<ins> .*?) \}\} !x => sub {
            my $ins = $exp->($+{ins});
            "', do {$ins}, '"
        },
        qr{<!--.*?-->}s => sub {
            $&
        },
        qr!['\\]! => sub {
            "\\\&"
        },
    ;

	$self
}

1;