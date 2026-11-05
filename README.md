# try-vmsingle

VictoriaMetrics single-node (vmsingle) と Cloudflare R2 / Parquet / DuckDB を使った
cold storage 構成の実証リポジトリです。

## 現在の実装範囲

まずは Docker Compose による vmsingle の起動のみを用意しています。
OTel Collectorと模擬PLC Readerのデータ登録まで対応しています。Archiver、R2連携、DuckDBは今後追加します。

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
| `make logs` | vmsingleとOTel Collectorのログを追跡 |
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

## 1分間隔のサンプルデータ生成

模擬PLC Readerとして、`temperature_celsius`を4シリーズ生成します。

- `site_id`: `001`, `002`
- `sensor_id`: `1`, `2`
- 1分間隔、UTC基準の月初00:00から実行時刻以前の直近の分まで
- 決定論的な温度変動。センサーの業務メタデータは未定義
- デフォルトは当月のみ（`--months 1`）。`--months 3`なら前々月1日から当月の現在時点まで
- 1 UTC日ごとにOTLP/HTTP JSONで送信。1日あたり最大5,760データポイント

GoのSDKをホストへ導入せず、Docker内でLinux向け実行ファイルをビルドします。
**ホストで直接実行する想定のため、同じCPUアーキテクチャのLinuxホストを前提**とします。

```sh
make up
make build
make test
./bin/sample-generator
./bin/sample-generator --months 3
```

デフォルトの送信先は `http://127.0.0.1:4318/v1/metrics` です。
OTel Collectorのポート4318はホストのループバックアドレスだけに公開します。
送信先を変更する場合は以下の環境変数を使います。

```sh
OTLP_METRICS_ENDPOINT=http://127.0.0.1:4318/v1/metrics ./bin/sample-generator --months 2
```

`make generate`も、既にビルド済みのバイナリをホスト上で実行します。
`bin/` はGit管理対象外です。

### vmsingleで生データを確認

Collector側が成功を返しただけではvmsingleへの保存を保証しません。
バッチ転送後、次のAPIで確認してください。

```sh
curl -fsSG http://localhost:8428/api/v1/export \
  --data-urlencode 'match[]=temperature_celsius{site_id="001",sensor_id="1"}' \
  --data-urlencode 'start=-2h'
```

月単位の過去データも含めて件数を確認する際は、適切なUTC時刻範囲を指定します。
現行のvmsingle保持期間はデフォルト6か月です。`--months`をそれより大きくすると
古いデータは保持対象外になり得ます。また**同じ期間を繰り返し生成すると重複投入**に
なるため、実験条件を揃える場合は次の全消去を使用してください。

### vmsingleの全データ削除

```sh
make clear-vmsingle
make up
```

`clear-vmsingle` は対象が固定パスであることを検証し、`DELETE` の明示入力後、
Composeサービスを停止してから保存ディレクトリの**中身だけ**を削除します。
削除対象は `/srv/volumes/try-vmsingle/vmsingle/vmdata` の全保存データであり、
元に戻せません。完了後に `make up` でサービスを再起動してください。
通常の `make reset` は従来どおりbind mountのデータを保持します。

設計メモ: [UTCの月境界とParquetパーティショニング](docs/cold-storage-time-and-partitioning.md)
