# Installation

Official container images can be downloaded from Docker Hub or GitHub Container Registry.
We support popular CPU architectures like amd64 and arm64.

<!-- DOCKER_HUB_IMAGE: tmknom/test -->
<!-- GHCR_IMAGE: ghcr.io/tmknom/playground-workflows/test -->

## Pull

### Specify latest

```shell
docker pull tmknom/test:latest
docker pull ghcr.io/tmknom/playground-workflows/test:latest
```

### Specify version

```shell
docker pull tmknom/test:v3.3.0
docker pull ghcr.io/tmknom/playground-workflows/test:v3.3.0
```

### Specify digest

```shell
docker pull tmknom/test:sha256:dd531e71f9a01dd9c1f48dca4e90d823462eb86f1aae5720d9bbefd9ea9ce3ea
docker pull ghcr.io/tmknom/playground-workflows/test:sha256:dd531e71f9a01dd9c1f48dca4e90d823462eb86f1aae5720d9bbefd9ea9ce3ea
```

## Verify

### Cosign

```shell
cosign verify \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  --certificate-identity "https://github.com/tmknom/playground-workflows/.github/workflows/reusable-release.yml@refs/heads/main" \
  --certificate-github-workflow-repository "tmknom/playground-workflows" \
  --certificate-github-workflow-sha "fb2bef98a05599027d26337daaa48becbf9492d0" \
  tmknom/test@sha256:dd531e71f9a01dd9c1f48dca4e90d823462eb86f1aae5720d9bbefd9ea9ce3ea

cosign verify \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  --certificate-identity "https://github.com/tmknom/playground-workflows/.github/workflows/reusable-release.yml@refs/heads/main" \
  --certificate-github-workflow-repository "tmknom/playground-workflows" \
  --certificate-github-workflow-sha "fb2bef98a05599027d26337daaa48becbf9492d0" \
  ghcr.io/tmknom/playground-workflows/test@sha256:dd531e71f9a01dd9c1f48dca4e90d823462eb86f1aae5720d9bbefd9ea9ce3ea
```

> [!NOTE]
>
> Install [Cosign](https://github.com/sigstore/cosign) if not already available.


### GitHub Artifact Attestations

```shell
gh attestation verify tmknom/test@sha256:dd531e71f9a01dd9c1f48dca4e90d823462eb86f1aae5720d9bbefd9ea9ce3ea \
  --deny-self-hosted-runners \
  --repo "tmknom/playground-workflows" \
  --cert-oidc-issuer "https://token.actions.githubusercontent.com" \
  --cert-identity "https://github.com/tmknom/playground-workflows/.github/workflows/reusable-release.yml@refs/heads/main"

gh attestation verify oci://ghcr.io/tmknom/playground-workflows/test@sha256:dd531e71f9a01dd9c1f48dca4e90d823462eb86f1aae5720d9bbefd9ea9ce3ea \
  --deny-self-hosted-runners \
  --repo "tmknom/playground-workflows" \
  --cert-oidc-issuer "https://token.actions.githubusercontent.com" \
  --cert-identity "https://github.com/tmknom/playground-workflows/.github/workflows/reusable-release.yml@refs/heads/main"
```

> [!NOTE]
>
> Install [GitHub CLI](https://cli.github.com/) if not already available.
