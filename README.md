# playground-workflows

Debugging on GitHub Actions.

<!-- actdocs start -->

## Description

This action discovers the Terraform state directories that use the specified local modules.
A "state directory" is where you run `terraform plan` or `terraform apply`.
It usually contains the `terraform.tfstate` file.

For example, if you modify a Terraform local module, you can see which state directories are affected.
With this action, you can easily identify relationships in your Terraform configurations,
making it easier to manage changes and understand their impacts.

## Usage

```yaml
  steps:
    - name: Tf dependency
      uses: tmknom/tf-dependency-action@v0
      with:
        modules: module/foo,module/bar
```

## Inputs

| Name | Description | Default | Required |
| :--- | :---------- | :------ | :------: |
| base-dir | The base directory that contains the state directories and module directories. | `${{ github.workspace }}` | no |
| modules | Paths of files or directories that might be Terraform modules. | n/a | no |

## Outputs

| Name | Description |
| :--- | :---------- |
| dirs | The state directories that use the specified modules. |

<!-- actdocs end -->

## Go CLI

The `playground-workflows` CLI is released by the `.github/workflows/release.yml` workflow.
Each release publishes the following assets on [GitHub Releases][releases]:

- `playground-workflows_<version>_<os>_<arch>.tar.gz` (`<os>` is `linux` or `darwin`) and `playground-workflows_<version>_windows_<arch>.zip`. `<arch>` is `amd64` or `arm64`
- `<archive>.sbom.json`: the SBOM of each archive in SPDX JSON, where `<archive>` is the archive file name
- `SHA256SUMS`: the SHA-256 checksums of the archives and the SBOMs
- `container-image.txt`: the digest-pinned reference to the container image `ghcr.io/tmknom/playground-workflows`

`<version>` is the tag without the leading `v`.
This repository also creates releases for an AWS Lambda package in the same version series, and those releases do not include the assets above.
Choose a version whose release lists them.
The examples below use `vX.Y.Z` and `X.Y.Z`; replace them with the version you install.

### Download

```bash
gh release download vX.Y.Z --repo tmknom/playground-workflows \
  --pattern 'playground-workflows_X.Y.Z_linux_amd64.tar.gz' \
  --pattern SHA256SUMS \
  --pattern container-image.txt
```

### Verify the provenance of an archive

The archives and the container image carry [Artifact Attestations](https://docs.github.com/en/actions/concepts/security/artifact-attestations).
An attestation is only meaningful when you check it against values you expect, so verify it with the following expected values:

| Expected value | Value |
|---|---|
| Repository | `tmknom/playground-workflows` |
| Signer workflow | `tmknom/playground-workflows/.github/workflows/release.yml` |
| Source ref | `refs/tags/vX.Y.Z` (the tag of the version you install) |
| Runner | GitHub-hosted runners (`--deny-self-hosted-runners`) |

```bash
gh attestation verify playground-workflows_X.Y.Z_linux_amd64.tar.gz \
  --repo tmknom/playground-workflows \
  --signer-workflow tmknom/playground-workflows/.github/workflows/release.yml \
  --source-ref refs/tags/vX.Y.Z \
  --deny-self-hosted-runners
```

The command requires the GitHub CLI to be authenticated, because it fetches the attestations from the GitHub API.
If you pass a different `--source-ref`, the verification fails.
The SBOMs carry attestations as well; verify one with the same command, replacing the file name with `<archive>.sbom.json`.

### Verify the checksum

```bash
sha256sum --ignore-missing -c SHA256SUMS
```

On macOS, use `shasum -a 256 --ignore-missing -c SHA256SUMS`.
On Windows, compare the output of `Get-FileHash -Algorithm SHA256 <archive>` with the line for the archive in `SHA256SUMS`.

A checksum match alone does not detect an archive replaced together with `SHA256SUMS`.
Use it together with the provenance verification above.

### Verify the container image

Identify the image by the digest-pinned reference in `container-image.txt`, not by the `vX.Y.Z` tag, which can be moved.
Then verify the provenance with the same expected values as the archives:

```bash
gh attestation verify "oci://$(cat container-image.txt)" \
  --repo tmknom/playground-workflows \
  --signer-workflow tmknom/playground-workflows/.github/workflows/release.yml \
  --source-ref refs/tags/vX.Y.Z \
  --deny-self-hosted-runners
```

After the verification succeeds, pull and run the image by the same reference:

```bash
docker pull "$(cat container-image.txt)"
docker run --rm "$(cat container-image.txt)" --version
```

The attestation is attached to the digest of the image index only.
Verifying the digest of a platform-specific manifest (`linux/amd64` or `linux/arm64`) fails because no attestation is found.

### What is not guaranteed

- `SHA256SUMS` and `container-image.txt` are not signed. Rely on the provenance verification, not on these files alone
- `gh attestation verify` looks up attestations by the digest of the file, not by its name. An archive signed for another platform passes the verification even under a different name
- The verification pins the tag name, not the commit. If a version was built more than once (for example, deleted and released again), archives and images from the earlier build also pass
- The verification trusts everyone who can push to `main` and push tags, because a tag push runs the workflow file at the tagged commit
- Release assets and tags are not protected against modification after publication
- The attestation of an SBOM proves where the SBOM was generated, not that its contents are complete or accurate

After each release, the release workflow runs the same `gh attestation verify` commands against the published assets.
The release is already public at that point, and a failure does not withdraw it.

## Release notes

See [GitHub Releases][releases].

## License

Apache 2 Licensed. See [LICENSE](LICENSE) for full details.

[releases]: https://github.com/tmknom/playground-workflows/releases
