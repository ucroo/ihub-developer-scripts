# Flint - A file linter

If you have a collection of files and directories whose structure and content you want to lint, flint can help.

# Functions

## define_linter

Creates a top-level linter and any file or directory linters you want it to run.

## file

Creates a linter for a single file.

## files

Creates a linter for all files matching a glob.

## directory

Creates a linter for a single directory.

## directories

Creates a linter for all directories matching a glob.

## json_content

Creates a linter that can operate on files to ensure they have well-formed JSON.

## follows_schema

Creates a linter that can operate on JSON content to ensure that it adheres to a JSON schema.

## shell_command

Creates a linter that runs a shell command on a file and raises errors if the command fails.

## function

Creates a linter that takes a function or a lambda.

If the function or lambda returns a `str`, the returned string is considered an error message.

If the function or lambda returns a `bool` and the bool is False, the False is taken as a failure.

If the function or lambda returns an int and the `int` is not zero, the False is taken as a failure.
