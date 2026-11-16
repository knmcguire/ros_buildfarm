# escape=`
# generated from @template_name
@#
@# Windows build environment for devel jobs using the 'pixi' package format.
@# Ported from ros2/ci windows_docker_resources/Dockerfile (without Connext).
@# The escape directive must stay on the very first line of the output.
@{
assert arch == 'amd64', "Windows targets only support 'amd64', not '%s'" % arch
pixi_toml_url = vars().get('pixi_toml_url') or \
    'https://raw.githubusercontent.com/ros2/ros2/refs/heads/%s/pixi.toml' % rosdistro_name
}@

# The image version must match the host for process isolation;
# an older image than the host requires --isolation=hyperv.
FROM mcr.microsoft.com/windows/server:@(os_code_name)

# Enable long paths
RUN powershell -NoProfile -Command "New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1 -PropertyType DWORD -Force"

# Install MSVC 2022 build tools
RUN powershell -NoProfile -Command "irm https://aka.ms/vs/17/release/vs_buildtools.exe -OutFile vs_buildtools_2022.exe"
RUN vs_buildtools_2022.exe --quiet --wait --norestart --add Microsoft.Component.MSBuild --add Microsoft.Net.Component.4.6.1.TargetingPack --add Microsoft.Net.Component.4.8.SDK --add Microsoft.VisualStudio.Component.CoreBuildTools --add Microsoft.VisualStudio.Component.Roslyn.Compiler --add Microsoft.VisualStudio.Component.TextTemplating --add Microsoft.VisualStudio.Component.VC.CLI.Support --add Microsoft.VisualStudio.Component.VC.CoreBuildTools --add Microsoft.VisualStudio.Component.VC.CoreIde --add Microsoft.VisualStudio.Component.VC.Redist.14.Latest --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK --add Microsoft.VisualStudio.Component.Windows11SDK.22621 --add Microsoft.VisualStudio.ComponentGroup.NativeDesktop.Core --add Microsoft.VisualStudio.Workload.MSBuildTools --add Microsoft.VisualStudio.Workload.VCTools

# Install a pinned and checksum-verified version of Pixi
RUN powershell -NoProfile -Command "irm https://github.com/prefix-dev/pixi/releases/download/v0.78.0/pixi-x86_64-pc-windows-msvc.zip -OutFile pixi-x86_64-pc-windows-msvc.zip"
RUN powershell -NoProfile -Command "if ((Get-FileHash pixi-x86_64-pc-windows-msvc.zip -Algorithm SHA256).Hash -ne '0655d6e11aa1dae56067f266d48b3c5815c02ed0031d5f3e96a1b0b81e1555b4') { exit 1 }"
RUN powershell -NoProfile -Command "Expand-Archive -Path pixi-x86_64-pc-windows-msvc.zip -DestinationPath (Join-Path $Env:USERPROFILE\.pixi 'bin') -Force"
RUN powershell -NoProfile -Command "$bindir = Join-Path $Env:USERPROFILE\.pixi 'bin' ; $pathkey = (Get-Item -Path 'HKCU:').OpenSubKey('Environment', $true) ; $oldpath = $pathkey.GetValue('PATH', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) ; $pathkey.SetValue('PATH', \"$bindir;$oldpath\", [Microsoft.Win32.RegistryValueKind]::String)"

# automatic invalidation once every day
RUN echo "@today_str"

# Install the dependencies of the ROS distribution with Pixi
WORKDIR C:\pixi_ws
ADD @(pixi_toml_url) pixi.toml
RUN powershell -NoProfile -Command "(Get-Item pixi.toml).LastWriteTime = Get-Date"
RUN pixi --color never --no-progress -q install -e buildfarm
RUN pixi --color never --no-progress -q list -e buildfarm

@(TEMPLATE(
    'snippet/set_environment_variables.Dockerfile.em',
    environment_variables=build_environment_variables,
))@

ENV PYTHONPATH=C:\ros_buildfarm
WORKDIR C:\
@{
cmd = \
    'call "C:\\Program Files (x86)\\Microsoft Visual Studio\\2022\\BuildTools\\VC\\Auxiliary\\Build\\vcvarsall.bat" x86_amd64' + \
    ' && pixi run --manifest-path C:\\pixi_ws\\pixi.toml --frozen -e buildfarm python -u'
if not testing:
    cmd += \
        ' C:\\ros_buildfarm\\scripts\\devel\\build_and_install.py' + \
        ' --rosdistro-name ' + rosdistro_name + \
        ' --ros-version ' + str(ros_version) + \
        ' --clean-before'
else:
    cmd += \
        ' C:\\ros_buildfarm\\scripts\\devel\\build_and_test.py' + \
        ' --rosdistro-name ' + rosdistro_name + \
        ' --ros-version ' + str(ros_version)
cmd += \
    ' --build-tool ' + build_tool + \
    ' --workspace-root ' + workspace_root
if vars().get('build_tool_args'):
    cmd += ' --build-tool-args ' + ' '.join(build_tool_args)
if vars().get('build_tool_test_args'):
    cmd += ' --build-tool-test-args ' + ' '.join(
        a if ' ' not in a else '"%s"' % a for a in build_tool_test_args)
}@
# Shell form so that cmd.exe runs it; /S strips the outer quotes
CMD "@(cmd)"
