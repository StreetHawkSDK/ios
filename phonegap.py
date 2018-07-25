#!/usr/bin/python
"""
Usage:
    phonegap paths <path>
    phonegap version <version>

"""
from os.path import join
from glob import glob
import pathlib
from docopt import docopt


def update_paths(opts):
    src_root = opts.get('<path>', 'StreetHawk/Classes')

    files = sorted(
        glob(join(src_root, '**/*.h'), recursive=True) +
        glob(join(src_root, '**/*.m'), recursive=True)
    )
    for file_ in files:
        path_ = pathlib.Path(file_).relative_to(src_root)
        path_ = pathlib.Path("src/ios/SDK").joinpath(path_)
        if str(path_).endswith('.h'):
            print('<header-file src="%s" />' % path_)
        else:
            print('<source-file src="%s" />' % path_)


def update_version(opts):
    pass


def 
if __name__ == "__main__":
    opts = docopt(__doc__)
    if opts['paths']:
        update_paths(opts)
    elif opts['version']:
        update_version(opts)
