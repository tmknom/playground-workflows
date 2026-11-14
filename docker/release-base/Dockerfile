# release.yml の container ジョブがビルドするイメージのベースイメージを、digest で固定する。
# Dependabot が digest を更新するためのファイルで、ビルドには使わない。ビルドに使う Dockerfile は release.yml が書き出す。
# release.yml は、コメント行と空行を除いて digest で固定した FROM の 1 行だけであることを確かめ、イメージの参照だけを取り出す。
# release.yml の Dockerfile は USER に nonroot を指定するため、Distroless の nonroot のイメージにする
FROM gcr.io/distroless/static-debian13:nonroot@sha256:aafe993665bf6200db38a02c11a9351e782a84b6a45e7f33b6695638c88e3931
