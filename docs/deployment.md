# Deploying the published Weblua image

The fork's [image workflow](../.github/workflows/image.yml) publishes
`ghcr.io/notrainer/weblua:latest` for `linux/amd64` and `linux/arm64` after its
image build, Compose validation, container health, and route checks pass. Pushes
to `main` publish automatically; **Actions → Build and publish image → Run workflow** on
`main` rebuilds manually. Pull requests only run checks. The workflow uses
current action release tags without SHA pinning, and grants package write access
only to the publishing job. No additional registry secret is needed in CI.

## Start locally

On macOS, ensure the Podman machine is running. `podman compose` needs a Compose
provider supporting `--wait`, such as Docker Compose. The same file works with
`docker compose`.

If the GHCR package is private, authenticate with `podman login ghcr.io` using
a GitHub personal access token with `read:packages`. Keep it out of the Compose
file and Git. Repository visibility and package visibility are separate settings.

From the repository root:

```sh
podman compose pull
podman compose up -d --pull never --wait --wait-timeout 60
podman compose ps
curl -fsS -o /dev/null -w 'homepage HTTP %{http_code}\n' http://127.0.0.1:8085/
curl -fsS -o /dev/null -w 'playground HTTP %{http_code}\n' http://127.0.0.1:8085/playground
curl -fsS -o /dev/null -w 'embed HTTP %{http_code}\n' http://127.0.0.1:8085/embed
```

Expect a healthy container and HTTP 200 on all three routes. Open
<http://127.0.0.1:8085/playground>, run an example, and confirm output appears.
For Luau, also press **Check** to verify the analyzer loads.

The service binds only to loopback. Use a reverse proxy for a hosted deployment.
The root filesystem is read-only, with temporary nginx cache/PID directories,
and the health check requests nginx every 30 seconds with a five-second timeout.

Use `podman compose stop` and `podman compose start` to stop and resume it.
If the older standalone `weblua` container is using port 8085, stop it with
`podman stop weblua` before starting Compose. Keep it for rollback until the new
service passes verification.

Projects and recovery drafts live in browser IndexedDB. There is no server data
volume to migrate. Keep the same browser, scheme, hostname, and port to retain
access to saved projects.

## Update and rollback

Before pulling a replacement, retain the currently running image locally:

```sh
podman tag ghcr.io/notrainer/weblua:latest localhost/weblua:rollback
podman compose pull
podman compose up -d --pull never --wait --wait-timeout 60
```

Repeat the health, HTTP, and browser checks above. If they fail, restore the
retained image and repeat verification:

```sh
WEBLUA_IMAGE=localhost/weblua:rollback podman compose up -d --pull never --wait --wait-timeout 60
```

## Local builds and build arguments

The deployment Compose file always uses `image:`. To validate a locally built
image with the same service settings:

```sh
podman build --format=docker -t weblua .
WEBLUA_IMAGE=localhost/weblua:latest podman compose up -d --pull never --wait --wait-timeout 60
```

For stale Docker Hub credentials during a local build, use the
[temporary auth-file workaround](../README.md#local-podman-container).
Published images are built in CI; deployments pull them without building.
`--format=docker` preserves the image's health check in local Podman builds;
the Compose file also declares it explicitly.

Optional telemetry is disabled in the published image. To enable it in a custom
build, pass `--build-arg VITE_PLAUSIBLE_DOMAIN=example.com` and/or
`--build-arg VITE_SENTRY_DSN=...`. Vite embeds these values in browser assets;
they are public configuration, not a place for credentials. Restarting the
container cannot change them.
