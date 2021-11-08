from distutils.core import setup

setup(
    name='flint',
    version='0.1dev',
    packages=['flint',],
    install_requires=[
        "jsonschema",
        "PyYAML"
        ]
)
