# GitHooks

This small collection of bash script is an attempt to have a git-repository-independent hooks setup mechanism to comfortably use over and over again the own implemented hooks.
The basic idea is to have a general hooks implementation and a bash main script to set up them in any git repository with command line options to fine tune the setup.
All provided hooks and setup have a highly informative output.

## Quick start and main features

Once cloned the repository on your system, you can run the main script as `./hooksSetup.bash -h` to get an overview of functionality.
Few options to tell the script the repository for which hooks should be set up as well as how (i.e. copying or symlinking) must be specified.
The following hooks will be then prepared for future use.

### Copy or symlink?

The automatic setup offers two possibilities:

1. Copy hooks and auxiliary files from this repository to the `.git` directory of the chosen repository;
1. Create symbolic links to files of the clone of this repository to the `.git` directory of the chosen repository.

There are pros and cons and it is up to you to choose what better suites your usage.
If you simply want to give it a try and keeping hooks up to date to newer versions is not an immediate priority, then just go for the copy.

### The `pre-commit` hook

> This hook is invoked by `git commit`, and can be bypassed with the `--no-verify` option. It takes no parameters, and is invoked before obtaining the proposed commit log message and making a commit.

The provided implementation has the following features.

* Check if user name and email are set and reasonable
* Prevent non-ASCII, spaces and endline characters in filenames
* Optionally, go through staged files and
   - check code style using clang-format
   - check copyright statement
   - check license notice
* Optionally, go through fully staged files and
   - remove trailing spaces at end of lines
   - add end of line at the end of file
   - remove empty lines at the end of the file
* Optionally, make whitespace git check
* Optionally, check branch on which the commit is being done

### The `commit-msg` hook

> This hook is invoked by `git commit` and `git merge`, and can be bypassed with the --no-verify option. It takes a single parameter, the name of the file that holds the proposed commit log message.

The provided implementation has the following enforcements.

* Trailing spaces at beginning of first three lines are removed
* Trailing spaces at the end of all lines are removed
* An endline at the end of the message is added if missing
* A small letter at the beginning of the first line is capitalised
* Any character among ".?!" at the end of the first line is removed in a repetitive way (e.g. "commit..!!!" -> "commit")                                                                                                                                                                                                                                                                                                                 
* Optionally:                                                                                                                                                                                                                                                                                                                                                          
  - The first line of the commit must be at maximum 60 chars.                                                                                                                                                                                                                                                                                                        
    This is the hard limit for GitHub at which a commit message is hidden.                                                                                                                                                                                                                                                                                           
    More [good practices](https://chris.beams.io/posts/git-commit/) are encouraged.
  - The first line of the commit must have at least 8 chars.                                                                                                                                                                                                                                                                                                         
  - The second line must be empty                                                                                                                                                                                                                                                                                                                                    
  - Any following line after the second must be 72 chars at maximum                                                                                                                                                                                                                                                                                                  
  - The first line must begin with a character

The minimum and maximum line lengths can be customized.
