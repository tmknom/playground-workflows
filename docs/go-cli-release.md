# Go CLI のリリースワークフロー設計

このリポジトリの Go CLI（`playground-workflows`）を、Git タグのプッシュを起点に GitHub Releases と GitHub Container Registry（GHCR）へ公開するワークフローの設計です。
対象はワークフロー `.github/workflows/release-go-cli.yml` の完成形で、各ジョブの責務、権限、成果物の受け渡し、検証の条件、失敗時の扱いを定めます。

## 対象と前提

| 項目 | 方針 |
|---|---|
| リポジトリ | GitHub Free の Public リポジトリ。リリースワークフローの動作を検証するためのものである |
| 設計の位置づけ | 個人開発の Go CLI の本番リリースに適用することを前提とする。検証用のリポジトリであることを、品質の確認を省く理由にしない |
| 実行基盤 | GitHub-hosted runners |
| 配布する CLI | リポジトリ直下の `main.go`。バイナリ名は `playground-workflows` |
| 配布物 | Linux / macOS / Windows × amd64 / arm64 の 6 種類の配布アーカイブと、アーカイブごとの SBOM（SPDX JSON） |
| コンテナ | `linux/amd64`、`linux/arm64` のマルチアーキテクチャイメージ `ghcr.io/tmknom/playground-workflows` |
| リリースの起点 | ローカルで作成してプッシュした `vX.Y.Z` 形式の Git タグ |
| 認証 | `GITHUB_TOKEN` と GitHub Actions の OIDC だけを使う。長期保管する秘密鍵や GitHub App は導入しない |
| cgo | `CGO_ENABLED=0` で固定する |

deb / rpm / apk の OS パッケージと Homebrew Formula は、現時点では配布しません。

## 保証する性質と保証しない内容

リリースの各工程は、次の性質を確保するために置いています。
「証明を生成したこと」と「期待する生成元・対象を検証したこと」は別の条件として扱い、後者を公開の条件にします。

| 性質 | 保証・検証する内容 | 保証しない内容 |
|---|---|---|
| 完全性 | 配布アーカイブと SBOM の SHA-256、OCI イメージの digest が期待値に一致する | ハッシュ値だけで期待値の入手元を信頼できること |
| 来歴 | 成果物の digest と、リポジトリ、タグ、コミット、署名したワークフローの対応が署名で検証できる | 実行された処理やソースコードが安全であること、SBOM の記載内容が正確であること |
| 機能品質 | テストが成功する。linux_amd64 の配布アーカイブと、amd64 / arm64 のコンテナで、`--version` の出力がタグと一致する | 全障害・全欠陥の不存在、Linux 以外の OS での実行 |
| 公開の一貫性 | GitHub Release と GHCR のイメージを `container-image.txt` の digest で結び付け、公開後に照合する | GitHub Releases と GHCR の原子的な同時公開 |

