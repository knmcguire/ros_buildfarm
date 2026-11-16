@# Batch file counterpart of builder_shell_clone-ros-buildfarm.xml.em
@{
import base64
filename = 'git.py'
# cmd.exe has no way to write a multi-line file verbatim, so the wrapper
# script is passed base64-encoded to Python (the alphabet needs no escaping)
encoded = base64.b64encode(wrapper_scripts[filename].encode('utf-8')).decode('ascii')
check = 'if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%'
}@
@(SNIPPET(
    'builder_batch',
    script='\n'.join([
        'echo # BEGIN SECTION: Embed wrapper scripts',
        'if exist wrapper_scripts rmdir /S /Q wrapper_scripts',
        'mkdir wrapper_scripts',
        'python -c "import base64, sys; open(sys.argv[1], \'wb\').write(base64.b64decode(sys.argv[2]))" wrapper_scripts\\%s %s' % (filename, encoded),
        check,
        'echo # END SECTION',
    ]),
))@
@{
import re
cmds = []
if ros_buildfarm_repository.version and re.match('[0-9a-f]{40}', ros_buildfarm_repository.version):
    # cannot create a shallow clone for hashes
    cmds += [
        'python -u wrapper_scripts\\git.py clone %s ros_buildfarm' % ros_buildfarm_repository.url,
        check,
        'git -C ros_buildfarm checkout %s' % ros_buildfarm_repository.version,
        check,
    ]
else:
    # shallow clone when version is a branch or tag
    cmds += [
        'python -u wrapper_scripts\\git.py clone --depth 1 %s%s ros_buildfarm' % ('-b %s ' % ros_buildfarm_repository.version if ros_buildfarm_repository.version else '', ros_buildfarm_repository.url),
        check,
    ]
}@
@(SNIPPET(
    'builder_batch',
    script='\n'.join([
        'echo # BEGIN SECTION: Clone ros_buildfarm',
        'if exist ros_buildfarm rmdir /S /Q ros_buildfarm',
    ] + cmds + [
        'git -C ros_buildfarm --no-pager log -n 1',
        check,
        'rmdir /S /Q ros_buildfarm\\.git ros_buildfarm\\doc',
        'echo # END SECTION',
    ]),
))@
