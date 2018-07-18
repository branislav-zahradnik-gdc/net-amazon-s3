package Net::Amazon::S3::Response::Service::Buckets::List;

use Moose;

extends 'Net::Amazon::S3::Response';

sub _parse_data {
    my ($self) = @_;

    my $xpc = $self->xpath_content;

    my $data = {
        owner_id          => $xpc->findvalue ("//s3:Owner/s3:ID"),
        owner_displayname => $xpc->findvalue ("//s3:Owner/s3:DisplayName"),
        buckets           => [],
    };

    foreach my $node ($xpc->findnodes("//s3:Buckets/s3:Bucket")) {
        push @{ $data->{buckets} }, {
            name          => $xpc->findvalue ("./s3:Name", $node),
            creation_date => $xpc->findvalue ("./s3:CreationDate", $node),
        };
    }

    return $data;
}

1;


