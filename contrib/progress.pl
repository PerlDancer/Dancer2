our ($v); # verbose
$v =1;

# deprecated:
# - layout
# - logger
# - mime_type
# - render_with_layout
# - set_cookie

my @expected = qw(
  after
  any
  before
  before_template
  cookie
  cookies
  config
  content_type
  dance
  debug
  del
  dirname
  error
  engine
  false
  forward
  from_dumper
  from_json
  from_yaml
  from_xml
  get
  halt
  header
  headers
  hook
  load
  load_app
  mime
  options
  param
  params
  pass
  patch
  path
  post
  prefix
  push_header
  put
  redirect
  request
  send_file
  send_error
  set
  setting
  session
  splat
  status
  start
  template
  to_dumper
  to_json
  to_yaml
  to_xml
  true
  upload
  captures
  uri_for
  var
  vars
  warning
);

use Dancer::Core::DSL;
my @done = Dancer::Core::DSL->dsl_keywords_as_list;

my $target = scalar(@expected);
my $done   = scalar(@done);

my @missing = grep { ! { map { $_ => 1 } @done }->{$_}  }  @expected;
my @additional = grep { ! { map { $_ => 1 } @expected }->{$_}  }  @done;

use feature 'say';

if ($v) {

    print "TODO and FIXME:\n", "-" x 40, "\n";
    my @lines = `ack -i '(fixme|todo)' | grep -v 'progress.pl'`;
    # I would use s///r but... :)
    print join("", map { s/:(\d+):\s*/:$1:\n   /; $_ } @lines);
    print "\n";

    print "Statistics:\n", "-" x 40, "\n";
    say "Dancer 2.0 DSL is missing: ", join (", ", @missing );
    say "Dancer 2.0 DSL has these new keywords: ", join (", ", @additional );

}

my $percent = sprintf('%02.2f', (100 - @missing * 100 / $target));
say "Dancer 2.0 is at $percent% ( " . ($target - @missing) . " symbols supported on $target)";

my $dancer1_lines=11999;
my $dancer2_lines=`wc -l \`find lib -name '*.pm'\` | grep 'total' | awk '{print \$1}'`;
chomp $dancer2_lines;

my $lines_percent = sprintf('%02.2f', ($dancer2_lines / $dancer1_lines * 100));
say "Dancer 2.0 code-lines ratio: $lines_percent% ($dancer2_lines/$dancer1_lines)";


