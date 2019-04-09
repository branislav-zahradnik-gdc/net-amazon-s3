package Net::Amazon::S3::Client::Bucket;

use Moose 0.85;
use MooseX::StrictConstructor 0.16;
use Data::Stream::Bulk::Callback;
use MooseX::Types::DateTime::MoreCoercions 0.07 qw( DateTime );

# ABSTRACT: An easy-to-use Amazon S3 client bucket

has 'client' =>
    ( is => 'ro', isa => 'Net::Amazon::S3::Client', required => 1 );
has 'name' => ( is => 'ro', isa => 'Str', required => 1 );
has 'creation_date' =>
    ( is => 'ro', isa => DateTime, coerce => 1, required => 0 );
has 'owner_id'           => ( is => 'ro', isa => 'Str', required => 0 );
has 'owner_display_name' => ( is => 'ro', isa => 'Str',     required => 0 );
has 'region' => (
    is => 'ro',
    lazy => 1,
    default => sub { $_[0]->location_constraint },
);


__PACKAGE__->meta->make_immutable;

sub _create {
    my ( $self, %conf ) = @_;

    my $response = $self->_fetch_response (
        response_class => 'Net::Amazon::S3::Operation::Bucket::Create::Response',
        request_class  => 'Net::Amazon::S3::Operation::Bucket::Create::Request',
        error_handler  => 'Net::Amazon::S3::Error::Handler::Confess',

        acl_short           => $conf{acl_short},
        location_constraint => $conf{location_constraint},
    );

    return $response->is_error;

    return $response->http_response;
}

sub delete {
    my $self         = shift;

    my $response = $self->_fetch_response (
        response_class => 'Net::Amazon::S3::Operation::Bucket::Delete::Response',
        request_class  => 'Net::Amazon::S3::Operation::Bucket::Delete::Request',
        error_handler  => 'Net::Amazon::S3::Error::Handler::Confess',
    );

    return if $response->is_error;
    return $response->http_response;
}

sub acl {
    my $self = shift;

    my $http_request = Net::Amazon::S3::Request::GetBucketAccessControl->new(
        s3     => $self->client->s3,
        bucket => $self->name,
    )->http_request;

    return $self->client->_send_request_content($http_request);
}

sub location_constraint {
    my $self = shift;

    my $response = $self->_fetch_response (
        response_class => 'Net::Amazon::S3::Operation::Bucket::Location::Response',
        request_class  => 'Net::Amazon::S3::Operation::Bucket::Location::Request',
        error_handler  => 'Net::Amazon::S3::Error::Handler::Confess',
    );

    return if $response->is_error;
    return $response->location;
}

sub object_class { 'Net::Amazon::S3::Client::Object' }

sub list {
    my ( $self, $conf ) = @_;
    $conf ||= {};
    my $prefix = $conf->{prefix};
    my $delimiter = $conf->{delimiter};

    my $marker = undef;
    my $end    = 0;

    return Data::Stream::Bulk::Callback->new(
        callback => sub {

            return undef if $end;

            my $response = $self->_fetch_response(
                response_class => 'Net::Amazon::S3::Operation::Bucket::Objects::List::Response',
                request_class  => 'Net::Amazon::S3::Operation::Bucket::Objects::List::Request',
                error_handler  => 'Net::Amazon::S3::Error::Handler::Confess',

                marker => $marker,
                prefix => $prefix,
                delimiter => $delimiter,
            );

            return if $response->is_error;

            my @objects;
            foreach my $node ($response->contents) {
                push @objects,
                    $self->object_class->new(
                    client => $self->client,
                    bucket => $self,
                    key    => $node->{key},
                    last_modified_raw => $node->{last_modified},
                    etag => $node->{etag},
                    size => $node->{size},
                    );
            }

            return undef unless @objects;

            $end = 1 unless $response->is_truncated;

            $marker = $response->next_marker
                || $objects[-1]->key;

            return \@objects;
        }
    );
}

