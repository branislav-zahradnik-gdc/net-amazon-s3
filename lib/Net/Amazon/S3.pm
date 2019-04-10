package Net::Amazon::S3;

use Moose 0.85;
use MooseX::StrictConstructor 0.16;

# ABSTRACT: Use the Amazon S3 - Simple Storage Service

=head1 SYNOPSIS

  use Net::Amazon::S3;
  my $aws_access_key_id     = 'fill me in';
  my $aws_secret_access_key = 'fill me in too';

  my $s3 = Net::Amazon::S3->new(
      {   aws_access_key_id     => $aws_access_key_id,
          aws_secret_access_key => $aws_secret_access_key,
          # or use an IAM role.
          use_iam_role          => 1

          retry                 => 1,
      }
  );

  # a bucket is a globally-unique directory
  # list all buckets that i own
  my $response = $s3->buckets;
  foreach my $bucket ( @{ $response->{buckets} } ) {
      print "You have a bucket: " . $bucket->bucket . "\n";
  }

  # create a new bucket
  my $bucketname = 'acmes_photo_backups';
  my $bucket = $s3->add_bucket( { bucket => $bucketname } )
      or die $s3->err . ": " . $s3->errstr;

  # or use an existing bucket
  $bucket = $s3->bucket($bucketname);

  # store a file in the bucket
  $bucket->add_key_filename( '1.JPG', 'DSC06256.JPG',
      { content_type => 'image/jpeg', },
  ) or die $s3->err . ": " . $s3->errstr;

  # store a value in the bucket
  $bucket->add_key( 'reminder.txt', 'this is where my photos are backed up' )
      or die $s3->err . ": " . $s3->errstr;

  # list files in the bucket
  $response = $bucket->list_all
      or die $s3->err . ": " . $s3->errstr;
  foreach my $key ( @{ $response->{keys} } ) {
      my $key_name = $key->{key};
      my $key_size = $key->{size};
      print "Bucket contains key '$key_name' of size $key_size\n";
  }

  # fetch file from the bucket
  $response = $bucket->get_key_filename( '1.JPG', 'GET', 'backup.jpg' )
      or die $s3->err . ": " . $s3->errstr;

  # fetch value from the bucket
  $response = $bucket->get_key('reminder.txt')
      or die $s3->err . ": " . $s3->errstr;
  print "reminder.txt:\n";
  print "  content length: " . $response->{content_length} . "\n";
  print "    content type: " . $response->{content_type} . "\n";
  print "            etag: " . $response->{content_type} . "\n";
  print "         content: " . $response->{value} . "\n";

  # delete keys
  $bucket->delete_key('reminder.txt') or die $s3->err . ": " . $s3->errstr;
  $bucket->delete_key('1.JPG')        or die $s3->err . ": " . $s3->errstr;

  # and finally delete the bucket
  $bucket->delete_bucket or die $s3->err . ": " . $s3->errstr;

=head1 DESCRIPTION

This module provides a Perlish interface to Amazon S3. From the
developer blurb: "Amazon S3 is storage for the Internet. It is
designed to make web-scale computing easier for developers. Amazon S3
provides a simple web services interface that can be used to store and
retrieve any amount of data, at any time, from anywhere on the web. It
gives any developer access to the same highly scalable, reliable,
fast, inexpensive data storage infrastructure that Amazon uses to run
its own global network of web sites. The service aims to maximize
benefits of scale and to pass those benefits on to developers".

To find out more about S3, please visit: http://s3.amazonaws.com/

To use this module you will need to sign up to Amazon Web Services and
provide an "Access Key ID" and " Secret Access Key". If you use this
module, you will incurr costs as specified by Amazon. Please check the
costs. If you use this module with your Access Key ID and Secret
Access Key you must be responsible for these costs.

I highly recommend reading all about S3, but in a nutshell data is
stored in values. Values are referenced by keys, and keys are stored
in buckets. Bucket names are global.

