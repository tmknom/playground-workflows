FROM gcr.io/distroless/static-debian13:nonroot@sha256:aafe993665bf6200db38a02c11a9351e782a84b6a45e7f33b6695638c88e3931
ARG TARGETARCH
# COPY と ENTRYPOINT のバイナリ名は、次の箇所と同じ値にする。変えるときは、すべてを同時に変える。
#   - .github/workflows/release.yml の APP_NAME
#   - .github/workflows/test-release-build.yml の APP_NAME
#   - .goreleaser.yaml の project_name
COPY --chmod=0755 ${TARGETARCH}/playground-workflows /usr/local/bin/playground-workflows
USER nonroot:nonroot
ENTRYPOINT ["/usr/local/bin/playground-workflows"]
