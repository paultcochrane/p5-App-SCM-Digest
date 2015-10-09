#!perl

use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 10;

use App::SCM::Digest::SCM::Hg;
use File::Temp qw(tempdir);

sub _system
{
    my ($cmd) = @_;

    my $res = system("$cmd >/dev/null 2>&1");
    if ($res != 0) {
        die "Command ($cmd) failed: $res";
    }
}

sub _system_np
{
    my ($cmd) = @_;

    my $res = system("$cmd 2>&1");
    if ($res != 0) {
        die "Command ($cmd) failed: $res";
    }
}

SKIP: {
    my $hg = eval { App::SCM::Digest::SCM::Hg->new(); };
    if ($@) {
        skip 'Mercurial not available', 9;
    }

    my $repo_dir = tempdir(CLEANUP => 1);
    chdir $repo_dir;
    _system("hg init .");

    $hg->open_repository($repo_dir);
    my @branches = @{$hg->branches()};
    is_deeply(\@branches, [],
              'No branches found in repository');

    _system("hg branch new-branch");
    _system_np("echo 'asdf' > out");
    _system("hg add out");
    _system("hg commit -m 'out'");

    my $repo_holder = tempdir(CLEANUP => 1);
    chdir $repo_holder;
    my $hg2 = App::SCM::Digest::SCM::Hg->new();
    $hg2->clone("file://".$repo_dir, "repo");
    $hg2->open_repository("repo");

    @branches = @{$hg2->branches()};
    my @branch_names = map { $_->[0] } @branches;
    is_deeply(\@branch_names, [qw(new-branch)],
              'New branch found in repository');

    is($hg2->branch_name(), 'new-branch',
        'Current branch name is correct');

    _system("hg branch new-branch2");
    _system_np("echo 'asdf2' > out2");
    _system("hg add out2");
    _system("hg commit -m 'out2'");

    is($hg2->branch_name(), 'new-branch2',
        'Current branch name is correct (switched)');

    $hg2->checkout('new-branch');

    is($hg2->branch_name(), 'new-branch',
        'Current branch name is correct (switched back)');

    @branches = sort { $a->[0] cmp $b->[0] } @{$hg2->branches()};
    is_deeply($hg2->commits_from($branches[0]->[0], $branches[0]->[1]),
              [],
              'No commits found since most recent commit');

    _system_np("echo 'asdf3' > out3");
    _system("hg add out3");
    _system("hg commit -m 'out3'");

    my @commits = @{$hg2->commits_from($branches[0]->[0], $branches[0]->[1])};
    is(@commits, 1, 'Found one commit since original commit');
    @branches = sort { $a->[0] cmp $b->[0] } @{$hg2->branches()};
    is($commits[0], $branches[0]->[1],
        'The found commit has the correct ID');

    my $info = join '', @{$hg2->show($commits[0])};
    like($info, qr/out3/,
        'Log information contains log message');

    $info = join '', @{$hg2->show_all($commits[0])};
    like($info, qr/\+.*asdf3/,
        'Diff contains changed text');

    chdir("/tmp");
}

1;