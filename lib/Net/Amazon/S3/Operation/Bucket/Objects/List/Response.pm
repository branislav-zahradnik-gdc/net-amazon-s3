package Net::Amazon::S3::Operation::Bucket::Objects::List::Response;

use Moose;

extends 'Net::Amazon::S3::Response';

sub bucket {
    $_[0]->data->{bucket};
}

sub prefix {
    $_[0]->data->{prefix};
}

sub marker {
    $_[0]->data->{marker};
}

sub next_marker {
    $_[0]->data->{next_marker};
}

sub max_keys {
    $_[0]->data->{max_keys};
}

sub is_truncated {
    $_[0]->data->{is_truncated};
}

sub contents {
    @{ $_[0]->data->{contents} };
}

sub common_prefixes {
    @{ $_[0]->data->{common_prefixes} };
}

sub _parse_data {
    my ($self) = @_;

    my $xpc = $self->xpath_context;

    my $data = {
        bucket       => scalar $xpc->findvalue ("/s3:ListBucketResult/s3:Name"),
        prefix       => scalar $xpc->findvalue ("/s3:ListBucketResult/s3:Prefix"),
        marker       => scalar $xpc->findvalue ("/s3:ListBucketResult/s3:Marker"),
        next_marker  => scalar $xpc->findvalue ("/s3:ListBucketResult/s3:NextMarker"),
        max_keys     => scalar $xpc->findvalue ("/s3:ListBucketResult/s3:MaxKeys"),
        is_truncated => scalar $xpc->findvalue ("/s3:ListBucketResult/s3:IsTruncated") eq 'true',
        contents     => [],
        common_prefixes => [],
    };

    for my $content ($xpc->findnodes ("/s3:ListBucketResult/s3:Contents")) {
        push @{ $data->{contents} }, {
            key             => scalar $xpc->findvalue ("./s3:Key",          $content),
            last_modified   => scalar $xpc->findvalue ("./s3:LastModified", $content),
            etag            => scalar $xpc->findvalue ("./s3:ETag",         $content),
            size            => scalar $xpc->findvalue ("./s3:Size",         $content),
            storage_class   => scalar $xpc->findvalue ("./s3:StorageClass", $content),
            owner => {
                id          => $xpc->findvalue ("./s3:Owner/s3:ID",           $content),
                displayname => $xpc->findvalue ("./s3:Owner/s3:DisplayName",  $content),
            },
        };
        $data->{contents}[-1]{etag} =~ s/^"|"$//g;
    }

    for my $delimiter ($xpc->findnodes ("/s3:ListBucketResult/s3:Delimiter")) {
        $data->{delimiter} = $xpc->findvalue ('.', $delimiter);
    }

    if (defined $data->{delimiter}) {
        my $strip_delim = length $data->{delimiter};

        for my $common_prefix ($xpc->findnodes ("/s3:ListBucketResult/s3:CommonPrefixes")) {
            my $prefix = $xpc->findvalue ('./s3:Prefix', $common_prefix);
            $prefix = substr $prefix, 0, -$strip_delim;
            push @{ $data->{common_prefixes} }, $prefix;
        }
    }

    return $data;
}

1;
