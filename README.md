# try-vmsingle

VictoriaMetrics single-node (vmsingle) と Cloudflare R2 / Parquet / DuckDB を使った
cold storage 構成の実証リポジトリです。

## 現在の実装範囲

まずは Docker Compose による vmsingle の起動のみを用意しています。
Archiver、R2 連携、DuckDB、Go ビルドコンテナは今後追加します。

## 前提条件

- Docker Engine + Docker Compose v2
- Make（ショートカットを使用する場合）
- 疎通確認用の curl（任意）

## 起動

```sh
cp .env.example .env
make up
```

Make を使用しない場合：

```sh
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
| `make up` | vmsingle をバックグラウンドで起動 |
| `make down` | コンテナを停止・削除（データ保持） |
| `make ps` | コンテナ状態を表示 |
| `make logs` | vmsingle のログを追跡 |
| `make reset` | コンテナと named volume を削除（**保存データ消去**） |

`.env` は任意です。作成しない場合も保持期間は6か月になります。
変更する場合は `.env` の `VM_RETENTION_PERIOD` を設定してください。

vmsingle のデータは Docker named volume `vmdata` に保持します。
`make down` では削除されませんが、`make reset` では削除されます。
このリポジトリの vmsingle は実験用のため、ホストの `127.0.0.1:8428` のみに公開しています。
認証は設けていないので、外部公開しないでください。

## 参照

- [VictoriaMetrics single-node](https://docs.victoriametrics.com/victoriametrics/)
- [VictoriaMetrics Docker Compose example](https://github.com/VictoriaMetrics/VictoriaMetrics/blob/master/deployment/docker/compose-vm-single.yml)
