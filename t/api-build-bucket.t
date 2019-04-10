
use strict;
use warnings;

use Test::More tests => 4;
use Test::Deep;
use Test::Warnings qw[ :no_end_test had_no_warnings ];
use Scalar::Util;

sub build_bucket;
sub test_method_bucket;

SKIP:
{
    require_ok ('Net::Amazon::S3') or skip "Cannot load module", 2;

    test_method_bucket
        "bucket (STRING) should return respective bucket object",
        build_bucket ('foo'),
        obj_isa ('Net::Amazon::S3::Bucket'),
        methods (bucket => 'foo'),
        ;

    my $bar = build_bucket ('bar');
    test_method_bucket
        "bucket (Instance) should return its argument",
        scalar build_bucket ($bar),
        obj_isa ('Net::Amazon::S3::Bucket'),
        methods (bucket => 'bar'),
        code (sub {
            return 1 if Scalar::Util::refaddr ($_[0]) == Scalar::Util::refaddr ($bar);
            return 0, "Object is has different address"
        }),
        ;
}

had_no_warnings;
done_testing;

sub build_bucket {
    my $s3 = bless {}, 'Net::Amazon::S3';

    $s3->bucket (@_);
}

sub test_method_bucket {
    my ($title, $bucket, @plan) = @_;

    cmp_deeply $bucket, all (@plan), $title;
}

