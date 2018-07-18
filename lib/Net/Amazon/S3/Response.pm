package Net::Amazon::S3::Response;

use Moose;

use Carp ();

use XML::LibXML;
use XML::LibXML::XPathContext;

use constant AMAZON_S3_NAMESPACE_URI => 'http://s3.amazonaws.com/doc/2006-03-01/';

use namespace::clean;

has s3 => (
    is => 'ro',
);

has http_response => (
    is => 'ro',
    handles => [
        qw[ content ],
        qw[ content_length ],
        qw[ content_type ],
        qw[ header ],
        qw[ headers ],
    ],
);

has xml_document => (
    is => 'ro',
    init_arg => undef,
    lazy => 1,
    builder => '_build_xml_content',
);

has xpath_context => (
    is => 'ro',
    init_arg => undef,
    lazy => 1,
    builder => '_build_xpath_context',
);

has error_code => (
    is => 'ro',
    init_arg => undef,

    lazy => 1,
    default => sub {
        $_[0]->is_error
            ? $_[0]->xpath_context->findvalue( '/Error/Code' )
            : undef
            ;
    },
);

has error_message => (
    is => 'ro',
    init_arg => undef,
    lazy => 1,
    default => sub {
        $_[0]->is_error
            ? $_[0]->xpath_context->findvalue( '/Error/Message' )
            : undef
            ;
    },
);

has error_resource => (
    is => 'ro',
    init_arg => undef,
    lazy => 1,
    default => sub {
        $_[0]->is_error
            ? $_[0]->xpath_context->findvalue( '/Error/Resource' )
            : undef
            ;
    },
);

has error_request_id => (
    is => 'ro',
    init_arg => undef,
    lazy => 1,
    default => sub {
        $_[0]->is_error
            ? $_[0]->xpath_context->findvalue( '/Error/RequestId' )
            : undef
            ;
    },
);

has etag => (
    is => 'ro',
    lazy => 1,
    init_arg => undef,
    default => sub {
        my $etag = shift->http_response->header ('ETag');
        $etag =~ s/ (?:^") | (?:"$) //gx if $etag;
        $etag;
    },
);

has data => (
    is => 'ro',
    init_arg => undef,
    lazy => 1,
    default => sub {
        $_[0]->is_success
            ? $_[0]->_parse_data
            : undef
            ;
    },
);

sub _build_xml_content {
    my ($self) = @_;

    return unless $self->is_xml_content;
    # TODO: A 200 OK response can contain valid or invalid XML
    my $doc = XML::LibXML->new->parse_string ($self->http_response->decoded_content);
}

sub _build_xpath_context {
    my ($self) = @_;

    die "xpath context expected but not a xml content"
        unless $self->is_xml_content;

    my $doc = $self->xml_document;
    my $xpc = XML::LibXML::XPathContext->new ($doc);
    $xpc->registerNs (s3 => AMAZON_S3_NAMESPACE_URI);

    return $xpc;
}

sub is_xml_content {
    my ($self) = @_;

    return unless $self->http_response->content;
    return unless $self->http_response->content_type =~ m:^application/xml\b:;
    return 1;
}

sub is_success {
    my ($self) = @_;

    return $self->http_response->is_success;
}

sub is_error {
    my ($self) = @_;

    return 1 if $self->http_response->is_error;
    return unless $self->is_xml_content;
    return 1 if $self->xpath_context->findvalue ('/Error');
    return;
}

sub is_redirect {
    my ($self) = @_;

    return $self->http_response->is_redirect;
}

sub parse {
    my ($self) = @_;

    return unless $self->is_success;
    return unless $self->http_response->content_type eq 'application/xml';

    return $self->data;
}

sub _parse_data {
    return {};
}

1;