sub delete_multi_object {
    my $self = shift;
    my @objects = @_;
    return unless( scalar(@objects) );

    # Since delete can handle up to 1000 requests, be a little bit nicer
    # and slice up requests and also allow keys to be strings
    # rather than only objects.
    my $last_result;
    while (scalar(@objects) > 0) {
        my $response = $self->_fetch_response (
            response_class => 'Net::Amazon::S3::Operation::Bucket::Objects::Delete::Response',
            request_class  => 'Net::Amazon::S3::Operation::Bucket::Objects::Delete::Request',
            error_handler  => 'Net::Amazon::S3::Error::Handler::Confess',

            keys    => [map {
                if (ref($_)) {
                    $_->key
                } else {
                    $_
                }
            } splice @objects, 0, ((scalar(@objects) > 1000) ? 1000 : scalar(@objects))]
        );

        $last_result = $response->http_response;

        last unless $response->is_success;
    }
    return $last_result;
}

sub object {
    my ( $self, %conf ) = @_;
    return $self->object_class->new(
        client => $self->client,
        bucket => $self,
        %conf,
    );
}

sub _fetch_response {
    my ($self, @params) = @_;

    $self->client->_fetch_response (
        bucket => $self->name,
        @params,
    );
}

1;

__END__

=for test_synopsis
no strict 'vars'

=head1 SYNOPSIS

  # return the bucket name
  print $bucket->name . "\n";

  # return the bucket location constraint
  print "Bucket is in the " . $bucket->location_constraint . "\n";

  # return the ACL XML
  my $acl = $bucket->acl;

  # list objects in the bucket
  # this returns a L<Data::Stream::Bulk> object which returns a
  # stream of L<Net::Amazon::S3::Client::Object> objects, as it may
  # have to issue multiple API requests
  my $stream = $bucket->list;
  until ( $stream->is_done ) {
    foreach my $object ( $stream->items ) {
      ...
    }
  }

  # or list by a prefix
  my $prefix_stream = $bucket->list( { prefix => 'logs/' } );

  # returns a L<Net::Amazon::S3::Client::Object>, which can then
  # be used to get or put
  my $object = $bucket->object( key => 'this is the key' );

  # delete the bucket (it must be empty)
  $bucket->delete;

=head1 DESCRIPTION

This module represents buckets.

=head1 METHODS

=head2 acl

  # return the ACL XML
  my $acl = $bucket->acl;

=head2 delete

  # delete the bucket (it must be empty)
  $bucket->delete;

=head2 list

  # list objects in the bucket
  # this returns a L<Data::Stream::Bulk> object which returns a
  # stream of L<Net::Amazon::S3::Client::Object> objects, as it may
  # have to issue multiple API requests
  my $stream = $bucket->list;
  until ( $stream->is_done ) {
    foreach my $object ( $stream->items ) {
      ...
    }
  }

  # or list by a prefix
  my $prefix_stream = $bucket->list( { prefix => 'logs/' } );

  # you can emulate folders by using prefix with delimiter
  # which shows only entries starting with the prefix but
  # not containing any more delimiter (thus no subfolders).
  my $folder_stream = $bucket->list( { prefix => 'logs/', delimiter => '/' } );

=head2 location_constraint

  # return the bucket location constraint
  print "Bucket is in the " . $bucket->location_constraint . "\n";

=head2 name

  # return the bucket name
  print $bucket->name . "\n";

=head2 object

  # returns a L<Net::Amazon::S3::Client::Object>, which can then
  # be used to get or put
  my $object = $bucket->object( key => 'this is the key' );

=head2 delete_multi_object

  # delete multiple objects using a multi object delete operation
  # Accepts a list of L<Net::Amazon::S3::Client::Object or String> objects.
  $bucket->delete_multi_object($object1, $object2)

=head2 object_class

  # returns string "Net::Amazon::S3::Client::Object"
  # allowing subclasses to add behavior.
  my $object_class = $bucket->object_class;

