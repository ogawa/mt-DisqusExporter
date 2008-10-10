#!/usr/bin/perl -w
# disqus-exporter: export MT comments to Disqus commenting sytem
#
# $Id$
#
# This software is provided as-is. You may use it for commercial or
# personal use. If you distribute it, please keep this notice intact.
#
# Copyright (c) 2008 Hirotaka Ogawa

use strict;
use warnings;

use lib 'lib', '../lib';
use MT::Bootstrap;

use constant BLOG_ID         => 1;
use constant SHORT_NAME      => 'your forum short name';
use constant ANONYMOUS_EMAIL => 'nobody@your.domain';
use constant USER_API_KEY    => 'your user api key';

use constant VERBOSE => 0;

our $VERSION = '0.1-dev';

use MT;
use MT::Blog;
use MT::Entry;
use MT::I18N;
use MT::Util;
use WWW::Disqus;

my $api = WWW::Disqus->new( user_api_key => USER_API_KEY );
$api->set_forum_api_key_by_forum_name(SHORT_NAME);

my $mt   = MT->new;
my $blog = MT::Blog->load(BLOG_ID);
my $iter = MT::Entry->load_iter(
    {
        blog_id => BLOG_ID,
        status  => MT::Entry::RELEASE,
    },
    {
        join => [
            'MT::Comment', 'entry_id',
            { blog_id => BLOG_ID, visible => 1 }, { unique => 1 }
        ],
    }
);

my %stats = (
    entry_processed   => 0,
    entry_skipped     => 0,
    comment_processed => 0,
    comment_failed    => 0
);
my @permalinks_without_threads = ();
while ( my $entry = $iter->() ) {
    my $thread;
    eval { $thread = $api->get_thread_by_url( $entry->permalink ); };
    if ($@) {
        $stats{entry_skipped}++;
        print STDERR "Disqus API error: $@\n" if VERBOSE;
        next;
    }
    unless ( exists $thread->{id} ) {
        $stats{entry_skipped}++;
        push @permalinks_without_threads, $entry->permalink;
        print STDERR "No Disqus thread found for MT::Entry(ID="
          . $entry->id . ")\n"
          if VERBOSE;
        next;
    }
    my $thread_id = $thread->{id};

    for my $comment ( @{ $entry->comments( { visible => 1 } ) } ) {
        next unless $comment->is_published;

        # author_name
        my $author_name = MT::I18N::first_n( $comment->author, 30 );

        # author_email
        my $author_email = ANONYMOUS_EMAIL;
        if ( $comment->email && MT::Util::is_valid_email( $comment->email ) ) {
            $author_email = $comment->email;
        }
        elsif ( $comment->commenter_id ) {
            my $author = MT::Author->load( $comment->commenter_id );
            if (   $author
                && $author->email
                && MT::Util::is_valid_email( $author->email ) )
            {
                $author_email = $author->email;
            }
        }

        # author_url
        my $author_url = $comment->url;
        if ( !$author_url && $comment->commenter_id ) {
            my $author = MT::Author->load( $comment->commenter_id );
            if ( $author && $author->url ) {
                $author_url = $author->url;
            }
        }

        # created_at (UTC)
        my $ts = $comment->created_on;
        $ts = ts2ts_utc( $blog, $ts );
        my $created_at = MT::Util::format_ts( '%Y-%m-%dT%H:%M', $ts );

        my %post_data = (
            thread_id    => $thread_id,
            message      => $comment->text,
            author_name  => $author_name,
            author_email => $author_email,
            created_at   => $created_at,
            $author_url  ? ( author_url => $author_url )  : (),
            $comment->ip ? ( ip_address => $comment->ip ) : (),
        );
        my $post;
        eval { $post = $api->create_post(%post_data); };
        if ($@) {
            $stats{comment_failed}++;
            print STDERR "Disqus API error: $@\n" if VERBOSE;
            next;
        }
        $comment->visible(0);
        $comment->save or die $comment->errstr;
        $stats{comment_processed}++;
        print STDERR "MT::Comment(ID="
          . $comment->id
          . ") successfully converted to Disqus post(ID="
          . $post->{id} . ")\n"
          if VERBOSE;
    }
    $stats{entry_processed}++;
}

# Statistics
print << "EOD";
-----------------------------------
 Statistics
-----------------------------------
Processed entries: $stats{entry_processed}
  Skipped entries: $stats{entry_skipped}
Exported comments: $stats{comment_processed}
  Failed comments: $stats{comment_failed}
EOD
if (@permalinks_without_threads) {
    print << "EOD";
-----------------------------------
 Permalinks without Disqus threads
-----------------------------------
EOD
    for (@permalinks_without_threads) {
        print $_ . "\n";
    }
}

use Time::Local qw( timegm timelocal );

sub ts2ts_utc {
    my ( $blog, $ts ) = @_;
    my ( $y, $mo, $d, $h, $m, $s ) = $ts =~
      /(\d\d\d\d)[^\d]?(\d\d)[^\d]?(\d\d)[^\d]?(\d\d)[^\d]?(\d\d)[^\d]?(\d\d)/;
    $mo--;
    my $server_offset = $blog->server_offset;
    if ( ( localtime( timelocal( $s, $m, $h, $d, $mo, $y ) ) )[8] ) {
        $server_offset += 1;
    }
    my $four_digit_offset = sprintf( '%.02d%.02d',
        int($server_offset), 60 * abs( $server_offset - int($server_offset) ) );
    require MT::DateTime;
    my $tz_secs = MT::DateTime->tz_offset_as_seconds($four_digit_offset);
    my $ts_utc = Time::Local::timegm_nocheck( $s, $m, $h, $d, $mo, $y );
    $ts_utc -= $tz_secs;
    ( $s, $m, $h, $d, $mo, $y ) = gmtime($ts_utc);
    $y += 1900;
    $mo++;
    sprintf( "%04d%02d%02d%02d%02d%02d", $y, $mo, $d, $h, $m, $s );
}

1;
