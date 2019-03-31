package Net::Amazon::S3::Operation::Service::List::Response;

use Moose;

extends 'Net::Amazon::S3::Response';

sub owner_id {
    $_[0]->data->{owner_id};
}

sub owner_displayname {
    $_[0]->data->{owner_displayname};
}

sub buckets {
    @{ $_[0]->data->{buckets} };
}

sub _parse_data {
    my ($self) = @_;

    my $xpc = $self->xpath_context;

    my $data = {
        owner_id          => $xpc->findvalue ("/s3:ListAllMyBucketsResult/s3:Owner/s3:ID"),
        owner_displayname => $xpc->findvalue ("/s3:ListAllMyBucketsResult/s3:Owner/s3:DisplayName"),
        buckets           => [],
    };

    foreach my $node ($xpc->findnodes("/s3:ListAllMyBucketsResult/s3:Buckets/s3:Bucket")) {
        push @{ $data->{buckets} }, {
            name          => $xpc->findvalue ("./s3:Name", $node),
            creation_date => $xpc->findvalue ("./s3:CreationDate", $node),
        };
    }

    return $data;
}

1;


