package Net::Amazon::S3::Error::Handler::Croak::404;

use Moose;
extends 'Net::Amazon::S3::Error::Handler::Croak';

# ABSTRACT: An internal class to handle errors except of http 404

push @Net::Amazon::S3::Error::Handler::Carp::CARP_NOT, __PACKAGE__;

override handle_error => sub {
    my ($self, $response) = @_;

    return 1 if $response->http_response->code == 404;

    super;
};

