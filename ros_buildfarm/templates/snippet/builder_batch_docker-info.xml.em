@(SNIPPET(
    'builder_batch',
    script='\n'.join([
        'echo # BEGIN SECTION: cpu info',
        'powershell -NoProfile -Command "Get-CimInstance Win32_Processor | Format-List Name, NumberOfCores, NumberOfLogicalProcessors"',
        'echo # END SECTION',
        'echo # BEGIN SECTION: docker version',
        'docker version',
        'if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%',
        'echo # END SECTION',
        'echo # BEGIN SECTION: docker info',
        'docker info',
        'if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%',
        'echo # END SECTION',
    ]),
))@
