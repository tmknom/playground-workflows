# Installation

Official container images can be downloaded from [Docker Hub][docker_hub] or [GitHub Container Registry][ghcr].
We support popular CPU architectures like amd64 and arm64.

## Pull

### Specify latest

**Docker Hub:**

```shell
docker pull ${DOCKER_HUB_IMAGE}:latest
```

**GitHub Container Registry:**

```shell
docker pull ${GHCR_IMAGE}:latest
```

### Specify version

**Docker Hub:**

```shell
docker pull ${DOCKER_HUB_IMAGE}:${VERSION}
```

**GitHub Container Registry:**

```shell
docker pull ${GHCR_IMAGE}:${VERSION}
```

### Specify digest

**Docker Hub:**

```shell
docker pull ${DOCKER_HUB_IMAGE}:${IMAGE_DIGEST}
```

**GitHub Container Registry:**

```shell
docker pull ${GHCR_IMAGE}:${IMAGE_DIGEST}
```

## Verify

### Cosign

Install [Cosign](https://github.com/sigstore/cosign) if not already available.

**Docker Hub:**

```shell
cosign verify \
  --certificate-oidc-issuer "${CERTIFICATE_OIDC_ISSUER}" \
  --certificate-identity "${CERTIFICATE_IDENTITY}" \
  --certificate-github-workflow-repository "${GITHUB_REPOSITORY}" \
  --certificate-github-workflow-sha "${GITHUB_SHA}" \
  ${DOCKER_HUB_IMAGE}@${IMAGE_DIGEST}
```

**GitHub Container Registry:**

```shell
cosign verify \
  --certificate-oidc-issuer "${CERTIFICATE_OIDC_ISSUER}" \
  --certificate-identity "${CERTIFICATE_IDENTITY}" \
  --certificate-github-workflow-repository "${GITHUB_REPOSITORY}" \
  --certificate-github-workflow-sha "${GITHUB_SHA}" \
  ${GHCR_IMAGE}@${IMAGE_DIGEST}
```

### GitHub Artifact Attestations

Install [GitHub CLI](https://cli.github.com/) if not already available.

**Docker Hub:**

```shell
gh attestation verify oci://${DOCKER_HUB_IMAGE}@${IMAGE_DIGEST} \
  --deny-self-hosted-runners \
  --repo "${GITHUB_REPOSITORY}" \
  --cert-oidc-issuer "${CERTIFICATE_OIDC_ISSUER}" \
  --cert-identity "${CERTIFICATE_IDENTITY}"
```

**GitHub Container Registry:**

```shell
gh attestation verify oci://${GHCR_IMAGE}@${IMAGE_DIGEST} \
  --deny-self-hosted-runners \
  --repo "${GITHUB_REPOSITORY}" \
  --cert-oidc-issuer "${CERTIFICATE_OIDC_ISSUER}" \
  --cert-identity "${CERTIFICATE_IDENTITY}"
```

[docker_hub]: https://hub.docker.com/r/${GITHUB_REPOSITORY_OWNER}/${NAME}
[ghcr]: https://github.com/${GITHUB_REPOSITORY}/pkgs/container/dockerfiles%2F${NAME}
