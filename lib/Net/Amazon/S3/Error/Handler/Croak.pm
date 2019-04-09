package Net::Amazon::S3::Error::Handler::Croak;

# ABSTRACT: An internal class to report errors via Carp::croak

use Moose;
use Carp;
use HTTP::Status;

extends 'Net::Amazon::S3::Error::Handler::Status';

our @CARP_NOT = (__PACKAGE__);

sub handle_error {
    my ($self, $response) = @_;

    return 1 unless $response->is_error;

    $self->s3->err ("network_error");
    $self->s3->errstr ($response->http_response->status_line);

    Carp::croak ("Net::Amazon::S3: Amazon responded with ${\ $self->s3->errstr }\n");
}

1;

