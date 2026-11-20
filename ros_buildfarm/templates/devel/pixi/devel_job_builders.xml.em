@# Build steps of a devel job for targets using the 'pixi' package format
@# (Windows). Included from devel/devel_job.xml.em in place of the Linux
@# build steps; the rest of the job configuration is shared.
@#
@# Unlike on Linux there is no container generating the task Dockerfiles:
@# the dependencies come from a distribution-wide pixi.toml, so nothing needs
@# to be resolved and create_pixi_devel_task.py renders them on the agent.
@#
@# The steps are batch files run by cmd.exe, as on ci.ros2.org. Every native
@# command is followed by an explicit error check on its own line, since
@# %ERRORLEVEL% is expanded when a line (or parenthesized block) is parsed.
@{
# EmPy code blocks can not use closures, so no helper functions which
# reference other names of this block.
check = 'if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%'
image_suffix = '%s_%s' % (rosdistro_name, source_repo_spec.name.lower())

# Arguments as double-quoted cmd strings with literal percent signs; the tool
# arguments are split on whitespace only like the unquoted expansion on Linux.
quoted_args = {}
for key, values in (
    ('env_vars', build_environment_variables),
    ('tool_args', (build_tool_args or '').split()),
    ('tool_test_args', (build_tool_test_args or '').split()),
):
    quoted_args[key] = []
    for value in values:
        assert '"' not in value, \
            'Double quotes are not supported in arguments on Windows: %s' % value
        quoted_args[key].append('"%s"' % value.replace('%', '%%'))

generate_cmds = []
tasks = []
for task, title, testing in (
    ('build_and_install', 'build and install', False),
    ('build_and_test', 'build and test', True),
):
    task_dir = '%%WORKSPACE%%\\docker_%s' % task
    tasks.append({
        'title': title,
        'dockerfile_dir': task_dir,
        'image': 'devel_%s.%s' % (task, image_suffix),
        'cid_file': '%s\\docker.cid' % task_dir,
    })
    generate_cmds += [
        ' '.join(
            [
                'python -u "%WORKSPACE%\\ros_buildfarm\\scripts\\devel\\pixi\\create_pixi_devel_task.py"',
                '--rosdistro-name', rosdistro_name,
                '--os-name', os_name,
                '--os-code-name', os_code_name,
                '--arch', arch,
                '--build-tool', build_tool,
                '--ros-version', str(ros_version),
                '--env-vars',
            ] + quoted_args['env_vars'] + [
                '--dockerfile-dir', '"%s"' % task_dir,
            ] + (['--testing'] if testing else []) +
            # must come last, they consume all remaining arguments
            ['--build-tool-args'] + quoted_args['tool_args'] +
            ['--build-tool-test-args'] + quoted_args['tool_test_args']),
        check,
    ]
volumes = [
    '%WORKSPACE%\\ros_buildfarm:C:\\ros_buildfarm:ro',
    '%WORKSPACE%\\ws:C:\\ws',
]
}@
@(SNIPPET(
    'builder_system-groovy_check-free-disk-space',
))@
@(SNIPPET(
    'builder_batch_docker-info',
))@
@# before the Dockerfile directories holding the .cid files are recreated
@(SNIPPET(
    'builder_batch_docker-remove-containers',
    cid_files=[task['cid_file'] for task in tasks],
))@
@(SNIPPET(
    'builder_batch_clone-ros-buildfarm',
    ros_buildfarm_repository=ros_buildfarm_repository,
    wrapper_scripts=wrapper_scripts,
))@
@(SNIPPET(
    'builder_batch',
    script='\n'.join([
        'echo # BEGIN SECTION: Generate Dockerfiles - devel tasks',
        'if exist "%WORKSPACE%\\docker_build_and_install" rmdir /S /Q "%WORKSPACE%\\docker_build_and_install"',
        'if exist "%WORKSPACE%\\docker_build_and_test" rmdir /S /Q "%WORKSPACE%\\docker_build_and_test"',
        'mkdir "%WORKSPACE%\\docker_build_and_install"',
        'mkdir "%WORKSPACE%\\docker_build_and_test"',
        'set "PYTHONPATH=%WORKSPACE%\\ros_buildfarm;%PYTHONPATH%"',
    ] + generate_cmds + [
        'echo # END SECTION',
    ]),
))@
@[for task in tasks]@
@(SNIPPET(
    'builder_batch_docker-build-and-run',
    title=task['title'],
    dockerfile_dir=task['dockerfile_dir'],
    image=task['image'],
    volumes=volumes,
    cid_file=task['cid_file'],
))@
@[end for]@
@(SNIPPET(
    'builder_batch',
    script='\n'.join([
        'if not "%skip_cleanup%" == "false" exit /b 0',
        'echo # BEGIN SECTION: Clean up to save disk space on agents',
        'if exist ws\\build_isolated rmdir /S /Q ws\\build_isolated',
        'if exist ws\\devel_isolated rmdir /S /Q ws\\devel_isolated',
        'if exist ws\\install_isolated rmdir /S /Q ws\\install_isolated',
        'echo # END SECTION',
    ]),
))@
@[if (not pull_request) and collate_test_stats]@
@(SNIPPET(
    'builder_batch',
    script='\n'.join([
        'echo # BEGIN SECTION: Create collated test stats dir',
        'if exist "%WORKSPACE%\\collated_test_stats" rmdir /S /Q "%WORKSPACE%\\collated_test_stats"',
        'mkdir "%WORKSPACE%\\collated_test_stats"',
        'echo # END SECTION',
    ]),
))@
@[end if]@
