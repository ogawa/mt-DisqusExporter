# $Id$

package WWW::Disqus;

use strict;
use warnings;

use base qw( Class::Accessor::Fast );
use Carp;
use LWP::UserAgent;
use JSON 1.1;

use constant DISQUS_API_URL => 'http://disqus.com/api/';

our $VERSION = '0.01';

sub new {
    my $class = shift;
    my (%param) = @_;
    $param{ua}   ||= LWP::UserAgent->new;
    $param{json} ||= JSON->new;
    bless \%param, $class;
}

__PACKAGE__->mk_accessors(qw( user_api_key forum_api_key ));

## Helper methods
sub get_forum_id {
    my $this         = shift;
    my ($forum_name) = @_;
    my $forums       = $this->get_forum_list();
    for my $forum (@$forums) {
        return $forum->{id}
          if $forum->{name} eq $forum_name
              || $forum->{shortname} eq $forum_name;
    }
    confess "No forum_id found for $forum_name";
}

sub set_forum_api_key_by_forum_id {
    my $this = shift;
    my ($forum_id) = @_;
    if ( my $key = $this->get_forum_api_key($forum_id) ) {
        $this->forum_api_key($key);
    }
}

sub set_forum_api_key_by_forum_name {
    my $this = shift;
    my ($forum_name) = @_;
    if ( my $forum_id = $this->get_forum_id($forum_name) ) {
        $this->set_forum_api_key_by_forum_id($forum_id);
    }
}

sub is_succeeded {
    my $obj = shift;
    return 1
      if $obj->{succeeded}
          && $obj->{succeeded}->{value}
          && $obj->{succeeded}->{value} eq 'true';
    confess $obj->{message};
}

## API methods (using user_api_key)
sub get_forum_list {
    my $this         = shift;
    my $user_api_key = $this->user_api_key
      or confess 'user_api_key must be set';
    my $res =
      $this->{ua}
      ->get( DISQUS_API_URL . "get_forum_list/?user_api_key=" . $user_api_key );
    confess 'Failed to access DISQUS API: ' . $res->status_line
      unless $res->is_success;
    my $obj = $this->{json}->jsonToObj( $res->content );
    return $obj->{message} if is_succeeded($obj);
}

sub get_forum_api_key {
    my $this         = shift;
    my $user_api_key = $this->user_api_key
      or confess 'user_api_key must be set';
    my ($forum_id) = @_;
    my $res =
      $this->{ua}->get( DISQUS_API_URL
          . "get_forum_api_key/?user_api_key="
          . $user_api_key
          . "&forum_id="
          . $forum_id );
    confess 'Failed to access DISQUS API: ' . $res->status_line
      unless $res->is_success;
    my $obj = $this->{json}->jsonToObj( $res->content );
    return $obj->{message} if is_succeeded($obj);
}

## API methods (using forum_api_key)
sub create_post {
    my $this          = shift;
    my $forum_api_key = $this->forum_api_key
      or confess 'forum_api_key must be set';
    my (%param) = @_;
    my $res = $this->{ua}->post(
        DISQUS_API_URL . "create_post/",
        {
            forum_api_key => $forum_api_key,
            %param,
        }
    );
    confess 'Failed to access DISQUS API: ' . $res->status_line
      unless $res->is_success;
    my $obj = $this->{json}->jsonToObj( $res->content );
    return $obj->{message} if is_succeeded($obj);
}

sub get_thread_list {
    my $this          = shift;
    my $forum_api_key = $this->forum_api_key
      or confess 'forum_api_key must be set';
    my $res =
      $this->{ua}->get(
        DISQUS_API_URL . "get_thread_list/?forum_api_key=" . $forum_api_key );
    confess 'Failed to access DISQUS API: ' . $res->status_line
      unless $res->is_success;
    my $obj = $this->{json}->jsonToObj( $res->content );
    return $obj->{message} if is_succeeded($obj);
}

sub get_num_posts {
    my $this          = shift;
    my $forum_api_key = $this->forum_api_key
      or confess 'forum_api_key must be set';
    my ($thread_ids) = @_;
    my $res =
      $this->{ua}->get( DISQUS_API_URL
          . "get_num_posts/?forum_api_key="
          . $forum_api_key
          . "&thread_ids="
          . $thread_ids );
    confess 'Failed to access DISQUS API: ' . $res->status_line
      unless $res->is_success;
    my $obj = $this->{json}->jsonToObj( $res->content );
    return $obj->{message} if is_succeeded($obj);
}

