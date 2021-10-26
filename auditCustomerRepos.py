import re
import abc
import sys
import yaml
import json
import subprocess

from functools import partial
from pathlib import Path

# Union is similar to Scala's Either but with out any of the type safety.
# Optional is similar to Scala's Option but with out any of the type safety.
from typing import Optional, Union, List, Any, Iterator, Callable


# Type alias
JSON = Union[dict, list, bool, str, int, None]


def _ellipsis(s: str, max_len: int = 100) -> str:
    """Try to keep output clean by omitting some of the text for longer strings."""
    if len(s) <= max_len:
        return s
    return s[: int(max_len * 0.9)] + "..." + s[-int(max_len * 0.1) :]


class AuditResult:
    pass


class Error(AuditResult):
    def __init__(self, file_path: Path, message: str) -> None:
        self.file_path = file_path
        self.message = message

    def __str__(self) -> str:
        return f"Error: {self.message}:\n\tFile: {self.file_path}\n"


class Warning(AuditResult):
    def __init__(
        self,
        file_path: Path,
        message: str,
    ) -> None:
        """
        Arguments:

        file_path -- the path to the file where the warning was found
        message -- a description of the issue found
        """
        self.file_path = file_path
        self.message = message

    def __str__(self) -> str:
        value = _ellipsis(" ".join(self.value.split("\n")))
        return f"Warning: {self.message}:\n\tFile: {self.file_path}"


class JsonWarning(Warning):
    """Similar to a Warning but with additional, JSON-specific, context."""

    def __init__(
        self, file_path: Path, message: str, context: List[JSON], value: JSON
    ) -> None:
        """
        Arguments:

        file_path -- the path to the file where the warning was found
        message -- a description of the issue found
        context -- a path from the root of the file to where the problematic JSON element was found.
        value -- the JSON element that generated the warning
        """
        super().__init__(file_path, message)
        self.context = list(context)
        self.value = value

    def __str__(self) -> str:
        value = _ellipsis(" ".join(self.value.split("\n")))
        return f"Warning: {self.message}:\n\tContext: /{'/'.join(self.context)}\n\tFile: {self.file_path}\n\tValue: \"{value}\"\n"


class Auditor(abc.ABC):
    @abc.abstractmethod
    def audit_file(self, file_path: Path) -> List[AuditResult]:
        """Perform an audit on the file, returning any audit results."""

    def should_audit_repo(self, repo_dir: Path) -> bool:
        """Return True if the Auditor should audit the specified repository directory."""
        return True

    def can_audit_file(self, file_path: Path) -> bool:
        """Return True if the Auditor knows how to audit the specified file."""
        return True

    def audit_repos(self, path: Path) -> List[AuditResult]:
        audit_results = []
        for repo in self._repos_under(Path.cwd()):
            if self.should_audit_repo(repo):
                audit_results.extend(self._audit_repo(repo))
        return audit_results

    def _repos_under(self, path: Path) -> Iterator[Path]:
        for file in path.rglob(".git"):
            yield file.parent

    def _audit_repo(self, repo_path: Path) -> List[AuditResult]:
        """
        Audits at the git repository level.  repo_path is a repo directory.
        """
        audit_results = []
        for file in (repo_path).rglob("*"):
            if file.is_file() and self.can_audit_file(file):
                audit_results.extend(self.audit_file(file))
        return audit_results


