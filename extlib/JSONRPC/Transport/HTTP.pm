package JSONRPC::Transport::HTTP;

use strict;
use JSONRPC;
use base qw(JSONRPC);
use vars qw($VERSION);

use HTTP::Request;
use HTTP::Response;

$VERSION = 1.02;

#
#
#


package JSONRPC::Transport::HTTP::Client;

use base qw(JSONRPC::Client);


sub send { require LWP::UserAgent;
    my ($self, $content) = @_;
    my ($url, $proxy_url) = @{$self->{_proxy}};

    my $ua  = LWP::UserAgent->new;

    $ua->proxy(['http','https'], $proxy_url) if($proxy_url);
    $ua->post($url, Content_Type => 'text/plain', Content => $content);
}


#
#
#

package JSONRPC::Transport::HTTP::Server;

use base qw(JSONRPC);

use constant DEFAULT_CHARSET => 'UTF-8';

sub new {
    my $self = shift;
    my %opt  = @_;

    unless (ref $self) {
        my $class = ref($self) || $self;
        $self = $class->SUPER::new(%opt);
    }

    $self->charset( $opt{charset} || DEFAULT_CHARSET );

    return $self;
}


sub handle {
    my $self = shift;
    my $jp   = $self->jsonParser;

    unless(ref $self){ $self = $self->new(@_) }

    my $req;

    if( $req = $self->request ){
        $self->{json_data}
             = eval q| $jp->parse($req->content) |
                or return $self->send_response( $self->invalid_request() );

        if( defined $self->request_id($self->{json_data}->{id}) ){
            my $res = $self->handle_method($req) or return $self->invalid_request();
            return $self->send_response( $self->response($res) );
        }
        else{
            $self->notification();
            $self->send_response( $self->no_response() );
        }
    }
    else{
        $self->send_response( $self->invalid_request() );
    }
}


sub charset {
    $_[0]->{_charset} = $_[1] if(@_ > 1);
    $_[0]->{_charset};
}


sub response {
    my $self    = shift;
    my $res     = shift;
    my $charset = $self->charset;
    my $h    = HTTP::Headers->new;

    $h->header('Content-Type' => "text/plain; charset=$charset");

    HTTP::Response->new(200 => undef, $h, $res);
}


sub invalid_request {
    my $self    = shift;
    my $charset = $self->charset;
    my $h       = HTTP::Headers->new;

    $h->header('Content-Type' => "text/plain; charset=$charset");

    HTTP::Response->new(500 => undef, $h);
}


sub no_response {
    my $self    = shift;
    my $charset = $self->charset;
    my $h       = HTTP::Headers->new;

    $h->header('Content-Type' => "text/plain; charset=$charset");

    HTTP::Response->new(200 => undef, $h);
}


sub send_response { }

#
#
#


package JSONRPC::Transport::HTTP::CGI;

use CGI;
use base qw(JSONRPC::Transport::HTTP::Server);

use constant DEFAULT_CHARSET => 'UTF-8';
use constant MAX_CONTENT_LENGTH => 1024 * 1024 * 5; # 5M


sub new { shift->SUPER::new(@_); }


sub handle {
    my $self = shift->new();
    my %opt  = @_;

    for my $name (qw/charset paramName query/){
        $self->$name( $opt{$name} ) if(exists $opt{$name});
    }

    $self->SUPER::handle();
}


sub request {
    my $self = shift;
    my $q    = $self->query || new CGI;
    my $len  = $ENV{'CONTENT_LENGTH'} || 0;

    if(MAX_CONTENT_LENGTH < $len){ return; }

    my $req = HTTP::Request->new($q->request_method, $q->url);

    return if($req->method ne 'POST');

    if(defined $self->paramName){
        $req->content( $q->param($self->paramName) );
    }
    else{
        my @name = $q->param;
        $req->content(
            ((@name == 1) ? $q->param($name[0]) : $q->param('POSTDATA'))
        );
    }

    return $self->{_request} = $req;
}


sub send_response {
    my ($self, $res) = @_;
    print "Status: " . $res->code . "\015\012" . $res->headers_as_string("\015\012")
           . "\015\012" . $res->content;
}


sub query {
    $_[0]->{_query} = $_[1] if(@_ > 1);
    $_[0]->{_query};
}


sub paramName {
    $_[0]->{_paramName} = $_[1] if(@_ > 1);
    $_[0]->{_paramName};
}

#
#
#

package JSONRPC::Transport::HTTP::Daemon;

use base qw(JSONRPC::Transport::HTTP::Server);

sub new {
    my $self = shift;

    unless (ref $self) {
        my $class = ref($self) || $self;
        $self = $class->SUPER::new(@_);
    }

    my $pkg;
    if(  grep { $_ =~ /^SSL_/ } @_ ){
        $self->{_daemon_pkg} = $pkg = 'HTTP::Daemon::SSL';
    }
    else{
        $self->{_daemon_pkg} = $pkg = 'HTTP::Daemon';
    }
    eval qq| require $pkg; |;
    if($@){ die $@ }

    $self->{_daemon} ||= $pkg->new(@_) or die;

    return $self;
}


sub handle {
    my $self = shift;
    my %opt  = @_;
    my $d    = $self->{_daemon} ||= $self->{_daemon_pkg}->new(@_) or die;

    $self->charset($opt{charset}) if($opt{charset});

    while (my $c = $d->accept) {
        $self->{con} = $c;
        while (my $r = $c->get_request) {
            if ($r->method eq 'POST') {
                $self->request($r);
                $self->SUPER::handle();
            }
            else {
                $self->invalid_request();
            }
            last;
        }
        $c->close;
    }
}



