package Net::Amazon::S3::Operation::Object::Delete::Request;

use Moose 0.85;
use Moose::Util::TypeConstraints;
extends 'Net::Amazon::S3::Request::Object';

# ABSTRACT: An internal class to delete an object

with 'Net::Amazon::S3::Request::Role::HTTP::Method::DELETE';

__PACKAGE__->meta->make_immutable;

1;

__END__

=for test_synopsis
no strict 'vars'

=head1 SYNOPSIS

  my $http_request = Net::Amazon::S3::Operation::Object::Delete::Request->new(
    s3     => $s3,
    bucket => $bucket,
    key    => $key,
  )->http_request;

=head1 DESCRIPTION

This module deletes an object.

=head1 METHODS

=head2 http_request

This method returns a HTTP::Request object.

