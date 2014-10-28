#!/usr/bin/env perl
# Copyright 2014 Michal Špaček <tupinek@gmail.com>

# Pragmas.
use strict;
use warnings;

# Modules.
use Database::DumpTruck;
use Encode qw(decode_utf8 encode_utf8);
use English;
use HTML::TreeBuilder;
use LWP::UserAgent;
use URI;

# Don't buffer.
$OUTPUT_AUTOFLUSH = 1;

# URI of service.
my $base_uri = URI->new('http://www.sako.cz/harmonogram-svozu/cz/?vybrat_vse=1#vse');

# Open a database handle.
my $dt = Database::DumpTruck->new({
	'dbname' => 'data.sqlite',
	'table' => 'data',
});

# Create a user agent object.
my $ua = LWP::UserAgent->new(
	'agent' => 'Mozilla/5.0',
);

# Get base root.
print 'Page: '.$base_uri->as_string."\n";
my $root = get_root($base_uri);

# Get data.
my @tr = $root->find_by_tag_name('table')->find_by_tag_name('tr');
my $district;
my $num;
foreach my $tr (@tr) {
	my $th = $tr->find_by_tag_name('th');
	if ($th) {
		$district = ucfirst(lc($th->as_text));
		print 'District: '.encode_utf8($district)."\n";
		$num = 0;
	} else {
		if ($num == 1) {
			$num++;
			next;
		}
		my ($street, $periodicity, $day) = map { $_->as_text }
			$tr->find_by_tag_name('td');
		$day = lc($day);
		remove_trailing(\$day);

		# Save.
		# TODO Update.
		print 'Street: '.encode_utf8($street)."\n";
		$dt->insert({
			'District' => $district,
			'Street' => $street,
			'Day' => $day,
			'Periodicity' => $periodicity,
		});
	}
	$num++;
}

# Get root of HTML::TreeBuilder object.
sub get_root {
	my $uri = shift;
	my $get = $ua->get($uri->as_string);
	my $data;
	if ($get->is_success) {
		$data = $get->content;
	} else {
		die "Cannot GET '".$uri->as_string." page.";
	}
	my $tree = HTML::TreeBuilder->new;
	$tree->parse(decode_utf8($data));
	return $tree->elementify;
}

# Removing trailing whitespace.
sub remove_trailing {
	my $string_sr = shift;
	${$string_sr} =~ s/^\s*//ms;
	${$string_sr} =~ s/\s*$//ms;
	return;
}
