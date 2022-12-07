import io
import sys
import json
from enum import Enum, auto
from typing import Optional


class _State(Enum):
    INIT = auto()
    OBJECT = auto()
    ARRAY = auto()
    STRING_SINGLE = auto()
    STRING_DOUBLE = auto()


class _Position:
    def __init__(self) -> None:
        self.line = 1
        self.column = 1
    def on_character(self, c: str) -> None:
        if c == '\n':
            self.line += 1
            self.column = 1
        else:
            self.column += 1
    def __str__(self) -> str:
        return f"line: {self.line}, column: {self.column}"


class _Stack:
    def __init__(self):
        self.stack = []

    def push(self, state: _State) -> None:
        self.stack.append(state)

    def pop(self) -> _State:
        assert len(self.stack), "popping from empty stack"
        return self.stack.pop()

    def current(self):
        assert len(self.stack), "getting current of empty stack"
        return self.stack[-1]

    def size(self) -> int:
        return len(self.stack)

    def __str__(self) -> str:
        return ', '.join([state.name for state in self.stack])


class _JsonFixer:
    def __init__(self) -> None:
        self.position = _Position()
        self.stack = _Stack()
        self.stack.push(_State.INIT)
        self.output = io.StringIO()
        self.escaped = False

    def on_character(self, c: str) -> None:
        escaped = self.escaped
        if escaped:
            self.escaped = False
        if self.stack.current() in (_State.STRING_DOUBLE, _State.STRING_SINGLE):
            if c == '\\':
                self.escaped = True
            if c == '\n':
                c = '\\n'
            elif c == '\t':
                c = '\\t '
            elif not escaped and _JsonFixer._string_type(c) == self.stack.current():
                self.stack.pop()
        elif c == '[':
            self.stack.push(_State.ARRAY)
        elif c == '{':
            self.stack.push(_State.OBJECT)
        elif c == ']':
            self.stack.pop()
        elif c == '}':
            self.stack.pop()
        elif c == '"':
            self.stack.push(_State.STRING_DOUBLE)
        elif c == "'":
            self.stack.push(_State.STRING_SINGLE)
        self.output.write(c)

    def fix_json(self, json_text: str) -> str:
        for c in json_text:
            self.on_character(c)
        return self.output.getvalue()

    @staticmethod
    def _string_type(c: str) -> Optional[_State]:
        if c == '"':
            return _State.STRING_DOUBLE
        elif c == "'":
            return _State.STRING_SINGLE
        return None

    def __str__(self) -> str:
        return f"_Stack: {self.stack}, _Position: {self.position}"


def fix_json_file(filename: str, in_place: Optional[bool]=False) -> str:
    fixed_json = None
    with open(filename, 'r') as file:
        fixed_json = fix_json(file.read())
    if in_place:
        with open(filename, 'w') as file:
            file.write(fixed_json)
    return fixed_json


def fix_json(json_text: str) -> str:
    return _JsonFixer().fix_json(json_text)


def format_javascript(body) -> str:
    if body:
        result = '\n'.join([line.rstrip()
                        for line in (body.strip()
                                    .replace('\\', '\\\\')
                                    .replace('"', '\\"')
                                    .split('\n'))])
        return result
    return ''


def format_json_text(json_text: str) -> str:
    json_object = json.loads(json_text)
    string_io = io.StringIO()
    format_json(json_object, string_io, 0)
    return string_io.getvalue()


def _indent(s: str, level: int) -> str:
    return '\n' + '\n'.join([('  ' * level) + line
                             for line in s.split('\n')])


def _format_dict(json_dict, string_io: io.StringIO, level: int) -> None:
    first = True
    string_io.write("{")
    for key, value in json_dict.items():
        if not first:
            string_io.write(",")
        first = False
        string_io.write(_indent(f'"{key}": ', level + 1))
        javascript_properties = (
            'jsFunc',
            'testDataTransformFunc',
            'testData',
            'assertionFunc'
        )
        if value and (key in javascript_properties):
            js_code = format_javascript(value)
            string_io.write('"')
            string_io.write(_indent(f'{js_code}\n"', 0))
        else:
            format_json(value, string_io, level + 1)
    if json_dict:
        string_io.write(_indent("}", level))
    else:
        string_io.write("}")


def _format_list(json_list, string_io: io.StringIO, level: int) -> None:
        first = True
        string_io.write("[")
        for obj in json_list:
            if not first:
                string_io.write(",")
            string_io.write(_indent("", level+ 1))
            format_json(obj, string_io, level + 1)
            first = False
        if json_list:
            string_io.write(_indent("]", level))
        else:
            string_io.write("]")


def format_json(json_object: str, string_io: io.StringIO, level: int) -> None:
    if isinstance(json_object, dict):
        _format_dict(json_object, string_io, level)
    elif isinstance(json_object, list):
        _format_list(json_object, string_io, level)
    elif isinstance(json_object, str):
        json_object = json_object.replace('\\', '\\\\').replace('"', '\\"')
        string_io.write(f'"{json_object}"')
    elif isinstance(json_object, float):
        string_io.write(str(json_object))
    elif isinstance(json_object, bool):
        string_io.write('true' if json_object else 'false')
    elif isinstance(json_object, int):
        string_io.write(str(json_object))
    elif json_object is None:
        string_io.write('null')
    else:
        raise Exception(f"Don't know how to format a {type(json_object)} like: {json_object}")


def main(files):
    for file in files:
        fix_json_file(file, in_place=True)


if __name__ == '__main__':
    main(sys.argv[1:])