Note: This is the legacy interface, please check out
L<Net::Amazon::S3::Client> instead.

Development of this code happens here: https://github.com/rustyconover/net-amazon-s3

=cut

use Carp;
use Digest::HMAC_SHA1;
use Safe::Isa ();

use Net::Amazon::S3::Bucket;
use Net::Amazon::S3::Client;
use Net::Amazon::S3::Client::Bucket;
use Net::Amazon::S3::Client::Object;
use Net::Amazon::S3::Error::Handler::Legacy;
use Net::Amazon::S3::HTTPRequest;
use Net::Amazon::S3::Request;
use Net::Amazon::S3::Operation::Service::List::Request;
use Net::Amazon::S3::Operation::Service::List::Response;
use Net::Amazon::S3::Operation::Bucket::Acl::Fetch::Request;
use Net::Amazon::S3::Operation::Bucket::Acl::Fetch::Response;
use Net::Amazon::S3::Operation::Bucket::Acl::Set::Request;
use Net::Amazon::S3::Operation::Bucket::Acl::Set::Response;
use Net::Amazon::S3::Operation::Bucket::Create::Request;
use Net::Amazon::S3::Operation::Bucket::Create::Response;
use Net::Amazon::S3::Operation::Bucket::Delete::Request;
use Net::Amazon::S3::Operation::Bucket::Delete::Response;
use Net::Amazon::S3::Operation::Bucket::Location::Request;
use Net::Amazon::S3::Operation::Bucket::Location::Response;
use Net::Amazon::S3::Operation::Bucket::Objects::Delete::Request;
use Net::Amazon::S3::Operation::Bucket::Objects::Delete::Response;
use Net::Amazon::S3::Operation::Bucket::Objects::List::Request;
use Net::Amazon::S3::Operation::Bucket::Objects::List::Response;
use Net::Amazon::S3::Operation::Object::Add::Request;
use Net::Amazon::S3::Operation::Object::Add::Response;
use Net::Amazon::S3::Operation::Object::Delete::Request;
use Net::Amazon::S3::Operation::Object::Delete::Response;
use Net::Amazon::S3::Operation::Object::Fetch::Request;
use Net::Amazon::S3::Operation::Object::Fetch::Response;
use Net::Amazon::S3::Operation::Object::Acl::Fetch::Request;
use Net::Amazon::S3::Operation::Object::Acl::Fetch::Response;
use Net::Amazon::S3::Operation::Object::Acl::Set::Request;
use Net::Amazon::S3::Operation::Object::Acl::Set::Response;
use Net::Amazon::S3::Operation::Object::Upload::Abort::Request;
use Net::Amazon::S3::Operation::Object::Upload::Abort::Response;
use Net::Amazon::S3::Operation::Object::Upload::Complete::Request;
use Net::Amazon::S3::Operation::Object::Upload::Complete::Response;
use Net::Amazon::S3::Operation::Object::Upload::Initialize::Request;
use Net::Amazon::S3::Operation::Object::Upload::Initialize::Response;
use Net::Amazon::S3::Operation::Object::Upload::List::Request;
use Net::Amazon::S3::Operation::Object::Upload::Part::Request;
use Net::Amazon::S3::Operation::Object::Upload::Part::Response;
use Net::Amazon::S3::Signature::V2;
use Net::Amazon::S3::Signature::V4;
use LWP::UserAgent::Determined;
use URI::Escape qw(uri_escape_utf8);
use XML::LibXML;
use XML::LibXML::XPathContext;

my $AMAZON_S3_HOST = 's3.amazonaws.com';

