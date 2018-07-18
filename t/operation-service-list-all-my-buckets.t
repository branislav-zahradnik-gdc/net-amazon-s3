
use strict;
use warnings;

use Test::More tests => 1 + 7;
use Test::Deep;
use Test::Warnings;

use Net::Amazon::S3::Error::Handler::Status;

require_ok 'Net::Amazon::S3::Operation::Service::Buckets::List';

my $s3 = bless {}, 'Net::Amazon::S3';

my $operation = new_ok 'Net::Amazon::S3::Operation::Service::Buckets::List', [
    s3 => $s3,
    error_handler => Net::Amazon::S3::Error::Handler::Status->new (s3 => $s3),
];

cmp_deeply
    $operation,
    obj_isa ('Net::Amazon::S3::Operation'),
    "operation inherits from base class"
    ;

cmp_deeply
    $operation,
    methods (request_class  => 'Net::Amazon::S3::Request::ListAllMyBuckets'),
    "operation request class"
    ;

cmp_deeply
    $operation,
    methods (response_class => 'Net::Amazon::S3::Response::Service::Buckets::List'),
    "operation response class"
    ;

require_ok $operation->request_class;
require_ok $operation->response_class;
