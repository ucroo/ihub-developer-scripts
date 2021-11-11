import sys

from pathlib import Path
from typing import List

from flint import define_linter, process_results, file, directory, files, LinterArgs, function
from flint.json import json_content, follows_schema, collect_values, JsonPath

def main(args: List[str]):
    process_results(define_linter(
        children=[
            file("metadata.json", children=[
                json_content(children=[
                    follows_schema("metadata.schema"),
                    collect_values(JsonPath.compile("bindings.keys(@)"), "binding", "definitions")
                ]),
            ]),

            directory("statefulBehaviours", optional=True, children=[
                files("*.json", children=[
                    json_content(children=[
                    collect_values(JsonPath.compile("*.binding"), "binding", "references")
                ]),
                ])]),


            directory("flows", optional=True, children=[
                files("*.json", children=[
                    json_content(children=[
#                    collect_values(JsonPath.compile("*.binding"), "binding", "definitions")
                ])
            ])]),

            directory("sharedConfigs", optional=True, children=[
                files("*.json", children=[
                    json_content(children=[
                    # collect_values(JsonPath.compile("/binding/"), "binding", "definitions")
                ])
                ])]),

            directory("resourceCollections", optional=True, children=[
                files("*.json", children=[
                    json_content(children=[
                    # collect_values(JsonPath.compile("/binding/"), "binding", "definitions")
                ])
                ])]),
            function(lambda x: print("FUNC:", x.properties['binding']['definitions']))
        ]).run(LinterArgs.parse_arguments(args)))


if __name__ == '__main__':
    main(sys.argv[1:])
