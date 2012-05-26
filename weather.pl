#!/usr/bin/perl
use strict;
use utf8;
use Mojo::UserAgent;
use Mojo::Template;

my $url = 'http://pogoda.mail.ru';
my ($is_error, $now, $today, $future) = (0);

my $ua = Mojo::UserAgent->new;
my $res = $ua->get($url.'/prognoz/moskva/');

if ($res->success) {
	my $weather = $res->res;

	my @months = ('января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря');
	my @weekdays = ('воскресенье', 'понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье');
	my @time = localtime(time);

	$now->{'time'} = sprintf("%02d:%02d", $time[2], $time[1]);
	$now->{'date'} = $time[3];
	$now->{'month'} = $months[$time[4]];
	$now->{'weekday'} = $weekdays[$time[6]];

	my $forecast_now = $weather->dom->at('.forecast__now');
	if ($forecast_now) {
		my $temp = $forecast_now->at('.data__temp');
		if ($temp) {
			$temp = $temp->text;
			if ($temp =~ m{^([-+]?)(\d+)$}o) {
				$now->{'sign'} = $1;
				$now->{'temp'} = $2;
			} else {
				$now->{'temp'} = $temp;
			}
		}

		my $img = $forecast_now->at('.data__temp__img');
		$now->{'img'} = $url.$img->{'src'} if $img;

		my $desc = $forecast_now->at('.data__descr .air');
		if ($desc) {
			$desc = $desc->text;
			$desc =~ s{^\s+|\s+$}{}g;
			if ($desc =~ m{^(\d+)(.+?),\s+(\d+)(.+?),\s+(\d+)(.+?)$}o) {
				$now->{'info'} = 1;
				($now->{'info1_val'}, $now->{'info1_txt'}) = ($1, $2);
				($now->{'info2_val'}, $now->{'info2_txt'}) = ($3, $4);
				($now->{'info3_val'}, $now->{'info3_txt'}) = ($5, $6);
			}
		}

		my $info = $forecast_now->at('.data__descr .sky');
		$now->{'text'} = $info->text if $info;
	}

	my $forecast_today = $weather->dom->at('.forecast__today');
	if ($forecast_today) {
		foreach my $i (1 .. 3) {
			my $soon = $forecast_today->at('.forecast-time:nth-child('.$i.')');
			if ($soon) {
				my $name = $soon->at('.forecast__title');
				$today->{'day_'.$i.'_name'} = $name->text if $name;

				my $time = $soon->at('.forecast__time');
				if ($time) {
					if ($time->text =~ m{(\d\d:\d\d)$}o) {
						$today->{'day_'.$i.'_time'} = $1;
					} else {
						$today->{'day_'.$i.'_time'} = $time->text;
					}
				}

				my $temp = $soon->at('.data__temp');
				if ($temp) {
					$temp = $temp->text;
					if ($temp =~ m{^([-+]?)(\d+)$}o) {
						$today->{'day_'.$i.'_sign'} = $1;
						$today->{'day_'.$i.'_temp'} = $2;
					} else {
						$today->{'day_'.$i.'_temp'} = $temp;
					}
				}

				my $img = $soon->at('.data__temp__img');
				$today->{'day_'.$i.'_img'} = $url.$img->{'src'} if $img;
			}
		}
	}

	my $forecast = $weather->dom->at('.forecast-ext');
	if ($forecast) {
		foreach my $i (1 .. 3) {
			my $soon = $forecast->at('.forecast__week__day:nth-child('.$i.')');
			if ($soon) {
				my $name = $soon->at('.fwd__daymonth');
				$future->{'day_'.$i.'_name'} = $name->text if $name;

				my $time = $soon->at('.fwd__day');
				$future->{'day_'.$i.'_time'} = $time->text if $time;

				my $temp = $soon->at('.temp');
				if ($temp) {
					$temp = $temp->text;
					if ($temp =~ m{^([-+]?)(\d+)°\.\.([-+]?)(\d+)°$}o) {
						my $min = $1 eq '-' ? -$2 : $2;
						my $max = $3 eq '-' ? -$4 : $4;
						my $value = int(($min + $max) / 2 + 0.5);
						$future->{'day_'.$i.'_sign'} = $value == 0 ? '' : $value < 0 ? '-' : '+';
						$future->{'day_'.$i.'_temp'} = abs($value);
					} elsif ($temp =~ m{^([-+]?)(\d+)}o) {
						$future->{'day_'.$i.'_sign'} = $1;
						$future->{'day_'.$i.'_temp'} = $2;
					} else {
						$future->{'day_'.$i.'_temp'} = $temp;
					}
				}

				my $img = $soon->at('.fwd__data img');
				$future->{'day_'.$i.'_img'} = $url.$img->{'src'} if $img;

				$future->{'day_'.$i.'_weekend'} = 1 if $soon->at('.fwd__date_weekend');
			}
		}
	}
} else {
	$is_error = 1;
}

