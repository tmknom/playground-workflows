FROM gcr.io/distroless/static-debian13:nonroot@sha256:aafe993665bf6200db38a02c11a9351e782a84b6a45e7f33b6695638c88e3931
ARG TARGETARCH
COPY --chmod=0755 ${TARGETARCH}/playground-workflows /usr/local/bin/playground-workflows
USER nonroot:nonroot
ENTRYPOINT ["/usr/local/bin/playground-workflows"]
