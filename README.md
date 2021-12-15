# TemplatesToGithub

# Summary

This plugin facilitates the movement of custom template sets in Movable Type between instances with the benefit of easy insertion into a git-based code repository system.

# Naming Conventions

## Significance of the name TemplatesToGithub

The assumption made in the naming of this plugin is that most developers using git will use use the Software-as-a-Service provider of distributed version control and source code management known as [GitHub](https://github.com), which is owned by Microsoft, as their cloud git repository.

But this plugin does not require use of Github. Developers could manage git repositories to which templates are contributed locally, or could manage those git repositories via a corporate or institutional git repository, or an alternative cloud service to GitHub.

## Terminology
      STAGING: The MT instance that has the templates you're going to export
      PRODUCTION: The MT instance where you'll import STAGING's templates

# Usage

This plugin includes command-line tools, that are used in conjunction with the plugin itself, to implement the import and export of text files representing each template; neither the plugin nor the associated command-line tools extend any user-facing or editorial functionality within the Movable Type content management system.

The export script exports the instance's full set of templates, including the Global Templates, into a directory of text files, organized per blog per template type, with a templates.manifest file (formerly known as info.txt) providing as the index.  The export script does not modify an MT instance's templates at all; it only reads from the database.  

The import script only modifies live content with the --apply_changes flag.  Without that flag, the script prints status messages and any potential errors with the intended import.  The import script does not preserve template_id's between environments; it keys off of blog name, template name, and output file.
   
## Process

It is extremely important on multi-developer projects that everyone who may commit template code to the Github repository understands and uses the following workflow.  If this process is adopted, all commits involving changes to template text files must be made from a complete set of directories created or updated using github_export_templates.pl.  If execution of github_export_templates.pl is omitted on either the PRODUCTION or STAGING server, this may result in templates.manifest becoming out of sync with the template text files.

1. Deploy the TemplatesToGithub plugin and the github_export_templates.pl and github_import_templates.pl tools to both PRODUCTION and STAGING.

2. Run the export script on the PRODUCTION instance as a backup. 
      
         perl tools/github_export_templates.pl --output_dir=/full/path/to/output/dir
      
   
3. Check the resulting PRODUCTION files (in that /full/path/to/output/dir path) into your favorite code repository in its own branch.

4. Run the export script on the STAGING instance. Same command as Step #2 but in the Staging environment.

5. Check the resulting STAGING files into your favorite code repository in a different branch than Step #3.

6. If you want to do some diff'ing, use your favorite file-diffing or repo-diffing tools.  

7. When you're ready to make those staging template live, you can do any amount of branch merging or tagging; whatever suits your process.

8. TEST OUT an import of templates into the PRODUCTION environment with the following command:


         perl tools/github_import_templates.pl --input_dir=/full/path/to/staging/templates 
      
9.  Resolve any errors that happen in Step 8; repeat Step 8 until the script finishes successfully.  Errors will be displayed if a template archive existed on STAGING but not PRODUCTION, if a blog existed on STAGING but not PRODUCTION; if a template cannot be found, etc.

10. Execute the template import into the PRODUCTION environment:

      
         perl tools/github_import_templates.pl --input_dir=/full/path/to/staging/templates --apply_changes
      

11. Revert to the PRODUCTION templates (exported in Step 2) in case of emergency.

# Support

For technical support of this theme, contact After6 Services at support@after6services.com or customer.service@after6services.com.

# License

# Authorship

The TemplatesToGithub Plugin and associated command line tools were originally developed by Natalie Podrazik. This project was adopted by After6 Services LLC, with small code and documentation changes by Dave Aiello.

# Copyright

Copyright &copy; 2011, Natalie Podrazik.

Copyright &copy; 2012-2021, After6 Services LLC. All rights reserved.

AMovable Type is a registered trademark of Six Apart Limited.

Trademarks, product names, company names, or logos used in connection with this repository are the property of their respective owners and references do not imply any endorsement, sponsorship, or affiliation with After6 Services LLC unless otherwise specified.
