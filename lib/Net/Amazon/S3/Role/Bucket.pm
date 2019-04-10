package Net::Amazon::S3::Role::Bucket;
# ABSTRACT: Bucket role

use Moose::Role;
use Safe::Isa ();

around BUILDARGS => sub {
    my ($orig, $class, %params) = @_;

    $params{bucket} = $params{bucket}->name
        if $params{bucket}->$Safe::Isa::_isa ('Net::Amazon::S3::Client::Bucket');

    $params{bucket} = Net::Amazon::S3::Bucket->new(
        bucket => $params{bucket},
        account => $params{s3},
    ) if $params{bucket} and ! ref $params{bucket};

    $class->$orig( %params );
};

has bucket => (
    is => 'ro',
    isa => 'Net::Amazon::S3::Bucket',
    required => 1,
);

1;

