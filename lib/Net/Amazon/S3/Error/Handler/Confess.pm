package Net::Amazon::S3::Error::Handler::Confess;

# ABSTRACT: An internal class to report errors via Carp::confess

use Moose;
use Carp;
use HTTP::Status;

extends 'Net::Amazon::S3::Error::Handler';

our @CARP_NOT = (__PACKAGE__);

has s3 => (
    is => 'ro',
    isa => 'Net::Amazon::S3',
    required => 1,
);

sub handle_error {
    my ($self, $response) = @_;

    return 1 unless $response->is_error;

    Carp::confess ("${\ $response->error_code }: ${\ $response->error_message }")
        if $response->is_xml_content;

    Carp::confess (HTTP::Status::status_message ($response->http_response->code));
}

1;

