package Net::Amazon::S3::Operation::Bucket::Delete::Request;

use Moose 0.85;
extends 'Net::Amazon::S3::Request::Bucket';

# ABSTRACT: An internal class to delete a bucket

with 'Net::Amazon::S3::Request::Role::HTTP::Method::DELETE';

__PACKAGE__->meta->make_immutable;

1;

__END__

=for test_synopsis
no strict 'vars'

=head1 SYNOPSIS

  my $http_request = Net::Amazon::S3::Operation::Bucket::Delete::Request->new(
    s3     => $s3,
    bucket => $bucket,
  )->http_request;

=head1 DESCRIPTION

This module deletes a bucket.

=head1 METHODS

=head2 http_request

This method returns a HTTP::Request object.

