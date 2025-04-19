# Installation

Official container images can be downloaded from Docker Hub or GitHub Container Registry.
We support popular CPU architectures like amd64 and arm64.

<!-- DOCKER_HUB_IMAGE: ${GITHUB_REPOSITORY_OWNER}/${NAME} -->
<!-- GHCR_IMAGE: ghcr.io/${GITHUB_REPOSITORY}/${NAME} -->

## Pull

### Specify latest

```shell
docker pull ${DOCKER_HUB_IMAGE}:latest
docker pull ${GHCR_IMAGE}:latest
```

### Specify version

```shell
docker pull ${DOCKER_HUB_IMAGE}:${VERSION}
docker pull ${GHCR_IMAGE}:${VERSION}
```

### Specify digest

```shell
docker pull ${DOCKER_HUB_IMAGE}:${IMAGE_DIGEST}
docker pull ${GHCR_IMAGE}:${IMAGE_DIGEST}
```

## Verify

### Cosign

```shell
cosign verify \
  --certificate-oidc-issuer "${CERTIFICATE_OIDC_ISSUER}" \
  --certificate-identity "${CERTIFICATE_IDENTITY}" \
  --certificate-github-workflow-repository "${GITHUB_REPOSITORY}" \
  --certificate-github-workflow-sha "${GITHUB_SHA}" \
  ${DOCKER_HUB_IMAGE}@${IMAGE_DIGEST}

cosign verify \
  --certificate-oidc-issuer "${CERTIFICATE_OIDC_ISSUER}" \
  --certificate-identity "${CERTIFICATE_IDENTITY}" \
  --certificate-github-workflow-repository "${GITHUB_REPOSITORY}" \
  --certificate-github-workflow-sha "${GITHUB_SHA}" \
  ${GHCR_IMAGE}@${IMAGE_DIGEST}
```

> [!NOTE]
>
> Install [Cosign](https://github.com/sigstore/cosign) if not already available.


### GitHub Artifact Attestations

```shell
gh attestation verify ${DOCKER_HUB_IMAGE}@${IMAGE_DIGEST} \
  --deny-self-hosted-runners \
  --repo "${GITHUB_REPOSITORY}" \
  --cert-oidc-issuer "${CERTIFICATE_OIDC_ISSUER}" \
  --cert-identity "${CERTIFICATE_IDENTITY}"

gh attestation verify oci://${GHCR_IMAGE}@${IMAGE_DIGEST} \
  --deny-self-hosted-runners \
  --repo "${GITHUB_REPOSITORY}" \
  --cert-oidc-issuer "${CERTIFICATE_OIDC_ISSUER}" \
  --cert-identity "${CERTIFICATE_IDENTITY}"
```

> [!NOTE]
>
> Install [GitHub CLI](https://cli.github.com/) if not already available.