再現可能性（同じ入力から同じバイト列を再生成できること）と既知の脆弱性の検査は、現時点の保証に含めません。
扱いは [将来の拡張](#将来の拡張) に記載します。

Linux 以外の OS でのバイナリの実行も、リリースの工程では確かめません。
`CGO_ENABLED=0` でクロスコンパイルするため、OS ごとの挙動の違いはソースコードの性質であり、リリースの工程が持ち込むものではないからです。
OS ごとの確認はプルリクエストで実行する通常 CI の役割としますが、この CI は現時点ではありません（[将来の拡張](#将来の拡張)）。

SLSA の Build Level を名乗ることは目的にしません。

## リリースの起点とバージョン

リリースは、`v[0-9]+.[0-9]+.[0-9]+` に一致するタグの `push` で始まります。
`v0` のような形式外のタグやプレリリースのタグでは、ワークフローが起動しません。

- **バージョンの正本**：Git タグである。ビルドはタグが指すコミット SHA（`GITHUB_SHA`）から行い、実行中に `main` の最新状態を解決し直さない
- **起動者の制限**：すべてのジョブの `if` で `github.actor_id == github.repository_owner_id` と `github.triggering_actor == github.repository_owner` の両方を要求する。`github.actor` は再実行しても最初の実行者のままで、再実行はその権限で動くため、再実行した者を `github.triggering_actor` で確かめる。`triggering_actor` には ID がないため、ユーザー名で比べる。最初のジョブだけに置かないのは、「Re-run failed jobs」では成功済みのジョブが実行し直されず、その `if` も評価し直されないためである。必須なのは権限を持つジョブ（attest、container、release）で、読み取り専用のジョブにも置くのは、ジョブごとに要否を判断せずに済む規則にするためである
- **タグの移動**：公開物を残したまま、タグを別のコミットへ移動しない。ソースを直す場合は新しいバージョンを使うか、[失敗時のやり直し](#失敗時のやり直し) の手順で公開物を削除してから作り直す
- **正式リリースの完了点**：GitHub Release の公開である。タグや GHCR のイメージが存在しても、GitHub Release が公開されるまではリリース済みと扱わない
- **ワークフローの成功**：post-verify までのすべてのジョブが成功した状態である。正式リリースの完了点とは別に判定するため、post-verify が失敗した場合は「公開済みだが、公開後の照合に失敗した」状態になる

CLI は `--version` で、ビルド時に `-X main.version=<バージョン>` で埋め込んだ値を出力します。
値は先頭の `v` を除いた形（`1.2.3`）で、配布アーカイブのファイル名に入るバージョンと同じです。
ワークフローはこの出力を、ビルドしたバイナリにタグのバージョンが埋め込まれたことの確認に使います（build で linux_amd64 のアーカイブ、verify-image でイメージ）。

アプリケーション名とバージョンは、ワークフローの `env` に1回だけ書き、各ジョブはそれを参照します。

- **`APP_NAME`**：`playground-workflows`。`.goreleaser.yaml` の `project_name` と `binary`、`Dockerfile` のバイナリのパスと一致させる。食い違うと build のアーカイブの確認で止まる
- **`VERSION`**：`github.ref_name`、つまり起動したタグ（`v1.2.3`）である。GitHub Release と GHCR のタグに使い、配布アーカイブの名前と `--version` の照合には、シェルで先頭の `v` を除いた値を使う

preflight の outputs で後続のジョブへ渡す方法は採りません。
outputs は `needs` に直接書いたジョブからしか参照できないため、全ジョブの `needs` に preflight を加えることになるうえ、`github.ref_name` は実行中に変わらず、preflight を通したことで値の信頼性が増すわけでもないためです。

## ジョブ構成

```text
push refs/tags/vX.Y.Z
    │
    ▼
preflight ── タグが main の履歴にあるか、同じバージョンの公開物がないか
    │
    ▼
test ── go mod verify / go vet / go test
    │
    ▼
build ── GoReleaser で配布アーカイブ 6 件、SBOM 6 件、SHA256SUMS を生成し、中身とバージョンを確認
    │
    ▼
attest ── 配布アーカイブと SBOM の Artifact Attestation
    │
    ▼
container ── アーカイブ内の Linux バイナリを OCI 化して GHCR へ公開、証明
    │
    ▼
verify-image ── GHCR から digest 指定で取得し、証明の検証、バイナリ照合、実行
    │
    ▼
release ── 来歴を検証し、container-image.txt を作り、GitHub Release を公開
    │
    ▼
post-verify ── 公開済みのアセットと GHCR を取得し直して照合
```

取り消しにくい処理ほど後ろに置きます。
GHCR への公開は、ビルドと配布アーカイブの確認、来歴証明が成功してから行い、GitHub Release の公開は、GHCR に公開したイメージの検証が成功してから行います。

| ジョブ | `needs` | `GITHUB_TOKEN` の権限 | ソースの Checkout |
|---|---|---|---|
| preflight | なし | `contents: read`、`packages: read` | あり（全履歴） |
| test | preflight | `contents: read` | あり |
| build | test | `contents: read` | あり（全履歴） |
| attest | build | `id-token: write`、`attestations: write` | なし |
| container | build、attest | `contents: read`、`packages: write`、`id-token: write`、`attestations: write` | あり（Dockerfile だけを使う） |
| verify-image | container | `attestations: read` | なし |
| release | attest、container、verify-image | `contents: write`、`attestations: read` | なし |
| post-verify | container、release | `contents: read`、`attestations: read` | なし |

ワークフロー全体の `permissions` は `{}` とし、権限は各ジョブに明示します。
Action はトークンを引数で渡さなくても `github.token` を参照できる場合があるため、権限の付与そのものを絞ります。

権限の割り当ては、次の考え方に従います。

- **コードを実行するジョブ**（test、build）には、OIDC と公開の権限を与えない
- **署名するジョブ**（attest）は、Checkout もビルドもせず、受け取ったチェックサムに署名するだけにする
- **公開するジョブ**（container、release）では、リポジトリのコードを実行しない。container は Dockerfile を読むためだけに Checkout し、release は Checkout せずに受け取ったファイルをデータとして登録する

## 各ジョブの責務

### preflight

リリースできない状態のタグで、テストやビルドの前に止めます。

- タグの指すコミットが `origin/main` の履歴に含まれない場合は失敗する（`git merge-base --is-ancestor`）
- 同じバージョンの GitHub Release が存在する場合は失敗する（`gh release view`）
- GHCR に同じバージョンのタグが存在する場合は失敗する（`docker buildx imagetools inspect`）

存在しない場合も、認証や通信の障害の場合も、コマンドの終了コードは 1 です。
終了コードだけで判定すると、障害を「存在しない」と誤判定して先へ進み、GHCR のタグを上書きしてしまいます。
そのため、エラーメッセージが「存在しない」ことを示す場合（`release not found`、`ERROR: <参照>: not found`）だけを「存在しない」とし、それ以外の失敗では確認できなかったものとして止めます。
`git merge-base` も同じく、祖先でない場合（終了コード 1）と、`origin/main` がないなどの失敗を分けて報告します。

GHCR は、`packages: read` を与えて `GITHUB_TOKEN` でログインしてから確認します。
匿名では、存在しないパッケージも `not found` になるため、パッケージが非公開になっていると既存のタグを検出できないからです。
preflight はリポジトリのコードを実行せず、読み取りの権限を足すだけのため、ログインを加えても公開の権限には届きません。

preflight は「Re-run all jobs」では実行し直されますが、「Re-run failed jobs」では成功済みのため実行されません。
そのため、container も公開の直前に同じ判定で GHCR のタグの存在を確かめます（[container](#container)）。

### test

`go mod download`、`go mod verify`、`go vet ./...`、`go test -count=1 ./...` を実行します。
`GOTOOLCHAIN=local` と `GOFLAGS=-mod=readonly` を指定し、テスト中に Go のツールチェーンや依存の定義が切り替わらないようにします。

コード変更に対する包括的な品質の検証は、プルリクエストで動く通常 CI の役割です。
このジョブは、リリースするコミットそのものについて、重要な品質条件を通常 CI とは独立に確かめ直します。
タグはプルリクエストで検証したコミットとは別のコミットに付けられ得るため、通常 CI を整備した後もこのジョブを残します。
現時点では、プルリクエストで `go test` を実行する通常 CI はまだありません（[将来の拡張](#将来の拡張)）。

### build

GoReleaser OSS で配布アーカイブ 6 件、SBOM 6 件、`SHA256SUMS` を生成し、`release-assets` という名前の Actions Artifact としてアップロードします。
このジョブの出力が、以降のすべてのジョブが扱う正規の成果物です。

- GoReleaser がタグからバージョンを決めるため、全履歴（`fetch-depth: 0`）を取得する
- GoReleaser と、GoReleaser が SBOM の生成に呼び出す Syft を、GitHub Releases から取得し、ワークフローに書いた SHA-256 と照合してからインストールする（[外部 Action とツールの固定](#外部-action-とツールの固定)）
- `goreleaser check` の後、`goreleaser release --clean --skip=publish,announce` を実行する
- `GORELEASER_CURRENT_TAG` に起動したタグを渡す。同じコミットに複数のタグがあると、GoReleaser は最も大きいバージョンのタグを選ぶためである
- `dist/` のアーカイブが、タグのバージョンを含む期待どおりの 6 件と一致し、`dist/` の SBOM がその 6 件に `.sbom.json` を付けた名前と一致し、`SHA256SUMS` の列挙がその 12 件と一致することを確かめる。アーカイブや SBOM の欠落、バージョンの食い違い、想定外のファイルの混入を検出する
- 6 件それぞれの直下が `playground-workflows`（Windows では `playground-workflows.exe`）と `LICENSE` だけであること、tar.gz のバイナリに実行権限があることを確かめる
- 各 SBOM が SPDX の JSON として読め、文書の名前が対象のアーカイブ名であり、アーカイブ名のパッケージに対象のアーカイブの SHA-256 が記録されていることを確かめる。SBOM の記載内容の正確さは確かめない
- linux_amd64 のアーカイブを `dist/` の外に展開して実行し、`--version` の出力がタグと一致することを確かめる。`-X` の変数名を誤ってもリンカは警告なしに無視するため、埋め込みはバイナリを実行して確かめる
- 最後に `sha256sum -c SHA256SUMS` を実行する。バイナリの実行より後に置き、照合の後はアップロードだけにする
- アップロードするのは `dist/*.tar.gz`、`dist/*.zip`、`dist/*.sbom.json`、`dist/SHA256SUMS` だけで、`dist/` 内の内部メタデータや単体のバイナリは渡さない

アーカイブの確認を別ジョブにせず build に置くのは、アップロードするファイルそのものを確かめられ、build が OIDC も公開の権限も持たないためです。
test ジョブでは、GoReleaser が作ったバイナリがまだ存在しないため、`-X` が効いたかを確かめられません。

`--version` を公開前に実行して確かめるのは、linux_amd64 だけです。
linux_arm64 は verify-image が確かめますが、GHCR への公開後になります。
darwin と windows は、`ldflags` が全ターゲットで共通であるという設定上の前提に依存しており、`.goreleaser.yaml` の `builds` にターゲット別の上書きを加えると、この前提は崩れます。

### attest

`actions/attest` に `subject-checksums` として `SHA256SUMS` を渡し、`SHA256SUMS` に列挙された配布アーカイブ 6 件と SBOM 6 件に SLSA Build Provenance の Artifact Attestation を付けます。
`SHA256SUMS` 自体は subject に含まれません。

`actions/attest` には、Build Provenance を作るよう指定する入力がありません。
predicate の入力（`predicate-type`、`predicate`、`predicate-path`）を省いたときに Build Provenance を作り、`predicate-type` を渡すと独自の predicate として扱われ、predicate の本体も自分で書く必要があります。
そのため入力は省き、既定の挙動が将来変わっても公開しないよう、検証する側（container、verify-image、release）の `gh attestation verify` に `--predicate-type https://slsa.dev/provenance/v1` を明示します。

署名するジョブを build と分けるのは、GoReleaser やビルド中に動くコードに OIDC の権限を渡さないためです。
ただし、attest が署名するのは同じ実行の build がアップロードした Artifact の中身であり、build の実行環境が侵害されていればその出力にも署名が付きます。
この限界は、build と attest を1ジョブにまとめた場合と変わりません。

### container

配布アーカイブに入っている Linux バイナリを格納したイメージを、GHCR に公開して証明します。

1. `release-assets` をダウンロードし、`sha256sum -c SHA256SUMS` で照合する
2. Linux 向けアーカイブ 2 件で、release と同じ期待値の `gh attestation verify` を実行し、署名された subject の名前も確かめる
3. Linux 向けアーカイブ 2 件から `playground-workflows` を取り出し、`<arch>/playground-workflows` の形で専用のビルドコンテキストに置く
4. GHCR にログインし、同じバージョンのタグがないことを preflight と同じ判定で確かめる
5. Docker Buildx で `linux/amd64,linux/arm64` のイメージをビルドし、`ghcr.io/tmknom/playground-workflows:vX.Y.Z` として公開する
6. `docker/build-push-action` が出力した Image Index の digest に Artifact Attestation を付け、GHCR にも保存する
7. digest をジョブの出力として後続ジョブへ渡す

GHCR への公開も取り消しにくいため、release と同じく、来歴の検証を公開の条件にします。
`SHA256SUMS` との照合だけでは、アーカイブと `SHA256SUMS` が一緒に差し替えられた場合を検出できないためです。
検証するのは、イメージに格納するバイナリを取り出す Linux 向けアーカイブ 2 件だけです。
`attestations: write` は読み取りも含むため、権限は増えません。

公開の直前にもタグの存在を確かめるのは、公開後の Attestation の生成などでこのジョブが失敗したとき、「Re-run failed jobs」で同じタグへ再び公開するのを防ぐためです。
「Re-run failed jobs」では成功済みの preflight が実行されないため、preflight の確認だけでは防げません。
BuildKit が既定で付ける Provenance にはビルドの時刻などが記録されるため、再び公開すると Image Index の digest が変わり、タグが別のイメージを指す可能性があります。

`docker/build-push-action` は既定で、ビルドの記録（ビルドのログや設定、BuildKit の Provenance をまとめた `.dockerbuild` ファイル）を Actions Artifact としてアップロードします。
ビルドの失敗を Docker Desktop などで調べるための記録で、公開物にも検証にも使いません。
ジョブ間で受け渡す Actions Artifact を `release-assets` だけにするため、`DOCKER_BUILD_RECORD_UPLOAD=false` で止めます。

公開した後に Attestation の生成で失敗すると、Attestation のないイメージがタグ付きで GHCR に残ります。
再実行はこの確認で止まるため、そのイメージを再利用して証明を付け直すことはしません。
GitHub Release は公開されておらず、このイメージを参照する `container-image.txt` もないため、GHCR のバージョンを削除するか、新しいバージョンでやり直します。

イメージの設計は [コンテナイメージ](#コンテナイメージ)、証明の設計は [来歴証明](#来歴証明) に記載します。

### verify-image

GHCR に公開したイメージを、container の出力した digest で取得して検証します。
amd64 と arm64 の runner で1回ずつ実行し、それぞれの CPU のイメージを確かめます。
runner の CPU が matrix の指定と一致することを先に確かめます。
QEMU が使える runner では、別の CPU のイメージもエミュレーションで実行できてしまうためです。

1. `sha256sum -c SHA256SUMS` で照合し、digest が `sha256:<64 桁の 16 進数>` の形であることを確かめる
2. `gh attestation verify oci://...` が、期待する predicate type、リポジトリ、署名したワークフロー、タグ、コミット SHA で成功する
3. イメージから取り出したバイナリと、Linux 向けアーカイブから取り出したバイナリが `cmp` で一致する
4. イメージの実行ユーザーが `nonroot:nonroot` である
5. `--version` の出力がタグと一致する

来歴とバイナリの一致を確かめてから、イメージを実行します。
`gh attestation verify` は、`--bundle-from-oci` を付けなければ Attestation を GitHub の Attestation API から取得するため、`attestations: read` が要ります。

GHCR にはログインせず、匿名で取得します。
パッケージが Public であることが前提で、`packages: read` も与えません。
パッケージが非公開のままだと取得に失敗し、GitHub Release は公開されません。

### release

受け取った成果物と公開先の状態を検証してから、GitHub Release を公開します。
検証は、公開するファイル（Verify assets）と公開の前提（Verify release target）の2つのステップに分け、公開のステップ（Publish release）は公開だけを行います。

Verify assets は、公開するファイルを確かめます。

1. `SHA256SUMS` に列挙されたファイル名が、タグのバージョンを含む期待どおりの 12 件（アーカイブ 6 件と SBOM 6 件）と一致することを確かめ、`sha256sum -c SHA256SUMS` で照合する
2. 12 件のそれぞれで `gh attestation verify` を実行する。期待値は、predicate type（`https://slsa.dev/provenance/v1`）、リポジトリ、署名したワークフロー（`release-go-cli.yml`）、`--signer-digest` と `--source-digest` に `GITHUB_SHA`、`--source-ref` に `GITHUB_REF` である。`gh attestation verify` はファイルの digest だけで Attestation を探すため、`--format json` の出力から、ファイル名と digest の組が署名された subject に含まれることも確かめる

Verify release target は、公開の前提を確かめます。

1. container の出力した digest が `sha256:<64 桁の 16 進数>` の形であることを確かめる
2. コミットの API に `refs/tags/vX.Y.Z` を渡して得た SHA が `GITHUB_SHA` と一致することを確かめる
3. Draft を含めて、同じタグの Release がないことを確かめる
4. 公開するバージョンが現在の「Latest」より小さければ、警告を出す

Publish release は、公開します。

1. `ghcr.io/tmknom/playground-workflows@sha256:<digest>` を1行で書いた `container-image.txt` を作る
2. `gh release create <タグ> --verify-tag --target <GITHUB_SHA> --title <タグ> --generate-notes` で公開する。アセットとして登録するのは、`SHA256SUMS` に列挙されたアーカイブと SBOM、`SHA256SUMS`、`container-image.txt` だけである。列挙を配列に読み込んだ結果が 12 件でなければ公開しない

`SHA256SUMS` との照合だけでは、アーカイブと `SHA256SUMS` が一緒に差し替えられた場合を検出できません。
署名の検証を加えることで、公開するアーカイブが、このワークフローによって同じコミットとタグで署名されたものであることを確かめます。
検証は実行 ID までは照合しないため、同じコミットとタグで実行した過去の実行の署名も受け入れます。
subject の名前を確かめるのは、署名されたアーカイブ同士で中身を入れ替えても digest の照合だけでは検出できないためです。

登録するファイルをディレクトリの中身すべてにしないのは、受け渡す Artifact の対象が将来広がったときに、照合も署名もしていないファイルが黙って公開されるのを防ぐためです。

`--verify-tag` は、タグが存在しないときに `gh` がタグを新しく作ることを防ぎます。
`--target` は、タグが存在するときはタグの作成に使われず、Release のメタデータ（`target_commitish`）に記録されるだけです。
指定しなければ既定ブランチの名前が記録されるため、`GITHUB_SHA` を記録するよう指定します。
Release はタグの指すコミットに付くため、`--target` ではタグの付け替えを検出できません。
そのため、公開の直前にタグの参照先を確かめます。
確かめた直後の付け替えまでは防げないため、post-verify が公開後にもう一度確かめます。

公開した Release は、バージョンの大小にかかわらず「Latest」になります。
そのため、大きいバージョンを公開した後に小さいバージョンを公開すると（失敗した古い実行を後から再実行した場合など）、小さいほうが「Latest」を奪います。
動作確認では、`make_latest: false` を渡しても、公開した小さいバージョンが「Latest」になりました。
防ぐには、公開の後に元の「Latest」へ `make_latest: true` を付け直す必要があります。

この付け直しは、ワークフローでは行いません。
古いバージョンを後から公開する場面はまれで、起きても「Latest」を手動で付け直せば済みます。
一方で自動化すると、CLI のリリースが、関係のない Release（Lambda リリースの場合もある）を書き換えることになります。
代わりに、公開するバージョンが現在の「Latest」より `sort -V` で小さければ、警告を出します。
警告のための確認なので、「Latest」を取得できなくても公開は止めません。

動作確認で既存より小さい `v0.0.N` を公開すると、削除するまでの間は確認用の Release が「Latest」になります。
削除すると、「Latest」は元に戻ります。

Draft を確認してから公開する独立した工程は設けません。
Draft と公開の間に挟む確認がないためです。
ただし、アセットを指定した `gh release create` は、内部で Draft を作り、アセットをアップロードしてから公開します。
途中で失敗すると、アセットの一部だけを持つ Draft が残る可能性があります。
Draft があっても `gh release create` が失敗するとは限らないため、公開の前に Draft を含めて同じタグの Release がないことを確かめます。
同じタグの Release は公開済みのものも含めてこの確認で止まるため、既存の Release を書き換えません。
post-verify も、Release が Draft でないことを確かめます。

### post-verify

公開した GitHub Release と GHCR のイメージを取得し直し、ワークフローが生成した正規の成果物と照合します。
このジョブの成功をもって、ワークフローの成功とします（[リリースの起点とバージョン](#リリースの起点とバージョン)）。

- Release が Draft ではない
- コミットの API に `refs/tags/vX.Y.Z` を渡して得た SHA が `GITHUB_SHA` と一致する（軽量タグと注釈付きタグのどちらでも、指しているコミットの SHA が得られる。タグ名だけを渡すと、同じ名前のブランチがあるときに参照先が曖昧になる）
- `gh release download` で取得したアセットと、正規の成果物に `container-image.txt` を加えたものが `diff -r` で一致する。アセットの過不足と内容の違いを同時に検出する
- GHCR の `vX.Y.Z` タグが、`container-image.txt` に記録した digest を指している
- 取得したアセットと `container-image.txt` の参照を使い、[利用者による検証](#利用者による検証) と同じコマンドで来歴を検証できる

来歴の検証には、release と verify-image が付けている `--signer-digest` と `--source-digest` を付けません。
目的は、利用者向けの手順が公開済みのアセットで通ることを確かめることにあるためです。
コミットとの対応は、`diff -r` でアセットが release の検証したファイルと一致し、タグが `GITHUB_SHA` を指すことで確かめています。

verify-image と同じく、GHCR にはログインせず、`packages: read` も与えません。

このジョブが失敗した時点で、GitHub Release はすでに公開されています。
自動では取り消さず、失敗の内容を見てから削除してやり直すかを判断します。
`release-assets` の保持期間は 1 日のため、それを過ぎると post-verify だけを再実行できません。
その場合は [失敗時のやり直し](#失敗時のやり直し) の手順で全体をやり直します。

## 成果物とジョブ間の受け渡し

GitHub Release のアセットは、次の 14 件です。

| アセット | 内容 | 生成するジョブ |
|---|---|---|
| `playground-workflows_<バージョン>_<os>_<arch>.tar.gz` | Linux、macOS 向けの配布アーカイブ。4 件 | build |
| `playground-workflows_<バージョン>_windows_<arch>.zip` | Windows 向けの配布アーカイブ。2 件 | build |
| `<アーカイブ名>.sbom.json` | 配布アーカイブごとの SBOM（SPDX JSON）。6 件 | build |
| `SHA256SUMS` | 配布アーカイブ 6 件と SBOM 6 件の SHA-256 | build |
| `container-image.txt` | GHCR のイメージの digest 付きの参照。1行 | release |

`<バージョン>` は先頭の `v` を除いた形です。
各アーカイブは直下に `playground-workflows`（Windows では `playground-workflows.exe`）と `LICENSE` を含みます。

ジョブ間で受け渡す Actions Artifact は `release-assets` の1つだけで、中身は配布アーカイブ 6 件、SBOM 6 件、`SHA256SUMS` です。
コンテナに格納する Linux バイナリは、container が Linux 向けアーカイブから取り出します。
アーカイブは `SHA256SUMS` と Artifact Attestation で検証できるため、取り出したバイナリは配布物と同じバイト列になり、バイナリ単体のハッシュ一覧を別に持つ必要がありません。
実行権限もアーカイブの中で保持されます。

GHCR の Image Index digest は、container ジョブの出力 `digest` として後続ジョブへ渡します。
イメージ名は `ghcr.io/${{ github.repository }}` で各ジョブが組み立てます。

`actions/download-artifact` の転送単位の digest 検査とは別に、各ジョブで `sha256sum -c SHA256SUMS` を実行します。
転送の検査は Artifact の破損を検出するものであり、公開の停止条件はファイル単位の照合と署名の検証に置くためです。

## ビルドの設定

Go のビルドとパッケージングは GoReleaser OSS に任せ、担当範囲をバイナリ、アーカイブ、SBOM、チェックサムの生成までに限ります。

| 処理 | 担当 |
|---|---|
| Go のクロスコンパイル | GoReleaser OSS |
| tar.gz / ZIP の生成 | GoReleaser OSS |
| SBOM の生成 | GoReleaser OSS の `sboms` が呼び出す Syft |
| `SHA256SUMS` の生成 | GoReleaser OSS の `checksum` |
| コンテナイメージの生成と GHCR への公開 | Docker Buildx（GoReleaser の Docker 機能は使わない） |
| 来歴証明 | GitHub Artifact Attestations（GoReleaser の署名機能は使わない） |
| GitHub Release の公開とリリースノート | GitHub CLI（GoReleaser の公開機能と changelog は使わない） |

`.goreleaser.yaml` の要点は次のとおりです。

- **`builds`**：`main: .`、`binary: playground-workflows`、`goos` は linux / darwin / windows、`goarch` は amd64 / arm64
- **環境変数**：`CGO_ENABLED=0`、`GOTOOLCHAIN=local`
- **フラグ**：`-trimpath`、`-mod=readonly`
- **`ldflags`**：`-s -w -X main.version={{ .Version }}`
- **`mod_timestamp`**：`{{ .CommitTimestamp }}`。バイナリの更新時刻をビルド時刻ではなくコミット時刻にする
- **`archives`**：既定は tar.gz、Windows は ZIP。名前は `{{ .ProjectName }}_{{ .Version }}_{{ .Os }}_{{ .Arch }}`。同梱ファイルは `LICENSE` だけを明示する
- **`sboms`**：`artifacts: archive` で、アーカイブごとに `<アーカイブ名>.sbom.json` を SPDX JSON で生成する。GoReleaser では `sboms` が `checksum` より先に動くため、SBOM も `SHA256SUMS` に列挙され、署名の対象になる。Syft の既定の引数にある `--enrich all` は、ライセンスなどの情報をネットワークから取得するため外し、アーカイブの中身だけから作る。Syft の更新の確認（`SYFT_CHECK_FOR_APP_UPDATE`）も止める
- **`checksum`**：`name_template: SHA256SUMS`、`algorithm: sha256`
- **`changelog`**：`disable: true`

SBOM には生成時刻と実行ごとに変わる文書の識別子が入るため、同じ入力から生成し直しても同じバイト列になりません。
SBOM の記載内容は、アーカイブ内のバイナリに埋め込まれたビルド情報から Syft が読み取ったもので、正確さはリリースの工程で確かめません。

`before.hooks` は置きません。
`go generate` や `go mod tidy` をリリース中に実行すると、ソースや依存の定義がビルドの途中で変わり得るためです。
依存の整合性はテストの段階で `go mod verify` が確かめます。

Go のバージョンは `go.mod` の `go` 行で固定し、`actions/setup-go` に `go-version-file: go.mod` を渡します。
固定が成り立つのは、`go` 行がパッチバージョンまで書かれ（`1.27.0` など）、`toolchain` 行がない場合です。
パッチバージョンを省くと `actions/setup-go` が利用できるパッチバージョンを解決し、`toolchain` 行があればそちらが優先されます。
`GOTOOLCHAIN=local` により、ビルド中に別のツールチェーンを取得しません。
`actions/setup-go` のキャッシュは、同じリポジトリの他のワークフローも書き込めるため無効にします。

## コンテナイメージ

リポジトリ直下の `Dockerfile` でイメージを定義します。

```dockerfile
FROM gcr.io/distroless/static-debian13:nonroot@sha256:<Image Index digest>
ARG TARGETARCH
COPY --chmod=0755 ${TARGETARCH}/playground-workflows /usr/local/bin/playground-workflows
USER nonroot:nonroot
ENTRYPOINT ["/usr/local/bin/playground-workflows"]
```

- **ベースイメージ**：Distroless static の nonroot。非 cgo の Go バイナリが必要とすることの多い CA 証明書とタイムゾーン情報を含む。Image Index の digest で固定し、Dependabot（`docker` の `directories` に `/` を含める）で更新する
- **`RUN` を使わない**：ビルド中に対象 CPU のプログラムを実行しないため、QEMU が要らない
- **Go を再コンパイルしない**：格納するのは配布アーカイブから取り出したバイナリである。イメージ内のバイナリは配布物とバイト単位で一致する
- **ビルドコンテキスト**：Linux バイナリ 2 つだけを置いた専用ディレクトリを渡す。ソースコードは Buildx に渡らない。Buildx の既定の Git コンテキストは、先行ステップで用意したファイルを反映しないため使わない
- **タグ**：`vX.Y.Z` だけを付け、`latest` は付けない。イメージの識別と検証には digest を使う
- **OCI ラベル**：`org.opencontainers.image.source`、`org.opencontainers.image.revision`、`org.opencontainers.image.version` を付ける

GHCR へは `docker/login-action` に `GITHUB_TOKEN` を渡してログインします。
初回の公開直後のパッケージは非公開のため、パッケージの設定で公開範囲を Public に変え、リポジトリに紐づいていることを一度だけ確認します。
リポジトリが Public であることと、GHCR のパッケージが Public であることは別の設定です。

## 来歴証明

来歴証明には GitHub Artifact Attestations（`actions/attest`）を使い、SLSA Build Provenance を生成します。

| subject | 生成するジョブ | 保存先 |
|---|---|---|
| 配布アーカイブ 6 件と SBOM 6 件（`SHA256SUMS` に列挙されたもの） | attest | GitHub の Attestation API |
| GHCR の Image Index digest | container | GitHub の Attestation API と GHCR（`push-to-registry: true`） |

イメージの証明は、container ジョブの中で生成します。
レジストリへ証明を保存するには `packages: write` が要り、別ジョブにしても同じ権限を持つジョブが2つに増えるだけだからです。
subject はタグではなく digest にします。
タグは付け替えられるためです。

`create-storage-record` は `false` にします。
storage record は、組織の linked artifacts ページに成果物の保存先を記録する、組織が所有するリポジトリ向けの機能で、`artifact-metadata: write` を必要とするためです。
Attestation の生成と検証には使われず、作らなくても来歴の検証は変わりません。
container の `DOCKER_BUILD_RECORD_UPLOAD` が止めるビルドの記録とは別のものです（[container](#container)）。

Docker BuildKit が既定で付ける Provenance はそのまま残しますが、GitHub の署名が付いた来歴としては扱いません。
Public リポジトリでは BuildKit の Provenance にビルド引数が記録され得るため、ビルド引数に秘密情報を渡しません。

`SHA256SUMS` と `container-image.txt` は証明の subject に含めません。
この2ファイルには、現時点で署名による保護がありません。

## 公開の順序と部分成功

公開は次の順に進みます。

1. 正規の成果物を生成して中身とバージョンを確かめ、来歴証明を成功させる
2. GHCR にイメージを公開し、digest と来歴証明を確定する
3. GHCR から digest 指定で取得したイメージを検証する
4. `container-image.txt` を作り、GitHub Release を公開する
5. 公開済みのアセットと GHCR を取得し直して照合する

GitHub Releases と GHCR は原子的に公開できないため、手順 2 から 4 の間は GHCR にだけイメージがある状態になります。
この間に失敗した場合の部分成功は、避けられない状態として受け入れます。
GHCR への公開は、GitHub Release の公開と同義ではありません。

## 失敗時のやり直し

ワークフローは、公開途中の状態から自動で回復しません。
また、公開途中で生成したものを自動で削除するロールバックも行いません。

| 失敗した位置 | 対応 |
|---|---|
| preflight、test、build、attest | 何も公開されていない。原因を直し、必要ならタグを削除して新しいコミットにタグを付け直す。ソースが変わらないなら失敗したジョブを再実行してよい |
| container | GHCR にイメージがある可能性がある。公開前に失敗したなら「Re-run failed jobs」で再実行してよい。公開後に失敗したなら、再実行は公開直前の確認で止まるため、GHCR のバージョンを削除してから再実行するか、新しいバージョンでやり直す |
| verify-image | GHCR にイメージがある。「Re-run failed jobs」では container が実行されず、公開済みのイメージをそのまま検証し直す。「Re-run all jobs」は preflight で止まるため、GHCR のバージョンを削除してから実行する |
| release 以降 | GitHub Release が公開されているか、Draft が残っている可能性がある。下記の手順で全体をやり直す。Draft も Release と同じく削除する |

同じバージョンを作り直すときは、次の3つを手動で削除してからタグをプッシュし直します。

```bash
gh release delete vX.Y.Z --yes
git push origin :refs/tags/vX.Y.Z
git tag -d vX.Y.Z
```

GHCR の該当バージョンは、パッケージの設定画面から削除します。
preflight は同じバージョンの Release と GHCR のタグがあると止まるため、一部だけ削除した状態では再実行できません。

`concurrency` は `group: release`、`cancel-in-progress: false` とし、実行中の公開を後続の実行が取り消さないようにします。
グループ名は Lambda のリリースと共有します（[Lambda リリースとの共存](#lambda-リリースとの共存)）。
`queue` は既定の `single` のままのため、グループ内で待機できる実行は1つだけです。
待機中の実行は、後から待機に入った実行に置き換えられて取り消されます。
取り消された実行は、何も公開していないため、再実行してやり直します。
同時実行の制御では管理者の直接操作を防げないため、preflight の存在確認と post-verify の照合は省略しません。

## Immutable Release を採用しない運用

GitHub の Immutable Releases は、現時点では有効にしません。
有効にすると、公開済みの Release のアセットと関連する Git タグを変更、削除できなくなり、同じバージョンでリリース工程を繰り返し試すことができなくなるためです。

この運用は、次の前提に立ちます。

- Git タグ、GitHub Release、GHCR のパッケージバージョンは、検証のために削除してよい
- 不整合な状態になった場合は、すべて削除して初めからやり直してよい
- Tag Rulesets によるタグの更新、削除の制限も導入しない
- Release Attestation が生成されないため、`gh release verify` と `gh release verify-asset` は使わない。公開後のアセットは post-verify が取得し直して照合する

この運用で失う保証は2つです。

- 公開後の Release のアセットと Git タグを、書き換えから保護すること
- `SHA256SUMS` と `container-image.txt` の内容を、署名で検証できるようにすること

配布アーカイブとイメージには Artifact Attestation が付くため、それらの来歴の検証は Immutable Release がなくても成り立ちます。

## 利用者による検証

利用者は `gh attestation verify` で、配布物の生成元を確かめられます。
Attestation は、検証する側が期待値を知っていて初めて意味を持つため、期待値を次のように定めます。
利用者向けの手順は、[playground-workflows の Go CLI の節](../README.md#go-cli) に載せています。

| 期待値 | 値 |
|---|---|
| リポジトリ | `tmknom/playground-workflows` |
| 署名したワークフロー | `tmknom/playground-workflows/.github/workflows/release-go-cli.yml` |
| ソースの ref | `refs/tags/vX.Y.Z` |
| 実行基盤 | GitHub-hosted runners（`--deny-self-hosted-runners`） |

配布アーカイブは次のように検証します。

```bash
gh attestation verify playground-workflows_X.Y.Z_linux_amd64.tar.gz \
  --repo tmknom/playground-workflows \
  --signer-workflow tmknom/playground-workflows/.github/workflows/release-go-cli.yml \
  --source-ref refs/tags/vX.Y.Z \
  --deny-self-hosted-runners
```

SBOM も、ファイル名を `<アーカイブ名>.sbom.json` に変えた同じコマンドで検証します。

コンテナイメージは、`container-image.txt` に書かれた digest 付きの参照で特定してから検証します。

```bash
gh attestation verify "oci://$(cat container-image.txt)" \
  --repo tmknom/playground-workflows \
  --signer-workflow tmknom/playground-workflows/.github/workflows/release-go-cli.yml \
  --source-ref refs/tags/vX.Y.Z \
  --deny-self-hosted-runners
```

署名したワークフローは、`--cert-identity` ではなく `--signer-workflow` で指定します。
GitHub CLI v2.103.3 では、`--signer-workflow` は前方一致ではありませんでした。
`release-go-cli.ym` のような途中までのパス、`.` を別の文字に変えたパス、`release-go-cli.yml@refs` のように ref の途中までを付けた値では、検証が失敗しました。
渡したパスの直後に、証明書の SubjectAlternativeName の `@<ref>` が続く場合だけ一致すると考えられます。
`--cert-identity` はタグまで含む値を渡す必要があり、タグの照合は `--source-ref` と重なります。

Attestation の subject は Image Index の digest だけです。
Index に含まれる `linux/amd64` や `linux/arm64` のマニフェストの digest を指定すると、Attestation が見つからず検証に失敗します。

`SHA256SUMS` によるハッシュの照合も使えますが、それだけではアーカイブと `SHA256SUMS` が一緒に差し替えられた場合を検出できません。
来歴の検証と併用します。

post-verify は、公開済みのアセットに対してこれと同じ引数で検証を実行します。
そのため、利用者向けの手順が実際に通ることを、リリースのたびに確かめられます。

## Lambda リリースとの共存

このリポジトリには、同じ `main.go` を AWS Lambda 用にビルドして GitHub Release を作る別のワークフロー（`release-lambda.yml`）があります。
両者は次の点で影響し合います。

- **バージョン番号を共有する**：Lambda リリースも `vX.Y.Z` のタグと GitHub Release を作るため、同じ番号は片方しか使えない。検証用リポジトリのため、この共有を受け入れる
- **ソースを共有する**：CLI に加える変更（`--version` など）は Lambda のバイナリにも入る
- **二重起動は起きない**：Lambda リリースは `GITHUB_TOKEN` でタグを作る。`GITHUB_TOKEN` による push は新しいワークフローを起動しないため、Lambda リリースが作ったタグで CLI のリリースは始まらない
- **実行を重ねない**：どちらもタグと GitHub Release を作るため、`concurrency` のグループを `release` で共有する

Lambda リリースは直近のタグから次のバージョンを計算するため、動作確認用に作ったタグを残すと、その計算に影響する可能性があります。
確認に使ったタグは削除します。

## 外部 Action とツールの固定

- **Action**：`uses` はすべて完全なコミット SHA で固定し、行末のコメントにバージョンを書く。更新は Dependabot（`github-actions`）に任せる
- **GoReleaser と Syft**：GitHub Releases から Linux amd64 のアーカイブを取得し、ワークフローに書いた SHA-256 と照合してから使う。インストール用の Action（`goreleaser/goreleaser-action`、`anchore/sbom-action/download-syft`）は使わない。Action の SHA で固定できるのは Action のコードだけで、Action が実行時に取得するバイト列は固定できないためである。たとえば `goreleaser/goreleaser-action` v7.3.0 は、アーカイブを同じ Release の `checksums.txt` と照合するだけで、`checksums.txt` を取得できなければ警告を出して照合を飛ばし、cosign による署名の検証は runner に cosign があるときしか行わない。Dependabot では更新できないため、バージョンとハッシュは手動で更新し、release-go-cli.yml と test-release-build.yml を同時に変える
- **Go**：`go.mod` の `go` 行にパッチバージョンまで書いて固定する（[ビルドの設定](#ビルドの設定)）
- **ベースイメージ**：Dockerfile の `FROM` に digest で固定する

固定する値は、追加や更新のたびに公式のリリース情報で確認します。

GoReleaser と Syft は、どちらも Release の `checksums.txt` に cosign の署名（Sigstore バンドル `checksums.txt.sigstore.json`）を付けています。
ワークフローの実行時には、この署名を検証しません。
ハッシュを固定していれば取得したバイト列は一意に決まり、実行時の署名検証は完全性に何も加えないうえ、cosign 自体を固定してインストールする手間が増えるためです。
署名が役立つのは、固定するハッシュが正規の発行元のものかを確かめる場面のため、バージョンとハッシュを更新するときに、次のように手元で検証してから `checksums.txt` の値を書き写します。

```bash
cosign verify-blob checksums.txt \
  --bundle checksums.txt.sigstore.json \
  --certificate-identity https://github.com/goreleaser/goreleaser/.github/workflows/release.yml@refs/tags/vX.Y.Z \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

cosign verify-blob syft_X.Y.Z_checksums.txt \
  --bundle syft_X.Y.Z_checksums.txt.sigstore.json \
  --certificate-identity https://github.com/anchore/syft/.github/workflows/release.yaml@refs/heads/main \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

署名者の identity は、GoReleaser v2.19.0 と Syft v1.55.0 の署名証明書に記録された値です。
Syft はタグではなく `main` ブランチのワークフローで署名しているため、identity からはバージョンを確かめられません。

## 設計上の不変条件

1. リリースタグを、公開物を残したまま別のコミットへ移動しない。
2. リリースの実行中に `main` の最新コミットを解決し直さない。
3. `CGO_ENABLED=0` でビルドする。
4. リリースの工程でソースコードや依存の定義を変更しない。
5. Go のバイナリは build ジョブの GoReleaser だけが生成し、コンテナ化で再コンパイルしない。
6. コンテナ内のバイナリは、配布アーカイブ内の Linux バイナリとバイト単位で一致する。
7. 来歴証明の subject は、配布アーカイブと SBOM の SHA-256、Image Index の digest である。
8. OIDC の権限は attest と container だけに、公開の権限は container と release だけに与える。
9. 必須の検証に失敗した場合は、GitHub Release を公開しない。
10. 既存の GitHub Release と GHCR のバージョンタグを、自動で上書きしない。
11. 公開済みの Release のアセットを自動で変更しない。作り直す場合は Release ごと削除する。
12. 公開後に、GitHub Release と GHCR の成果物を正規の成果物と照合する。

## 残るリスク

- **build の実行環境の侵害**：attest は build の出力に署名するため、build が侵害されていればその出力にも正しい署名が付く
- **GitHub 基盤への依存**：署名、実行、公開のすべてが GitHub の基盤に依存しており、基盤全体の侵害には対抗できない
- **タグ起点のワークフロー定義**：タグの指すコミットにあるワークフロー定義そのものが実行される。悪意のある定義が実行された後では、preflight は防御にならない。`main` の変更のレビューと、タグを作成できる者の限定に依存する
- **実行中のタグの付け替え**：Tag Rulesets でタグを保護していないため、実行中にタグを付け替えられる可能性がある。release が公開の直前に、post-verify が公開後にタグの参照先を確認するが、確認の直後の付け替えは防げない
- **存在確認の誤判定**：エラーメッセージの文言で判定するため、`gh` や Docker Buildx の文言が変わると、存在しないバージョンでも preflight や container が止まる
- **公開物の書き換え**：Immutable Release を採用していないため、公開後のアセットとタグは書き換えから保護されていない
- **作り直す前のビルドの Attestation**：利用者による検証はタグの名前を固定し、コミットを固定しない。[失敗時のやり直し](#失敗時のやり直し) で同じバージョンを作り直しても、前の実行が付けた Attestation は残るため、前のビルドのアーカイブやイメージも利用者の検証を通る。README の「保証しない内容」に書いている
- **Linux 以外の OS での実行**：macOS と Windows のバイナリは、どの工程でも実行していない。通常 CI を用意するまでは、OS 固有の不具合を公開前に検出できない
- **待機中の実行の取り消し**：`concurrency` の `queue` が `single` のため、リリースの実行中に2つ以上の実行が待機に入ると、先に待機していた実行が取り消される。取り消しは実行の一覧に残るため、気付いた時点で再実行する

## 将来の拡張

次の拡張は、必要性を判断してから着手します。

| 拡張 | 着手の条件 | 概要 |
|---|---|---|
| OS matrix の通常 CI | OS 固有の処理がコードに入ったとき | プルリクエストで、Linux / macOS / Windows の runner で `go test` を実行する |
| SBOM Attestation | `gh attestation verify` だけで、SBOM がどのアーカイブを記述しているかまで確かめたいとき | `actions/attest` の `sbom-path` で、アーカイブの digest を subject、SBOM を predicate とする Attestation を付ける。1回の呼び出しで渡せる SBOM は1つのため、アーカイブごとに呼び出す。現在は、SBOM 自体の来歴と、SBOM に記録したアーカイブの SHA-256 で対応を確かめる |
| コンテナイメージの SBOM | 提供を求められたとき | 格納するバイナリは配布アーカイブと同じため、アーカイブの SBOM で代えられないかを先に判断する |
| `govulncheck` | 外部のモジュールへの依存が増えたとき | 通常 CI と定期実行で既知の脆弱性を検出し、結果からリスクを評価する。リリースワークフローには加えない。脆弱性を減らすリリースまで止めないよう、検出の有無をリリースの必須条件にしない |
| 再ビルドによる再現性の確認 | Attestation と実行確認に加えて必要と判断したとき | 別の runner で再ビルドし、正規の `SHA256SUMS` のアーカイブの行で照合する。SBOM は生成のたびに変わるため照合から外す。アーカイブ内のファイルの時刻、所有者、権限の固定が必要になる可能性がある |
| Immutable Release | 削除を伴う試行が不要になったとき（Lambda リリースも含む） | Immutable Releases と Tag Rulesets を有効にし、post-verify と利用者向けの手順に `gh release verify` を加える |
| deb / rpm / apk | 配布を求められたとき | GoReleaser の `nfpms` を第一候補とし、build が生成したバイナリを再コンパイルせずに格納する |
| Homebrew Formula | 配布を求められたとき | 別リポジトリへの書き込み権限と認証情報の設計が必要になる |

次の項目は、拡張の予定もありません。

- **コンテナイメージの脆弱性検査**：ベースイメージは Distroless static で、格納するのは Go バイナリ1つだけである
- **公開途中の自動復旧**：手動で削除してやり直す運用で足りる
- **コンテナイメージ全体のバイト単位の再現**：内部のバイナリの一致とベースイメージの固定で足りる
