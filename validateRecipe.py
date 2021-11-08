import sys

from pathlib import Path
from typing import List

from flint import define_linter, process_results, file, directory, files, LinterArgs
from flint.json import json_content, follows_schema

def main(args: List[str]):
    process_results(define_linter(
        children=[
            file("metadata.json", children=[
                json_content(children=[
                    follows_schema("metadata.schema")
                ])
            ]),

            directory("statefulBehaviours", optional=True, children=[
                files("*.json", children=[
                    json_content()
                ])]),

            directory("flows", optional=True, children=[
                files("*.json", children=[
                    json_content()
                ])]),

            directory("sharedConfigs", optional=True, children=[
                files("*.json", children=[
                    json_content()
                ])]),

            directory("resourceCollections", optional=True, children=[
                files("*.json", children=[
                    json_content()
                ])]),
        ]).run(LinterArgs.parse_arguments(args)))


if __name__ == '__main__':
    main(sys.argv[1:])
