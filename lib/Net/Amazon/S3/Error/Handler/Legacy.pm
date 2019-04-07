package Net::Amazon::S3::Error::Handler::Legacy;

# ABSTRACT: An internal class to report errors like legacy API

use Moose;

extends 'Net::Amazon::S3::Error::Handler::Status';

our @CARP_NOT = __PACKAGE__;

my %croak = map +($_ => 1), (
    'Net::Amazon::S3::Operation::Object::Fetch::Response',
    'Net::Amazon::S3::Operation::Object::Acl::Fetch::Response',
    'Net::Amazon::S3::Operation::Bucket::Acl::Fetch::Response',
);

override handle_error => sub {
    my ($self, $response) = @_;

    return super unless exists $croak{ref $response};

    return 1 unless $response->is_error;
    return 1 if $response->http_response->code == 404;

    $self->s3->err ("network_error");
    $self->s3->errstr ($response->http_response->status_line);

    Carp::croak ("Net::Amazon::S3: Amazon responded with ${\ $self->s3->errstr }\n");
};

1;

