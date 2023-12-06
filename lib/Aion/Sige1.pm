package Aion::Sige;
use 5.22.0;
no strict; no warnings; no diagnostics;
use common::sense;

our $VERSION = "0.0.0-prealpha";

use Exporter qw/import/;
our @EXPORT = our @EXPORT_OK = qw/sige/;

use Aion::Format qw/matches/;

# Огдоада:
# Bythos or Proarxh or Propatry - глубина или первоначало или праотец
# Sige or Ennoia or Haris - молчание или мысль (идея) или благодать - html
# Nous - ум
# Aletheia - истина - js
# Logos - слово - css
# Zoe - жизнь
# Anthropos - человек
# Ekklesia - церковь
# Sophia - Премудрость - pl|sql
# Achamoth - похоть - pl|sql+html+css+js
# Abraxas - Абраксас -

sub _str ($) { local $_=$_[0]; s/'/\\'/g; "'$_'" }
sub _exp ($) {
	my ($y) = @_;
	$y =~ s{
		\b (ge|le|gt|lt|ne|eq|and|or|not) \b
		| (?<call> [a-z_] \( )
		| (?<who> [&:.])? (?<var> [a-z_]\w* ) (?<sk> \[ )?
		| "(\\"|[^"])*"
		| '(\\'|[^'])*'
	}{
		exists $+{var}? ((
			$+{who} eq "&"? $+{var}:
			$+{who} eq "."? "->$+{var}":
			$+{who} eq ":"? "->{$+{var}}":
			"(exists \$kw{$+{var}}? \$kw{$+{var}}: \$self->$+{var})") . (exists $+{sk}? "->[": "")
		):
		exists $+{call}? $+{call}:
		$&
	}xinge;
	$y
}

sub _exp_html {
	my ($y) = @_;
	$y =~ s!(?<attr> \w+) = (?<val> '(\{\{.*?\}\}|[^'])*' | "(\{\{.*?\}\}|[^"])*" | \{\{.*?\}\} | \S+)!
		my $attr = $+{attr}; my $val = $+{val};
		$val =~ s/^["']?/'/s;
		$val =~ s/["']?\z/'/s;
		$val = "join('', $val)" if $val =~ s/\{\{(.*)?\}\}/join "", "', ", _exp($1), ", '"/ge;
		"$attr => $val,"
	!xgse;
	$y
}

# дампит данные в html
sub dump {
	my ($x) = @_;
	join "", "<div class=dump>", to_html(np $x), "</div>";
}

# используется в sige для тестирования переменных
sub test {
	my ($s) = @_;

	return scalar @$s if ref $s eq "ARRAY";
	return scalar keys %$s if ref $s eq "HASH";

	$s
}

# рендер
=pod
@@name - метод

Вставить свойство метода:

	{{ x.y.z }} -> to_html $self->x->y->z

Если нулевое значение, то вставить текст:

	{{ x.y.z | string }} -> to_html $self->x->y->z // " string "

Вызвать функцию начинающуюся на to_:

	{{ x.y.z -> json }} -> to_json($self->x->y->z)

! - вставить без экранирования символов html:

	{{x.y.z!}} -> $data->{x}->{y}->{z}

Условные вставки. _ - пробелы и табуляции:

	_{{y?}} -> y? '': '_style="display:none"'
	_{{y? A<sub>i<sub>}} -> y? '_A<sub>i<sub>': ''

Цикл:

	{{*z = x.y.z }} ... {{/*z}}

Условие:

	{{? !(x eq z) }} ... {{/?x}}

 - {{> dir/file }} -> sige "dir/file", $data
 - {{> $ x.y.z }} -> sige "$data->{x}->{y}->{z}", $data

Метод:

	@@ имя

Комментарии:

	{{{# многострочный комментарий c {{ ... }} }}}
	{{# многострочный комментарий }}

Присваивание:

	{{ x = y }}
	
Эон:

	<Eon::Windows::Window
		x=10px
		y={{object}}	# TODO: тут не будет конвертироваться в строку
		z="{{10 + "20"}}!"
	>
		<b>hi! {{ abc }}</b>
	</Eon::Windows::Window>
	
Присваивание блока:

	{{=x}} ... {{/=x}}

TODO: Цикл в стиле vue:

	<li for="x=list">{{x}}</li> или новый <li>
	
	<label For="id"> - атрибут for в <label>
	
TODO: Условие в стиле vue:

	<ul if="a < b">
	</ul>
	<ol else-if="a == 0">
	</ol>
	<p else>...</p>

=cut
sub sige_compile($$) {
	my ($sige, $pkg) = @_;

	my $dev = $main_config::dev;
	my @S;
	my $last_sub;
	$sige =~ s!^!\@\@render\n! if $sige !~ /\A\s*^@@[ \t]*\w+[ \t]*\r?$/m;
	
	$sige = replace $sige,
		
		qr/'/ => sub { "\\'" },
		qr/\\/ => sub { "\\\\" },
		
		qr/^@@[ \t]*(?<sub>\w+)[ \t]*\r?$/mn => sub {
			my $s = join "", !defined($last_sub)? (): ($dev && $last_sub ne "meta"? "<!-- /aion-mark -->": (), "' } "), # <!-- /aion-mark -->
				"sub ${pkg}::$+{sub} { my (\$self, %kw) = \@_; join '', '", $dev && $+{sub} ne "meta"? "<!-- aion-mark ${pkg}#$+{sub} -->": ();
			$last_sub = $+{sub};
			$s
		},
		
		#qr/\{\{ \s* ! (?<fn> \w+) \s* \}\}/x => sub { "', $+{fn}(\$data), '" },
		
		# Тернарный комментарий
		qr/(?<s> \s*) \{\{\{\# (?<comment>.*?) \}\}\}/sxn => sub { my $c=$+{comment}; { $c =~ s/'/\\'/g }; "', do { $+{s}'$c'; '' }, '" },

		# <Эон>
		qr/< (?<pkg> [A-Z][:\w]*) (?<params> (\{\{.*?\}\}|[^<>])*) >/nsx => sub {
			push @S, ['@', my $pkg = $+{pkg}];
			my $params = _exp_html($+{params});
			$params =~ s/,?$/,/ if $params !~ /^\s*$/;
			include $pkg;
			"', $pkg->new(${params}content => join('', '"
		},
		
		# </Конец эона>
		qr/<\/ (?<pkg> [A-Z][:\w]* ) \s*>/nsx => sub {
			my $x = pop @S;
			die "Конец эона не совпадает с началом: {{@$x}} ... </$+{pkg}>" if $x->[0] ne '@' || $x->[1] ne $+{pkg};
			"'))->render, '"
		},
		
		# # <tag if=""
		# qr! <(?<tag> [a-z]\w*) \s* if=("(?<e> [^"]*) | '(?<e> [^']*)' | [^\s<>]*)" !nix => sub {
			
		# },
		
		# # </tag>
		# qr! </ \s* (?<tag> [a-z]\w*) \s* > !ix => sub {
			# my $tag = $+{tag};
			
			# if(@S) {
				# my ($x, $y) = {$S->[$#$S]};
				# if($x eq "i") 
			# }
			
			# my $x = pop @S;
			# die "Конец тега не совпадает с началом: {{@$x}} ... </$tag>" if $x->[0] ne '@' || $x->[1] ne $tag;
			
		# },

		# {{ ... }} с распознаванием что там
		qr/(?<s> \s*) \{\{ (?<e>.*?) \}\}/nsx => sub {
			my $S = $+{s};

			# {{# ... }}
			$+{e} =~ /^ \# (.*) $/sxn ? do {
				my $c=$+{comment};
				$c =~ s/'/\\'/g;
				"', do { $S'$c'; '' }, '"
			}:

			# {{* a = b}}
			$+{e} =~ /^ \* \s* (?<i>[a-z_]\w*) \s* = \s* (?<arr>.*?) \s* $/isxn ? do {
				push @S, ["*", $+{i}, $+{arr}];
				"$S', (map { local \$kw{$+{i}} = \$_; ('"
			}:

			# {{/* a }}
			$+{e} =~ /^ \/\* \s* (?<i>[a-z_]\w*) \s* $/isxn ? do {
				my $x = pop @S;
				my $i = $+{i};
				die "Конец цикла не совпадает с началом: {{@$x}} ... {{/*$+{i}}}" if $x->[0] ne "*" || $x->[1] ne $+{i};
				my $arr = _exp($x->[2]);
				"$S') } \@{$arr}), '"
			}:

			# {{? a }}
			$+{e} =~ /^ \? \s* (?<x> .*? (?<y> [a-z_]\w*) .*?) \s* $/isxn ? do {
				push @S, ["?", $+{y}];
				my $x = _exp($+{x});
				"$S', test($x)? ('"
			}:

			# {{/? a }}
			$+{e} =~ /^ \/\? \s* (?<i>[a-z_]\w*) \s* $/ixn ? do {
				my $x = pop @S;
				die "Конец условия не совпадает с началом: {{@$x}} ... {{/?$+{i}}}" if $x->[0] ne "?" || $x->[1] ne $+{i};
				"$S'): (), '"
			}:
			
			# {{= a }}
			$+{e} =~ /^ = \s* (?<x> [a-z_]\w* ) \s* $/isxn ? do {
				push @S, ["=", $+{x}];
				"$S', do { \$kw{$+{x}} = join('', '"
			}:

			# {{/= a }}
			$+{e} =~ /^ \/= \s* (?<i>[a-z_]\w*) \s* $/ixn ? do {
				my $x = pop @S;
				die "Конец присваивания блока не совпадает с началом: {{@$x}} ... {{/?$+{i}}}" if $x->[0] ne "=" || $x->[1] ne $+{i};
				"$S') }, '"
			}:
			
			# {{ x = y }}
			$+{e} =~ /^\s* (?<x> [a-z_]\w*) \s* \s=\s \s* (?<y> .*?) \s*$/isxn ? do {
				my $x = $+{x};
				my $y = $+{y};
				$x = "\$kw{$x}";
				$y = _exp($y);
				"',$S do { $x = $y; () }, '"
			}:

			# {{ a ? b }} или {{ a? }}
			$+{e} =~ /^\s* (?<v> [^?]*) \s* \? \s* (?<in>.*?) \s*$/sxn ? do {
				my ($sl, $s) = do { $S =~ /^(.*?)([\ \t]+)\z/ };
				my $v = $+{v};
				my $x = $+{in} ne ""? "$s$+{in}": '';
				my $y = $+{in} ne ""? '': "${s}style=\"display:none\"";
				$x =~ s/\'/\'/g;
				$v = _exp($v);
				"$sl', test($v)? '$x': '$y', '"
			}:

			# {{ a }} или {{ a! }} или {{ a | txt }} или {{ a! | txt }}
			# {{ a {-> fn} [!] [| txt] }}
			$+{e} =~ /^ \s* (?<v> .*?) \s* (?<fn> (->\w+ \s*)* ) (?<w>!)? \s* ( \| (?<s>\s .*?) )? $/nxs ? do {

				my $default = exists $+{s}? " // " . _str($+{s}): "";

				my $exclamation = exists $+{w};
				my $fn = $+{fn};
				my $s = _exp($+{v}) . $default;
				$s = "$_($s)" for grep length, split /->\s*/, $fn;
				$s = "to_html($s)" if !$exclamation;
				"$S', $s, '"
			}: die "Ничего не распознано! {{$+{e}}}";
		},
	;

	die "Остались незакрытые теги: " . join "", map {"{{/$_->[0]$_->[1]}}"} @S if @S;

	$sige = join "", $sige, $dev && $last_sub ne "meta"? "<!-- /aion-mark -->": (), "' }"; #<!-- /aion-mark -->

	#msg1 $sige;

	eval $sige;
	die "$pkg: $@\n$sige" if $@;

	return;
}

# формирует опции для select
sub options_for_select(@) {
	my ($param, $set, $k, $v) = @_;

	$k //= "val";
	$v //= "text";

	$param = [map {+{val=>$_, text=>$param->[$_]}} 0..$#$param] if ref $param eq "ARRAY" and !ref $param->[0];

	$param = [sort { $a->{text} cmp $b->{text} } map {+{val=>$_, text=>$param->{$_}}} keys %$param] if ref $param eq "HASH";

	if(defined $set and ref $set ne "Regexp") { $set = join "|", map quotemeta, @$set if ref $set eq "ARRAY"; $set = qr/^($set)\z/n; }

	join "\n", map {
		my $x = $_->{$k};
		"<option value='".to_html($x)."'".(defined($set) && $x =~ $set? " selected": "").">".to_html($_->{$v})
	} @$param;
}

1;
