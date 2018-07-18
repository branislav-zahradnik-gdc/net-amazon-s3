
use strict;
use warnings;

use Test::More tests => 1 + 4;
use Test::Deep;
use Test::Warnings;

use Shared::Examples::Net::Amazon::S3::Response (
    qw[ it_should_parse_s3_errors ],
    qw[ it_should_parse_s3_response ],
    qw[ response_class ],
);

use Shared::Examples::Net::Amazon::S3::Operation::Service::Buckets::List (
    qw[ buckets_list_with_displayname ],
    qw[ buckets_list_without_displayname ],
);


response_class 'Net::Amazon::S3::Response::Service::Buckets::List';

it_should_parse_s3_errors "should recognize common errors" => (
    response_class => 'Net::Amazon::S3::Response::Service::Buckets::List',
);

it_should_parse_s3_response "should recognize response with displayname" => (
    response_class     => 'Net::Amazon::S3::Response::Service::Buckets::List',
    with_content       => buckets_list_with_displayname(),
    expect_is_success  => bool (1),
    expect_is_error    => bool (0),
    expect_is_redirect => bool (0),
    expect_data        => {
        owner_id            => 'bcaf1ffd86f461ca5fb16fd081034f',
        owner_displayname   => 'webfile',
        buckets             => [ {
            name            => 'quotes',
            creation_date   => '2006-02-03T16:45:09.000Z',
        }, {
            name            => 'samples',
            creation_date   => '2006-02-03T16:41:58.000Z',
        } ],
    },
);

it_should_parse_s3_response "should recognize response without displayname" => (
    response_class     => 'Net::Amazon::S3::Response::Service::Buckets::List',
    with_content       => buckets_list_without_displayname(),
    expect_is_success  => bool (1),
    expect_data        => {
        owner_id            => 'bcaf1ffd86f461ca5fb16fd081034f',
        owner_displayname   => '',
        buckets             => [ {
            name            => 'quotes',
            creation_date   => '2006-02-03T16:45:09.000Z',
        }, {
            name            => 'samples',
            creation_date   => '2006-02-03T16:41:58.000Z',
        } ],
    },
);

