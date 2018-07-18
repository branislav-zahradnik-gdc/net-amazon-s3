package Net::Amazon::S3::Client;

use Moose 0.85;
use HTTP::Status qw(is_error status_message);
use MooseX::StrictConstructor 0.16;
use Moose::Util::TypeConstraints;

use Net::Amazon::S3::Error::Handler::Confess;

# ABSTRACT: An easy-to-use Amazon S3 client

type 'Etag' => where { $_ =~ /^[a-z0-9]{32}(?:-\d+)?$/ };

has 's3' => ( is => 'ro', isa => 'Net::Amazon::S3', required => 1 );

__PACKAGE__->meta->make_immutable;

sub bucket_class { 'Net::Amazon::S3::Client::Bucket' }

sub _build_bucket {
    my ($self, %params) = @_;

    $self->bucket_class->new (
        client => $self,
        name   => $params{name},
        creation_date => $params{creation_date},
        owner_id           => $params{owner_id},
        owner_display_name => $params{owner_displayname},
    );
}

sub buckets {
    my ($self) = @_;

    my $operation = Net::Amazon::S3::Operation::Service::Buckets::List->new (
        s3 => $self->s3,
        error_handler_class => 'Net::Amazon::S3::Error::Handler::Confess',
    );

    my $response = $operation->response;
    return unless $response;

    my $owner_id           = $response->data->{owner_id};
    my $owner_display_name = $response->data->{owner_displayname};

    my @buckets;
    foreach my $bucket ( @{ $response->data->{buckets} } ) {
        push @buckets, $self->_build_bucket (
            name   => $bucket->{name},
            creation_date => $bucket->{creation_date},
            owner_id          => $owner_id,
            owner_displayname => $owner_display_name,
        );
    }
    return @buckets;
}

sub buckets_old {
    my $self = shift;
    my $s3   = $self->s3;

    my $response = $self->_fetch_response (
        response_class => 'Net::Amazon::S3::Operation::Service::List::Response',
        request_class  => 'Net::Amazon::S3::Operation::Service::List::Request',
        error_handler  => 'Net::Amazon::S3::Error::Handler::Confess',
    );

    return if $response->is_error;

    my $owner_id = $response->owner_id;
    my $owner_display_name = $response->owner_displayname;

    my @buckets;
    foreach my $bucket ($response->buckets) {
        push @buckets,
            $self->bucket_class->new(
            {   client => $self,
                name   => $bucket->{name},
                creation_date => $bucket->{creation_date},
                owner_id           => $owner_id,
                owner_display_name => $owner_display_name,
            }
            );

    }
    return @buckets;
}

sub create_bucket {
    my ( $self, %conf ) = @_;

    my $bucket = $self->bucket_class->new(
        client => $self,
        name   => $conf{name},
    );
    $bucket->_create(
        acl_short           => $conf{acl_short},
        location_constraint => $conf{location_constraint},
    );
    return $bucket;
}

sub bucket {
    my ( $self, %conf ) = @_;
    return $self->bucket_class->new(
        client => $self,
        %conf,
    );
}

sub _send_request_raw {
    my ( $self, $http_request, $filename ) = @_;

    return $self->s3->ua->request( $http_request, $filename );
}


sub _default_error_handler_class {
    return 'Net::Amazon::S3::Error::Handler::Throw::Error';
}

sub _do_operation {
    my ($self, $operation_class, %request_params) = @_;

    my $http_response = $self->_send_request ($http_request, $filename);
    my $error_handler_class = delete $request_params{error_handler_class}
        || $self->_default_error_handler_class;

    my $operation = $operation_class->new (
        s3 => $self,
        error_handler_class => $error_handler_class,
    );

    return $operation->response (%request_params);
}

1;

__END__

=for test_synopsis
no strict 'vars'

=head1 SYNOPSIS

  my $s3 = Net::Amazon::S3->new(
    aws_access_key_id     => $aws_access_key_id,
    aws_secret_access_key => $aws_secret_access_key,
    retry                 => 1,
  );
  my $client = Net::Amazon::S3::Client->new( s3 => $s3 );

  # list all my buckets
  # returns a list of L<Net::Amazon::S3::Client::Bucket> objects
  my @buckets = $client->buckets;
  foreach my $bucket (@buckets) {
    print $bucket->name . "\n";
  }

  # create a new bucket
  # returns a L<Net::Amazon::S3::Client::Bucket> object
  my $bucket = $client->create_bucket(
    name                => $bucket_name,
    acl_short           => 'private',
    location_constraint => 'us-east-1',
  );

  # or use an existing bucket
  # returns a L<Net::Amazon::S3::Client::Bucket> object
  my $bucket = $client->bucket( name => $bucket_name );

=head1 DESCRIPTION

The L<Net::Amazon::S3> module was written when the Amazon S3 service
had just come out and it is a light wrapper around the APIs. Some
bad API decisions were also made. The
L<Net::Amazon::S3::Client>, L<Net::Amazon::S3::Client::Bucket> and
L<Net::Amazon::S3::Client::Object> classes are designed after years
of usage to be easy to use for common tasks.

These classes throw an exception when a fatal error occurs. It
also is very careful to pass an MD5 of the content when uploaded
to S3 and check the resultant ETag.

WARNING: This is an early release of the Client classes, the APIs
may change.

=head1 METHODS

=head2 buckets

  # list all my buckets
  # returns a list of L<Net::Amazon::S3::Client::Bucket> objects
  my @buckets = $client->buckets;
  foreach my $bucket (@buckets) {
    print $bucket->name . "\n";
  }

=head2 create_bucket

  # create a new bucket
  # returns a L<Net::Amazon::S3::Client::Bucket> object
  my $bucket = $client->create_bucket(
    name                => $bucket_name,
    acl_short           => 'private',
    location_constraint => 'us-east-1',
  );

=head2 bucket

  # or use an existing bucket
  # returns a L<Net::Amazon::S3::Client::Bucket> object
  my $bucket = $client->bucket( name => $bucket_name );

=head2 bucket_class

  # returns string "Net::Amazon::S3::Client::Bucket"
  # subclasses will want to override this.
  my $bucket_class = $client->bucket_class

