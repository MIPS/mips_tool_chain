#! python

import argparse
import json
import os
import subprocess


def parse_args():
    """Parse the command line arguments."""
    parser = argparse.ArgumentParser()

    parser.add_argument(
        '--version',
        default='2019.09-01',
        help='Toolchain version to build')

    parser.add_argument(
        '--workroot',
        default='.',
        help='Workroot for building toolchain')

    parser.add_argument(
        '--no-build',
        action='store_true',
        default=False,
        help='Do the build?')

    args = parser.parse_args()

    return args


def create_workdir(workroot, version):
    """Create a workdir for version under workroot, return its path."""
    workdir = os.path.join(workroot, f"build-{version}")
    if os.path.exists(workdir):
        raise ValueError(f"""\
Workdir '{workdir}' already exists. Delete it first, or choose another \
--workroot or --version""")
    os.mkdir(workdir)
    return workdir


def link_sconstruct(workdir, build_script_dir):
    """Link the sconstruct file which does the build work under workdir."""
    src = os.path.join(build_script_dir, 'darwin.sconstruct')
    dst = os.path.join(workdir, 'SConstruct')
    os.symlink(src, dst)

    
def create_configfile(workdir, version, build_script_dir):
    """Create a configfile in the workdir, to be read by scons."""
    configfile = os.path.join(workdir, 'config.json')
    config = {
        'version': version,
        'build_script_dir': build_script_dir,
    }
    with open(configfile, 'w') as fh:
        json.dump(config, fh, indent=4, sort_keys=True)


def run_scons(workdir):
    """Run scons in the workdir."""
    subprocess.run(['scons'], cwd=workdir, check=True)


def main():
    """The main function of the program."""

    args = parse_args()

    # Setup a work directory under the workroot
    workdir = create_workdir(args.workroot, args.version)

    build_script_dir = os.path.abspath(os.path.dirname(__file__))

    # Link the SConstruct file in the work directory
    link_sconstruct(workdir, build_script_dir)

    # Create a json config file in the work directory
    create_configfile(workdir, args.version, build_script_dir)

    # Run scons
    if not args.no_build:
        run_scons(workdir)


if __name__ == '__main__':
    main()
