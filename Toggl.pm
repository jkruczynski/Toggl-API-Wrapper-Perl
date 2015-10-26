#!/usr/bin/perl 
package Toggl;
use strict;
use warnings;
use LWP::UserAgent;
use JSON::Parse ':all';
use JSON;
use Data::Dumper;
#Instance Variables
my $uaV2;
my $uaV8;
my $wsid;

#Private Functions
my $authV2 = sub {
	shift;
	my $user=shift;
	my $url = 'https://toggl.com/reports/api/v2/login';
	my $passwd = 'api_token';
	$uaV2 = LWP::UserAgent->new( agent=>"Billing Script",cookie_jar=>{} );
	my $req = HTTP::Request->new(POST => "$url" );
	$req->authorization_basic($user,$passwd);
	my $response = $uaV2->request($req);
	if ($response->is_success) {
		$response =$response->decoded_content;
	}
	else {
		die $response->status_line;
	}
};

my $authV8 = sub {
	shift;
	my $user=shift;
	my $url = 'https://www.toggl.com/api/v8/sessions';
	my $passwd = 'api_token';
	$uaV8 = LWP::UserAgent->new( agent=>"Billing Script",cookie_jar=>{} );
	my $req = HTTP::Request->new(POST => "$url" );
	$req->authorization_basic($user,$passwd);
	my $response = $uaV8->request($req);
	if ($response->is_success) {
		$response =$response->decoded_content;
		my $json=parse_json($response);
		$wsid = $json->{data}->{default_wid};
	}
	else {
		die $response->status_line;
	}
};

#$URL, $params, API Version
my $mk_get_request = sub {
	my ($self, $url, $params) = @_;
	my $ua;
	if($url=~/v8/){
		$ua = $uaV8;
	}elsif ($url =~/v2/){
		$ua = $uaV2;
	}
	my $request = HTTP::Request->new( GET=>"$url$params");
	my $response = $ua->request($request);
	if ($response->is_success) {
		$response =$response->decoded_content;  # or whatever
		my $json=parse_json($response);
		return $json;
	}
	else {
		die $response->status_line;
	}
};

#$URL, $JSON
my $mk_post_request = sub{
	my ($self, $url, $json) = @_;
	my $ua;
	if($url=~/v8/){
		$ua = $uaV8;
	}elsif ($url =~/v2/){
		$ua = $uaV2;
	}
	my $request = HTTP::Request->new( POST=>"$url");
	$request->header( 'Content-Type' => 'application/json' );
	$request->content( $json );
	my $response = $ua->request($request);
	if ($response->is_success) {
		$response =$response->decoded_content;  # or whatever
		my $json=parse_json($response);
		return $json;
	}
	else {
		print $response->decoded_content;
		die $response->status_line;
	}
};
#$URL, $JSON
my $mk_put_request = sub{
	my ($self, $url, $json) = @_;
	my $ua;
	if($url=~/v8/){
		$ua = $uaV8;
	}elsif ($url =~/v2/){
		$ua = $uaV2;
	}
	my $request = HTTP::Request->new( PUT=>"$url");
	$request->header( 'Content-Type' => 'application/json' );
	$request->content( $json );
	my $response = $ua->request($request);
	if ($response->is_success) {
		$response =$response->decoded_content;  # or whatever
		my $json=parse_json($response);
		return $json;
	}
	else {
		die $response->status_line;
	}
};


#Public Functions
sub new{
	my $self = shift;
	my $user=shift;
	my $result = $self->$authV8($user);
	$result = $self->$authV2($user);
	bless {$self, "Toggl"};
}
#Get Time Entries
#@param ( start, end)
sub get_time_entries{
	my ($self, $start, $end) = @_;
	my @data;
	my $count;
	my $page = 1; 
	my $url = "https://toggl.com/reports/api/v2/details?";
	my $params= "workspace_id=$wsid&since=$start&until=$end&user_agent=api_test&rounding=on";
	my $json=$self->$mk_get_request($url, $params);
	$count = $json->{total_count};
	push (@data,@{$json->{data}});
	$count-=50;
	$page ++;
	while($count>0){
		$json=$self->$mk_get_request($url, $params."&page=$page");
		push (@data,@{$json->{data}});
		$count-=50;
		$page ++;
	}
	return @data;
}
sub get_workspace_projects{
	my ($self, $name) = @_;
	my $url="https://www.toggl.com/api/v8/workspaces/$wsid/projects?";
	my $params="user_agent=api_test&name=$name";
	my $json=$self->$mk_get_request($url, $params);
	return @{$json}
}
sub create_project{
	my ($self, $pid, $cid, $name, $estHours) = @_;
	my $url="https://www.toggl.com/api/v8/projects";
	my $params="";
	my %data=(
	'project'=>{
		'name'=>$name,
		'wid'=>$wsid,
		'template_id'=>$pid,
		'is_private'=>JSON::false,
		'cid'=>$cid,
		'estimated_hours'=>$estHours
		}
	);
	my $json = encode_json(\%data);
	$self->$mk_post_request($url, $json);
}
sub archive_project{
#	`curl -v -u $apiKey:api_token -H "Content-type: application/json" -d '{"project":{"active":false,"name":"$year $project->{name}"}}' -X PUT https://www.toggl.com/api/v8/projects/$project->{id} 2>junk.txt`;
my ($self, $pid, $name) = @_;
my $url="https://www.toggl.com/api/v8/projects/$pid";
	my %data=(
	'project'=>{
		'active'=> JSON::false,
		'name' => $name,
		}
	);
	my $json = encode_json(\%data);
	$self->$mk_put_request($url, $json);

}
sub create_a_task{
	my ($self, $pid, $hours, $name) = @_;
	my $url= "https://www.toggl.com/api/v8/tasks";
	#'{"task":{"name":"A new task","pid":777}}'
	my %data = (
		'task' => {
			'name'=> $name,
			'pid' => $pid,
			'tracked_seconds' => $hours*60*60,
			'active' =>'true'
		}
	);
	my $json = encode_json(\%data);
	$self->$mk_post_request($url, $json);
}
sub create_a_time_entry{
	my ($self, $pid, $hours, $desc, $start) = @_;
	my $url= "https://www.toggl.com/api/v8/time_entries";
	$hours=$hours*60*60;
	my $json ="{\"time_entry\":{\"wid\":\"$wsid\",\"billable\":true,\"pid\":$pid,\"duration\":$hours,\"description\":\"June Hours Overage\",\"created_with\":\"Billing Script\",\"start\":\"$start-04:00\"}}";
	$self->$mk_post_request($url, $json);
}
sub get_clients{
	my $self = shift;
	my $url = "https://www.toggl.com/api/v8/clients"; 
	my $json = $self->$mk_get_request($url,"");
	return @{$json}
}
sub get_billable{
	my ($self, $pid, $start, $end) = @_;
	my $url = "https://toggl.com/reports/api/v2/summary.json?";
	my $params ="grouping=projects&subgrouping=time_entries&order_field=title&order_desc=off&rounding=on&distinct_rates=Off&free=false&status=active&name=&billable=yes&calculate=time&sortDirection=asc&sortBy=title&page=1&project_ids=$pid&description=&since=$start&until=$end&period=prevMonth&with_total_currencies=1&user_agent=Toggl+New+3.50.2&workspace_id=$wsid&bars_count=31&subgrouping_ids=true&bookmark_token=";
	my $json=$self->$mk_get_request($url,$params);
	return $json;
}
1;