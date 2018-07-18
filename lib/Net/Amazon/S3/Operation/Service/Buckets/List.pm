package Net::Amazon::S3::Operation::Service::Buckets::List;

use Moose 0.85;
use MooseX::StrictConstructor 0.16;

use Net::Amazon::S3::Request::ListAllMyBuckets;
use Net::Amazon::S3::Response::Service::Buckets::List;

extends 'Net::Amazon::S3::Operation::Service';

__PACKAGE__->meta->make_immutable;

use constant request_class  => 'Net::Amazon::S3::Request::ListAllMyBuckets';
use constant response_class => 'Net::Amazon::S3::Response::Service::Buckets::List';

1;
