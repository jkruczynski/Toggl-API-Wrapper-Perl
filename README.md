# Toggl-API-Wrapper-Perl
- Authenticates a session with the Toggl API
- Implements some basic functions for exporting entries, creating entries
- Example usage:
- my $toggl=Toggl->new($api_token);
- my @data = $toggl->get_time_entries($start, $end);
