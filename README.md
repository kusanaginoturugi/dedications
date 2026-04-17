# Dedications

FAXで届く護摩供注文書を、サインイン済みユーザーが画面入力するRailsアプリです。

## セットアップ

```bash
bundle install
bin/rails db:create db:migrate db:seed
bin/rails server
```

`mise` を使う場合:

```bash
mise install
mise run setup
mise run server
```

## 初期ログイン

- Email: `admin@example.com`
- Password: `password123`

必要なら `DEFAULT_PASSWORD` 環境変数で seed 時の初期パスワードを変更できます。

## 主な仕様

- 注文入力はサインイン済みユーザーのみ
- FAX 1枚ごとに `ページ番号` を付けて登録
- 伝道会は `資料/伝道会番号.csv` の新コードで選択
- 新コードは2桁以上の入力で候補を絞り込み表示
- 注文書の種類は3種類
  - 八大明王如意棒代理奉納
  - 三會龍華之御柱代理奉納
  - 三期滅劫之霊木代理奉納
- 本数と金額はページ単位で自動合計表示
- 入金済チェックあり

## テスト

```bash
bin/rails test
```

`mise` 経由なら `mise run test` でも実行できます。

## 自動デプロイ

`main` への push で GitHub Actions から本番デプロイできます。

前提:

- サーバ配置先: `/home/ubuntu/dedications`
- systemd サービス: `dedications.service`
- アセット出力先: `/home/ubuntu/dedications/public/assets`
- サーバ上で `sudo systemctl restart dedications.service` が通ること

必要な GitHub Secrets:

- `EC2_HOST`
- `EC2_PORT`
- `EC2_SSH_KEY`

デプロイ処理本体は `scripts/deploy.sh` です。
