
use strict;
use warnings;

package Shared::Examples::Net::Amazon::S3::Response;

use parent 'Exporter';

use Test::More;
use Test::Deep;

use Hash::Util;
use HTTP::Status;
use HTTP::Response;

our @EXPORT_OK = (
    qw[ it_should_parse_s3_errors ],
    qw[ it_should_parse_s3_response ],
    qw[ response_class ],
);

our $response_class;

sub response_class {
    ($response_class) = @_;

    use_ok $response_class;
}

sub it_should_parse_s3_response {
    my ($title, %params) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my @expectations = (
        qw[ expect_data ],
        qw[ expect_error_code ],
        qw[ expect_error_message ],
        qw[ expect_error_resource ],
        qw[ expect_error_request_id ],
        qw[ expect_is_error ],
        qw[ expect_is_redirect ],
        qw[ expect_is_success ],
    );

    Hash::Util::lock_keys %params, (
        qw[ response_class ],
        qw[ with_http_status ],
        qw[ with_content_type ],
        qw[ with_content ],
        @expectations,
    );

    $params{response_class}    ||= $response_class;
    $params{with_http_status}  ||= HTTP::Status::HTTP_OK;
    $params{with_content_type} ||= 'application/xml'
        if defined $params{with_content};

    my $http_response = HTTP::Response->new ($params{with_http_status});
    $http_response->content_type ($params{with_content_type})
        if exists $params{with_content_type};
    $http_response->content ($params{with_content})
        if defined $params{with_content};

    my $response = $params{response_class}->new (
        http_response => $http_response,
    );

    subtest $title => sub {
        plan tests => scalar grep exists $params{$_}, @expectations;

        cmp_deeply $response->is_error, $params{expect_is_error}, "response should report error status"
            if exists $params{expect_is_error};
        cmp_deeply $response->is_redirect, $params{expect_is_redirect}, "response should report success"
            if exists $params{expect_is_redirect};
        cmp_deeply $response->is_success, $params{expect_is_success}, "response should report redirect"
            if exists $params{expect_is_success};

        cmp_deeply $response->error_code, $params{expect_error_code}, "response should report error code"
            if exists $params{expect_error_code};
        cmp_deeply $response->error_message, $params{expect_error_message}, "response should report error message"
            if exists $params{expect_error_message};
        cmp_deeply $response->error_resource, $params{expect_error_resource}, "response should report resource that caused error"
            if exists $params{expect_error_resource};
        cmp_deeply $response->error_request_id, $params{expect_error_request_id}, "response should report request id that caused error"
            if exists $params{expect_error_request_id};

        cmp_deeply scalar $response->parse, $params{expect_data}, "response should provide response data"
            if exists $params{expect_data};
    };
}

sub it_should_parse_s3_errors {
    my ($title, %params) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    Hash::Util::lock_keys %params, (
        qw[ response_class ],
    );

    subtest $title => sub {
        plan tests => 1;
        it_should_parse_s3_response "no such key error" => (
            response_class          => $params{response_class},
            with_http_status        => HTTP::Status::HTTP_NOT_FOUND,
            with_content            => s3_content_error_no_such_key(),
            expect_is_error         => bool (1),
            expect_is_redirect      => bool (0),
            expect_is_success       => bool (0),
            expect_error_code       => 'NoSuchKey',
            expect_error_message    => 'The resource you requested does not exist',
            expect_error_resource   => '/mybucket/myfoto.jpg',
            expect_error_request_id => '4442587FB7D0A2F9',
            expect_data             => undef,
        );
    };
}

use constant s3_content_error_no_such_key => <<'XML';
<?xml version="1.0" encoding="UTF-8"?>
<Error>
  <Code>NoSuchKey</Code>
  <Message>The resource you requested does not exist</Message>
  <Resource>/mybucket/myfoto.jpg</Resource>
  <RequestId>4442587FB7D0A2F9</RequestId>
</Error>
XML

1;
