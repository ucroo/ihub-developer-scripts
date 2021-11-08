"""
flint.py - a module that allows you to define linting operations to perform on
           a directory and its subdirectories and files.
"""
import sys
import subprocess
import argparse

from abc import ABC, abstractmethod
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any, Callable, Union


class LinterResult(ABC):
    """
    A single result from a linting operation.
    """

    def __init__(self, path: Path) -> None:
        self.path = path

    def is_fatal(self):
        return False

    def __repr__(self):
        return f"{self.__class__.__name__}({self.path})"

    def __str__(self):
        return f"{self.__class__.__name__}: {self.path}"


class Error(LinterResult):
    """
    An error discovered by a linting operation.
    """

    def __init__(self, path: Path, error: str) -> None:
        super().__init__(path)
        self.error = error

    def is_fatal(self):
        return True

    def __str__(self):
        return f"{self.__class__.__name__.lower()}: {self.path}: {self.error}"


class Warning(LinterResult):
    """
    An error discovered by a linting operation.
    """

    def __init__(self, path: Path, warning: str) -> None:
        super().__init__(path)
        self.warning = warning

    def __str__(self):
        return f"{self.__class__.__name__.lower()}: {self.path}: {self.warning}"


class LinterResults:
    """
    A collection of LinterResults.

    LinterResults are represented as a map from the linted file or directory to
    a list of LinterResults for that file or directory.
    """

    def __init__(self) -> None:
        self.path_map = defaultdict(list)

    def add(self, path: Path, result: LinterResult) -> None:
        self.path_map[path].append(result)

    def results(self) -> List[LinterResult]:
        return [result for results in self.path_map.values() for result in results]

    def items(self) -> List[Tuple[Path, List[LinterResult]]]:
        return list(self.path_map.items())

    def linted_paths(self) -> List[Path]:
        return list(self.path_map.keys())

    def failed(self) -> bool:
        for result in self.results():
            if result.is_fatal():
                return True
        return False


class LintContext:
    """
    Keeps track of LinterResults encountered during linting and what file or
    directory is currently being linted.
    """

    def __init__(
        self,
        path: Path,
        args: "LinterArgs",
        results: Optional[LinterResults] = None,
        properties: Optional[Dict[str, Dict[str, Any]]] = None,
    ) -> None:
        self.path = path
        self.args = args
        self.results = results or LinterResults()
        self.properties = properties if properties is not None else defaultdict(dict)

    def with_path(self, path: Path) -> Optional["LintContext"]:
        return LintContext(path, self.args, self.results, self.properties)

    def in_directory(self, directory: Path) -> Optional["LintContext"]:
        return (
            LintContext(directory, self.args, self.results, self.properties)
            if directory.is_dir()
            else None
        )

    def with_file(self, file: Path) -> Optional["LintContext"]:
        return (
            LintContext(file, self.args, self.results, self.properties)
            if file.is_file()
            else None
        )

    def with_filename(self, filename: str) -> Optional["LintContext"]:
        return self.with_file(Path(self.path, filename))

    def cd(self, directory: str) -> Optional["LintContext"]:
        new_dir = Path(self.path / directory)
        return (
            LintContext(new_dir, self.args, self.results, self.properties)
            if new_dir.is_dir()
            else None
        )

    def warning(self, message: str) -> None:
        self.results.add(self.path, Warning(self.path, message))

    def error(self, message: str) -> None:
        self.results.add(self.path, Error(self.path, message))

    def mark_linted(self) -> None:
        """
        Records that the current file or directory was handled by at least linter.

        This is so that we can detect any files that had no linters applied to
        them when the _Linter's strict_directory_contents flag is set to True.
        """
        self.results.path_map[self.path].extend([])

    def set_property(self, group: str, key: str, value: Any) -> None:
        self.properties[group][key] = value

    def get_property(self, group: str, key: str, default_value: Any = None) -> None:
        return self.properties[group].get(key, default_value)

    def append_property(self, group: str, key: str, value: Any) -> None:
        current_value = self.get_property(group, key, [])
        self.properties[group][key] = current_value + [value]

    def extend_property(self, group: str, key: str, values: List[Any]) -> None:
        current_value = self.get_property(group, key, [])
        self.properties[group][key] = current_value + values


class Lintable(ABC):
    """An object that can be linted"""

    @abstractmethod
    def lint(self, context: LintContext) -> None:
        pass


