#!/usr/bin/perl

use strict;
use lib qw( lib extlib plugins/TemplatesToGithub/lib );

use MT;
require MT::Blog;
require MT::Template;
require MT::TemplateMap;
use Getopt::Long;

use Data::Dumper;
use JSON;

require TemplatesToGithub::Util;

use constant DEBUG => 0;

my $mt = MT->new() or die MT->errstr;

# define cmd line arguments
my ( $input_dir, $help_flag, $log_file, $apply_changes );

my $result = GetOptions(
   "input_dir=s" => \$input_dir,
   "apply_changes" => \$apply_changes,
   "help"        => \$help_flag,
);

# confirm safe usage of cmdline args
(print_help_msg() and die "") if ($help_flag);
(print_help_msg() and die "ERROR: --input_dir flag required.\n") if (!$input_dir);


if (!$apply_changes) {
   $log_file = $input_dir . "/proposed-changes.log";
}
else {
   $log_file = $input_dir . "/applied-changes.log";
}

# clear the audit log before we begin.
unlink($log_file);


import_blog_templates($input_dir, $log_file, $apply_changes);

# if no changes were made, print that note.
if (!-e $log_file) {
   open (LOG_FILE, "> $log_file") or die "Could not open \"$log_file\" for writing.\n";
   print LOG_FILE TemplatesToGithub::Util->BREAKER . "\n" . "NO CHANGES.\n";
   close (LOG_FILE);
}


print STDERR "** SCRIPT COMPLETE.  Read the ";
if ($apply_changes) {
   print STDERR "applied ";
}
else {
   print STDERR "proposed "
}
print STDERR "changeset in $log_file. **\n";




#----------------------------
sub print_help_msg {
   print STDERR "This script imports text files on disk into Movable Type as templates.\n" . 
      "Usage:\n" . 
      "\t$0 \n" . 
      "\t\t--input_dir=/full/path/to/input_dir \n" . 
      
      #"log_file=s"  => \$log_file,
      "\t\t--log_file=log_file_name.txt \n" . 
      
      #"apply_changes" => \$apply_changes,
      "\t\t--apply_changes  \t ## This flag *APPLIES* the template import. \n" . 
      "\t\t--help\t {Optional}\n\n";
}


sub import_blog_templates {
   my ($input_dir, $log_file, $apply_changes) = @_;
   
   # critical data structure -- 
   #   {'id'} = 
   #     'type' => ('change', 'creation'),
   #     'changes' => [
   #       (
   #           'field': 'fieldname',
   #           'old_val': 'old_value', 
   #           'new_val': 'new_value'
   #       ),
   #  ...etc
   my $changes_made;
   
   
   # critical data structure -- 
   # {$blog_id} => 
   #     {type} => 
   #        name1
   #        name2
   #     {type2} => 
   #        name1
   #        name2
   # ...etc
   my $templates_seen;
	
	## left off here counting the number of template changes.
   my %template_change_counter = TemplatesToGithub::Util->TEMPLATE_TYPES;
	
	# suck in imported templates
	open (INPUT, "< $input_dir/templates.manifest");
   my $whole_file = "";
   my $line = <INPUT>;
   while ($line) {
      $line =~ s/\n$//g;

      my $mode = "";
      if ($line eq TemplatesToGithub::Util->BREAKER . "TEMPLATE" . TemplatesToGithub::Util->BREAKER) {
         $mode = "TEMPLATE";
      }  
      elsif ($line eq TemplatesToGithub::Util->BREAKER . "TEMPLATEMAP" . TemplatesToGithub::Util->BREAKER) {
         $mode = "TEMPLATEMAP";  
      }
      else {
         # if neither of these types match, skip.
         $line = <INPUT>;
         next;
      }

      my %template_def  = ();
         
         
      # The block of template data ends in a newline.   
      while (($line = <INPUT>) && ($line !~ m/^\n$/)) {
         $line =~ s/\n$//;
         $line =~ m/^([^:]+):(.*)$/;
            
         my $col = $1;
         my $val = $2;
            
         $template_def{$col} = $val;
      }         

      my $template;
      # grab the text if it's a TEMPLATE
      if ($mode eq "TEMPLATE") {
         $template_def{'text'} = get_template_text(\%template_def, $input_dir);

         require MT::Template;
         $template = MT::Template->load({
               'blog_id' => $template_def{'blog_id'},
               'name' => $template_def{'name'}
         });
      }
      else {
         require MT::TemplateMap;
                     
         # we actually do want to load the associated template.
         my $associated_template = MT::Template->load({
               'blog_id' => $template_def{'blog_id'},
               'name' => $template_def{'template_name'}});
               
         (print STDERR "Couldn't find associated_template for blog_id=" . 
            $template_def{'blog_id'} . ", template_name=" . 
            $template_def{'template_name'} . "\n" and next) if (!$associated_template);
            
         $template = MT::TemplateMap->load({
               'blog_id' => $template_def{'blog_id'},
               'archive_type' => $template_def{'archive_type'},
               'template_id' => $associated_template->id,
         });
      }
            
      if ($template) {
         # diff_templates() finds the difference between an MT::Template
         # object and a %template_def hash.
         if (my $changeset = diff_templates($template, \%template_def)) {
            foreach my $change (@$changeset) {
               apply_change ($template, $change, $log_file, $apply_changes);
            }
         }
      }
      else  {
         # there's a template in the import that doesn't exist on live.
         $template_def{'new_template'} = 1;
       
         if ($mode eq "TEMPLATE") {
            create_new_template(\%template_def, $log_file, $apply_changes);
         }
         elsif ($mode eq "TEMPLATEMAP") {

			# we actually do want to load the associated template.
         	my $associated_template = MT::Template->load({
               'blog_id' => $template_def{'blog_id'},
               'name' => $template_def{'template_name'}});

			next if (!$associated_template);
			
			# template_id is critical here.
			$template_def{'template_id'} = $associated_template->id;
		 
            create_new_templatemap(\%template_def, $log_file, $apply_changes);
         }
      }
   }
   close(INPUT);
   
   
   return;
}

