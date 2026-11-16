@@echo off
@#
@# Batch file counterpart of devel_script.sh.em for targets whose build steps
@# are batch files (Windows). Each build step runs as a subroutine with its own
@# environment scope, starting in the workspace, like a Jenkins batch step.
@# This also keeps an 'exit /b' in a step from ending the whole script.
@#
@# Labels and 'goto' are used instead of parenthesized blocks, since cmd.exe
@# expands %ERRORLEVEL% in a block when the block is parsed.
@{
check = 'if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%'
clone_cmds = {
    'git': [
        'git clone --recurse-submodules -b {version} {url} {path}',
        'git -C {path} --no-pager log -n 1',
    ],
    'hg': [
        'hg clone -b {version} {url} {path}',
        'hg --cwd {path} log -l 1',
    ],
    'svn': [
        'svn checkout -r {version} {url} {path}',
        'svn log -l 1 {path}',
    ],
}
}@
setlocal

echo Devel job: @devel_job_name
echo.
echo By default this script will not return an error code if any tests fail.
echo If you want the script to return a non-zero return code in that case
echo you can set the environment variable ABORT_ON_TEST_FAILURE=1.
echo.

set "WORKSPACE=%CD%"
echo Use workspace: %WORKSPACE%
echo.

set "OTHER_ITEMS="
for /f "delims=" %%f in ('dir /b /a') do if /i not "%%f" == "%~nx0" set "OTHER_ITEMS=1"
if not defined OTHER_ITEMS goto check_done
echo This script should be executed either in an empty folder or in a folder only containing the script itself 1>&2
if /i "%~1" == "-y" goto check_continue
set "answer="
set /p "answer=Do you wish to continue anyway, this might overwrite existing files and folders? (y/N) "
if /i "%answer%" == "y" goto check_continue
if /i "%answer%" == "yes" goto check_continue
exit /b 1
:check_continue
echo.
:check_done

echo.
echo Clone source repositories
echo.

rem list of repositories to clone
@[for repo_spec, _ in scms]@
rem - @repo_spec.name (@repo_spec.type, @repo_spec.url, @repo_spec.version)
@[end for]@

if not exist ws\src mkdir ws\src

@[for i, (repo_spec, path) in enumerate(scms)]@
@{
path = path.replace('/', '\\')
}@
if exist "@path" goto clone_skip_@(i)
@[  if repo_spec.type in clone_cmds]@
@[    for cmd in clone_cmds[repo_spec.type]]@
@{
cmd = cmd.format(version=repo_spec.version, url=repo_spec.url, path=path)
}@
echo + @cmd
@cmd
@check
@[    end for]@
@[  else]@
echo Unsupported repository type '@repo_spec.type' (@repo_spec.url)
exit /b 1
@[  end if]@
goto clone_done_@(i)
:clone_skip_@(i)
echo Skip cloning '@repo_spec.name' as it already exists (@path)
:clone_done_@(i)
echo.

@[end for]@

echo.
echo Build workspace
echo.

@[for i, _ in enumerate(scripts)]@
echo Build step @(i + 1)
call :build_step_@(i + 1)
@check
echo.

@[end for]@

echo.
echo Test results
echo.

@[if build_tool == 'catkin_make_isolated']@
set "test_result_EXECUTABLE=catkin_test_results"
set "test_result_CMD=catkin_test_results "%WORKSPACE%\ws\test_results" --all"
@[elif build_tool == 'colcon']@
set "test_result_EXECUTABLE=colcon"
set "test_result_CMD=colcon test-result --test-result-base "%WORKSPACE%\ws\test_results" --all"
@[else]@
echo Unsupported build tool: @build_tool
exit /b 1
@[end if]@

set "test_result_RC=0"
where %test_result_EXECUTABLE% >nul 2>nul
if %ERRORLEVEL% neq 0 goto test_result_not_found
@[if build_tool == 'colcon']@
colcon test-result --help >nul 2>nul
if %ERRORLEVEL% neq 0 goto test_result_no_extension
@[end if]@
echo Invoking: %test_result_CMD%
%test_result_CMD%
set "test_result_RC=%ERRORLEVEL%"
goto test_result_done
:test_result_not_found
echo '%test_result_EXECUTABLE%' not found on the PATH. Please make sure the tool is installed and the environment is setup (if applicable) to output the test result summary.
goto test_result_done
:test_result_no_extension
echo '%test_result_EXECUTABLE% test-result' not available. Please make sure the necessary extension is installed to output the test result summary.
:test_result_done

if not defined ABORT_ON_TEST_FAILURE exit /b 0
if "%ABORT_ON_TEST_FAILURE%" == "0" exit /b 0
exit /b %test_result_RC%

@[for i, script in enumerate(scripts)]@
:build_step_@(i + 1)
setlocal
cd /d "%WORKSPACE%"
@(script)
goto :eof

@[end for]@