class LintableGlobMatches(Lintable):
    """
    Multiple objects can match a glob. This object encapsulates logic for
    limits on matches.
    """

    def __init__(
        self,
        glob: str,
        min_matches: Optional[int] = None,
        max_matches: Optional[int] = None,
    ) -> None:
        self.glob = glob
        self.max_matches = max_matches
        self.min_matches = min_matches

    def _check_limits(self, context: LintContext, num_lintables: int) -> LintContext:

        if self.min_matches is not None and num_lintables < self.min_matches:
            context.error(
                f"'{self.glob}' should have had at least {self.min_matches} "
                f"matches but it only had {num_lintables} matches."
            )

        if self.max_matches is not None and num_lintables > self.max_matches:
            context.error(
                f"'{self.glob}' should have had at most {self.max_matches} "
                f"matches but it had {num_lintables} matches.",
            )

        return context


class _Directory(Lintable):
    """
    A directory that can be linted.

    Its contents can also be linted if any children are supplied.
    """

    def __init__(
        self,
        path: str,
        optional: bool = False,
        children: Optional[List[Lintable]] = None,
    ) -> None:
        self.path = path
        self.optional = optional
        self.children = list(children) if children else []

    def lint(self, context: LintContext) -> None:
        my_context = context.cd(self.path)
        if not my_context:
            if not self.optional:
                context.error(
                    f"required directory '{self.path}' does not exist",
                )
            return

        my_context.mark_linted()
        for child in self.children:
            child.lint(my_context)


class _File(Lintable):
    def __init__(
        self,
        path: str,
        optional: bool = False,
        children: Optional[List[Lintable]] = None,
    ) -> None:
        self.path = path
        self.optional = optional
        self.children = list(children) if children else []

    def lint(self, context: LintContext) -> None:
        file_context = context.with_filename(self.path)
        if not file_context:
            context.error(f"Could not find file: {self.path}")
            return

        file_context.mark_linted()

        for child in self.children:
            child.lint(file_context)


class _Files(LintableGlobMatches):
    """
    One or more files that match a glob, that can be linted.
    """

    def __init__(
        self,
        glob: str,
        min_matches: Optional[int] = None,
        max_matches: Optional[int] = None,
        optional: Optional[bool] = False,
        children: Optional[List[Lintable]] = None,
    ) -> None:
        super().__init__(glob, min_matches, max_matches)
        self.children = list(children) if children else []

    def lint(self, context: LintContext) -> None:
        matches = [match for match in context.path.glob(self.glob) if match.is_file()]

        for match in matches:
            match_context = context.with_file(match)
            match_context.mark_linted()
            for child in self.children:
                child.lint(match_context)

        self._check_limits(context, len(matches))


class _Directories(LintableGlobMatches):
    def __init__(
        self,
        glob: str,
        min_matches: Optional[int] = None,
        max_matches: Optional[int] = None,
        children: Optional[List[Lintable]] = None,
    ) -> None:
        super().__init__(glob, min_matches, max_matches)
        self.children = list(children) if children else []

    def lint(self, context: LintContext) -> None:
        matches = [match for match in context.path.glob(self.glob) if match.is_dir()]

        self._check_limits(context, len(matches))

        for match in matches:
            child_context = context.with_path(match)
            if child_context:
                child_context.mark_linted()
                for child in self.children:
                    child.lint(child_context)


class _ShellCommand(Lintable):
    def __init__(self, command_line: List[str]) -> None:
        """
        All occurences of "%s" anywhere in the command line will be replaced by
        the full path name of the file being linted (the parent of this
        bject).
        """
        self.command_line = list(command_line)

    def lint(self, context: LintContext) -> None:
        if not context.path.is_file():
            context.error(f"{context.path} is not a file")
        else:
            command_line = [
                x.replace("%s", str(context.path)) for x in self.command_line
            ]
            try:
                output = subprocess.run(command_line, capture_output=True)
                if output.returncode != 0:
                    context.error(
                        f"non-zero return code ({output.returncode})"
                        f" returned from '{' '.join(command_line)}'."
                        f" Output: {output.stderr.decode('utf-8')}"
                    )
            except (FileNotFoundError, subprocess.CalledProcessError) as ex:
                context.error(f"Error running: '{' '.join(command_line)}' {str(ex)}")


