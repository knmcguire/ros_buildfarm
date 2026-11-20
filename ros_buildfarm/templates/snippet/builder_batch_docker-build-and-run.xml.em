@# Build a Windows Docker image from a generated Dockerfile and run it once.
@#
@# Parameters:
@# - title: suffix of the section names (e.g. 'build and install')
@# - dockerfile_dir: directory containing the Dockerfile (cmd syntax)
@# - image: tag of the image to build and run
@# - volumes: list of 'host:container[:ro]' mount specifications
@# - cid_file: path of the .cid file recording the container id; a leftover
@#   file is handled by builder_batch_docker-remove-containers
@# - isolation (optional): Docker isolation mode, 'process' (default) or
@#   'hyperv'. Process isolation requires the image's Windows version to match
@#   the host's, so the agent's Windows version decides this.
@{
check = 'if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%'
isolation = vars().get('isolation') or 'process'
}@
@(SNIPPET(
    'builder_batch',
    script='\n'.join([
        'echo # BEGIN SECTION: Build Dockerfile - %s' % title,
        'cd /d "%s"' % dockerfile_dir,
        'python -u "%WORKSPACE%\\ros_buildfarm\\scripts\\misc\\docker_pull_baseimage.py"',
        check,
        'docker build --force-rm --isolation=%s -t %s .' % (isolation, image),
        check,
        'echo # END SECTION',
        '',
        'echo # BEGIN SECTION: Run Dockerfile - %s' % title,
        'docker run' +
        ' --rm' +
        ' --isolation=%s' % isolation +
        ' --cidfile="%s"' % cid_file +
        ''.join(' -v "%s"' % v for v in volumes) +
        ' ' + image,
        # keep the exit code while removing the .cid file of the container,
        # which --rm has removed; if this step is aborted the file remains
        'set "DOCKER_RUN_RC=%ERRORLEVEL%"',
        'del /F /Q "%s"' % cid_file,
        'if %DOCKER_RUN_RC% neq 0 exit /b %DOCKER_RUN_RC%',
        'cd /d "%WORKSPACE%"',
        'echo # END SECTION',
    ]),
))@
