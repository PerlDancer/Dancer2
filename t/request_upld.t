use strict;
use warnings FATAL => 'all';
use Test::More tests => 19;
use Test::Fatal;

use Dancer::Core::Request;

use File::Temp 0.22;
use File::Basename qw/dirname basename/;
use File::Spec;

sub test_path {
    my ($file, $dir) = @_;
    is dirname($file), $dir, "dir of $file is $dir";
}

my $filename = "some_\x{1A9}_file.txt";

my $content = qq{------BOUNDARY
Content-Disposition: form-data; name="test_upload_file"; filename="$filename"
Content-Type: text/plain

SHOGUN
------BOUNDARY
Content-Disposition: form-data; name="test_upload_file"; filename="yappo2.txt"
Content-Type: text/plain

SHOGUN2
------BOUNDARY
Content-Disposition: form-data; name="test_upload_file3"; filename="yappo3.txt"
Content-Type: text/plain

SHOGUN3
------BOUNDARY
Content-Disposition: form-data; name="test_upload_file4"; filename="yappo4.txt"
Content-Type: text/plain

SHOGUN4
------BOUNDARY
Content-Disposition: form-data; name="test_upload_file4"; filename="yappo5.txt"
Content-Type: text/plain

SHOGUN4
------BOUNDARY
Content-Disposition: form-data; name="test_upload_file6"; filename="yappo6.txt"
Content-Type: text/plain

SHOGUN6
------BOUNDARY--
};
$content =~ s/\r\n/\n/g;
$content =~ s/\n/\r\n/g;


do {
    open my $in, '<', \$content;
    my $req = Dancer::Core::Request->new(
       env => {
               'psgi.input'   => $in,
               CONTENT_LENGTH => length($content),
               CONTENT_TYPE   => 'multipart/form-data; boundary=----BOUNDARY',
               REQUEST_METHOD => 'POST',
               SCRIPT_NAME    => '/',
               SERVER_PORT    => 80,
              }
    );

    my @undef = $req->upload('undef');
    is @undef, 0, 'non-existent upload as array is empty';
    my $undef = $req->upload('undef');
    is $undef, undef, '... and non-existent upload as scalar is undef';

    my @uploads = $req->upload('test_upload_file');
    like $uploads[0]->content, qr|^SHOGUN|,
      "content for first upload is ok, via 'upload'";
    like $uploads[1]->content, qr|^SHOGUN|, "... content for second as well";
    is $req->uploads->{'test_upload_file4'}[0]->content, 'SHOGUN4',
      "... content for other also good";

    note "headers";
    is_deeply $uploads[0]->headers, {
        'Content-Disposition' => qq[form-data; name="test_upload_file"; filename="$filename"],
        'Content-Type'        => 'text/plain',
    };

    note "type";
    is $uploads[0]->type, 'text/plain';

    my $test_upload_file3 = $req->upload('test_upload_file3');
    is $test_upload_file3->content, 'SHOGUN3',
      "content for upload #3 as a scalar is good, via req->upload";

    my @test_upload_file6 = $req->upload('test_upload_file6');
    is $test_upload_file6[0]->content, 'SHOGUN6',
      "content for upload #6 is good";

    is $test_upload_file6[0]->content(':raw'), 'SHOGUN6';

    my $upload = $req->upload('test_upload_file6');
    isa_ok $upload, 'Dancer::Core::Request::Upload';
    is $upload->filename, 'yappo6.txt', 'filename is ok';
    ok $upload->file_handle, 'file handle is defined';
    is $req->params->{'test_upload_file6'}, 'yappo6.txt',
      "filename is accessible via params";

    # copy_to, link_to
    my $dest_dir = File::Temp::tempdir(CLEANUP => 1, TMPDIR => 1);
    my $dest_file = File::Spec->catfile( $dest_dir, $upload->basename );
    $upload->copy_to($dest_file);
    ok( ( -f $dest_file ), "file '$dest_file' has been copied" );

    my $dest_file_link = File::Spec->catfile( $dest_dir, "hardlink" );
    $upload->link_to( $dest_file_link );
    ok( ( -f $dest_file_link ), "hardlink '$dest_file_link' has been created" );

    # make sure cleanup is performed when the HTTP::Body object is purged
    my $file = $upload->tempname;
    ok( ( -f $file ), 'temp file exists while HTTP::Body lives' );
    undef $req->{_http_body};
    SKIP: {
        skip "Win32 can't remove file/link while open, deadlock with HTTP::Body", 1 if ($^O eq 'MSWin32');
        ok( ( !-f $file ), 'temp file is removed when HTTP::Body object dies' );
    }


    note "testing failing open for tempfile";

    # mocking open_file to make it fail
    {
        no strict 'refs'; no warnings 'redefine';
        *{"Dancer::FileUtils::open_file"} = sub { 0 };
    }
    $upload->{_fh} = undef;
    like(
        exception { $upload->file_handle },
        qr{Can't open.* using mode '<'},
    );

    unlink($file) if ($^O eq 'MSWin32');
};
