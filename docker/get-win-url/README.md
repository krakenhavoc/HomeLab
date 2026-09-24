# Windows media URL helper

This container runs a small Selenium job that obtains Microsoft's temporary 64-bit Windows 11 ISO download URL. The image is built by `docker-get-win-url.yaml` and published to GitHub Container Registry after changes land on `main`.

## Build locally

```bash
docker build -t get-win-url docker/get-win-url
docker run --rm get-win-url
```

Successful output is a JSON object:

```json
{"url": "https://software.download.prss.microsoft.com/..."}
```

The returned URL is temporary; do not commit it to Terraform variables.

The shared workflow's `win11_iso_url` dispatch input does not download the ISO today. A manual dispatch only plans (apply runs on push), and a push plans with an empty URL. The ISO on the host was placed outside Terraform state.

## Notes

- The image installs Google Chrome and runs it headlessly.
- Microsoft's page structure can change, so selector failures are expected maintenance rather than a Terraform problem.
- A failed run writes `debug_error.png` inside the ephemeral container. Mount a writable directory if the screenshot is needed for diagnosis.
- The current container process runs as root with Chrome's `--no-sandbox` flag. Keep it as a short-lived utility, not a network service.
