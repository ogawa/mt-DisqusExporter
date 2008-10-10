package JSONRPC;

 # JSON-RPC server and client

use strict;
use JSON;

use vars qw($VERSION);

$VERSION = 0.992;


sub new {
    my $self = bless {}, shift;
    $self->jsonParser( JSON::Parser->new() );
    $self->jsonConverter( JSON::Converter->new );
    $self;
}


sub proxy { # re-bless a client class
    my ($self,$url,$proxy_url) = @_;
    $self = $self->new unless(ref($self));
    my $class = ref($self) ? ref($self) . '::Client' : 'JSONRPC::Client';
    $self = bless $self, $class;
    $self->{_proxy} = [$url,$proxy_url] if(@_ > 1);
    $self;
}


# JSONRPC::Transport::XXX->dispatch_to('MyApp')->handle();
# This module looks for the method from MyApp.pm.
# looks for a method from the corresponding package name when a client call it.
# At present, only the module name can be specified. 

sub dispatch_to {
    my $class = shift;
    my $self  = ref($class) ? $class : $class->new;
    my @srv   = @_;

    if(@srv){
        $self->{_dispatch_to} = [ @srv ] ;
        $self;
    }
    else{
        @{ $self->{_dispatch_to} };
    }
}


# to a reqeust from a response (subclass must have the implementation.)

sub handle { }


# get a request from client (subclass must have the implementation.)
# The return value is a HTTP::Request object.

sub request { }


# return a response (subclass must have the implementation.)

sub response { }


# an error that should cut connection (subclass must have the implementation.)

sub invalid_request {}


# the process in case not making response (subclass must have the implementation.)

sub no_response {}


# return a mthod name and any parameters from JSON-RPC data structure.

sub get_request_data {
    my $self   = shift;
    my $js     = $self->{json_data};
    my $method = $js->{method} || '';
    my $params = $js->{params} || [];
    return ($method,$params);
}


# look for the method from module names set by the dispatch_to().
# $r is a HTTP::Request object.

sub find_method {
    my ($self, $method, $r) = @_;
    my $path  = ($r and $r->uri) ? ($r->uri->path || '') : '';

    $path =~ s{^/|/$}{}g;
    $path =~ s{/}{::}g;

    no strict 'refs';

    for my $srv ( @{$self->{_dispatch_to}} ){

        if($srv =~ m{/}){ # URI
            my $class = _path_to_class($srv);
            if($path eq $class){
                unless(defined %{"$class\::"}){
                    eval qq| require $class |;
                    if($@){ warn $@; return; }
                }
                if(my $func = $class->can($method)){
                    return $func;
                }
            }
            else{
                next;
            }
        }
        else{
            if(my $func = $srv->can($method)){
                return $func;
            }
        }
    }

    return;
}

sub _path_to_class {
    my $path = $_[0];
    $path =~ s{^/|/$}{}g;
    $path =~ s{/}{::}g;
    return $path;
}

# execution of method : return value is JSON-RPC data struture.
# $func->($self,@$params) returns a scalar or a hash ref or an array ref.

sub handle_method {
    my ($self, $r)       = @_;
    my ($method,$params) = $self->get_request_data();

    if( my $func = $self->find_method($method, $r) ){
        my $result = $func->($self,@$params);
        $self->set_response_data($result)
    }
    else{
        $self->set_err('No such a method.');
    }
}


# execution of notification

sub notification {
    my $self  = shift;
    my ($method,$params) = $self->get_request_data();

    if(my $func = $self->find_method($method)){
        $func->($self,@$params);
    }

    return 1;
}


# convert Perl data into JSON for a response.

sub set_response_data {
    my $self  = shift;
    my $value = shift;
    my $id    = $self->request_id;
    my $error = $self->error;

    if(!defined $value){ $value = JSON::Null; }
    if(!defined $error){ $error = JSON::Null; }

    my $result = {
        id     => $id,
        result => $value,
        error  => $error,
    };

    return $self->jsonConverter->objToJson($result);
}


# convert Perl data into JSON for an error response.

sub set_err {
    my $self  = shift;
    my $error = shift;
    my $id    = $self->request_id;

    my $result = {
        id     => $id,
        result => JSON::Null,
        error  => $error,
    };

    return $self->jsonConverter->objToJson($result);
}