class _Function(Lintable):

    FUNCTION_TYPE = Callable[[LintContext], Optional[str]]

    def __init__(self, function: "_Function.FUNCTION_TYPE", name: str = None) -> None:
        self.name = name if name is not None else function.__name__
        self.function = function

    def lint(self, context: LintContext) -> None:
        result = self.function(context)
        if isinstance(result, str):
            context.error(f"function: '{self.name}' failed with '{result}'.")
        elif isinstance(result, bool):
            if not result:
                context.error(f"function: '{self.name}' failed.")
        elif isinstance(result, int) and result:
            context.error(f"function: '{self.name}' failed with return code: {result}.")


class LinterArgs:
    def __init__(
        self, directory: Optional[str], schema_directories: Optional[List[str]] = None
    ) -> None:
        self.directory = Path(directory) if directory else Path.cwd()
        self.schema_directories = list(schema_directories) if schema_directories else []

    @staticmethod
    def parse_arguments(arguments: List[str]) -> Union[str, "LinterArgs"]:
        parser = argparse.ArgumentParser(description="lint files and directories")

        parser.add_argument("-d", "--directory", type=str, help="the directory to lint")
        parser.add_argument(
            "--schema-dir",
            dest="schema_directories",
            default=[],
            action="append",
            help="a directory to look for schema files in.",
        )

        args = parser.parse_args()
        return LinterArgs(
            directory=args.directory,
            schema_directories=[Path(x) for x in args.schema_directories],
        )

    def __str__(self) -> str:
        return f"directory: {self.directory} schema_dirs: {', '.join(self.schema_directories)}"


class _Linter:
    def __init__(
        self,
        children: List[Lintable],
        strict_directory_contents: bool = True,
        print_properties: bool = False,
    ) -> None:
        self.children = list(children)
        self.strict_directory_contents = strict_directory_contents
        self.print_properties = print_properties

    def run(self, args: LinterArgs) -> LinterResults:
        linted_map: Dict[Path, bool] = {
            entry: False for entry in args.directory.iterdir()
        }

        # Lint selected files and directories
        context = LintContext(args.directory, args)

        for child in self.children:
            child.lint(context)

        for path in context.results.linted_paths():
            linted_map[path] = True

        # Report unexpected entries in the directory
        if self.strict_directory_contents:
            for fso, linted in linted_map.items():
                if not linted:
                    fso_type = "directory" if fso.is_dir() else "file"
                    context.error(f"unexpected {fso_type} '{fso}'")

        if self.print_properties:
            self._print_properties(context)
        return context.results

    def _print_properties(self, context: LintContext):
        for group, key in context.properties.items():
            print("+-", group)
            for k, value in key.items():
                print("   +-", k)
                if isinstance(value, list):
                    for item in value:
                        print("      |-", item)
                else:
                    print("    Value:", value)


def define_linter(children: List[Lintable], *args, **kwargs):
    return _Linter(children=children, *args, **kwargs)


def directory(*args, **kwargs) -> Lintable:
    return _Directory(*args, **kwargs)


def directories(*args, **kwargs) -> Lintable:
    return _Directories(*args, **kwargs)


def files(*args, **kwargs) -> Lintable:
    return _Files(*args, **kwargs)


def file(*args, **kwargs) -> Lintable:
    return _File(*args, **kwargs)


def function(*args, **kwargs) -> Lintable:
    return _Function(*args, **kwargs)


def shell_command(*args, **kwargs) -> Lintable:
    return _ShellCommand(*args, **kwargs)


shell_command.__doc__ = _ShellCommand.__doc__
function.__doc__ = _Function.__doc__
file.__doc__ = _File.__doc__
files.__doc__ = _Files.__doc__
directory.__doc__ = _Directory.__doc__
directories.__doc__ = _Directories.__doc__
define_linter.__doc__ = _Linter.__doc__


def print_results(linter_results: LinterResults, print_statistics: bool = True) -> None:
    warnings = 0
    errors = 0
    files = 0
    directories = 0

    need_newline = False
    for obj, results in linter_results.items():
        if obj.is_dir():
            directories += 1
        else:
            files += 1
        if results:
            need_newline = True
            for result in results:
                if result.is_fatal():
                    errors += 1
                else:
                    warnings += 1
                print(f"{str(result)}")

    if print_statistics:
        if need_newline:
            print()
        print(f"Warnings:    {warnings}")
        print(f"Errors:      {errors}")
        print(f"Directories: {directories}")
        print(f"Files:       {files}")
        print(f"Passed:      {'no' if linter_results.failed() else 'yes'}")


def process_results(linter_results: LinterResults) -> None:
    print_results(linter_results)
    exit_code = 1 if linter_results.failed() else 0
    sys.exit(exit_code)
