# Installation

Official container images can be downloaded from [Docker Hub][docker_hub] or [GitHub Container Registry][ghcr].
We support popular CPU architectures like `amd64` and `arm64`.

## Pull

You can pull images by specifying the `latest` tag, a specific version, or a digest.

> [!NOTE]
>
> For production use or verification purposes, it is strongly recommended to pull by **digest** to ensure immutability.
> A digest is a unique, content-based identifier for the image.

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
docker pull tmknom/test:3.4.1
```

**GitHub Container Registry:**

```shell
docker pull ghcr.io/tmknom/playground-workflows/test:3.4.1
```

### Specify digest

**Docker Hub:**

```shell
docker pull tmknom/test@sha256:9e231ddde5c54ac57ad9ff2d16b84ffd1aef04e2194b12a0eb02556c6a6db72d
```

**GitHub Container Registry:**

```shell
docker pull ghcr.io/tmknom/playground-workflows/test@sha256:9e231ddde5c54ac57ad9ff2d16b84ffd1aef04e2194b12a0eb02556c6a6db72d
```

> [!TIP]
>
> The digest shown above is real and can be used as-is.
> If you need the digest for a different tag or version, you can find it on [Docker Hub][docker_hub] or [GitHub Container Registry][ghcr].
> You can find the digest in the image details section, usually labeled as `Digest` or starting with `sha256:`.

## Verify

To ensure the container image is authentic and has not been tampered with, we provide cryptographic verification methods.
Verification confirms it was published from a trusted GitHub Actions workflow.

You can choose one of the following methods:

### Cosign

To verify the signature of an image using [Cosign](https://github.com/sigstore/cosign), make sure it is installed.
Cosign allows you to confirm not only the publisher but also the exact commit used to build the image.

**Docker Hub:**

```shell
cosign verify \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  --certificate-identity "https://github.com/tmknom/playground-workflows/.github/workflows/reusable-release.yml@refs/heads/main" \
  --certificate-github-workflow-repository "tmknom/playground-workflows" \
  --certificate-github-workflow-sha "2ba61d12e727906d2db3dcf3f34bab4f0927de4b" \
  tmknom/test@sha256:9e231ddde5c54ac57ad9ff2d16b84ffd1aef04e2194b12a0eb02556c6a6db72d
```

**GitHub Container Registry:**

```shell
cosign verify \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  --certificate-identity "https://github.com/tmknom/playground-workflows/.github/workflows/reusable-release.yml@refs/heads/main" \
  --certificate-github-workflow-repository "tmknom/playground-workflows" \
  --certificate-github-workflow-sha "2ba61d12e727906d2db3dcf3f34bab4f0927de4b" \
  ghcr.io/tmknom/playground-workflows/test@sha256:9e231ddde5c54ac57ad9ff2d16b84ffd1aef04e2194b12a0eb02556c6a6db72d
```

<details>
<summary>Example output: verification succeeded</summary>
```shell

Verification for ghcr.io/tmknom/playground-workflows/test@sha256:9e231ddde5c54ac57ad9ff2d16b84ffd1aef04e2194b12a0eb02556c6a6db72d --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - Existence of the claims in the transparency log was verified offline
  - The code-signing certificate was verified using trusted certificate authority certificates

[{"critical":{"identity":{"docker-reference":"ghcr.io/tmknom/playground-workflows/test"},"image":{"d...
```
</details>

### GitHub Artifact Attestations

To verify provenance using [GitHub CLI](https://cli.github.com/), make sure it is installed.
GitHub Artifact Attestations allows you to confirm that the image was built by a trusted workflow and published by the specified repository.

**Docker Hub:**

```shell
gh attestation verify oci://tmknom/test@sha256:9e231ddde5c54ac57ad9ff2d16b84ffd1aef04e2194b12a0eb02556c6a6db72d \
  --deny-self-hosted-runners \
  --repo "tmknom/playground-workflows" \
  --cert-oidc-issuer "https://token.actions.githubusercontent.com" \
  --cert-identity "https://github.com/tmknom/playground-workflows/.github/workflows/reusable-release.yml@refs/heads/main"
```

**GitHub Container Registry:**

```shell
gh attestation verify oci://ghcr.io/tmknom/playground-workflows/test@sha256:9e231ddde5c54ac57ad9ff2d16b84ffd1aef04e2194b12a0eb02556c6a6db72d \
  --deny-self-hosted-runners \
  --repo "tmknom/playground-workflows" \
  --cert-oidc-issuer "https://token.actions.githubusercontent.com" \
  --cert-identity "https://github.com/tmknom/playground-workflows/.github/workflows/reusable-release.yml@refs/heads/main"
```

<details>
<summary>Example output: verification succeeded</summary>
```shell

```
</details>

[docker_hub]: https://hub.docker.com/r/tmknom/test
[ghcr]: https://github.com/tmknom/playground-workflows/pkgs/container/dockerfiles%2Ftest
