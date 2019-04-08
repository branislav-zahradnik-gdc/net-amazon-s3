package Net::Amazon::S3::Operation::Object::Upload::Initialize::Response;

use Moose;

extends 'Net::Amazon::S3::Response';

sub upload_id {
    $_[0]->data->{upload_id};
}

sub _parse_data {
    my ($self) = @_;

    my $xpc = $self->xpath_context;

    my $data = {
        upload_id => scalar $xpc->findvalue ("//s3:UploadId"),
    };

    return $data;
}

1;
