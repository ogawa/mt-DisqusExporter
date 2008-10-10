package Apache::JSONRPC;

use strict;
use JSONRPC::Transport::HTTP;
use base qw(JSONRPC::Transport::HTTP::Apache);
use vars qw($VERSION);

$VERSION = '1.01';

my $server = __PACKAGE__->new;


sub handler {
	$server->configure(@_);
	$server->handle(@_);
}


1;
__END__


=head1 NAME

 Apache::JSONRPC - mod_perl-based JSON-RPC server

=head1 SYNOPSIS

httpd.conf or htaccess

 SetHandler perl-script
 PerlHandler Apache::JSONRPC
 PerlModule MyApp::Test
 PerlSetVar dispatch_to "MyApp::Test, MyApp::Test2"
 # URL path base
 # PerlSetVar dispatch_to "MyApp/Test, MyApp/Test2"
 PerlSendHeader On

=head1 TRANSITION PLAN

In the next large update version, JSON and JSONRPC modules are split.

  JSONRPC* and Apache::JSONRPC are deleted from JSON dist.
  JSONRPC::Client, JSONRPC::Server and JSONRPC::Procedure in JSON::RPC dist.

  Modules in JSON::RPC dist supports JSONRPC protocol v1.1 and 1.0.


=head1 DESCRIPTION

This module inherites JSONRPC::Transport::HTTP and
provides JSON-RPC (L<http://json-rpc.org/>) server.

The ideas was borrowed from L<SOAP::Lite>, L<Apache::SOAP>.

Currently the modlue(JSONRPC::Transport::HTTP::Apache) does not support Apache2.

=head1 TODO

Apache2 support.


=head1 SEE ALSO

L<SOAP::Lite>,
L<Apache::SOAP>,
L<JSONRPC::Transport::HTTP>,
L<http://json-rpc.org/>,


=head1 AUTHOR

Makamaka Hannyaharamitu, E<lt>makamaka[at]cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 by Makamaka Hannyaharamitu

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

