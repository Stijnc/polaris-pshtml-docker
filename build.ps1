param (
    $Name = "polaris-pshtml",
    $version = "latest",
    $Path = "Dockerfile"
)

$tag = "{0}:{1}" -f $Name, $version
$commit  = git rev-parse --short HEAD
$buildArgs = @(
    "build",
    "--rm",
    "--file $Path"
    "--tag $tag"
    "."
    "--build-arg VERSION="
    "--build-arg VCS_REF='$commit'"
)
Write-information "Building dockerfile using file $Path and tag $tag. Remove intermediate containers after a successful build"
docker build --rm --file $Path --tag $tag . --build-arg

Start-Process -Docker -ArgumentList $buildArgs

ARG VERSION
ARG VCS_URL
ARG VCS_REF
ARG BUILD_DATE