class JsonAuditor(Auditor):
    @abc.abstractmethod
    def should_recurse(self, context: List[JSON], current_value: JSON) -> bool:
        """Return True if the Auditor should recurse into a JSON object."""
        return True

    def decorate_dict_context(
        self, context: List[JSON], current_node: JSON
    ) -> List[JSON]:
        return []

    def decorate_list_context(
        self, context: List[JSON], current_node: JSON
    ) -> List[JSON]:
        return []

    @staticmethod
    def could_be_json(text) -> bool:
        """
        This function is used to reduce the number of times we attempt to parse a
        non-JSON string as JSON. The concern is that the more forgiving YAML parser
        will interpret a non-JSON string as valid JSON.
        """
        return bool(isinstance(text, str) and re.match(r"^[{[]", text.strip()))

    def walk_json(
        self,
        file_path: Path,
        context: List[JSON],
        node: JSON,
        f: Callable[[Path, JSON, List[JSON]], List[AuditResult]],
    ) -> List[AuditResult]:
        context = context or ["root"]
        audit_results = []

        if isinstance(node, dict):
            if not self.should_recurse(context, node):
                return []

            for key, value in node.items():
                audit_results.extend(
                    self.walk_json(
                        file_path,
                        context
                        + self.decorate_dict_context(list(context), node)
                        + [key],
                        value,
                        f,
                    )
                )

        elif isinstance(node, list):
            for i, elem in enumerate(node):
                audit_results.extend(
                    self.walk_json(
                        file_path,
                        context + self.decorate_list_context(context, node) + [str(i)],
                        elem,
                        f,
                    )
                )

        elif isinstance(node, str):
            # Some of our JSON files contain strings that are themselves JSON
            # strings. Parse them as JSON, so that they too can be audited.
            if JsonAuditor.could_be_json(node):
                result = self.parse_json_string(node)
                if isinstance(result, Exception):
                    audit_results.append(Error(file_path, f"Exception: {result}"))
                else:
                    audit_results.extend(
                        self.walk_json(
                            file_path, context + ["embedded_json"], result, f
                        )
                    )
            else:
                audit_results.extend(f(file_path, context, node))
        return audit_results

    def parse_json_string(
        self, json_text: str, strict: bool = False
    ) -> Union[Exception, str]:
        """
        If a JSON file can be parsed with a strict parser, use that result. If not,
        use a more forgiving parser in hopes of extracting data from the JSON file.

        At some point, we may want to disable the forgiving parser altogether.
        """
        try:
            return self._check_json_syntax_strict(json_text)
        except Exception as ex:
            if strict:
                return ex
            try:
                return self._check_json_syntax_non_strict(json_text)
            except Exception as ex:
                return ex

    def parse_json_file(
        self, json_path: Path, strict: bool = False
    ) -> Union[Exception, str]:
        return self.parse_json_string(json_path.read_text(), strict)

    def _check_json_syntax_non_strict(self, raw_data: str) -> JSON:
        """
        YAML 1.2+ is a superset of JSON?  https://stackoverflow.com/a/1931531/26002 says yes.

        Python's default json library does not handle some of our JSON files so we
        use the YAML loader instead.
        """
        return yaml.load(raw_data.replace("\t", " "), Loader=yaml.SafeLoader)

    def _check_json_syntax_strict(self, raw_data: str) -> JSON:
        return json.loads(raw_data)


