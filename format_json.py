"""
Formats a JSON file that contains JavaScript by indenting the JSON and adding
newline characters and tabs.
"""
import sys
import json_utils


def main(files):
    for file in files:
        formatted_json = None
        with open(file, 'r') as infile:
            fixed_json = json_utils.fix_json(infile.read())
            formatted_json = json_utils.format_json_text(fixed_json)
        with open(file, 'w') as outfile:
            outfile.write(formatted_json)


if __name__ == '__main__':
    main(sys.argv[1:])
