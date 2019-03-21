package Net::Amazon::S3::Error::Handler::Status;

# ABSTRACT: An internal class to report errors via err properties

use Moose;

extends 'Net::Amazon::S3::Error::Handler';

has s3 => (
    is => 'ro',
    isa => 'Net::Amazon::S3',
    required => 1,
);

sub handle_error {
    my ($self, $response) = @_;

    return 1 unless $response->is_error;

    $self->s3->err ($response->error_code);
    $self->s3->errstr ($response->error_message);

    return;
}

1;

