package Net::Amazon::S3::Operation::Object::Add::Response;

use Moose;
extends 'Net::Amazon::S3::Response';

has etag => (
    is => 'ro',
    init_arg => undef,
    lazy => 1,
    builder => '_build_etag',
);

sub _build_etag {
    my ($self) = @_;

    my $etag = $self->http_response->header ('ETag');
    $etag =~ s/^"|"$//g if $etag;

    return $etag;
}

# ABSTRACT: An internal class to handle object add response

1;
