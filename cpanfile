requires 'perl', '5.22.0';

on 'develop' => sub {
    requires 'Minilla', 'v3.1.19';
    requires 'Data::Printer', '1.000004';
    requires 'Liveman', '1.0';
};

on 'test' => sub {
	requires 'Test::More', '0.98';
};

requires 'config';
requires 'common::sense';
requires 'Aion', '0.1';
requires 'Aion::Format', '0.0.10';
requires 'Aion::Fs', '0.0.6';
