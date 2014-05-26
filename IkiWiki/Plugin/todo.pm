#!/usr/bin/perl

# Ikiwiki todo plugin.
package IkiWiki::Plugin::todo;

use warnings;
use strict;
use IkiWiki 3.00;

# Import todo plugin
#
# registers a few hooks:
# - getsetup, called when setting up the wiki
# - needsbuild, called when the wiki is refresh
# - preprocess, called each time the todo directive is processed
# - pagetemplate, called when generating a page
sub import {
	hook(type => "getsetup", id => "todo", call => \&getsetup);
	hook(type => "needsbuild", id => "todo", call => \&needsbuild);
	hook(type => "preprocess", id => "todo", call => \&preprocess, scan => 1);
	hook(type => "pagetemplate", id => "todo", call => \&pagetemplate);
}

# getsetup hook
#
# Specify that the todo plugin:
# - is safe (to be used in websetup)
# - doesn't necessarily require a full rebuild
# - belongs to the widget plugin category
sub getsetup () {
	return
		plugin => {
			safe => 1,
			rebuild => undef,
			section => "widget",
		},
}

# needsbuild hook
#
# If a page has a todo directive, and is part of the needsbuild file list, then
# delete its state so it can be properly reevaluated later
sub needsbuild (@) {
	my $needsbuild=shift;

	foreach my $page (keys %pagestate) {
		if (exists $pagestate{$page}{todo}) {
			if (exists $pagesources{$page} &&
			    grep { $_ eq $pagesources{$page} } @$needsbuild) {
				# remove state, will be re-added if
				# the preprocessor directive is still
				# there during the rebuild
				delete $pagestate{$page}{todo};
			}
		}
	}
	return $needsbuild;
}

# preprocess hook
#
# Generate output for pages marked as todo pages
sub preprocess (@) {
	my %params=@_;
    my $page=$params{page};

    my $ret="<p>";

    # This is a todo page: make it so
    $pagestate{$page}{todo}{state}=1;

    # Evaluate the done parameter
    my $done=IkiWiki::yesno($params{done});
    $pagestate{$page}{todo}{done}=$done if $done;

    $ret.="<s>" if $done;

    $ret.="<b>Todo ";

    if (exists $params{deadline})
    {
        eval q{use Date::Parse};
        error $@ if $@;

        my $str = $params{deadline};
        my $time = str2time($str);
        if (! defined $time) {
            error("unable to parse $str");
        }

        # compute the time string once
        # if the hour is not specified, dont display it
        my $timestr;
        my @timetab = localtime($time);
        if ($timetab[0] == 0 && $timetab[1] == 0 && $timetab[2] == 0) {
            $timestr = displaytime($time, "%a, %d %b %Y");
        } else {
            $timestr = displaytime($time);
        }

        $pagestate{$page}{todo}{deadline}=$time;
        $pagestate{$page}{todo}{deadline_str}=$timestr;

        $ret.="(due for ".$timestr.")";
    }

    $ret.="</b>";
    $ret.="</s>" if $done;
    $ret.="</p>";

    return $ret;
}

# pagetemplate hook
#
# Adds two template parameters (to be used in .tmpl files), namely:
# - tododone (boolean indicating wether the page is done or not)
# - tododeadline (string giving the deadline if defined)
sub pagetemplate (@) {
    my %params=@_;
    my $page=$params{page};
    my $destpage=$params{destpage};
    my $template=$params{template};

    my $done = $pagestate{$page}{todo}{done};
    $template->param(tododone => $done) if defined $done;

    my $deadline = $pagestate{$page}{todo}{deadline_str};
    $template->param(tododeadline => $deadline) if defined $deadline;
}


# Utils for comparison
#
# get_sort_key: gets the deadline for a todo page if defined
# match: gets wether a page is a todo page or not
sub get_sort_key {
    my $page = shift;

    my $key = $pagestate{$page}{todo}{deadline};
    return $key if defined $key;
    return undef;
}

sub match {
    my $page = shift;
    my $field = shift;

    my $val = $pagestate{$page}{todo}{$field};

    return IkiWiki::SuccessReason->new("$page has a the field $field",
        $page => $IkiWiki::DEPEND_CONTENT, "" => 1) if defined $val;

    return IkiWiki::FailReason->new("$page does not have the field $field",
        $page => $IkiWiki::DEPEND_CONTENT, "" => 1);
}

# Match function for PageSpec
#
# provides a match function for todo pages
package IkiWiki::PageSpec;

sub match_todo ($$;@) {
    my $page=shift;
    my $field=shift;

    $field="state" unless $field;

    IkiWiki::Plugin::todo::match($page, $field);
}

# Sort function for SortSpec
#
# provides comparison functions for todo pages
package IkiWiki::SortSpec;

sub cmp_todo {

    my $akey = IkiWiki::Plugin::todo::get_sort_key($a);
    my $bkey = IkiWiki::Plugin::todo::get_sort_key($b);

    if (!defined $bkey) {
        return -1;
    } elsif (!defined $akey) {
        return 1;
    }

    return $akey <=> $bkey;
}

sub cmp_todo_deadline {
    cmp_todo(@_);
}

1