# apply one single change.
sub apply_change {
   my ($template, $change, $log_file, $apply_changes) = @_;
   
   print_log_file($log_file, $template, $change);
   
   if ($apply_changes) {
      my $field = $change->{'field'};
      my $new_val = $change->{'new'};
      
      $template->$field($new_val);
      $template->save();
   }
   
}

sub create_new_template {
   my ($template_def, $log_file, $apply_changes) = @_;
   
   require MT::Template;
   
   print_log_file($log_file, 0, $template_def);
   
   if ($apply_changes) {
      my $template = MT::Template->new;
      foreach my $field (keys(%$template_def)) {
         next if ($field eq "new_template");
         
         $template->$field($template_def->{$field});
      }

      $template->save;
   }
}

sub create_new_templatemap {
   my ($template_def, $log_file, $apply_changes) = @_;
   require MT::TemplateMap;
   
   print_log_file($log_file, 0, $template_def);
   
   my %ignore_differences = TemplatesToGithub::Util->IGNORE_DIFFERENCES;
   
   if ($apply_changes) {
      my $template = MT::TemplateMap->new;
      foreach my $field (keys(%$template_def)) {
         next if ($field eq "new_template");
         
         next if (exists($ignore_differences{$field}));
         
         $template->$field($template_def->{$field});
      }

      $template->save or print STDERR "MT::TemplateMap error upon saving: " . $template->errstr . 
		", Name: \"" . $template_def->{'name'} ."\", blog_id = " .
		$template_def->{'blog_id'} . "\n";
   }   
   
}

# find the differences between an existing template and a
# template created from the export script
sub diff_templates {
   my ($existing_template, $proposed_changes, $import_path) = @_;
   
   my $changeset;
   my %ignore_differences = TemplatesToGithub::Util->IGNORE_DIFFERENCES;
   
   foreach my $key (keys(%$proposed_changes)) {
      next if (!$key);
   
   
   
      my $change;

      next if (exists($ignore_differences{$key}));

      # if both values are false, ignore.
      next if (!$existing_template->$key and !$proposed_changes->{$key});

      if ($existing_template->$key ne $proposed_changes->{$key}) {
            $change->{'field'} = $key;
            $change->{'old'} = $existing_template->$key;
            $change->{'new'} = $proposed_changes->{$key};
            $change->{'new_template'} = 0;
            
            push (@$changeset, $change);
      }
   }
   
   return ($changeset) ? $changeset : 0;   
}


