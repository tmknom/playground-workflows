# Installation

Official container images can be downloaded from [Docker Hub][docker_hub] or [GitHub Container Registry][ghcr].
We support popular CPU architectures like amd64 and arm64.

## Pull

### Specify latest

**Docker Hub:**

```shell
docker pull tmknom/test:latest
```

**GitHub Container Registry:**

```shell
docker pull ghcr.io/tmknom/playground-workflows/test:latest
```

### Specify version

**Docker Hub:**

```shell
docker pull tmknom/test:3.3.1
```

**GitHub Container Registry:**

```shell
docker pull ghcr.io/tmknom/playground-workflows/test:3.3.1
```

### Specify digest

**Docker Hub:**

```shell
docker pull tmknom/test:sha256:17e40c15da7424adc441fcca53bf5c61cd85d6ff8c53adc780994dd27e25da8c
```

**GitHub Container Registry:**

```shell
docker pull ghcr.io/tmknom/playground-workflows/test:sha256:17e40c15da7424adc441fcca53bf5c61cd85d6ff8c53adc780994dd27e25da8c
```

## Verify

### Cosign

Install [Cosign](https://github.com/sigstore/cosign) if not already available.

**Docker Hub:**

```shell
cosign verify \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  --certificate-identity "https://github.com/tmknom/playground-workflows/.github/workflows/reusable-release.yml@refs/heads/main" \
  --certificate-github-workflow-repository "tmknom/playground-workflows" \
  --certificate-github-workflow-sha "4b6223c807174d468d2a7d992079fcb49823c41c" \
  tmknom/test@sha256:17e40c15da7424adc441fcca53bf5c61cd85d6ff8c53adc780994dd27e25da8c
```

**GitHub Container Registry:**

```shell
cosign verify \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  --certificate-identity "https://github.com/tmknom/playground-workflows/.github/workflows/reusable-release.yml@refs/heads/main" \
  --certificate-github-workflow-repository "tmknom/playground-workflows" \
  --certificate-github-workflow-sha "4b6223c807174d468d2a7d992079fcb49823c41c" \
  ghcr.io/tmknom/playground-workflows/test@sha256:17e40c15da7424adc441fcca53bf5c61cd85d6ff8c53adc780994dd27e25da8c
```

### GitHub Artifact Attestations

Install [GitHub CLI](https://cli.github.com/) if not already available.

**Docker Hub:**

```shell
gh attestation verify oci://tmknom/test@sha256:17e40c15da7424adc441fcca53bf5c61cd85d6ff8c53adc780994dd27e25da8c \
  --deny-self-hosted-runners \
  --repo "tmknom/playground-workflows" \
  --cert-oidc-issuer "https://token.actions.githubusercontent.com" \
  --cert-identity "https://github.com/tmknom/playground-workflows/.github/workflows/reusable-release.yml@refs/heads/main"
```

**GitHub Container Registry:**

```shell
gh attestation verify oci://ghcr.io/tmknom/playground-workflows/test@sha256:17e40c15da7424adc441fcca53bf5c61cd85d6ff8c53adc780994dd27e25da8c \
  --deny-self-hosted-runners \
  --repo "tmknom/playground-workflows" \
  --cert-oidc-issuer "https://token.actions.githubusercontent.com" \
  --cert-identity "https://github.com/tmknom/playground-workflows/.github/workflows/reusable-release.yml@refs/heads/main"
```

[docker_hub]: https://hub.docker.com/r/tmknom/test
[ghcr]: https://github.com/tmknom/playground-workflows/pkgs/container/dockerfiles%2Ftest