class SharedConfigAuditor(JsonAuditor):

    PASSWORD_RE = re.compile(
        r"((?=.*\d)(?=.*[a-z])(?=.*[!@#$%^&*]).{6,64})", re.IGNORECASE
    )

    VALUE_PATTERNS = {
        re.compile(r"BEGIN PRIVATE"): "Cryptographic Key",
        re.compile(r"BEGIN RSA"): "Cryptographic Key (RSA)",
        re.compile(
            r"_password$", re.IGNORECASE
        ): "referenceId has password in it's name",
        re.compile(r"_secret$", re.IGNORECASE): "referenceId has secret in it's name",
        re.compile(r"^passphrase$", re.IGNORECASE): "Pass Phrase",
        re.compile(r"^privkey$", re.IGNORECASE): "Private Key",
    }

    def can_audit_file(self, file_path: Path) -> bool:
        return "/sharedConfig/" in str(file_path) and file_path.suffix == ".json"

    def should_recurse(self, context: List[JSON], current_value: JSON) -> bool:
        return "secure" not in current_value or current_value["secure"] != True

    def audit_file(self, file_path: Path) -> List[AuditResult]:
        result = self.parse_json_file(file_path, False)
        if isinstance(result, Exception):
            return [
                Error(
                    file_path,
                    f"JSON Syntax Error:\n\tFile: {file_path}\n\tError: {result}",
                )
            ]
        else:
            return self.walk_json(file_path, None, result, self.find_unsecured_secret)

    def decorate_list_context(
        self, context: List[JSON], current_node: JSON
    ) -> List[JSON]:
        return ["list_index"]

    def decorate_dict_context(
        self, context: List[JSON], current_node: JSON
    ) -> List[JSON]:
        ref_id = current_node.get("referenceId", None)
        if ref_id:
            return ["referenceId", ref_id]
        return []

    def detect_password(self, text: str) -> bool:
        """
        JDBC configuration settings and SSH public keys have a tendency to look
        like a password to the PASSWORD_RE regex so explicitly ignore them.
        """
        text = text.strip().lower()
        if text.endswith(".edu"):
            return False
        if text.endswith(".com"):
            return False
        if text.startswith("http"):
            return False
        if text.startswith("jdbc"):
            return False
        if text.startswith("ssh-rsa"):
            return False
        return bool(SharedConfigAuditor.PASSWORD_RE.search(text))

    def find_unsecured_secret(
        self, file_path: Path, context: List[JSON], value: JSON
    ) -> List[AuditResult]:
        audit_results = []
        if isinstance(value, str):
            # Audit any kind of value
            if context[-1] != "referenceString":
                if self.detect_password(value):
                    audit_results.append(
                        JsonWarning(file_path, "Password Regex", context, value)
                    )
                for pattern, message in self.VALUE_PATTERNS.items():
                    if pattern.search(value):
                        audit_results.append(
                            JsonWarning(file_path, message, context, value)
                        )
        # Audit a dictionary key
        if isinstance(context[-1], str):
            key = context[-1]
            for pattern, message in self.VALUE_PATTERNS.items():
                if pattern.search(key):
                    audit_results.append(
                        JsonWarning(file_path, message, context, value)
                    )
        return audit_results


class JavaScriptAuditor(abc.ABC):
    def can_audit_file(self, file_path: Path) -> bool:
        return file_path.suffix == ".js" and file_path.stat().st_size < 10 * 1024

    def audit_file(self, file_path: Path) -> List[AuditResult]:
        proc = subprocess.run(["jslint", str(file_path)], capture_output=True)
        output = _ellipsis(str(proc.stdout), 512)
        if output:
            return [Error(file_path, output)]
        return []


class CompositeAuditor(Auditor):
    def __init__(self, *auditors) -> None:
        self.auditors = auditors

    def can_audit_file(self, file_path: Path) -> bool:
        return any(
            [auditor for auditor in self.auditors if auditor.can_audit_file(file_path)]
        )

    def audit_file(self, file_path: Path) -> List[AuditResult]:
        results = []
        for auditor in self.auditors:
            if auditor.can_audit_file(file_path):
                results.extend(auditor.audit_file(file_path))
        return results


class RepoFilter(Auditor):
    def __init__(self, regex: re, auditor: Auditor) -> None:
        self.regex = regex
        self.auditor = auditor

    def can_audit_file(self, repo_file: Path) -> bool:
        return self.auditor.can_audit_file(repo_file)

    def should_audit_repo(self, repo_dir: Path) -> bool:
        return bool(self.regex.search(str(repo_dir)))

    def audit_file(self, file_path: Path) -> List[AuditResult]:
        return self.auditor.audit_file(file_path)


def main() -> None:
    if False:
        # Audit using SharedConfigAuditor and JavaScriptAuditor
        auditor = CompositeAuditor(SharedConfigAuditor(), JavaScriptAuditor())
    elif False:
        auditor = RepoFilter(re.compile(r"aamu"), SharedConfigAuditor())
    else:
        auditor = SharedConfigAuditor()

    for i, audit_result in enumerate(auditor.audit_repos(Path.cwd()), 1):
        print(f"{i}: {audit_result}")


if __name__ == "__main__":
    main()
