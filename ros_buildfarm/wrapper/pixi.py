# Copyright 2026 Open Source Robotics Foundation, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Retry wrapper around pixi, mirroring the apt and dnf wrappers.

Packages are added to the pixi workspace found in the current directory, or
the one passed with --manifest-path / -m.

- 'update' drops pixi's cached repodata, so the next solve fetches it fresh.
- 'update-install-clean' runs 'update', then 'pixi add <args>', then
  'pixi clean cache' to keep image layers small. Installed environments are
  not touched by cleaning the cache.
"""

import subprocess
import sys
from time import sleep

# Pixi never prompts, accept these so callers can pass the same arguments as
# to the apt and dnf wrappers.
IGNORED_ARGS = ('-y', '--yes', '--assume-yes')

UPDATE_ARGV = ['clean', 'cache', '--repodata', '--yes']
CLEAN_ARGV = ['clean', 'cache', '--yes']


def main(argv=sys.argv[1:]):
    # Pixi's error reports contain non-ASCII characters, which can't always
    # be encoded for the console (e.g. cp1252 on Windows).
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(errors='replace')

    max_tries = 10
    # Pixi already retries each request a few times before reporting these.
    known_error_strings = [
        'Request failed after',
        'error sending request',
        'HTTP status server error',
    ]

    command = argv[0]
    if command == 'update':
        rc, _, _ = call_pixi_repeatedly(
            UPDATE_ARGV, known_error_strings, max_tries)
        return rc
    elif command == 'update-install-clean':
        install_argv = [arg for arg in argv[1:] if arg not in IGNORED_ARGS]
        return call_pixi_update_install_clean(
            install_argv, known_error_strings, max_tries)
    else:
        assert False, "Command '%s' not implemented" % command


def call_pixi_update_install_clean(
        install_argv, known_error_strings, max_tries):
    tries = 0
    command = 'update'
    while tries < max_tries:
        if command == 'update':
            rc, _, tries = call_pixi_repeatedly(
                UPDATE_ARGV, known_error_strings, max_tries - tries,
                offset=tries)
            if rc != 0:
                # abort if update was unsuccessful even after retries
                break
            # move on to the install command if update was successful
            command = 'install'

        if command == 'install':
            # any call is considered a try
            tries += 1
            known_error_strings_redo_update = [
                # can be caused by stale cached repodata
                'No candidates were found',
            ]
            rc, known_error_conditions = call_pixi(
                ['add'] + install_argv,
                known_error_strings + known_error_strings_redo_update)
            if not known_error_conditions:
                if rc != 0:
                    # abort if install was unsuccessful
                    break
                # move on to the clean command if install was successful
                command = 'clean'
                continue

            # check if update needs to be rerun
            if (
                set(known_error_conditions) &
                set(known_error_strings_redo_update)
            ):
                command = 'update'
                print("'pixi add' failed and likely requires the cached "
                      'repodata to be refreshed')
                # retry with update command
                continue

            print('')
            print('Invocation failed due to the following known error '
                  'conditions: ' + ', '.join(known_error_conditions))
            print('')
            if tries < max_tries:
                sleep_time = 5
                print("Reinvoke 'pixi add' after sleeping %s seconds" %
                      sleep_time)
                sleep(sleep_time)
                # retry install command

        if command == 'clean':
            rc, _ = call_pixi(CLEAN_ARGV, [])
            break

    return rc


def call_pixi_repeatedly(argv, known_error_strings, max_tries, offset=0):
    command = ' '.join(argv[:2])
    for i in range(1, max_tries + 1):
        if i > 1:
            sleep_time = 5 + 2 * (i + offset)
            print("Reinvoke 'pixi %s' (%d/%d) after sleeping %s seconds" %
                  (command, i + offset, max_tries + offset, sleep_time))
            sleep(sleep_time)
        rc, known_error_conditions = call_pixi(argv, known_error_strings)
        if not known_error_conditions:
            # break the loop and return the reported rc
            break
        print('')
        print('Invocation failed due to the following known error conditions: '
              ', '.join(known_error_conditions))
        print('')
        # retry in case of failure with known error condition
    return rc, known_error_conditions, i + offset


def call_pixi(argv, known_error_strings):
    cmd = ['pixi'] + argv
    print("Invoking '%s'" % ' '.join(cmd))
    proc = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    lines = []
    while True:
        line = proc.stdout.readline()
        if not line:
            break
        line = line.decode('utf-8', errors='replace')
        lines.append(line)
        sys.stdout.write(line)
    proc.wait()
    rc = proc.returncode

    # Unlike apt and dnf, only look for known errors if pixi failed: it also
    # reports network errors as warnings for requests it recovered from.
    known_error_conditions = []
    if rc:
        known_error_conditions = find_known_error_conditions(
            ''.join(lines), known_error_strings)
    if rc and not known_error_conditions:
        print('Invocation failed without any known error condition, '
              'printing all lines to debug known error detection:')
        for index, line in enumerate(lines):
            print(' ', index + 1, "'%s'" % line.rstrip('\n\r'))
        print('None of the following known errors were detected:')
        for index, known_error_string in enumerate(known_error_strings):
            print(' ', index + 1, "'%s'" % known_error_string)
    return rc, known_error_conditions


def find_known_error_conditions(output, known_error_strings):
    # Pixi wraps long error messages and draws them as a tree of non-ASCII
    # characters, so a message can span lines. Drop the non-ASCII characters
    # and collapse whitespace before matching.
    output = ''.join(c if ord(c) < 128 else ' ' for c in output)
    output = ' '.join(output.split())
    return [s for s in known_error_strings if s in output]


if __name__ == '__main__':
    sys.exit(main())
