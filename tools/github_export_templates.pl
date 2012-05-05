#!/usr/bin/perl

use strict;
use lib qw( lib extlib plugins/TemplatesToGithub/lib );

#use lib 'lib', '../lib';


use MT;
require MT::Blog;
require MT::Template;
require MT::TemplateMap;
use Getopt::Long;

require TemplatesToGithub::Util;

use JSON;


my $mt = MT->new() or die MT->errstr;

# define cmd line arguments
my ( $output_dir, $help_flag);

my $result = GetOptions(
   "output_dir=s" => \$output_dir,
   "help"         => \$help_flag,
);

# confirm safe usage of cmdline args
(print_help_msg() and die "") if ($help_flag);
(print_help_msg() and die "ERROR: --output_dir flag required.\n") if (!$output_dir);

# trailing slash in case for the outputdir it's missing, and 
# confirm directory exists and is writable
$output_dir = TemplatesToGithub::Util::create_directory($output_dir);

# clear info file it if exists.
unlink("$output_dir/templates.manifest");

# for each blog, dump their templates.
my $blog_iter = MT::Blog->load_iter();
my @final_summary;
while ( my $blog = $blog_iter->() ) {
	push(@final_summary, export_blog_templates(
	      $blog->id, 
	      $blog->name, 
	      $output_dir,
	      "templates.manifest"));
}

# repeat for the global templates.
push(@final_summary, export_blog_templates(
      0, 
      TemplatesToGithub::Util->GLOBAL_BLOG_NAME, 
      $output_dir,
      "templates.manifest"));

#open (OUTPUTINFO, ">>$output_dir/templates.manifest");
#print OUTPUTINFO encode_json(\@final_summary) . "\n";
#close OUTPUTINFO;


print STDERR "** SCRIPT COMPLETE **\n";

#----------------------------
sub print_help_msg {
   print STDERR "This script exports Movable Type templates to text files on disk.\n" . 
      "Usage:\n" . 
      "\t$0 \n" . 
      "\t\t--output_dir=/full/path/to/outputdir \n" . 
      "\t\t--help\t {Optional}\n\n";
}
   


sub export_blog_templates {
	my ($id, $name, $out_dir, $info_file_name) = @_;

   TemplatesToGithub::Util::debug("Now writing templates for Blog: $name\n");
   require TemplatesToGithub::Util;
   
   my $outer_hash = (
      'id' => $id,
      'name' => $name
   );

	my $directory = $name;
	$directory =~ s/\W/_/g;
   $directory = TemplatesToGithub::Util::create_directory($out_dir . $directory);
		
	my $unlink = 0;
	my $link = 0;
	
	require MT::Template;
   my @templates = MT::Template->load({'blog_id' => $id});
   my $template_json = ();
   foreach my $template (@templates) {
      
      my $final_template_hash;
		
		my $filename = $template->name;
		$filename =~ s/\W/_/g;
		$filename = $filename . ".tmpl";

		my %template_hash = TemplatesToGithub::Util->TEMPLATE_TYPES;
		my $type = $template->type;

      # Write the template to disk.
      my $outfile_path = TemplatesToGithub::Util::create_directory($directory . $type) . $filename;
      
		open (OUTPUTTEXT, "> $outfile_path") or die "Cannot open $outfile_path for writing.\n";
		print OUTPUTTEXT $template->text;
		close OUTPUTTEXT;

      my $info_file_path = $out_dir . "/" . $info_file_name;
      # now open the indexing file
      open (OUTFILE, ">>$info_file_path") or 
         die "Couldn't open \"$info_file_path\" for appending; dying early.\n";
      
      
   	print OUTFILE TemplatesToGithub::Util->BREAKER . 
   	              "TEMPLATE" . 
   	              TemplatesToGithub::Util->BREAKER . 
   	              "\n";
   	
		# Write the template summary to the info file as JSON.
      foreach my $field (TemplatesToGithub::Util->TEMPLATE_OBJ_COLUMNS) {
         $final_template_hash->{$field} = $template->$field;
         print OUTFILE $field . ":" . $template->$field . "\n";         
		}
		# an extra newline for good measure.
		print OUTFILE "\n";
		
      # Also report the template's mapping
      my @maps = MT::TemplateMap->load({ template_id => $template->id });
      my $template_map_array;
      foreach my $map (@maps) {
         print OUTFILE TemplatesToGithub::Util->BREAKER . 
                      "TEMPLATEMAP" . 
                       TemplatesToGithub::Util->BREAKER . "\n";
         my $json_templatemap_fields;
			for my $field (TemplatesToGithub::Util->TEMPLATEMAP_OBJ_COLUMNS) {
            # we need more identifying information for templatemap imports 
            # than their file_template (build path) in case it changes.
            if ($field eq "template_name") {
               print OUTFILE "template_name:" . $template->name . "\n";
            }
            else {
               print OUTFILE $field . ":" . $map->$field . "\n";
            }
			}
			# extra newline.
   		print OUTFILE "\n";
		}
			
		close OUTFILE;
		
		$final_template_hash->{'template_maps'} = $template_map_array;

		push (@$template_json, $final_template_hash);
	}

	# We're not wrapping the outer metadata here.
#	$outer_hash->{'templates'} = $template_json;
	return $template_json;  
#   return $outer_hash;
}



1;