sub request {
    $_[0]->{_request} = $_[1] if(@_ > 1);
    $_[0]->{_request};
}


sub send_response {
    my ($self, $res) = @_;
    $self->{con}->send_response($res);
}


#
#
#

package JSONRPC::Transport::HTTP::Apache;

use base qw(JSONRPC::Transport::HTTP::Server);

use constant MAX_CONTENT_LENGTH => 1024 * 1024 * 5; # 5M

sub new {
    my $self = shift;

    require Apache;
    require Apache::Constants;

    unless (ref $self) {
        my $class = ref($self) || $self;
        $self = $class->SUPER::new(@_);
    }

    return $self;
}


sub request {
    my $self = shift;
    my $r    = shift || Apache->request;
    my $len  = $r->header_in('Content-length');

    $self->{apr} = $r;

    return if($r->method ne 'POST');
    return if(MAX_CONTENT_LENGTH < $len);

    my $req = HTTP::Request->new($r->method, $r->uri);
    my ($buf, $content);

    while( $r->read($buf,$len) ){
        $content .= $buf;
    }

    $req->content($content);

    return $self->{_request} = $req;
}



sub send_response {
    my ($self, $res) = @_;
    my $r = $self->{apr};

    $r->send_http_header("text/plain");
    $r->print($res->content);

    return ($res->code == 200)
            ? &Apache::Constants::OK : &Apache::Constants::SERVER_ERROR;
}


sub configure {
    my $self   = shift;
    my $config = shift->dir_config;
    for my $method (keys %$config) {
        my @values = split(/\s*,\s*/, $config->{$method});
        $self->$method(@values) if($self->can($method));
    }
    $self;
}


1;
__END__

=head1 NAME

JSONRPC::Transport::HTTP

=head1 SYNOPSIS

 #--------------------------
 # In your application class
 package MyApp;

 sub own_method { # called by clients
     my ($server, @params) = @_; # $server is JSONRPC object.
     ...
     # return a scalar value or a hashref or an arryaref.
 }

 #--------------------------
 # In your main cgi script.
 use JSONRPC::Transport::HTTP;
 use MyApp;
 
 # a la XMLRPC::Lite
 JSONRPC::Transport::HTTP::CGI->dispatch_to('MyApp')->handle();


 ##################
 # Daemon version #
 ##################

 use strict;
 use lib qw(. ./lib);
 use JSONRPC::Transport::HTTP;
 
 my $daemon = JSONRPC::Transport::HTTP::Daemon
        ->new(LocalPort => 8080)
        ->dispatch_to('MyApp/Test', 'MyApp/Test2');
 
 $daemon->handle();

 ##################
 # Apache version #
 ##################

 http.conf or .htaccess

   SetHandler  perl-script
   PerlHandler Apache::JSONRPC
   PerlModule  MyApp::Test
   PerlSetVar  dispatch_to "MyApp::Test, MyApp/Test2/"


 #--------------------------
 # Client
 #--------------------------

 use JSONRPC::Transport::HTTP;
 my $uri = 'http://www.example.com/MyApp/Test/';

 my $res = JSONRPC::Transport::HTTP
            ->proxy($uri)
            ->call('echo',['This is test.'])
            ->result;

 if($res->error){
   print $res->error,"\n";
 }
 else{
   print $res->result,"\n";
 }

 # or

 my $client = JSONRPC::Transport::HTTP->proxy($uri);
 
 print $client->echo('This is test.'); # the alias, _echo is same.


=head1 TRANSITION PLAN

In the next large update version, JSON and JSONRPC modules are split.

  JSONRPC* and Apache::JSONRPC are deleted from JSON dist.
  JSONRPC::Client, JSONRPC::Server and JSONRPC::Procedure in JSON::RPC dist.

  Modules in JSON::RPC dist supports JSONRPC protocol v1.1 and 1.0.


=head1 DESCRIPTION

This module is L<JSONRPC> subclass.
Most ideas were borrowed from L<XMLRPC::Lite>.
Currently C<JSONRPC> provides only CGI server function.


=head1 CHARSET

When the module returns response, its charset is UTF-8 by default.
You can change it via passing a key/value pair into handle().

 my %charset = (charset => 'EUC-JP');
 JSONRPC::Transport::HTTP::CGI->dispatch_to('MyApp')->handle(%charset);

=head1 QUERY OBJECT

If you want to use any other query object instead of C<CGI>
for JSONRPC::Transport::HTTP::CGI, you can pass C<query> option and
C<paramName>.

 my %opt = (
   query     => $session, # CGI::Session object
   paramName => 'json',
 );

 JSONRPC::Transport::HTTP::CGI->dispatch_to('MyApp')->handle(%opt);


=head1 CAUTION

JSONRPC::Transport::HTTP::CGI requires CGI.pm which version is more than 2.9.2.
(the core module in Perl 5.8.1.)


Since verion 1.0, JSONRPC::Transport::HTTP requires L<HTTP::Request>
and L<HTTP::Response>. For using JSONRPC::Transport::HTTP::Client,
you need L<LWP::UserAgent>.

=head1 SEE ALSO

L<JSONRPC>
L<JSON>
L<XMLRPC::Lite>
L<http://json-rpc.org/>


=head1 AUTHOR

Makamaka Hannyaharamitu, E<lt>makamaka[at]cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 by Makamaka Hannyaharamitu

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