sub get_thread_by_url {
    my $this          = shift;
    my $forum_api_key = $this->forum_api_key
      or confess 'forum_api_key must be set';
    my ($url) = @_;
    my $res =
      $this->{ua}->get( DISQUS_API_URL
          . "get_thread_by_url/?forum_api_key="
          . $forum_api_key
          . "&url=$url" );
    confess 'Failed to access DISQUS API: ' . $res->status_line
      unless $res->is_success;
    my $obj = $this->{json}->jsonToObj( $res->content );
    return $obj->{message} if is_succeeded($obj);
}

sub get_thread_posts {
    my $this          = shift;
    my $forum_api_key = $this->forum_api_key
      or confess 'forum_api_key must be set';
    my ($thread_id) = @_;
    my $res =
      $this->{ua}->get( DISQUS_API_URL
          . "get_thread_posts/?forum_api_key="
          . $forum_api_key
          . "&thread_id="
          . $thread_id );
    confess 'Failed to access DISQUS API: ' . $res->status_line
      unless $res->is_success;
    my $obj = $this->{json}->jsonToObj( $res->content );
    return $obj->{message} if is_succeeded($obj);
}

sub thread_by_identifier {
    my $this          = shift;
    my $forum_api_key = $this->forum_api_key
      or confess 'forum_api_key must be set';
    my (%param) = @_;
    my $res = $this->{ua}->post(
        DISQUS_API_URL . "thread_by_identifier/",
        {
            forum_api_key => $forum_api_key,
            %param,
        }
    );
    confess 'Failed to access DISQUS API: ' . $res->status_line
      unless $res->is_success;
    my $obj = $this->{json}->jsonToObj( $res->content );
    return $obj->{message} if is_succeeded($obj);
}

sub update_thread {
    my $this          = shift;
    my $forum_api_key = $this->forum_api_key
      or confess 'forum_api_key must be set';
    my (%param) = @_;
    my $res = $this->{ua}->post(
        DISQUS_API_URL . "update_thread/",
        {
            forum_api_key => $forum_api_key,
            %param,
        }
    );
    confess 'Failed to access DISQUS API: ' . $res->status_line
      unless $res->is_success;
    my $obj = $this->{json}->jsonToObj( $res->content );
    return $obj->{message} if is_succeeded($obj);
}

1;
__END__

=head1 NAME

WWW::Disqus - Perl extension for accessing DISQUS API

=head1 SYNOPSIS

  use WWW::Disqus;

  # create a calendar object
  my $api = WWW::Disqus->new;

  # set user_api_key
  $api->user_api_key('your_user_api_key');

  # set forum_api_key by using forum_name
  $api->set_forum_api_key_by_forum_name('your_forum_name');

  # retrieve the thread list of the forum
  my $thread_list = $api->get_thread_list();

=head1 DESCRIPTION

C<WWW::Disqus> is a Perl extension for accessing DISQUS API.

=head1 REQUIREMENT

This application requires perl 5.8.0 with following Perl modules
installed on your box.

=over 4

=item JSON 1.1

=item LWP::UserAgent

=item Class::Accessor::Fast

=back

=head1 FUNCTIONS

=over 4

=item new(%attr)

Creates and returns a new instance of WWW::Disqus.  Following
attributes are available.

=over 8

=item user_api_key

User API Key for your DISQUS account.

=back

=item user_api_key([$user_api_key])

Gets/sets the User API Key.

=item forum_api_key([$forum_api_key])

Gets/sets the Forum API Key.

=item get_forum_id($forum_name)

Gets the forum_id correnponding to the given forum name.

=item set_forum_api_key_by_forum_id($forum_id)

Sets the Forum API Key correnponding to the given forum_id.

=item set_forum_api_key_by_forum_name($forum_name)

Sets the Forum API Key correnponding to the given forum_name.

=item get_forum_list()

Gets a list of objects representing all forums the user owns.

=item get_forum_api_key($forum_id)

Gets a string of the Forum API Key corresponding to the given
forum_id.

=item create_post(%param)

TBD

=item get_thread_list()

TBD

=item get_num_posts([$thread_ids])

TBD

=item get_thread_by_url($url)

TBD

=item get_thread_posts($thread_id)

TBD

=item thread_by_identifier(%param)

TBD

=item update_thread(%param)

TBD

=back

=head1 EXPORT

None.

=head1 DEVELOPMENT

The development version is always available from the following
subversion repository:

  http://code.as-is.net/svn/public/WWW-Disqus/trunk/

You can browse the files via Trac from the following:

  http://code.as-is.net/public/browser/WWW-Disqus/trunk/

Any comments, suggestions, or patches are welcome.

=head1 LICENSE

Copyright (c) 2008 Hirotaka Ogawa E<lt>hirotaka.ogawa at gmail.comE<gt>.
All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the terms of either:

   a) the GNU General Public License as published by the Free Software
      Foundation; either version 1, or (at your option) any later
      version, or

   b) the "Artistic License" which comes with Perl.

=cut