# accessor of error object

sub error {
    my $self = shift;
    $self->{_error} = $_[0] if(@_ > 0);
    $self->{_error};
}


# accessor of id

sub request_id {
    my $self = shift;

    if(@_ > 0){
        $self->{_request_id} = $_[0];
        if(ref($self->{_request_id}) =~ /JSON/ and !defined $self->{_request_id}->{value}){
            $self->{_request_id} = undef;
        }
    }

    $self->{_request_id};
}


# accessor to JSON::Parser

sub jsonParser {
    $_[0]->{json_parser} = $_[1] if(@_ > 1);
    return $_[0]->{json_parser};
}


# accessor to JSON::Converter

sub jsonConverter {
    $_[0]->{json_converter} = $_[1] if(@_ > 1);
    return $_[0]->{json_converter};
}


#
# Client
#

package JSONRPC::Client;

use base qw(JSONRPC);
use vars qw($AUTOLOAD);


sub AUTOLOAD {
    my $self = shift;
    my $attr = $AUTOLOAD;

    $attr =~ s/.*:://;

    return if($attr eq 'DESTROY');

    $attr =~ s/^_//;

    my $res = $self->call($attr,[@_])->result;

    if($res->error){
        $self->{_error} = $res->{error};
        return;
    }
    else{
        $res->result;
    }
}


# call($method, $params $id)
# without $id, 'JsonRpcClient' is set.
# explicitly set undef into $id, notification mode.

sub call {
    my ($self, $method, $params, $id) = @_;

    if(@_ == 3){ $id = 'JsonRpcClient'; }
    $self->{_id} = $id;

    my $content = eval q|
        $self->jsonConverter->objToJson({
            method => $method, params => $params, id => $id
        })
    | or die $@;

    $self->{_response} = $self->send($content);
    $self;
}


# post data (subclass must have the implementation.)

sub send {}


# return the result value.

sub result {
    my ($self) = @_;
    my $response  = $self->{_response};

    my $result = bless {
        success => $response->is_success,
        error   => undef,
        result  => undef,
        id      => undef,
    }, 'JSONRPC::Response';

    unless( $response->is_success ){
        $self->{_error} = $response->code;
        $result->error($response->code);
        return $result;
    }
    else{
        $self->{_error} = undef;
    }

    my $json = $response->content;
    my $obj  = eval q| $self->jsonParser->jsonToObj($json, {unmapping => 1}) |;

    return if(!$obj); # notification?

    if($obj->{id} eq $self->{_id}){
        $result->result( $obj->{result} );
        $result->error( $obj->{error} );
        $result->id( $obj->{id} );
    }

    return $result;
}


# accessor to status code. (when response is not sucessful, set status code)

sub error { $_[0]->{_error}; }


#
#
#

package JSONRPC::Response;

use base qw(HTTP::Response);

sub is_success { $_[0]->{success} }

sub result {
    $_[0]->{result} = $_[1] if(@_ > 1);
    $_[0]->{result};
}


sub error {
    $_[0]->{error} = $_[1] if(@_ > 1);
    $_[0]->{error};
}


sub id {
    $_[0]->{id} = $_[1] if(@_ > 1);
    $_[0]->{id};
}


1;
__END__


=head1 NAME

 JSONRPC - Perl implementation of JSON-RPC protocol

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


 #--------------------------
 # Client version
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

This module implementes JSON-RPC (L<http://json-rpc.org/>) server
and client. Most ideas were borrowed from L<XMLRPC::Lite>.
Currently C<JSONRPC> provides CGI server function.


=head1 METHOD

=over 4


=item dispatch_to


=item handle


=item jsonParser

The accessor of a JSON::Parser object.

 my $srv = JSONRPC::Transport::HTTP::CGI->new;
 $srv->jsonParser->{unmapping} = 1;


=item jsonConverter

The accessor of a JSON::Converter object.

=item proxy($uri,[$proxy_uri])

takes a service uri and optional proxy uri.
returns a client object.

=back

=head1 SEE ALSO

L<JSONRPC::Transport::HTTP>
L<JSON>
L<XMLRPC::Lite>
L<http://json-rpc.org/>


=head1 AUTHOR

Makamaka Hannyaharamitu, E<lt>makamaka[at]cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005-2007 by Makamaka Hannyaharamitu

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

