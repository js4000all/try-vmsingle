# try-vmsingle

VictoriaMetrics single-node (vmsingle) と Cloudflare R2 / Parquet / DuckDB を使った
cold storage 構成の実証リポジトリです。

## 現在の実装範囲

まずは Docker Compose による vmsingle の起動のみを用意しています。
Archiver、R2 連携、DuckDB、Go ビルドコンテナは今後追加します。

## 前提条件

- Linux ホスト（bind mount の保存先は固定パス）
- Docker Engine + Docker Compose v2
- Make と sudo（データディレクトリの初期化に使用）
- 疎通確認用の curl（任意）

## 起動

```sh
cp .env.example .env
make up
```

`make up` は事前に `sudo install -d` を実行し、
`/srv/volumes/try-vmsingle/vmsingle/vmdata` を作成・確認します。
sudo のパスワード入力を求められる場合があります。
ディレクトリの所有者は UID:GID `1000:1000`、パーミッションは `0755` に設定します。
既存のファイルやサブディレクトリの所有権を再帰変更することはありません。

vmsingle コンテナも `1000:1000` で起動するため、新規保存ファイルは原則としてこの所有者になります。
rootless Docker や userns-remap 使用時はホスト側の実際の UID/GID を確認してください。

Make を使わない場合は、あらかじめデータディレクトリを作成してから起動します。

```sh
sudo install -d -o 1000 -g 1000 -m 0755 /srv/volumes/try-vmsingle/vmsingle/vmdata
docker compose up -d
```

以下から VictoriaMetrics の UI を開けます。

- http://localhost:8428/vmui/

疎通確認：

```sh
curl -f http://localhost:8428/health
```

## 操作

| コマンド | 動作 |
| --- | --- |
| `make prepare-dirs` | ホストの保存先ディレクトリを作成・確認 |
| `make up` | 保存先を準備し、vmsingle をバックグラウンドで起動 |
| `make down` | コンテナを停止・削除（データ保持） |
| `make ps` | コンテナ状態を表示 |
| `make logs` | vmsingle のログを追跡 |
| `make reset` | コンテナを停止・削除（**bind mount の保存データは保持**） |

`.env` は任意です。作成しない場合も保持期間は6か月になります。
変更する場合は `.env` の `VM_RETENTION_PERIOD` を設定してください。

データはホストの `/srv/volumes/try-vmsingle/vmsingle/vmdata` に保存されます。
`make down` および `make reset` は、このディレクトリやデータを削除しません。
実験用コンテナのHTTPポートは `127.0.0.1:8428` のみに公開しています。
認証は設けていないので、外部公開しないでください。

## 参照

- [VictoriaMetrics single-node](https://docs.victoriametrics.com/victoriametrics/)
- [VictoriaMetrics Docker Compose example](https://github.com/VictoriaMetrics/VictoriaMetrics/blob/master/deployment/docker/compose-vm-single.yml)
