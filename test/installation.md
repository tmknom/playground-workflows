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
docker pull tmknom/test:3.4.0
```

**GitHub Container Registry:**

```shell
docker pull ghcr.io/tmknom/playground-workflows/test:3.4.0
```

### Specify digest

**Docker Hub:**

```shell
docker pull tmknom/test@sha256:1875369820bbfe94220af92319f565a14b4a80cc2f4a71b8b6cbcb627c989293
```

**GitHub Container Registry:**

```shell
docker pull ghcr.io/tmknom/playground-workflows/test@sha256:1875369820bbfe94220af92319f565a14b4a80cc2f4a71b8b6cbcb627c989293
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
  --certificate-github-workflow-sha "42d98e628a3c48932e362322543b59f91ecdde3c" \
  tmknom/test@sha256:1875369820bbfe94220af92319f565a14b4a80cc2f4a71b8b6cbcb627c989293
```

**GitHub Container Registry:**

```shell
cosign verify \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  --certificate-identity "https://github.com/tmknom/playground-workflows/.github/workflows/reusable-release.yml@refs/heads/main" \
  --certificate-github-workflow-repository "tmknom/playground-workflows" \
  --certificate-github-workflow-sha "42d98e628a3c48932e362322543b59f91ecdde3c" \
  ghcr.io/tmknom/playground-workflows/test@sha256:1875369820bbfe94220af92319f565a14b4a80cc2f4a71b8b6cbcb627c989293
