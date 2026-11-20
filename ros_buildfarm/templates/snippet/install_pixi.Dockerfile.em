@{
# pinned and checksum verified, like the Pixi installation in ros2/ci
pixi_version = '0.84.1'
pixi_releases = {
    'amd64': ('x86_64', 'linux-64', 'c81a16595e9e925fac3b12fe50cedbf415619a421ad2b72c1bba2a6ba6c2454a'),
    'arm64': ('aarch64', 'linux-aarch64', '0595613aedd95f84f90a55ba4b51fc1e4b86afb4eaa3e34ca3f3454d8f22c2e6'),
}
pixi_arch, pixi_platform, pixi_sha256 = pixi_releases[arch]
}@
RUN python3 -u /tmp/wrapper_scripts/apt.py update-install-clean -q -y ca-certificates curl
RUN curl -sSfL -o /tmp/pixi.tar.gz https://github.com/prefix-dev/pixi/releases/download/v@(pixi_version)/pixi-@(pixi_arch)-unknown-linux-musl.tar.gz && \
    echo "@(pixi_sha256)  /tmp/pixi.tar.gz" | sha256sum -c - && \
    tar -xzf /tmp/pixi.tar.gz -C /usr/local/bin pixi && \
    rm /tmp/pixi.tar.gz

# empty Pixi workspace, the dependencies are added to it by the pixi.py wrapper script
RUN pixi init --channel conda-forge --platform @(pixi_platform) /opt/pixi_ws
WORKDIR /opt/pixi_ws
ENV PATH /opt/pixi_ws/.pixi/envs/default/bin:$PATH
