import argparse

import json
import json_utils

from io import StringIO

def parse_arguments():
    parser = argparse.ArgumentParser(description='convert flows to and from other formats')
    parser.add_argument('--from', type=str, required=True, choices={'json', 'js'},
                        dest='from_format',
                        help='source type (e.g. json, js)')
    parser.add_argument('--to', type=str, required=True, choices={'json', 'js'},
                        dest='to_format',
                        help='destination type (e.g. json, js)')
    parser.add_argument('--input', type=str, required=True,
                        help='input file')
    parser.add_argument('--output', type=str, required=False,
                        help='output file')
    return parser.parse_args()


def convert_json_to_js(input_filename, output_filename):
    buffer = StringIO()

    buffer.write(f"""
/**
 * Input File: {input_filename}
 */
    """)
    fixed_json = json_utils.fix_json_file(input_filename)
    json_object = json.loads(fixed_json)
    for obj in json_object:
        for name, definition in obj['processors'].items():
            has_code = 'config' in definition and 'jsFunc' in definition['config']
            if has_code:
                code = definition['config']['jsFunc']
                buffer.write(f"""
function foo() {{
    {json_utils.format_javascript(code)}
}}
""")

    print(buffer.getvalue())


#         code = f"""
# {obj['config']['jsFunc']}
# """
#         buffer.write(comment)
#         buffer.write(code)


def main():
    args = parse_arguments()
    if args.from_format == args.to_format == 'js':
        print("nothing to do")
    elif args.from_format == 'json' and args.to_format == 'js':
        convert_json_to_js(args.input, args.output)


if __name__ == '__main__':
    main()
