@# Remove containers left behind by a previous build of this job.
@#
@# On Windows, aborting the batch step (or a timeout) kills the docker client
@# but not the container. Each 'docker run' records its container id in a .cid
@# file, which is removed after the run returns, so a .cid file that still
@# exists points to a container that may still be running.
@#
@# Run this before anything touches the mounted directories, since a running
@# container keeps files in them locked.
@#
@# Parameters:
@# - cid_files: list of .cid file paths (cmd syntax)
@{
lines = [
    'echo # BEGIN SECTION: Remove containers left over from previous builds',
]
for cid_file in cid_files:
    lines += [
        'if exist "%s" (' % cid_file,
        '  for /f "usebackq" %%%%i in ("%s") do docker rm -f %%%%i' % cid_file,
        '  del /F /Q "%s"' % cid_file,
        ')',
    ]
lines += [
    'echo # END SECTION',
    # the containers may be gone already, which is not an error
    'exit /b 0',
]
}@
@(SNIPPET(
    'builder_batch',
    script='\n'.join(lines),
))@
