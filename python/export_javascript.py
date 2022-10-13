import io
import os
import re
import sys
import json
from abc import ABC, abstractmethod
from typing import List, Optional

import json_utils

def log(message) -> None:
    sys.stderr.write(f"{message}\n")
    sys.stderr.flush()


class SymbolResolver(ABC):
    @abstractmethod
    def get_imports(self, source: str) -> List[str]:
        pass


class GetMatch(SymbolResolver):
    def __init__(self, regex, remove_suffix: Optional[str] = None) -> None:
        self.regex = regex
        self.remove_suffix = remove_suffix

    def get_imports(self, source: str) -> List[str]:
        results = list({match for match in re.findall(self.regex, source)})
        if self.remove_suffix:
            results = [result[:-len(self.remove_suffix)] for result in results
                             if result.endswith(self.remove_suffix)]
        return results


AUTO_IMPORT_SYMBOLS = frozenset([
    GetMatch("FlowException"),
    GetMatch("Java"),
    GetMatch("JavaString"),
    GetMatch("ListCanBuild"),
    GetMatch("ListHelper"),
    GetMatch("None"),
    GetMatch("Some"),
    GetMatch("UrlHelper"),
    GetMatch("_.", remove_suffix='.'),
    GetMatch("code_data_[^(]*"),
    GetMatch("code_model_[^(]*"),
    GetMatch("debug"),
    GetMatch("emptyConfig"),
    GetMatch("emptyMap"),
    GetMatch("error"),
    GetMatch("formatDate"),
    GetMatch("fromJValue"),
    GetMatch("getConfig"),
    GetMatch("item"),
    GetMatch("isEqual"),
    GetMatch("jArray"),
    GetMatch("jValueToString"),
    GetMatch("metric"),
    GetMatch("newList"),
    GetMatch("parseDateString"),
    GetMatch("payload"),
    GetMatch("toKVList"),
    GetMatch("toJValue"),
    GetMatch("toKVMap"),
    GetMatch("toMap"),
    GetMatch("toMapOfAny"),
    GetMatch("trace"),
    GetMatch("urlCompose"),
    GetMatch("urlEncode"),
    GetMatch("valuesFromDbRow"),
    GetMatch("warn"),
    GetMatch("EncodingHelper")
])


def export_javascript(json_object, path):
    if isinstance(json_object, list):
        for i, obj in enumerate(json_object):
            export_javascript(obj, path + [i])
    elif isinstance(json_object, dict):
        if 'name' in json_object:
            path.append(json_object['name'])
        for key, value in json_object.items():
            export_javascript(value, path + [key])
    elif isinstance(json_object, str):
        javascript_properties = ('jsFunc', )
        property_name = path[-1]
        if property_name in javascript_properties:
            export_javascript_source(json_object, path)


def get_source_file_path(path) -> str:
    dirs=path[2].split('@')
    dirs.reverse()
    return f"jsExport/{'/'.join(dirs)}/{path[4]}.js"


def get_imports(source: str) -> List[str]:
    result = []
    for action in AUTO_IMPORT_SYMBOLS:
        result.extend(action.get_imports(source))
    return list(x for x in set(result) if x)


def get_prologue(source: str, flow_name: str, step_name: str) -> str:
    code = io.StringIO()
    code.write("'use strict';\n")
    code.write(f'/**\n')
    code.write(f' * Flow: {flow_name}\n')
    code.write(f' * Step: {step_name}\n')
    code.write(f' */\n')
    code.write('(function(')
    code.write(', '.join(get_imports(source)))
    code.write(') {\n')
    return code.getvalue()


def format_function_body(body) -> str:
    return '\n'.join(['  ' + line.rstrip()
                      for line in (body.strip()
                                   .replace("\\n", "\n")
                                   .split('\n'))])


def export_javascript_source(source, path) -> None:
    javascript_epilogue = """
})();
"""
    outfile = get_source_file_path(path)
    os.makedirs(os.path.dirname(outfile), exist_ok=True)
    with open(outfile, "w") as file:
        file.write(get_prologue(source, path[2], path[4]))
        file.write(format_function_body(source))
        file.write(javascript_epilogue)


def export_javascript_from_file(filename: str) -> None:
    fixed_json = json_utils.fix_json_file(filename)
    try:
        flows = json.loads(fixed_json)
        export_javascript(flows, [filename])
    except json.decoder.JSONDecodeError as ex:
        print("Error in JSON: ----\n%s\n----\n" % fixed_json[ex.pos - 40: ex.pos + 40])


def main() -> None:
    for filename in sys.argv[1:]:
        export_javascript_from_file(filename)
    pass


if __name__ == '__main__':
    main()
