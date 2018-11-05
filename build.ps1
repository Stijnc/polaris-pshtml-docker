param (
    $Name = "stijnc/eleu2018k8sweb",
    $version = "latest",
    $Path = "Dockerfile"
)

$commit  = git rev-parse --short HEAD
$buildDate = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
$buildArgs = @(
    "build",
    "--rm",
    "--file $Path",
    "--tag $("{0}:{1}" -f $Name, $version)",
    "--tag $("{0}:{1}" -f $Name, $commit)",
    "--build-arg VERSION=$version",
    "--build-arg VCS_URL='https://github.com/stijnc/polaris-pshtml-docker'",
    "--build-arg VCS_REF='$commit'",
    "--build-arg BUILD_DATE='$buildDate'",
    "."
)
Write-information "Building dockerfile using file $Path and tag $tag. Remove intermediate containers after a successful build"

Start-Process docker -ArgumentList $buildArgs -NoNewWindow -Wait