my $tmpl = Mojo::Template->new;
my $html = $tmpl->render(join('', <DATA>), $is_error, $now, $today, $future);

binmode STDOUT, ":utf8";
print $html;

__DATA__
% my ($is_error, $now, $today, $future) = @_;
<!DOCTYPE html>
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<meta http-equiv="refresh" content="60">
	<title>Погода</title>
	<style>
html, body, div, span, img, strong, table, tbody, tr, th, td {margin:0;padding:0;border:0;font-size:100%;font:inherit;vertical-align:baseline}
strong {color:#fff;font-weight:bold}
table {border-collapse:collapse;border-spacing:0;width:100%}
body {background-color:#000;color:#fff;line-height:1;width:800px}
td {text-align:center;vertical-align:middle}
hr {height:0;line-height:0;font-size:0;border:0;border-top:2px solid #444;margin:25px 0}
.icon {background-repeat:no-repeat;background-position:center center;background-size:90%}
.now {margin-top:20px}
.now td {padding:0 10px}
.datetime {padding:0 10px}
.time {font-size:64px;margin-top:10px}
.date {color:#ddd;font-size:36px;margin-top:5px}
.weekday {color:#aaa;font-size:28px;margin:5px 0 10px}
.now__temp {font-size:112px}
.now__icon {width:170px}
.now__info {color:#ccc;font-size:30px;margin:10px 0}
.now__text {color:#eee;font-size:40px;margin:20px 0;text-align:center;text-transform:lowercase}
.soon {color:#aaa;margin-top:10px}
.div {width:50px}
.soon__time {font-size:24px;padding-top:4px;padding-bottom:10px;width:80px}
.soon__time_weekend {color:#f66}
.soon__date {color:#eee;font-size:32px;padding-bottom:10px;text-align:left}
.soon__date_weekend {color:#f99}
.soon__icon {height:60px}
.soon__temp {color:#ccc;font-size:56px;padding:0 10px;text-align:left}
.error {color:#fff;height:600px;font-size:48px;line-height:600px;text-align:center}
	</style>
</head>
<body>
	<% if ($is_error) { %>
	<div class="error">Ошибка получения данных</div>
	<% } else { %>
	<table class="now">
		<tbody>
			<tr>
				<td class="datetime">
					<div class="time"><strong><%= $now->{'time'} %></strong></div>
					<div class="date"><strong><%= $now->{'date'} %></strong>&nbsp;<%= $now->{'month'} %></div>
					<div class="weekday"><%= $now->{'weekday'} %></div>
				</td>
				<td class="now__temp"><% if ($now->{'temp'}) { %><%= $now->{'sign'} %><strong><%= $now->{'temp'} %></strong><sup>&deg;</sup><% } else { %>???<% } %></td>
				<td class="icon now__icon"<% if ($now->{'img'}) { %> style="background-image:url(<%= $now->{'img'} %>);"<% } %>></td>
				<td><% if ($now->{'info'}) { %>
					<div class="now__info"><strong><%= $now->{'info1_val'} %></strong><%= $now->{'info1_txt'} %></div>
					<div class="now__info"><strong><%= $now->{'info2_val'} %></strong><%= $now->{'info2_txt'} %></div>
					<div class="now__info"><strong><%= $now->{'info3_val'} %></strong><%= $now->{'info3_txt'} %></div>
				<% } %></td>
			</tr>
		</tbody>
	</table>
	<div class="now__text"><%= $now->{'text'} %></div>
	<hr>
	<table class="soon">
		<tbody>
			<tr>
				<td class="div" rowspan="2"></td>
				<td class="soon__time"><%= $today->{'day_1_time'} %></td>
				<td class="soon__date"><%= $today->{'day_1_name'} %></td>
				<td class="div" rowspan="2"></td>
				<td class="soon__time"><%= $today->{'day_2_time'} %></td>
				<td class="soon__date"><%= $today->{'day_2_name'} %></td>
				<td class="div" rowspan="2"></td>
				<td class="soon__time"><%= $today->{'day_3_time'} %></td>
				<td class="soon__date"><%= $today->{'day_3_name'} %></td>
				<td class="div" rowspan="2"></td>
			</tr>
			<tr>
				<td class="icon soon__icon"<% if ($today->{'day_1_img'}) { %>style="background-image:url(<%= $today->{'day_1_img'} %>);"<% } %>></td>
				<td class="soon__temp"><% if ($today->{'day_1_temp'}) { %><%= $today->{'day_1_sign'} %><strong><%= $today->{'day_1_temp'} %></strong><sup>&deg;</sup><% } else { %>???<% } %></td>
				<td class="icon soon__icon"<% if ($today->{'day_2_img'}) { %>style="background-image:url(<%= $today->{'day_2_img'} %>);"<% } %>></td>
				<td class="soon__temp"><% if ($today->{'day_2_temp'}) { %><%= $today->{'day_2_sign'} %><strong><%= $today->{'day_2_temp'} %></strong><sup>&deg;</sup><% } else { %>???<% } %></td>
				<td class="icon soon__icon"<% if ($today->{'day_3_img'}) { %>style="background-image:url(<%= $today->{'day_3_img'} %>);"<% } %>></td>
				<td class="soon__temp"><% if ($today->{'day_3_temp'}) { %><%= $today->{'day_3_sign'} %><strong><%= $today->{'day_3_temp'} %></strong><sup>&deg;</sup><% } else { %>???<% } %></td>
			</tr>
		</tbody>
	</table>
	<hr>
	<table class="soon">
		<tbody>
			<tr>
				<td class="div" rowspan="2"></td>
				<td class="soon__time<% if ($future->{'day_1_weekend'}) { %> soon__time_weekend<% } %>"><%= $future->{'day_1_time'} %></td>
				<td class="soon__date<% if ($future->{'day_1_weekend'}) { %> soon__date_weekend<% } %>"><%= $future->{'day_1_name'} %></td>
				<td class="div" rowspan="2"></td>
				<td class="soon__time<% if ($future->{'day_2_weekend'}) { %> soon__time_weekend<% } %>"><%= $future->{'day_2_time'} %></td>
				<td class="soon__date<% if ($future->{'day_2_weekend'}) { %> soon__date_weekend<% } %>"><%= $future->{'day_2_name'} %></td>
				<td class="div" rowspan="2"></td>
				<td class="soon__time<% if ($future->{'day_3_weekend'}) { %> soon__time_weekend<% } %>"><%= $future->{'day_3_time'} %></td>
				<td class="soon__date<% if ($future->{'day_3_weekend'}) { %> soon__date_weekend<% } %>"><%= $future->{'day_3_name'} %></td>
				<td class="div" rowspan="2"></td>
			</tr>
			<tr>
				<td class="icon soon__icon"<% if ($future->{'day_1_img'}) { %>style="background-image:url(<%= $future->{'day_1_img'} %>);"<% } %>></td>
				<td class="soon__temp"><% if ($future->{'day_1_temp'}) { %><%= $future->{'day_1_sign'} %><strong><%= $future->{'day_1_temp'} %></strong><sup>&deg;</sup><% } else { %>???<% } %></td>
				<td class="icon soon__icon"<% if ($future->{'day_2_img'}) { %>style="background-image:url(<%= $future->{'day_2_img'} %>);"<% } %>></td>
				<td class="soon__temp"><% if ($future->{'day_2_temp'}) { %><%= $future->{'day_2_sign'} %><strong><%= $future->{'day_2_temp'} %></strong><sup>&deg;</sup><% } else { %>???<% } %></td>
				<td class="icon soon__icon"<% if ($future->{'day_3_img'}) { %>style="background-image:url(<%= $future->{'day_3_img'} %>);"<% } %>></td>
				<td class="soon__temp"><% if ($future->{'day_3_temp'}) { %><%= $future->{'day_3_sign'} %><strong><%= $future->{'day_3_temp'} %></strong><sup>&deg;</sup><% } else { %>???<% } %></td>
			</tr>
		</tbody>
	</table>
	<% } %>
</body>
</html>