```

<details>
<summary>Example output: verification succeeded</summary>

Verification for ghcr.io/tmknom/playground-workflows/test@sha256:1875369820bbfe94220af92319f565a14b4a80cc2f4a71b8b6cbcb627c989293 --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - Existence of the claims in the transparency log was verified offline
  - The code-signing certificate was verified using trusted certificate authority certificates

[{"critical":{"identity":{"docker-reference":"ghcr.io/tmknom/playground-workflows/test"},"image":{"docker-manifest-digest":"sha256:1875369820bbfe94220af92319f565a14b4a80cc2f4a71b8b6cbcb627c989293"},"type":"cosign container image signature"},"optional":{"1.3.6.1.4.1.57264.1.1":"https://token.actions.githubusercontent.com","1.3.6.1.4.1.57264.1.2":"workflow_dispatch","1.3.6.1.4.1.57264.1.3":"42d98e628a3c48932e362322543b59f91ecdde3c","1.3.6.1.4.1.57264.1.4":"Release test","1.3.6.1.4.1.57264.1.5":"tmknom/playground-workflows","1.3.6.1.4.1.57264.1.6":"refs/heads/main","Bundle":{"SignedEntryTimestamp":"MEUCIDHcNANbwuxdETDVvSheAVZLUOkSS1kGMQf0nnUDaB6tAiEAix/VZT42otsdXPKFBpiDD4fuaEAx7lOzLCJZ7W8Hm0o=","Payload":{"body":"eyJhcGlWZXJzaW9uIjoiMC4wLjEiLCJraW5kIjoiaGFzaGVkcmVrb3JkIiwic3BlYyI6eyJkYXRhIjp7Imhhc2giOnsiYWxnb3JpdGhtIjoic2hhMjU2IiwidmFsdWUiOiJkYjhlYTgwMWY4ZTkwODg4ZDE5Y2ExZjdlMmMwYTJiMjY3YzEyY2EzZDEwZDI0YzkxNzk5ZWZkYmJlMWZiMDNjIn19LCJzaWduYXR1cmUiOnsiY29udGVudCI6Ik1FUUNJR051TDdHN1NzM2loU2hDOHJnS01vNzJzbk0vaVdHMXBsV09NdUlPeklyWEFpQnpiazdmTVZwODBTZ0FVVUtNbVNuMkY0bW9CeUJQdEsrRXJaWmxRdGw2Q3c9PSIsInB1YmxpY0tleSI6eyJjb250ZW50IjoiTFMwdExTMUNSVWRKVGlCRFJWSlVTVVpKUTBGVVJTMHRMUzB0Q2sxSlNVaEdSRU5EUW5CdFowRjNTVUpCWjBsVlIwOTVTbXBFTDBwTGVrMDNSV0pOUTFCUlMyZGtOazlCUTJGemQwTm5XVWxMYjFwSmVtb3dSVUYzVFhjS1RucEZWazFDVFVkQk1WVkZRMmhOVFdNeWJHNWpNMUoyWTIxVmRWcEhWakpOVWpSM1NFRlpSRlpSVVVSRmVGWjZZVmRrZW1SSE9YbGFVekZ3WW01U2JBcGpiVEZzV2tkc2FHUkhWWGRJYUdOT1RXcFZkMDVFUlRWTlJHTXdUWHBWZDFkb1kwNU5hbFYzVGtSRk5VMUVZekZOZWxWM1YycEJRVTFHYTNkRmQxbElDa3R2V2tsNmFqQkRRVkZaU1V0dldrbDZhakJFUVZGalJGRm5RVVZaZEhWSGJuUjBaV0ZCUkZSb1pqVkViM1JLTlZBMFRHaHNhMlJwUTIxNVdXZHdkbFFLVDI1VFMzVjVkWEpGV2xSUk9TOUxiaXQyZFU1SWNIcHRkRXRsVTNGcGFrVlFNWEV2VUdKNFV6WkJXblZVZERZMGVUWlBRMEppWjNkbloxY3dUVUUwUndwQk1WVmtSSGRGUWk5M1VVVkJkMGxJWjBSQlZFSm5UbFpJVTFWRlJFUkJTMEpuWjNKQ1owVkdRbEZqUkVGNlFXUkNaMDVXU0ZFMFJVWm5VVlZaVDA5a0NtbEJNa2RzTmtzMWFWVnBVM05vY1RjeFoxSkRUWEZaZDBoM1dVUldVakJxUWtKbmQwWnZRVlV6T1ZCd2VqRlphMFZhWWpWeFRtcHdTMFpYYVhocE5Ga0tXa1E0ZDJOM1dVUldVakJTUVZGSUwwSkhhM2RhTkZwc1lVaFNNR05JVFRaTWVUbHVZVmhTYjJSWFNYVlpNamwwVEROU2RHRXlOWFppVXpsM1lrZEdOUXBhTTBwMlpGYzFhMHhZWkhaamJYUnRZa2M1TTJONU9IVmFNbXd3WVVoV2FVd3paSFpqYlhSdFlrYzVNMk41T1hsYVdGWjZXVmRLYzFwVE1YbGFWM2hzQ2xsWVRteE1ibXgwWWtWQ2VWcFhXbnBNTW1oc1dWZFNla3d5TVdoaFZ6UjNUMUZaUzB0M1dVSkNRVWRFZG5wQlFrRlJVWEpoU0ZJd1kwaE5Oa3g1T1RBS1lqSjBiR0pwTldoWk0xSndZakkxZWt4dFpIQmtSMmd4V1c1V2VscFlTbXBpTWpVd1dsYzFNRXh0VG5aaVZFRm1RbWR2Y2tKblJVVkJXVTh2VFVGRlF3cENRa1l6WWpOS2NscHRlSFprTVRscllWaE9kMWxZVW1waFJFRXlRbWR2Y2tKblJVVkJXVTh2VFVGRlJFSkRaekJOYlZFMVQwZFZNazFxYUdoTk1rMHdDazlFYTNwTmJWVjZUbXBKZWsxcVNURk9SRTVwVGxSc2JVOVVSbXhaTWxKcldsUk9hazFDYjBkRGFYTkhRVkZSUW1jM09IZEJVVkZGUkVaS2JHSkhWbWdLWXpKVloyUkhWbnBrUkVGd1FtZHZja0puUlVWQldVOHZUVUZGUmtKQ2REQmlWM1IxWWpJd2RtTkhlR2hsVjJSNVlqTldkVnBETVROaU0wcHlXbTE0ZGdwa00wMTNTRkZaUzB0M1dVSkNRVWRFZG5wQlFrSm5VVkJqYlZadFkzazViMXBYUm10amVUbDBXVmRzZFUxRWMwZERhWE5IUVZGUlFtYzNPSGRCVVdkRkNreFJkM0poU0ZJd1kwaE5Oa3g1T1RCaU1uUnNZbWsxYUZrelVuQmlNalY2VEcxa2NHUkhhREZaYmxaNldsaEthbUl5TlRCYVZ6VXdURzFPZG1KVVFqRUtRbWR2Y2tKblJVVkJXVTh2VFVGRlNrSkhZMDFhVjJnd1pFaENlazlwT0haYU1td3dZVWhXYVV4dFRuWmlVemt3WWxkMGRXSXlNSFpqUjNob1pWZGtlUXBpTTFaMVdrTXhNMkl6U25KYWJYaDJaRE5OZGt4dFpIQmtSMmd4V1drNU0ySXpTbkphYlhoMlpETk5kbU50VmpGak1rWnBZa2RWZEdOdFZuTmFWMFo2Q2xwVE5UVmlWM2hCWTIxV2JXTjVPVzlhVjBaclkzazVkRmxYYkhWTlJHZEhRMmx6UjBGUlVVSm5OemgzUVZGdlJVdG5kMjlPUkVwclQxUm9iRTVxU1RRS1dWUk9hazVFWnpWTmVrcHNUWHBaZVUxNlNYbE9WRkY2V1dwVk5WcHFhM2hhVjA1cldrZFZlbGw2UVdSQ1oyOXlRbWRGUlVGWlR5OU5RVVZNUWtFNFRRcEVWMlJ3WkVkb01WbHBNVzlpTTA0d1dsZFJkMUJuV1V0TGQxbENRa0ZIUkhaNlFVSkVRVkYzUkVNMWIyUklVbmRqZW05MlRESmtjR1JIYURGWmFUVnFDbUl5TUhaa1J6RnlZbTA1ZEV3elFuTlpXR3h1WTIwNU1XSnRVWFJrTWpsNVlUSmFjMkl6WkhwTlJHZEhRMmx6UjBGUlVVSm5OemgzUVZFd1JVdG5kMjhLVGtSS2EwOVVhR3hPYWtrMFdWUk9hazVFWnpWTmVrcHNUWHBaZVUxNlNYbE9WRkY2V1dwVk5WcHFhM2hhVjA1cldrZFZlbGw2UVdaQ1oyOXlRbWRGUlFwQldVOHZUVUZGVDBKQ1JVMUVNMHBzV201TmRtRkhWbWhhU0UxMllsZEdjR0pxUVZwQ1oyOXlRbWRGUlVGWlR5OU5RVVZRUWtGelRVTlVVVE5OYWtWM0NrOUVaek5OZWtGd1FtZHZja0puUlVWQldVOHZUVUZGVVVKQ2MwMUhWMmd3WkVoQ2VrOXBPSFphTW13d1lVaFdhVXh0VG5aaVV6a3dZbGQwZFdJeU1IY0tSbmRaUzB0M1dVSkNRVWRFZG5wQlFrVlJVVXBFUVdONlQwUlpNVTFFVFRKTlNFVkhRMmx6UjBGUlVVSm5OemgzUVZKSlJWbDNlR2hoU0ZJd1kwaE5OZ3BNZVRsdVlWaFNiMlJYU1hWWk1qbDBURE5TZEdFeU5YWmlVemwzWWtkR05Wb3pTblprVnpWclRGaGtkbU50ZEcxaVJ6a3pZM2s0ZFZveWJEQmhTRlpwQ2t3elpIWmpiWFJ0WWtjNU0yTjVPWGxhVjNoc1dWaE9iRXhZVW14ak0xRjFaVmN4YzFGSVNteGFiazEyWVVkV2FGcElUWFppVjBad1ltcEJORUpuYjNJS1FtZEZSVUZaVHk5TlFVVlVRa052VFV0RVVYbGFSR3MwV2xSWmVVOUhSWHBaZWxFMFQxUk5lVnBVVFRKTmFrMTVUV3BWTUUweVNURlBWMWsxVFZkV2FncGFSMUpzVFRKTmQwbFJXVXRMZDFsQ1FrRkhSSFo2UVVKR1FWRlVSRUpHTTJJelNuSmFiWGgyWkRFNWEyRllUbmRaV0ZKcVlVUkNhVUpuYjNKQ1owVkZDa0ZaVHk5TlFVVldRa1pSVFZWdGFEQmtTRUo2VDJrNGRsb3liREJoU0ZacFRHMU9kbUpUT1RCaVYzUjFZakl3ZG1OSGVHaGxWMlI1WWpOV2RWcERNVE1LWWpOS2NscHRlSFprTTAxMldWZE9NR0ZYT1hWamVUbDVaRmMxZWt4NlJUQk9WRkV6VFVSbk5VOVVZelJNTWtZd1pFZFdkR05JVW5wTWVrVjNSbWRaU3dwTGQxbENRa0ZIUkhaNlFVSkdaMUZKUkVGYWQyUlhTbk5oVjAxM1oxbHZSME5wYzBkQlVWRkNNVzVyUTBKQlNVVm1RVkkyUVVoblFXUm5SR1JRVkVKeENuaHpZMUpOYlUxYVNHaDVXbHA2WTBOdmEzQmxkVTQwT0hKbUswaHBia3RCVEhsdWRXcG5RVUZCV2xwT1FWQlpSVUZCUVVWQmQwSklUVVZWUTBsUlEzUUtiWGd3T0d0eU5rNUZVV2hVYm1sSU9USXJaVFoxYm5WMmJESlFlSEY0UnpCMlNTOTRNVzlXZEU5M1NXZEVhRk53YUZjclZGUmtaSFozVURsc1JtUXZNZ295TDJwNlRrMUxSUzh3UmtaQ1praFFRMU15Tm5seldYZERaMWxKUzI5YVNYcHFNRVZCZDAxRVlWRkJkMXBuU1hoQlVGTmhXblJLVWxCb1VqRjRVWFZTQ2tWak9HeFlUblF2WmtsVWFXZE1XRWd4VEdzd2VISTBMMUZtTTFJdmRtazJOSGs1UXpKTE16bDVhR1U0ZDBGb1QxcFJTWGhCVFV0eUswNW9jR3BpUlVNS0swWlhjWFZzTmt0YWVXTjJWR3gzZG01U1dubFVSM1pVVkhFelVXdEVjamhCSzJkNFZESkNaV3RxYmpoTU16bEdNRk5OYWs5M1BUMEtMUzB0TFMxRlRrUWdRMFZTVkVsR1NVTkJWRVV0TFMwdExRbz0ifX19fQ==","integratedTime":1745048631,"logIndex":199608077,"logID":"c0d23d6ad406973f9559f3ba2d1ca01f84147d8ffc5b8445c224f98b9591801d"}},"Issuer":"https://token.actions.githubusercontent.com","Subject":"https://github.com/tmknom/playground-workflows/.github/workflows/reusable-release.yml@refs/heads/main","githubWorkflowName":"Release test","githubWorkflowRef":"refs/heads/main","githubWorkflowRepository":"tmknom/playground-workflows","githubWorkflowSha":"42d98e628a3c48932e362322543b59f91ecdde3c","githubWorkflowTrigger":"workflow_dispatch"}}]
[{"critical":{"identity":{"docker-reference":"ghcr.io/tmknom/playground-workflows/test"},"image":{"d...
</details>

### GitHub Artifact Attestations

To verify provenance using [GitHub CLI](https://cli.github.com/), make sure it is installed.
GitHub Artifact Attestations allows you to confirm that the image was built by a trusted workflow and published by the specified repository.

**Docker Hub:**

```shell
gh attestation verify oci://tmknom/test@sha256:1875369820bbfe94220af92319f565a14b4a80cc2f4a71b8b6cbcb627c989293 \
  --deny-self-hosted-runners \
  --repo "tmknom/playground-workflows" \
  --cert-oidc-issuer "https://token.actions.githubusercontent.com" \
  --cert-identity "https://github.com/tmknom/playground-workflows/.github/workflows/reusable-release.yml@refs/heads/main"
```

**GitHub Container Registry:**

```shell
gh attestation verify oci://ghcr.io/tmknom/playground-workflows/test@sha256:1875369820bbfe94220af92319f565a14b4a80cc2f4a71b8b6cbcb627c989293 \
  --deny-self-hosted-runners \
  --repo "tmknom/playground-workflows" \
  --cert-oidc-issuer "https://token.actions.githubusercontent.com" \
  --cert-identity "https://github.com/tmknom/playground-workflows/.github/workflows/reusable-release.yml@refs/heads/main"
```

<details>
<summary>Example output: verification succeeded</summary>

</details>

[docker_hub]: https://hub.docker.com/r/tmknom/test
[ghcr]: https://github.com/tmknom/playground-workflows/pkgs/container/dockerfiles%2Ftest