sub print_log_file {
   my ($log_file_path, $template, $change) = @_;
   
   open (OUTFILE, ">>$log_file_path") or 
      die "Cannot open log file \"$log_file_path\" for appending; dying.\n";
      
   
   if ($change->{'new_template'} || !$template ) {
      
      print OUTFILE TemplatesToGithub::Util->BREAKER . TemplatesToGithub::Util->BREAKER . "\n";
      
      my $blog_name = "UNDEFINED";
      $blog_name = TemplatesToGithub::Util->GLOBAL_BLOG_NAME if (!$change->{'blog_id'});
      my $blog = MT::Blog->load({'id' => $change->{'blog_id'}});
      $blog_name = $blog->name if ($blog);
      
      print OUTFILE "[$blog_name][NEW] -- " . $change->{'name'}. "\n";
      
      foreach my $key (keys(%$change)) {
         next if (($key eq "text") || ($key eq "name"));
         
         print OUTFILE "\t$key:" . $change->{$key} . "\n";
      }
      print OUTFILE "\ttext:" . $change->{'text'} . "\n";
      
   }
   else {
      require MT::Blog;
      
      # three possibilities:
      #   blog name exists
      #   global blog (template->blog_id=0)
      #   blog name doesn't exist.
      my $blog_name = "UNDEFINED";
      $blog_name = TemplatesToGithub::Util->GLOBAL_BLOG_NAME if (!$template->blog_id);
      my $blog = MT::Blog->load({'id' => $template->blog_id});
      $blog_name = $blog->name if ($blog);
      
      my $name = "UNDEFINED";
      if ($template->isa('MT::Template')) {
         $name = $template->name;
      }
      elsif ($template->isa('MT::TemplateMap')) {
         $name = $template->archive_type;
      }
      
      print OUTFILE TemplatesToGithub::Util->BREAKER . TemplatesToGithub::Util->BREAKER . "\n";
      print OUTFILE "[$blog_name][" . $template->id . "] -- " . $name . "\n";
      print OUTFILE "\tFIELD: " . $change->{'field'} . "\n";

      print OUTFILE "\n\t" . TemplatesToGithub::Util->BREAKER . "\n" if ($change->{'field'} eq "text");
      print OUTFILE "\tOLD VALUE (MT): ";
      print OUTFILE "\n\t" . TemplatesToGithub::Util->BREAKER . "\n" if ($change->{'field'} eq "text");
      print OUTFILE  $change->{'old'} . "\n";;

      
      print OUTFILE "\n\t" . TemplatesToGithub::Util->BREAKER . "\n" if ($change->{'field'} eq "text");
      print OUTFILE "\tNEW VALUE (IMPORT): ";
      print OUTFILE "\n\t" . TemplatesToGithub::Util->BREAKER . "\n" if ($change->{'field'} eq "text");
      print OUTFILE $change->{'new'} . "\n";
      
      print OUTFILE "\n";
   }

   close OUTFILE;

}


# get one template's text from the input directory.
# usage:
#   $template_def{'text'} = get_template_text($template_def, $input_dir);
sub get_template_text {
   my ($template_def, $input_dir) = @_;
   
   require MT::Blog;
   my $blog_name = TemplatesToGithub::Util->GLOBAL_BLOG_NAME;
   if ($template_def->{'blog_id'}) {
      my $blog = MT::Blog->load({'id' => $template_def->{'blog_id'}});
      $blog_name = $blog->name if ($blog);
   }
   
   $input_dir = TemplatesToGithub::Util::confirm_directory($input_dir);
   
   my $directory = $blog_name;
	$directory =~ s/\W/_/g;
   $directory = TemplatesToGithub::Util::confirm_directory($input_dir . $directory);
   
   my $type = $template_def->{'type'};

	my $filename = $template_def->{'name'};
	$filename =~ s/\W/_/g;
	$filename = $filename . ".tmpl";

	my $path = TemplatesToGithub::Util::confirm_directory($directory . $type);
	my $infile_path = $path . $filename;
   
   if (-e $infile_path) {
      my $line;
      open (TEMPLATE_FILE, "<$infile_path") or die "Cannot open $infile_path for reading.\n";
      
      my $template_text = "";
      while ($line = <TEMPLATE_FILE>) {
         $template_text .= $line;
      }
      
      close TEMPLATE_FILE;
      return $template_text;
   }
   else {
      print STDERR "File $infile_path does not exist.\n";
      return "";
   }
}
