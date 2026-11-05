# Cold Storage の時刻・月別パーティションとDuckDB検索（設計メモ）

状態: 検討中。Archiver / Query API 実装時に検証する。

## 決定事項

- サンプルの時刻と月別アーカイブ境界は UTC 基準とする。
- 月ごとの期間は半開区間 `[月初 00:00 UTC, 翌月初 00:00 UTC)` とする。
- ユーザーが指定する表示タイムゾーンと、保存データの時刻軸を混同しない。

例: 2026年11月は `2026-11-01T00:00:00Z` 以上、
`2026-12-01T00:00:00Z` 未満。

## クエリ時の時刻変換

DuckDBのSQLが必ずUTC表記でなければならないわけではない。
`TIMESTAMPTZ` にはオフセット付きの日時を指定でき、同じ時点として比較できる。

例えば、次の境界は同じ瞬間を指す。

- `2026-11-01 00:00:00+09`
- `2026-10-31 15:00:00+00`

Query API は、利用者が指定したタイムゾーンを解釈したうえで、
検索範囲を UTC の時点（instant）に正規化する設計が分かりやすい。
ただし SQL 側でタイムゾーンを扱うことも可能であり、これは必須の制約ではない。
`TIMESTAMP`（タイムゾーン無し）と `TIMESTAMPTZ` の扱いは
Parquetスキーマを決める際に明示的に検証する。

## R2上のParquetファイル探索

Hive形式のパスを検討する。

```text
archive/year=2026/month=10/part-000.parquet
archive/year=2026/month=11/part-000.parquet
```

DuckDBの`read_parquet(..., hive_partitioning = true)`は
`year`, `month` をパーティション列として扱える。
これらの列をWHERE句で絞ることで、パーティションプルーニングを期待できる。

**重要**: `timestamp` に対する範囲条件だけで、
パスの`year`/`month`条件まで自動的に導出されると期待しない。
Query API側で UTC の開始・終了範囲から対象月を求め、
明示的なパーティション条件または対象ファイル一覧を与える設計を検討する。

例（配置規則・スキーマが確定した場合の概念例）:

```sql
SELECT *
FROM read_parquet(
    'r2://example-bucket/archive/**/*.parquet',
    hive_partitioning = true
)
WHERE year = 2026
  AND month = 11
  AND timestamp >= TIMESTAMPTZ '2026-11-01 00:00:00+00'
  AND timestamp <  TIMESTAMPTZ '2026-12-01 00:00:00+00';
```

この例は2026年11月に限定した検索であり、
任意の時刻範囲に対する実装では対象となる全パーティションを列挙・指定する。
`timestamp`の型、`year`/`month`の推論型、R2の認証設定は別途決める。

## 実証項目（未検証）

1. R2上の複数Parquetをglobで横断検索できるか。
2. Hiveパーティション条件でR2への一覧取得・読み取りがどれだけ削減されるか。
3. 時刻範囲が月をまたぐ場合に、該当月のみを効率的に検索できるか。
4. `TIMESTAMPTZ`とParquetのtimestamp表現で、JST指定の検索とUTC境界が正確に一致するか。
5. wide / long / 異なるschemaを混在させた場合の検索可能性と実行コスト。

いずれもDuckDBとR2の実測によって仕様を確定する。