has 'use_iam_role' => ( is => 'ro', isa => 'Bool', required => 0, default => 0);
has 'aws_access_key_id'     => ( is => 'rw', isa => 'Str', required => 0 );
has 'aws_secret_access_key' => ( is => 'rw', isa => 'Str', required => 0 );
has 'secure' => ( is => 'ro', isa => 'Bool', required => 0, default => 1 );
has 'timeout' => ( is => 'ro', isa => 'Num',  required => 0, default => 30 );
has 'retry'   => ( is => 'ro', isa => 'Bool', required => 0, default => 0 );
has 'host'    => ( is => 'ro', isa => 'Str',  required => 0, default => $AMAZON_S3_HOST );
has 'use_virtual_host' => (
    is => 'ro',
    isa => 'Bool',
    required => 0,
    lazy => 1,
    default => sub { $_[0]->authorization_method->enforce_use_virtual_host },
);
has 'libxml' => ( is => 'rw', isa => 'XML::LibXML',    required => 0 );
has 'ua'     => ( is => 'rw', isa => 'LWP::UserAgent', required => 0 );
has 'err'    => ( is => 'rw', isa => 'Maybe[Str]',     required => 0 );
has 'errstr' => ( is => 'rw', isa => 'Maybe[Str]',     required => 0 );
has 'aws_session_token' => ( is => 'rw', isa => 'Str', required => 0 );
has authorization_method => (
    is => 'ro',
    isa => 'Str',
    required => 0,
    lazy => 1,
    default => sub {
        $_[0]->host eq $AMAZON_S3_HOST
            ? 'Net::Amazon::S3::Signature::V4'
            : 'Net::Amazon::S3::Signature::V2'
    },
);

has keep_alive_cache_size => ( is => 'ro', isa => 'Int', required => 0, default => 10 );

__PACKAGE__->meta->make_immutable;

=head1 METHODS

=head2 new

Create a new S3 client object. Takes some arguments:

=over

=item aws_access_key_id

Use your Access Key ID as the value of the AWSAccessKeyId parameter
in requests you send to Amazon Web Services (when required). Your
Access Key ID identifies you as the party responsible for the
request.

=item aws_secret_access_key

Since your Access Key ID is not encrypted in requests to AWS, it
could be discovered and used by anyone. Services that are not free
require you to provide additional information, a request signature,
to verify that a request containing your unique Access Key ID could
only have come from you.

DO NOT INCLUDE THIS IN SCRIPTS OR APPLICATIONS YOU DISTRIBUTE. YOU'LL BE SORRY

=item aws_session_token

If you are using temporary credentials provided by the AWS Security Token
Service, set the token here, and it will be added to the request in order to
authenticate it.

=item use_iam_role

If you'd like to use IAM provided temporary credentials, pass this option
with a true value.

=item secure

Set this to C<0> if you don't want to use SSL-encrypted connections when talking
to S3. Defaults to C<1>.

To use SSL-encrypted connections, LWP::Protocol::https is required.

=item keep_alive_cache_size

Set this to C<0> to disable Keep-Alives.  Default is C<10>.

=item timeout

How many seconds should your script wait before bailing on a request to S3? Defaults
to 30.

=item retry

If this library should retry upon errors. This option is recommended.
This uses exponential backoff with retries after 1, 2, 4, 8, 16, 32 seconds,
as recommended by Amazon. Defaults to off.

=item host

The S3 host endpoint to use. Defaults to 's3.amazonaws.com'. This allows
you to connect to any S3-compatible host.

=item use_virtual_host

Use the virtual host method ('bucketname.s3.amazonaws.com') instead of specifying the
bucket at the first part of the path. This is particularly useful if you want to access
buckets not located in the US-Standard region (such as EU, Asia Pacific or South America).
See L<http://docs.aws.amazon.com/AmazonS3/latest/dev/VirtualHosting.html> for the pros and cons.

=item authorization_method

Authorization implementation package name.

This library provides L<< Net::Amazon::S3::Signature::V2 >> and L<< Net::Amazon::S3::Signature::V4 >>

Default is Signature 4 if host is C<< s3.amazonaws.com >>, Signature 2 otherwise

