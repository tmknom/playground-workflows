# Go CLI のリリースワークフロー設計

このリポジトリの Go CLI（`playground-workflows`）を、Git タグのプッシュを起点に GitHub Releases と GitHub Container Registry（GHCR）へ公開するワークフローの設計です。
対象はワークフロー `.github/workflows/release-go-cli.yml` の完成形で、各ジョブの責務、権限、成果物の受け渡し、検証の条件、失敗時の扱いを定めます。

## 対象と前提

| 項目 | 方針 |
|---|---|
| リポジトリ | GitHub Free の Public リポジトリ。技術検証用である |
| 実行基盤 | GitHub-hosted runners |
| 配布する CLI | リポジトリ直下の `main.go`。バイナリ名は `playground-workflows` |
| 配布物 | Linux / macOS / Windows × amd64 / arm64 の 6 種類の配布アーカイブ |
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
| 完全性 | 配布アーカイブの SHA-256 と OCI イメージの digest が期待値に一致する | ハッシュ値だけで期待値の入手元を信頼できること |
| 来歴 | 成果物の digest と、リポジトリ、タグ、コミット、署名したワークフローの対応が署名で検証できる | 実行された処理やソースコードが安全であること |
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

CLI は `--version` で、ビルド時に `-X main.version=<バージョン>` で埋め込んだ値を出力します。
値は先頭の `v` を除いた形（`1.2.3`）で、配布アーカイブのファイル名に入るバージョンと同じです。
ワークフローはこの出力を、ビルドしたバイナリにタグのバージョンが埋め込まれたことの確認に使います（build で linux_amd64 のアーカイブ、verify-image でイメージ）。

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
build ── GoReleaser で配布アーカイブ 6 件と SHA256SUMS を生成し、中身とバージョンを確認
    │
    ▼
