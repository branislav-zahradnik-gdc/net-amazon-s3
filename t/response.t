
use strict;
use warnings;

use Test::More tests => 2;
use Test::Warnings qw[ :no_end_test had_no_warnings ];

use Net::Amazon::S3::Response;

use HTTP::Response;

sub fixture_error_xml_content {
    # https://docs.aws.amazon.com/AmazonS3/latest/API/ErrorResponses.html
    <<'FIXTURE';
<?xml version="1.0" encoding="UTF-8"?>
<Error>
  <Code>NoSuchKey</Code>
  <Message>The resource you requested does not exist</Message>
  <Resource>/mybucket/myfoto.jpg</Resource>
  <RequestId>4442587FB7D0A2F9</RequestId>
</Error>
FIXTURE
}


subtest 'response 404 Not Found and XML error response' => sub {
    my $http_response = HTTP::Response->new (404, 'Not Found');
    $http_response->content (fixture_error_xml_content);
    $http_response->content_length (length fixture_error_xml_content);
    $http_response->content_type ('application/xml');

    my $response = Net::Amazon::S3::Response->new (
        http_response => $http_response,
    );

    ok $response->is_error, 'should report an error';
    ok ! $response->is_success, 'should not report success';
    ok ! $response->is_redirect, 'should not report redirect';
    ok $response->is_xml_content, 'should recognize xml content';
    is $response->error_code, 'NoSuchKey', 'should parse error code';
    is $response->error_message, 'The resource you requested does not exist', 'should parse error message';
    is $response->error_resource, '/mybucket/myfoto.jpg', 'should parse error resource';
    is $response->error_request_id, '4442587FB7D0A2F9', 'should parse request id';
};

had_no_warnings;
