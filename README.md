# SUMMARY

This plugin facilitates the movement of custom template sets in Movable Type 4 between instances with the benefit of easy insertion into a code repository system.  

The export script exports the instance's full set of templates, including the Global Templates, into a directory of text files, organized per blog per template type, with a templates.manifest file (formerly known as info.txt) providing as the index.  The export script does not modify an MT instance's templates at all; it only reads from the database.  

The import script only modifies live content with the --apply_changes flag.  Without that flag, the script prints status messages and any potential errors with the intended import.  The import script does not preserve template_id's between environments; it keys off of blog name, template name, and output file.

This plugin only provides command-line tools; it does not extend any user-facing or editorial functionality of Movable Type.  


# USAGE

## Terminology
      STAGING: The MT instance that has the templates you're going to export
      LIVE: The MT instance where you'll import STAGING's templates
   
   
## Process

It is extremely on multi-developer projects that everyone who may commit to the Github repository understand the following workflow.  If this process is adopted, all commits involving changes to template text files must be made from a complete set of directories created or updated using github_export_templates.pl.  If execution of github_export_templates.pl is omitted, this may result in templates.manifest becoming out of sync with the template text files.

1. Deploy the TemplatesToGithub plugin and the github_export_templates.pl and github_import_templates.pl tools to both LIVE and STAGING.

2. Run the export script on the LIVE instance as a backup. 
      
         perl tools/github_export_templates.pl --output_dir=/full/path/to/output/dir
      
   
3. Check the resulting LIVE files (in that /full/path/to/output/dir path) into your favorite code repository in its own branch.

4. Run the export script on the STAGING instance. Same command as Step #2 but in the Staging environment.

5. Check the resulting STAGING files into your favorite code repository in a different branch than Step #3.

6. If you want to do some diff'ing, use your favorite file-diffing or repo-diffing tools.  

7. When you're ready to make those staging template live, you can do any amount of branch merging or tagging; whatever suits your process.

8. TEST OUT an import of templates into the LIVE environment with the following command:


         perl tools/github_import_templates.pl --input_dir=/full/path/to/staging/templates 
      
9.  Resolve any errors that happen in Step 8; repeat Step 8 until the script finishes successfully.  Errors will be displayed if a template archive existed on STAGING but not LIVE, if a blog existed on STAGING but not LIVE; if a template cannot be found, etc.

10. Execute the template import into the LIVE environment:

      
         perl tools/github_import_templates.pl --input_dir=/full/path/to/staging/templates --apply_changes
      

11. Revert to the LIVE templates (exported in Step 2) in case of emergency.