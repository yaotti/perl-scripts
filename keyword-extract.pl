#!/usr/bin/env perl
use strict;
use warnings;
use Perl6::Say;
use WWW::Mechanize;
use Web::Scraper;
use Config::Pit;
use IO::File;
use utf8;
use Encode qw(encode);
use Getopt::Long;

GetOptions('help' => \&HELP_MESSAGE);
my $group = $ARGV[0] or die "usage: $0 GROUPNAME";


# ログイン処理
my $config       = pit_get('hatena.ne.jp');
my $hatena_login = 'https://www.hatena.ne.jp/login';
my $mech         = WWW::Mechanize->new( cookie_jar => {} );
my $response     = $mech->get($hatena_login);
if ( !$response->is_success || $response->content =~ /errormessage/ ) {
    warn $mech->status;
    return;
}
$mech->submit_form(
    fields => {
        name     => $config->{username},
        password => $config->{password}
    }
);

# キーワードリスト取得
my $hatena_group_url = sprintf( "http://%s.g.hatena.ne.jp", $group );
$mech->get( $hatena_group_url . "/keywordlist" );
my $kwds = scraper {
    process '/html/body/div/div/div/ul/li/a',
      'list[]' => 'TEXT',
};
$response = $kwds->scrape( $mech->content );
my $keywords = $response->{list};


my $web      = scraper {
    process '//textarea[@name="body"]',
      body => 'TEXT',
};

for my $keyword (@$keywords) {
    my $keyword_url = $hatena_group_url . "/keyword/" . $keyword . "?mode=edit";
    $mech->get($keyword_url);
    $response = $web->scrape( $mech->content, $keyword_url );
    my $body =
        utf8::is_utf8( $response->{body} )
      ? encode( 'utf-8', $response->{body} )
      : $response->{body};

    my $filename = $keyword . ".txt";
    my $fh = new IO::File $filename, 'w';
    die "Can't open file $filename: $!" unless defined $fh;
    print $fh $body;
    say "$keyword.txt is successfully updated.";
}

sub HELP_MESSAGE {
    print <<"EOD";

Usage: perl $0 GROUPNAME

Options:
    --help          Show this message.
EOD
    exit(0);
}
