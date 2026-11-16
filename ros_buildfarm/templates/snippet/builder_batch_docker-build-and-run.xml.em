@# Build a Windows Docker image from a generated Dockerfile and run it once.
@#
@# Parameters:
@# - title: suffix of the section names (e.g. 'build and install')
@# - dockerfile_dir: directory containing the Dockerfile (cmd syntax)
@# - image: tag of the image to build and run
@# - volumes: list of 'host:container[:ro]' mount specifications
@{
check = 'if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%'
}@
@(SNIPPET(
    'builder_batch',
    script='\n'.join([
        'echo # BEGIN SECTION: Build Dockerfile - %s' % title,
        'cd /d "%s"' % dockerfile_dir,
        'python -u "%WORKSPACE%\\ros_buildfarm\\scripts\\misc\\docker_pull_baseimage.py"',
        check,
        'docker build --force-rm -t %s .' % image,
        check,
        'echo # END SECTION',
        '',
        'echo # BEGIN SECTION: Run Dockerfile - %s' % title,
        'docker run' +
        ' --rm' +
        ''.join(' -v "%s"' % v for v in volumes) +
        ' ' + image,
        check,
        'cd /d "%WORKSPACE%"',
        'echo # END SECTION',
    ]),
))@
