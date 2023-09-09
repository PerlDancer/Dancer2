# Releasing Dancer2

This document is an overview of the process we go through when putting
together a new release of Dancer2. This is a guide, not a bible - we
don't follow this religiously - but it is better to do more of what's in
here than less.

## Ongoing

For all PRs and branches merged:
- Make sure all tests pass on the branch to be merged.
- Make sure Changes is updated. Include the GitHub issue or PR # in the
  changelog entry.
- Make sure the author is reflected in the Contributors section of
  Dancer2.pm
- `git merge --no-ff <branch-name> && git push`

## One week before release

Notify the Core Team that a release is going out. Do this via the
dancer-dev mailing list and Twist. If anyone has something to be merged,
now is the time to bring it up. If the release needs to be delayed in
order for someone to get a change into a release, this is the time to
pump the brakes.

## Day of Release

### Pull the latest code from main

Don't be That Person. Make sure everything you have is current.

### Ensure all changes are merged

Each release should have a milestone in GitHub. Make sure all issues and
PRs in the milestone are closed. If an issue or PR needs to move to a
later release, do that now.

### Update the version in `dist.ini`

We use [Semantic Versioning](https://semver.org/) for all Dancer2
releases.

### Do the release!

Run `dzil release --all`. This will:

- Run the test suite, including the author tests
- Build a tarball for upload to PAUSE
- Upload the new version to PAUSE
- Commit `Dancer2.pm` and the new `README` file to the repo (after
  which, you need to `git push`)

After this, you must `git push` to push the updated release files to
GitHub.

The test suite *must* pass before a release can be done. This is your
last chance to resolve any test failures.

Provided the tests pass, you will be prompted to continue the release
process. Provided you have your PAUSE credentials set up, this will
upload the new dist to PAUSE. If you don't have a credential file set
up, you can manually update the new release via the PAUSE web interface.

### Send out release announcements

Historically, release announcements have been sent out via the following
channels:

- dancer-users mailing list
- Twitter/X
- blogs.perl.org

Going forward, we intend to also send out announcements via:

- LinkedIn
- Perl Community group on Facebook
- dev.to
- Medium

Reshare from any accounts you have. Blog about it.

## After the Release

Watch for bug reports, praise, criticism, and respond appropriately.

