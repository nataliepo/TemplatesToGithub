package TemplatesToGithub::Util;

use strict;
use Data::Dumper;

use constant DEBUG => 1;

use constant TEMPLATE_TYPES => (
   "archive" =>  "archive",
   "comment_preview" =>  "system",
   "comment_response" =>  "system",
   "custom" =>  "modules",
   "dynamic_error" =>  "system",
   "email" =>  "email",
   "entry_response" =>  "system",
   "index" =>  "index",
   "individual" =>  "archive",
   "login_form" =>  "system",
   "new_password" =>  "system",
   "new_password_reset_form" =>  "system",
   "page" =>  "archive",
   "password_reset_form" =>  "system",
   "popup_image" =>  "system",
   "profile_edit_form" =>  "system",
   "profile_error" =>  "system",
   "profile_feed" =>  "system",
   "profile_mail_subscribe" =>  "system",
   "profile_mail_thank_you" =>  "system",
   "profile_view" =>  "system",
   "register_confirmation" =>  "system",
   "register_form" =>  "system",
   "search_results" =>  "system",
   "widget" =>  "widget",
   "comment" =>  "system",
   "pings" =>  "system",
);

use constant TEMPLATE_OBJ_COLUMNS => (
   'blog_id',
   'name',
   'type',
   'outfile',
#   'linked_file_mtime',
#   'linked_file_size',
   'modulesets',
   'rebuild_me',
   'build_dynamic',
   'identifier',
   'build_type',
   'build_interval',
   'last_rebuild_time',
   'page_layout',
   'include_with_ssi',
   'cache_expire_type',
   'cache_expire_interval',
   'cache_expire_event',
   'cache_path',
);

use constant TEMPLATEMAP_OBJ_COLUMNS => (
   'blog_id',
   'archive_type',
   'file_template',
   'is_preferred', 
   'build_type',
   'build_interval',
   #### We use the associated template_name instead of an id here 
   #### because we need more identifying info for a templatemapping.
   'template_name'
);

use constant BREAKER =>  "==========";


use constant IGNORE_DIFFERENCES => (
   'template_name' => 1,
   );

use constant GLOBAL_BLOG_NAME => "Global Templates";
sub create_directory {
   my ($directory) = @_;

   $directory .= '/' if ($directory !~ m{/$});

   unless (-d $directory) {
		mkdir($directory, 0777) || die "ERROR: Cannot mkdir output_dir: $!\n";
	}
	
	return $directory;
}

sub confirm_directory {
   my ($directory) = @_;

    $directory .= '/' if ($directory !~ m{/$});

   if (-d $directory) {
 	   return $directory;
 	}
 	else {
 	   die "ERROR: Directory $directory does not exist.\n";
 	}

 	return $directory; 
}


sub debug {
   my ($msg) = @_;
   
   print STDERR "$msg" if DEBUG;
}

1;