=back

=head3 Notes

When using L<Net::Amazon::S3> in child processes using fork (such as in
combination with the excellent L<Parallel::ForkManager>) you should create the
S3 object in each child, use a fresh LWP::UserAgent in each child, or disable
the L<LWP::ConnCache> in the parent:

    $s3->ua( LWP::UserAgent->new( 
        keep_alive => 0, requests_redirectable => [qw'GET HEAD DELETE PUT POST'] );

=cut

sub BUILD {
    my $self = shift;

    if (!$self->use_iam_role) {
        if (!defined($self->aws_secret_access_key) || !defined($self->aws_access_key_id)) {
            die("Must specify aws_secret_access_key and aws_access_key_id");
        }
    }


    my $ua;
    if ( $self->retry ) {
        $ua = LWP::UserAgent::Determined->new(
            keep_alive            => $self->keep_alive_cache_size,
            requests_redirectable => [qw(GET HEAD DELETE PUT POST)],
        );
        $ua->timing('1,2,4,8,16,32');
    } else {
        $ua = LWP::UserAgent->new(
            keep_alive            => $self->keep_alive_cache_size,
            requests_redirectable => [qw(GET HEAD DELETE PUT POST)],
        );
    }

    $ua->timeout( $self->timeout );
    $ua->env_proxy;

    $self->ua($ua);
    $self->libxml( XML::LibXML->new );

    if ($self->use_iam_role) {
        eval "require VM::EC2::Security::CredentialCache" or die $@;
        my $creds = VM::EC2::Security::CredentialCache->get();
        defined($creds) || die("Unable to retrieve IAM role credentials");
        $self->aws_access_key_id($creds->accessKeyId);
        $self->aws_secret_access_key($creds->secretAccessKey);
        $self->aws_session_token($creds->sessionToken);
    }
}

=head2 buckets

Returns undef on error, else hashref of results

=cut

sub bucket_class {
    'Net::Amazon::S3::Bucket'
}

sub buckets {
    my $self = shift;

    my $response = $self->_fetch_response (
        response_class => 'Net::Amazon::S3::Operation::Service::List::Response',
        request_class  => 'Net::Amazon::S3::Operation::Service::List::Request',
        error_handler  => 'Net::Amazon::S3::Error::Handler::Legacy',
    );

    return if $response->is_error;

    my $owner_id          = $response->owner_id;;
    my $owner_displayname = $response->owner_displayname;

    my @buckets;
    foreach my $bucket ( $response->buckets ) {
        push @buckets,
            $self->bucket_class->new(
            {   bucket => $bucket->{name},
                creation_date => $bucket->{creation_date},
                account => $self,
            }
            );

    }
    return {
        owner_id          => $owner_id,
        owner_displayname => $owner_displayname,
        buckets           => \@buckets,
    };
}

=head2 add_bucket

Takes a hashref:

=over

=item bucket

The name of the bucket you want to add

=item acl_short (optional)

See the set_acl subroutine for documentation on the acl_short options

=item location_constraint (option)

Sets the location constraint of the new bucket. If left unspecified, the
default S3 datacenter location will be used. Otherwise, you can set it
to 'EU' for a European data center - note that costs are different.

=back

Returns 0 on failure, Net::Amazon::S3::Bucket object on success

=cut

sub add_bucket {
    my ( $self, $conf ) = @_;

    my $response = $self->_fetch_response(
        response_class => 'Net::Amazon::S3::Operation::Bucket::Create::Response',
        request_class  => 'Net::Amazon::S3::Operation::Bucket::Create::Request',
        error_handler  => 'Net::Amazon::S3::Error::Handler::Legacy',

        bucket              => $conf->{bucket},
        acl_short           => $conf->{acl_short},
        location_constraint => $conf->{location_constraint},
    );

    return if $response->is_error;

    return $self->bucket( $conf->{bucket} );
}

=head2 bucket BUCKET

Takes a scalar argument, the name of the bucket you're creating

Returns an (unverified) bucket object from an account. Does no network access.

=cut

sub bucket {
    my ( $self, $bucket ) = @_;

    return $bucket if $bucket->$Safe::Isa::_isa ($self->bucket_class);

    return $self->bucket_class->new(
        { bucket => $bucket, account => $self } );
}

=head2 delete_bucket

Takes either a L<Net::Amazon::S3::Bucket> object or a hashref containing

=over

=item bucket

The name of the bucket to remove

=back

Returns false (and fails) if the bucket isn't empty.

Returns true if the bucket is successfully deleted.

=cut

sub delete_bucket {
    my ( $self, $conf ) = @_;
    my $bucket;
    if ( eval { $conf->isa("Net::S3::Amazon::Bucket"); } ) {
        $bucket = $conf->bucket;
    } else {
        $bucket = $conf->{bucket};
    }
    croak 'must specify bucket' unless $bucket;

    my $response = $self->_fetch_response (
        response_class => 'Net::Amazon::S3::Operation::Bucket::Delete::Response',
        request_class  => 'Net::Amazon::S3::Operation::Bucket::Delete::Request',
        error_handler  => 'Net::Amazon::S3::Error::Handler::Legacy',

        bucket => $bucket,
    );

    return if $response->is_error;

    return 1;
}

=head2 list_bucket

List all keys in this bucket.

Takes a hashref of arguments:

MANDATORY

=over

=item bucket

The name of the bucket you want to list keys on

=back

OPTIONAL

=over

=item prefix

Restricts the response to only contain results that begin with the
specified prefix. If you omit this optional argument, the value of
prefix for your query will be the empty string. In other words, the
results will be not be restricted by prefix.

=item delimiter

If this optional, Unicode string parameter is included with your
request, then keys that contain the same string between the prefix
and the first occurrence of the delimiter will be rolled up into a
single result element in the CommonPrefixes collection. These
rolled-up keys are not returned elsewhere in the response.  For
example, with prefix="USA/" and delimiter="/", the matching keys
"USA/Oregon/Salem" and "USA/Oregon/Portland" would be summarized
in the response as a single "USA/Oregon" element in the CommonPrefixes
collection. If an otherwise matching key does not contain the
delimiter after the prefix, it appears in the Contents collection.

Each element in the CommonPrefixes collection counts as one against
the MaxKeys limit. The rolled-up keys represented by each CommonPrefixes
element do not.  If the Delimiter parameter is not present in your
request, keys in the result set will not be rolled-up and neither
the CommonPrefixes collection nor the NextMarker element will be
present in the response.

=item max-keys

This optional argument limits the number of results returned in
response to your query. Amazon S3 will return no more than this
number of results, but possibly less. Even if max-keys is not
specified, Amazon S3 will limit the number of results in the response.
Check the IsTruncated flag to see if your results are incomplete.
If so, use the Marker parameter to request the next page of results.
For the purpose of counting max-keys, a 'result' is either a key
in the 'Contents' collection, or a delimited prefix in the
'CommonPrefixes' collection. So for delimiter requests, max-keys
limits the total number of list results, not just the number of
keys.

=item marker

This optional parameter enables pagination of large result sets.
C<marker> specifies where in the result set to resume listing. It
restricts the response to only contain results that occur alphabetically
after the value of marker. To retrieve the next page of results,
use the last key from the current page of results as the marker in
your next request.

See also C<next_marker>, below.

If C<marker> is omitted,the first page of results is returned.

=back


Returns undef on error and a hashref of data on success:

The hashref looks like this:

  {
        bucket          => $bucket_name,
        prefix          => $bucket_prefix,
        common_prefixes => [$prefix1,$prefix2,...]
        marker          => $bucket_marker,
        next_marker     => $bucket_next_available_marker,
        max_keys        => $bucket_max_keys,
        is_truncated    => $bucket_is_truncated_boolean
        keys            => [$key1,$key2,...]
   }

Explanation of bits of that:

=over

=item common_prefixes

If list_bucket was requested with a delimiter, common_prefixes will
contain a list of prefixes matching that delimiter.  Drill down into
these prefixes by making another request with the prefix parameter.

=item is_truncated

B flag that indicates whether or not all results of your query were
returned in this response. If your results were truncated, you can
make a follow-up paginated request using the Marker parameter to
retrieve the rest of the results.


=item next_marker

A convenience element, useful when paginating with delimiters. The
value of C<next_marker>, if present, is the largest (alphabetically)
of all key names and all CommonPrefixes prefixes in the response.
If the C<is_truncated> flag is set, request the next page of results
by setting C<marker> to the value of C<next_marker>. This element
is only present in the response if the C<delimiter> parameter was
sent with the request.

=back

Each key is a hashref that looks like this:

     {
        key           => $key,
        last_modified => $last_mod_date,
        etag          => $etag, # An MD5 sum of the stored content.
        size          => $size, # Bytes
        storage_class => $storage_class # Doc?
        owner_id      => $owner_id,
        owner_displayname => $owner_name
    }

=cut

sub list_bucket {
    my ( $self, $conf ) = @_;

    my $response = $self->_fetch_response(
        response_class => 'Net::Amazon::S3::Operation::Bucket::Objects::List::Response',
        request_class  => 'Net::Amazon::S3::Operation::Bucket::Objects::List::Request',
        error_handler  => 'Net::Amazon::S3::Error::Handler::Legacy',

        bucket    => $conf->{bucket},
        delimiter => $conf->{delimiter},
        max_keys  => $conf->{max_keys},
        marker    => $conf->{marker},
        prefix    => $conf->{prefix},
    );

    return if $response->is_error;

    my $return = {
        bucket      => $response->bucket,
        prefix      => $response->prefix,
        marker      => $response->marker,
        next_marker => $response->next_marker,
        max_keys    => $response->max_keys,
        is_truncated => $response->is_truncated,
    };

    my @keys;
    foreach my $node ($response->contents) {
        push @keys,
            {
            key           => $node->{key},
            last_modified => $node->{last_modified},
            etag          => $node->{etag},
            size          => $node->{size},
            storage_class => $node->{storage_class},
            owner_id      => $node->{owner}{id},
            owner_displayname => $node->{owner}{displayname},
            };
    }
    $return->{keys} = \@keys;

    if ( $conf->{delimiter} ) {
        $return->{common_prefixes} = [ $response->common_prefixes ];
    }

    return $return;
}

=head2 list_bucket_all

List all keys in this bucket without having to worry about
'marker'. This is a convenience method, but may make multiple requests
to S3 under the hood.

Takes the same arguments as list_bucket.

=cut

sub list_bucket_all {
    my ( $self, $conf ) = @_;
    $conf ||= {};
    my $bucket = $conf->{bucket};
    croak 'must specify bucket' unless $bucket;

    my $response = $self->list_bucket($conf);
    return $response unless $response->{is_truncated};
    my $all = $response;

    while (1) {
        my $next_marker = $response->{next_marker}
            || $response->{keys}->[-1]->{key};
        $conf->{marker} = $next_marker;
        $conf->{bucket} = $bucket;
        $response       = $self->list_bucket($conf);
        push @{ $all->{keys} }, @{ $response->{keys} };
        last unless $response->{is_truncated};
    }

    delete $all->{is_truncated};
    delete $all->{next_marker};
    return $all;
}

=head2 add_key

DEPRECATED. DO NOT USE

=cut

# compat wrapper; deprecated as of 2005-03-23
sub add_key {
    my ( $self, $conf ) = @_;
    my $bucket = $self->bucket (delete $conf->{bucket});
    my $key    = delete $conf->{key};
    my $value  = delete $conf->{value};
    return $bucket->add_key( $key, $value, $conf );
}

=head2 get_key

DEPRECATED. DO NOT USE

=cut

# compat wrapper; deprecated as of 2005-03-23
sub get_key {
    my ( $self, $conf ) = @_;
    my $bucket = $self->bucket (delete $conf->{bucket});
    return $bucket->get_key( $conf->{key} );
}

=head2 head_key

DEPRECATED. DO NOT USE

=cut

# compat wrapper; deprecated as of 2005-03-23
sub head_key {
    my ( $self, $conf ) = @_;
    my $bucket = $self->bucket (delete $conf->{bucket});
    return $bucket->head_key( $conf->{key} );
}

=head2 delete_key

DEPRECATED. DO NOT USE

=cut

# compat wrapper; deprecated as of 2005-03-23
sub delete_key {
    my ( $self, $conf ) = @_;
    my $bucket = $self->bucket (delete $conf->{bucket});
    return $bucket->delete_key( $conf->{key} );
}

sub _validate_acl_short {
    my ( $self, $policy_name ) = @_;

    if (!grep( { $policy_name eq $_ }
            qw(private public-read public-read-write authenticated-read) ) )
    {
        croak "$policy_name is not a supported canned access policy";
    }
}

sub _fetch_response {
    my ($self, %params) = @_;

    my $request_class = delete $params{request_class};
    my $response_class = delete $params{response_class};
    my $error_handler = delete $params{error_handler};

    my $request       = $request_class->new (s3 => $self, %params);
    my $http_response = $self->_do_http ($request->http_request);
    my $response      = $response_class->new (http_response => $http_response);

    $error_handler->new (s3 => $self)->handle_error ($response)
        if $error_handler;

    return $response;
}

# centralize all HTTP work, for debugging
sub _do_http {
    my ( $self, $http_request, $filename ) = @_;

    confess 'Need HTTP::Request object'
        if ( ref($http_request) ne 'HTTP::Request' );

    # convenient time to reset any error conditions
    $self->err(undef);
    $self->errstr(undef);
    return $self->ua->request( $http_request, $filename );
}

sub _urlencode {
    my ( $self, $unencoded ) = @_;
    return uri_escape_utf8( $unencoded, '^A-Za-z0-9_\-\.' );
}

1;

__END__

=head1 LICENSE

This module contains code modified from Amazon that contains the
following notice:

  #  This software code is made available "AS IS" without warranties of any
  #  kind.  You may copy, display, modify and redistribute the software
  #  code either by itself or as incorporated into your code; provided that
  #  you do not remove any proprietary notices.  Your use of this software
  #  code is at your own risk and you waive any claim against Amazon
  #  Digital Services, Inc. or its affiliates with respect to your use of
  #  this software code. (c) 2006 Amazon Digital Services, Inc. or its
  #  affiliates.

=head1 TESTING

Testing S3 is a tricky thing. Amazon wants to charge you a bit of
money each time you use their service. And yes, testing counts as using.
Because of this, the application's test suite skips anything approaching
a real test unless you set these three environment variables:

=over

=item AMAZON_S3_EXPENSIVE_TESTS

Doesn't matter what you set it to. Just has to be set

=item AWS_ACCESS_KEY_ID

Your AWS access key

=item AWS_ACCESS_KEY_SECRET

Your AWS sekkr1t passkey. Be forewarned that setting this environment variable
on a shared system might leak that information to another user. Be careful.

=back

=head1 AUTHOR

Leon Brocard <acme@astray.com> and unknown Amazon Digital Services programmers.

Brad Fitzpatrick <brad@danga.com> - return values, Bucket object

Pedro Figueiredo <me@pedrofigueiredo.org> - since 0.54

=head1 SEE ALSO

L<Net::Amazon::S3::Bucket>