attest ── 配布アーカイブの Artifact Attestation
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
post-verify ── 公開済みの資産と GHCR を取得し直して照合
```

取り消しにくい処理ほど後ろに置きます。
GHCR への公開は、ビルドと配布アーカイブの確認、来歴証明が成功してから行い、GitHub Release の公開は、GHCR に公開したイメージの検証が成功してから行います。

| ジョブ | `needs` | `GITHUB_TOKEN` の権限 | ソースの Checkout |
|---|---|---|---|
| preflight | なし | `contents: read` | あり（全履歴） |
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

GHCR は、ログインせず、`packages: read` も与えずに匿名で確認します。
匿名では、存在しないパッケージも `not found` になるため、パッケージが非公開になっていると既存のタグを検出できない可能性があります。
パッケージが Public であることは verify-image と post-verify の前提でもあります。

preflight は「Re-run all jobs」でも実行し直されます。
container が GHCR に公開した後に失敗した実行は、全ジョブの再実行では preflight で止まります。
「Re-run failed jobs」では成功済みの preflight は実行されないため、失敗したジョブから再開できます。

### test

`go mod download`、`go mod verify`、`go vet ./...`、`go test -count=1 ./...` を実行します。
`GOTOOLCHAIN=local` と `GOFLAGS=-mod=readonly` を指定し、テスト中に Go のツールチェーンや依存の定義が切り替わらないようにします。

プルリクエストで `go test` を実行する通常 CI はこのリポジトリにないため、このジョブがリリース前の唯一のテストです。
プルリクエストで動く `verify-goreleaser.yml` は、GoReleaser の設定を snapshot ビルドで確かめるだけです。

### build

GoReleaser OSS で配布アーカイブ 6 件と `SHA256SUMS` を生成し、`release-assets` という名前の Actions Artifact としてアップロードします。
このジョブの出力が、以降のすべてのジョブが扱う正規の成果物です。

- GoReleaser がタグからバージョンを決めるため、全履歴（`fetch-depth: 0`）を取得する
- `goreleaser check` の後、`goreleaser release --clean --skip=publish,announce` を実行する
- `GORELEASER_CURRENT_TAG` に起動したタグを渡す。同じコミットに複数のタグがあると、GoReleaser は最も大きいバージョンのタグを選ぶためである
- `dist/` のアーカイブと `SHA256SUMS` に列挙されたファイル名が、どちらもタグのバージョンを含む期待どおりの 6 件と一致することを確かめる。アーカイブの欠落、バージョンの食い違い、想定外のファイルの混入を検出する
- 6 件それぞれの直下が `playground-workflows`（Windows では `playground-workflows.exe`）と `LICENSE` だけであること、tar.gz のバイナリに実行権限があることを確かめる
- linux_amd64 のアーカイブを `dist/` の外に展開して実行し、`--version` の出力がタグと一致することを確かめる。`-X` の変数名を誤ってもリンカは警告なしに無視するため、埋め込みはバイナリを実行して確かめる
- 最後に `sha256sum -c SHA256SUMS` を実行する。バイナリの実行より後に置き、照合の後はアップロードだけにする
- アップロードするのは `dist/*.tar.gz`、`dist/*.zip`、`dist/SHA256SUMS` だけで、`dist/` 内の内部メタデータや単体のバイナリは渡さない

アーカイブの確認を別ジョブにせず build に置くのは、アップロードするファイルそのものを確かめられ、build が OIDC も公開の権限も持たないためです。
test ジョブでは、GoReleaser が作ったバイナリがまだ存在しないため、`-X` が効いたかを確かめられません。

`--version` を公開前に実行して確かめるのは、linux_amd64 だけです。
linux_arm64 は verify-image が確かめますが、GHCR への公開後になります。
darwin と windows は、`ldflags` が全ターゲットで共通であるという設定上の前提に依存しており、`.goreleaser.yaml` の `builds` にターゲット別の上書きを加えると、この前提は崩れます。

### attest

`actions/attest` に `subject-checksums` として `SHA256SUMS` を渡し、配布アーカイブ 6 件に SLSA Build Provenance の Artifact Attestation を付けます。
`SHA256SUMS` 自体は subject に含まれません。

署名するジョブを build と分けるのは、GoReleaser やビルド中に動くコードに OIDC の権限を渡さないためです。
ただし、attest が署名するのは同じ実行の build がアップロードした Artifact の中身であり、build の実行環境が侵害されていればその出力にも署名が付きます。
この限界は、build と attest を1ジョブにまとめた場合と変わりません。

### container

配布アーカイブに入っている Linux バイナリを格納したイメージを、GHCR に公開して証明します。

1. `release-assets` をダウンロードし、`sha256sum -c SHA256SUMS` で照合する
2. Linux 向けアーカイブ 2 件から `playground-workflows` を取り出し、`<arch>/playground-workflows` の形で専用のビルドコンテキストに置く
3. Docker Buildx で `linux/amd64,linux/arm64` のイメージをビルドし、`ghcr.io/tmknom/playground-workflows:vX.Y.Z` として公開する
4. `docker/build-push-action` が出力した Image Index の digest に Artifact Attestation を付け、GHCR にも保存する
5. digest をジョブの出力として後続ジョブへ渡す

イメージの設計は [コンテナイメージ](#コンテナイメージ)、証明の設計は [来歴証明](#来歴証明) に記載します。

### verify-image

GHCR に公開したイメージを、container の出力した digest で取得して検証します。
amd64 と arm64 の runner で1回ずつ実行し、それぞれの CPU のイメージを確かめます。
runner の CPU が matrix の指定と一致することを先に確かめます。
QEMU が使える runner では、別の CPU のイメージもエミュレーションで実行できてしまうためです。

1. `sha256sum -c SHA256SUMS` で照合し、digest が `sha256:<64 桁の 16 進数>` の形であることを確かめる
2. `gh attestation verify oci://...` が、期待するリポジトリ、署名したワークフロー、タグ、コミット SHA で成功する
3. イメージから取り出したバイナリと、Linux 向けアーカイブから取り出したバイナリが `cmp` で一致する
4. イメージの実行ユーザーが `nonroot:nonroot` である
5. `--version` の出力がタグと一致する

来歴とバイナリの一致を確かめてから、イメージを実行します。
`gh attestation verify` は、`--bundle-from-oci` を付けなければ Attestation を GitHub の Attestation API から取得するため、`attestations: read` が要ります。

GHCR にはログインせず、匿名で取得します。
パッケージが Public であることが前提で、`packages: read` も与えません。
パッケージが非公開のままだと取得に失敗し、GitHub Release は公開されません。

### release

受け取った成果物を検証してから、GitHub Release を公開します。

1. `SHA256SUMS` に列挙されたファイル名が、タグのバージョンを含む期待どおりの 6 件と一致することを確かめ、`sha256sum -c SHA256SUMS` で照合する
2. 配布アーカイブ 6 件のそれぞれで `gh attestation verify` を実行する。期待値は、リポジトリ、署名したワークフロー（`release-go-cli.yml`）、`--signer-digest` と `--source-digest` に `GITHUB_SHA`、`--source-ref` に `GITHUB_REF` である。`gh attestation verify` はファイルの digest だけで Attestation を探すため、`--format json` の出力から、ファイル名と digest の組が署名された subject に含まれることも確かめる
3. container の出力した digest が `sha256:<64 桁の 16 進数>` の形であることを確かめる
4. `ghcr.io/tmknom/playground-workflows@sha256:<digest>` を1行で書いた `container-image.txt` を作る
5. `gh release create <タグ> --verify-tag --target <GITHUB_SHA> --title <タグ> --generate-notes` で公開する。資産として登録するのは、`SHA256SUMS` に列挙されたアーカイブ、`SHA256SUMS`、`container-image.txt` だけである。列挙が 6 件でなければ公開しない

`SHA256SUMS` との照合だけでは、アーカイブと `SHA256SUMS` が一緒に差し替えられた場合を検出できません。
署名の検証を加えることで、公開するアーカイブが、このワークフローによって同じコミットとタグで署名されたものであることを確かめます。
検証は実行 ID までは照合しないため、同じコミットとタグで実行した過去の実行の署名も受け入れます。
subject の名前を確かめるのは、署名されたアーカイブ同士で中身を入れ替えても digest の照合だけでは検出できないためです。

登録するファイルをディレクトリの中身すべてにしないのは、受け渡す Artifact の対象が将来広がったときに、照合も署名もしていないファイルが黙って公開されるのを防ぐためです。

`--verify-tag` は、タグが存在しないときに `gh` がタグを新しく作ることを防ぎます。
`--target` は Release のメタデータに記録するコミットを `GITHUB_SHA` にするためのもので、指定しなければ既定ブランチの名前が記録されます。
タグが存在するときは Release がタグの指すコミットに付くため、`--target` ではタグの付け替えを検出できません。
同じバージョンの Release がすでにあれば `gh release create` が失敗し、既存の Release は書き換えません。

公開した Release は、バージョンの大小にかかわらず「Latest」になります。
正式なリリースでは最も大きいバージョンを公開するため、この挙動を変えません。
動作確認で既存より小さい `v0.0.N` を公開すると、削除するまでの間は確認用の Release が「Latest」になります。
削除すると、「Latest」は既存の最も新しい Release に戻ります。

Draft を作ってから公開する2段階にはしません。
Draft と公開の間に挟む確認がないためです。

### post-verify

公開した GitHub Release と GHCR のイメージを取得し直し、ワークフローが生成した正規の成果物と照合します。
このジョブの成功をもって、リリースの完了とします。

- Release が Draft ではない
- コミットの API に `refs/tags/vX.Y.Z` を渡して得た SHA が `GITHUB_SHA` と一致する（軽量タグと注釈付きタグのどちらでも、指しているコミットの SHA が得られる。タグ名だけを渡すと、同じ名前のブランチがあるときに参照先が曖昧になる）
- `gh release download` で取得した資産と、正規の成果物に `container-image.txt` を加えたものが `diff -r` で一致する。資産の過不足と内容の違いを同時に検出する
- GHCR の `vX.Y.Z` タグが、`container-image.txt` に記録した digest を指している
- 取得した資産と `container-image.txt` の参照を使い、[利用者による検証](#利用者による検証) と同じコマンドで来歴を検証できる

来歴の検証には、release と verify-image が付けている `--signer-digest` と `--source-digest` を付けません。
目的は、利用者向けの手順が公開済みの資産で通ることを確かめることにあるためです。
コミットとの対応は、`diff -r` で資産が release の検証したファイルと一致し、タグが `GITHUB_SHA` を指すことで確かめています。

verify-image と同じく、GHCR にはログインせず、`packages: read` も与えません。

このジョブが失敗した時点で、GitHub Release はすでに公開されています。
自動では取り消さず、失敗の内容を見てから削除してやり直すかを判断します。
`release-assets` の保持期間は 1 日のため、それを過ぎると post-verify だけを再実行できません。
その場合は [失敗時のやり直し](#失敗時のやり直し) の手順で全体をやり直します。

## 成果物とジョブ間の受け渡し

GitHub Release の資産は、次の 8 件です。

| 資産 | 内容 | 生成するジョブ |
|---|---|---|
| `playground-workflows_<バージョン>_<os>_<arch>.tar.gz` | Linux、macOS 向けの配布アーカイブ。4 件 | build |
| `playground-workflows_<バージョン>_windows_<arch>.zip` | Windows 向けの配布アーカイブ。2 件 | build |
| `SHA256SUMS` | 配布アーカイブ 6 件の SHA-256 | build |
| `container-image.txt` | GHCR のイメージの digest 付きの参照。1行 | release |

`<バージョン>` は先頭の `v` を除いた形です。
各アーカイブは直下に `playground-workflows`（Windows では `playground-workflows.exe`）と `LICENSE` を含みます。

ジョブ間で受け渡す Actions Artifact は `release-assets` の1つだけで、中身は配布アーカイブ 6 件と `SHA256SUMS` です。
コンテナに格納する Linux バイナリは、container が Linux 向けアーカイブから取り出します。
アーカイブは `SHA256SUMS` と Artifact Attestation で検証できるため、取り出したバイナリは配布物と同じバイト列になり、バイナリ単体のハッシュ一覧を別に持つ必要がありません。
実行権限もアーカイブの中で保持されます。

GHCR の Image Index digest は、container ジョブの出力 `digest` として後続ジョブへ渡します。
イメージ名は `ghcr.io/${{ github.repository }}` で各ジョブが組み立てます。

`actions/download-artifact` の転送単位の digest 検査とは別に、各ジョブで `sha256sum -c SHA256SUMS` を実行します。
転送の検査は Artifact の破損を検出するものであり、公開の停止条件はファイル単位の照合と署名の検証に置くためです。

## ビルドの設定

Go のビルドとパッケージングは GoReleaser OSS に任せ、担当範囲をバイナリ、アーカイブ、チェックサムの生成までに限ります。

| 処理 | 担当 |
|---|---|
| Go のクロスコンパイル | GoReleaser OSS |
| tar.gz / ZIP の生成 | GoReleaser OSS |
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
- **`checksum`**：`name_template: SHA256SUMS`、`algorithm: sha256`
- **`changelog`**：`disable: true`

`before.hooks` は置きません。
`go generate` や `go mod tidy` をリリース中に実行すると、ソースや依存の定義がビルドの途中で変わり得るためです。
依存の整合性はテストの段階で `go mod verify` が確かめます。

Go のバージョンは `go.mod` の `go` 行で固定し、`actions/setup-go` に `go-version-file: go.mod` を渡します。
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
| 配布アーカイブ 6 件（`SHA256SUMS` に列挙されたもの） | attest | GitHub の Attestation API |
| GHCR の Image Index digest | container | GitHub の Attestation API と GHCR（`push-to-registry: true`） |

イメージの証明は、container ジョブの中で生成します。
レジストリへ証明を保存するには `packages: write` が要り、別ジョブにしても同じ権限を持つジョブが2つに増えるだけだからです。
subject はタグではなく digest にします。
タグは付け替えられるためです。

`create-storage-record` は `false` にします。
storage record は組織が所有するリポジトリ向けの機能で、`artifact-metadata: write` を必要とするためです。

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
5. 公開済みの資産と GHCR を取得し直して照合する

GitHub Releases と GHCR は原子的に公開できないため、手順 2 から 4 の間は GHCR にだけイメージがある状態になります。
この間に失敗した場合の部分成功は、避けられない状態として受け入れます。
GHCR への公開は、GitHub Release の公開と同義ではありません。

## 失敗時のやり直し

ワークフローは、公開途中の状態から自動で回復しません。
また、公開途中で生成したものを自動で削除するロールバックも行いません。

| 失敗した位置 | 対応 |
|---|---|
| preflight、test、build、attest | 何も公開されていない。原因を直し、必要ならタグを削除して新しいコミットにタグを付け直す。ソースが変わらないなら失敗したジョブを再実行してよい |
| container 以降 | GHCR にイメージがある。「Re-run failed jobs」で失敗したジョブから再実行する。「Re-run all jobs」は preflight で止まるため、GHCR のバージョンを削除してから実行する |
| release 以降 | GitHub Release が公開されている可能性がある。下記の手順で全体をやり直す |

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
有効にすると、公開済みの Release の資産と関連する Git タグを変更、削除できなくなり、同じバージョンでリリース工程を繰り返し試すことができなくなるためです。

この運用は、次の前提に立ちます。

- Git タグ、GitHub Release、GHCR のパッケージバージョンは、検証のために削除してよい
- 不整合な状態になった場合は、すべて削除して初めからやり直してよい
- Tag Rulesets によるタグの更新、削除の制限も導入しない
- Release Attestation が生成されないため、`gh release verify` と `gh release verify-asset` は使わない。公開後の資産は post-verify が取得し直して照合する

この運用で失う保証は2つです。

- 公開後の Release の資産と Git タグを、書き換えから保護すること
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

post-verify は、公開済みの資産に対してこれと同じ引数で検証を実行します。
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
- **GoReleaser**：`goreleaser/goreleaser-action` の `version` に、GoReleaser OSS の正確なバージョンを指定する。`install-only: true` でインストールだけを行い、実行はシェルから明示的に行う
- **Go**：`go.mod` の `go` 行で固定する
- **ベースイメージ**：Dockerfile の `FROM` に digest で固定する

固定する値は、追加や更新のたびに公式のリリース情報で確認します。

## 設計上の不変条件

1. リリースタグを、公開物を残したまま別のコミットへ移動しない。
2. リリースの実行中に `main` の最新コミットを解決し直さない。
3. `CGO_ENABLED=0` でビルドする。
4. リリースの工程でソースコードや依存の定義を変更しない。
5. Go のバイナリは build ジョブの GoReleaser だけが生成し、コンテナ化で再コンパイルしない。
6. コンテナ内のバイナリは、配布アーカイブ内の Linux バイナリとバイト単位で一致する。
7. 来歴証明の subject は、配布アーカイブの SHA-256 と Image Index の digest である。
8. OIDC の権限は attest と container だけに、公開の権限は container と release だけに与える。
9. 必須の検証に失敗した場合は、GitHub Release を公開しない。
10. 既存の GitHub Release と GHCR のバージョンタグを、自動で上書きしない。
11. 公開済みの Release の資産を自動で変更しない。作り直す場合は Release ごと削除する。
12. 公開後に、GitHub Release と GHCR の成果物を正規の成果物と照合する。

## 残るリスク

- **build の実行環境の侵害**：attest は build の出力に署名するため、build が侵害されていればその出力にも正しい署名が付く
- **GitHub 基盤への依存**：署名、実行、公開のすべてが GitHub の基盤に依存しており、基盤全体の侵害には対抗できない
- **タグ起点のワークフロー定義**：タグの指すコミットにあるワークフロー定義そのものが実行される。悪意のある定義が実行された後では、preflight は防御にならない。`main` の変更のレビューと、タグを作成できる者の限定に依存する
- **実行中のタグの付け替え**：Tag Rulesets でタグを保護していないため、実行中にタグを付け替えられる可能性がある。post-verify がタグの参照先を確認して検出する
- **存在確認の誤判定**：preflight は GHCR を匿名で確認するため、パッケージが非公開になっていると既存のタグを「存在しない」と判定し、container がタグを上書きする可能性がある。エラーメッセージの文言で判定するため、`gh` や Docker Buildx の文言が変わると、存在しないバージョンでも preflight が止まる
- **公開物の書き換え**：Immutable Release を採用していないため、公開後の資産とタグは書き換えから保護されていない
- **作り直す前のビルドの Attestation**：利用者による検証はタグの名前を固定し、コミットを固定しない。[失敗時のやり直し](#失敗時のやり直し) で同じバージョンを作り直しても、前の実行が付けた Attestation は残るため、前のビルドのアーカイブやイメージも利用者の検証を通る。README の「保証しない内容」に書いている
- **Linux 以外の OS での実行**：macOS と Windows のバイナリは、どの工程でも実行していない。通常 CI を用意するまでは、OS 固有の不具合を公開前に検出できない
- **待機中の実行の取り消し**：`concurrency` の `queue` が `single` のため、リリースの実行中に2つ以上の実行が待機に入ると、先に待機していた実行が取り消される。取り消しは実行の一覧に残るため、気付いた時点で再実行する

## 将来の拡張

次の拡張は、必要性を判断してから着手します。

| 拡張 | 着手の条件 | 概要 |
|---|---|---|
| OS matrix の通常 CI | OS 固有の処理がコードに入ったとき | プルリクエストで、Linux / macOS / Windows の runner で `go test` を実行する |
| 配布アーカイブの SBOM | 外部のモジュールへの依存が増えたとき、または提供を求められたとき | GoReleaser の `sboms` で生成し、Syft をバージョン固定でインストールする |
| `govulncheck` | 外部のモジュールへの依存が増えたとき | test ジョブで実行し、検出があれば止める。通常 CI を先に用意するかもあわせて判断する |
| 再ビルドによる再現性の確認 | Attestation と実行確認に加えて必要と判断したとき | 別の runner で再ビルドし、正規の `SHA256SUMS` で `sha256sum -c` する。アーカイブ内のファイルの時刻、所有者、権限の固定が必要になる可能性がある |
| Immutable Release | 削除を伴う試行が不要になったとき（Lambda リリースも含む） | Immutable Releases と Tag Rulesets を有効にし、post-verify と利用者向けの手順に `gh release verify` を加える |
| deb / rpm / apk | 配布を求められたとき | GoReleaser の `nfpms` を第一候補とし、build が生成したバイナリを再コンパイルせずに格納する |
| Homebrew Formula | 配布を求められたとき | 別リポジトリへの書き込み権限と認証情報の設計が必要になる |

次の項目は、拡張の予定もありません。

- **コンテナイメージの脆弱性検査**：ベースイメージは Distroless static で、格納するのは Go バイナリ1つだけである
- **公開途中の自動復旧**：手動で削除してやり直す運用で足りる
- **コンテナイメージ全体のバイト単位の再現**：内部のバイナリの一致とベースイメージの固定で足りる
