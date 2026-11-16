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
Generate the 'Dockerfile' of a devel task for the 'pixi' package format.

Counterpart of create_devel_task_generator.py for targets whose dependencies
come from a distribution-wide pixi.toml. Nothing needs to be resolved inside
a container of the target platform, so this runs directly on the agent.
"""

import argparse
import sys

from ros_buildfarm.argument import add_argument_build_tool
from ros_buildfarm.argument import add_argument_build_tool_args
from ros_buildfarm.argument import add_argument_build_tool_test_args
from ros_buildfarm.argument import add_argument_dockerfile_dir
from ros_buildfarm.argument import add_argument_env_vars
from ros_buildfarm.argument import add_argument_ros_version
from ros_buildfarm.argument import extract_multiple_remainders
from ros_buildfarm.templates import create_dockerfile


def main(argv=sys.argv[1:]):
    parser = argparse.ArgumentParser(
        description="Generate a 'Dockerfile' for a devel task using Pixi")
    parser.add_argument(
        '--rosdistro-name',
        required=True,
        help='The name of the ROS distro')
    parser.add_argument(
        '--workspace-root',
        default='C:\\ws',
        help='The root path of the workspace inside the container')
    parser.add_argument(
        '--os-name',
        required=True,
        help="The OS name (e.g. 'windows')")
    parser.add_argument(
        '--os-code-name',
        required=True,
        help="The OS code name (e.g. 'ltsc2025')")
    parser.add_argument(
        '--arch',
        required=True,
        help="The architecture (e.g. 'amd64')")
    parser.add_argument(
        '--pixi-toml-url',
        help='The URL of the pixi.toml providing the dependencies '
             '(default: the one of the ROS distro in ros2/ros2)')
    add_argument_build_tool(parser, required=True)
    add_argument_ros_version(parser)
    add_argument_env_vars(parser)
    add_argument_dockerfile_dir(parser)
    a1 = add_argument_build_tool_args(parser)
    a2 = add_argument_build_tool_test_args(parser)
    parser.add_argument(
        '--testing',
        action='store_true',
        help='The flag if the workspace should be built with tests enabled '
             'and instead of installing the tests are ran')

    remainder_args = extract_multiple_remainders(argv, (a1, a2))
    args = parser.parse_args(argv)
    for k, v in remainder_args.items():
        setattr(args, k, v)

    data = {
        'os_name': args.os_name,
        'os_code_name': args.os_code_name,
        'arch': args.arch,
        'rosdistro_name': args.rosdistro_name,
        'pixi_toml_url': args.pixi_toml_url,
        'build_tool': args.build_tool,
        'build_tool_args': args.build_tool_args,
        'build_tool_test_args': args.build_tool_test_args,
        'ros_version': args.ros_version,
        'build_environment_variables': [
            '%s=%s' % key_value for key_value in args.env_vars.items()],
        'testing': args.testing,
        'workspace_root': args.workspace_root,
    }
    create_dockerfile(
        'devel/pixi/devel_task.Dockerfile.em', data, args.dockerfile_dir)


if __name__ == '__main__':
    sys.exit(main())
