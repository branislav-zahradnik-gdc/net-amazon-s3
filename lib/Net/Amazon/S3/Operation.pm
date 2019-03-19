
use strict;
use warnings;

package Net::Amazon::S3::Operation;

use Moose;

has s3 => (
    is => 'ro',
    isa => 'Net::Amazon::S3',
    required => 1,
    handles => {
        _do_request => '_do_http',
    },
);

has error_handler => (
    is => 'ro',
    isa => 'Net::Amazon::S3::Error::Handler',
    lazy => 1,
    default => sub { $_[0]->error_handler_class->new (s3 => $_[0]->s3) },
);

has error_handler_class => (
    is => 'ro',
);

sub _build_request {
    my ($self, %params) = @_;

    delete $params{response};
    # TODO: accept redirect uri redirect (Signature::V4)
    return $self->request_class->new (
        %params,
        s3 => $self->s3,
    );
}

sub response {
    my ($self, %params) = @_;

    my $response;
    do {
        my $request = $self->_build_request (%params, response => $response);
        my $http_response = $self->_do_request ($request->http_request);
        $response = $self->response_class->new (s3 => $self->s3, http_response => $http_response);
    } while $response->is_redirect;

    return $self->error_handler->handle_error ($response)
        if $response->is_error;

    return $response;
}

1;
