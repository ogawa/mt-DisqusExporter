JSON version 1.00
=================

DESCRIPTION

This module converts between JSON (JavaScript Object Notation) and Perl
data structure into each other.
For JSON, See to http://www.crockford.com/JSON/.

  JSON-RPC http://json-rpc.org/


INSTALLATION

To install this module type the following:

   perl Makefile.PL
   make
   make test
   make install


DEPENDENCIES

This module requires these other modules and libraries:

  Test::More

If you want to use JSONRPC::Transport::HTTP, you need

  HTTP::Request,
  HTTP::Response

If you want to use JSONRPC::Transport::HTTP::Daemon,
HTTP::Daemon is required.

If you want to use JSONRPC::Transport::HTTP::Client, you need
LWP::UserAgent.



COPYRIGHT AND LICENCE

Copyright (C) 2005 by Makamaka Hannyaharamitu

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 
