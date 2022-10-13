import sys

from pathlib import Path
from typing import List, Optional

from flint import (
    LintContext,
    LinterArgs,
    define_linter,
    directory,
    file,
    files,
    function,
    process_results
)

from flint.json import (
    json_content,
    follows_schema,
    collect_values,
    JsonPath
)

collect_binding_references = collect_values(
    JsonPath.compile("..|.binding?"),
    "binding",
    "references"
)

collect_binding_definitions = collect_values(
    JsonPath.compile(".bindings | keys"),
    "binding",
    "definitions")


def check_bindings(context: LintContext) -> Optional[str]:
    definitions = set(x for x in context.properties['binding']['definitions'] if x)
    references = set(x for x in context.properties['binding']['references'] if x)

    unused_bindings = definitions - references
    undefined_bindings = references - definitions

    if undefined_bindings:
        return f"Undefined bindings: {list(undefined_bindings)}"

    # Commented out because, of false-positives for regex bindings
    # if unused_bindings:
    #     return f"Unused bindings: {list(unused_bindings)}"

    return None


def main(args: List[str]):
    process_results(define_linter(
        children=[

            directory("triggerers", optional=True, children=[
                files("**/*.json", children=[
                     json_content(children=[
                         follows_schema("triggerers.schema"),
                         collect_binding_references
                     ]),
                    ]),
                ]),

            directory("sharedConfig", optional=True, children=[
                 files("**/*.json", children=[
                     json_content(children=[
                         follows_schema("shared-config.schema"),
                         collect_binding_references
                    ])
                ]),
            ]),

            directory("javascript", optional=True, children=[]),
            directory("dnsOverrides", optional=True, children=[]),
            directory("flowResources", optional=True, children=[]),
            directory("flows", optional=True, children=[]),
            directory("resourceCollections", optional=True, children=[])
        ]).run(LinterArgs.parse_arguments(args)))


if __name__ == '__main__':
    main(sys.argv[1:])
