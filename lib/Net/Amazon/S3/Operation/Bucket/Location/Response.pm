package Net::Amazon::S3::Operation::Bucket::Location::Response;

use Moose;

extends 'Net::Amazon::S3::Response';

sub location {
    $_[0]->data->{location};
}

sub _parse_data {
    my ($self) = @_;

    my $xpc = $self->xpath_context;

    my $data = {
        location => scalar $xpc->findvalue ("//s3:LocationConstraint"),
    };

    # S3 documentation: https://docs.aws.amazon.com/AmazonS3/latest/API/RESTBucketGETlocation.html
    # When the bucket's region is US East (N. Virginia),
    # Amazon S3 returns an empty string for the bucket's region
    $data->{location} = 'us-east-1'
        if defined $data->{location} && $data->{location} eq '';

    return $data;
}

1;
