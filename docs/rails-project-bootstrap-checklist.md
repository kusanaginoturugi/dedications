# Rails Project Bootstrap Checklist

Rails プロジェクトを新規に作る時は、アプリが育ってから整えるのではなく、最初に開発基盤を置く。

このチェックリストは、`rails new` 直後から本番 deploy までを見通して最低限そろえるためのもの。

## 1. 作成直後にやること

- リポジトリを作る
- `README.md` に目的と起動方法を書く
- `.ruby-version` を確認する
- `mise.toml` を置く
- `bin/setup` または `mise run setup` を整える
- 最初の commit を切る

## 2. 開発環境を固定する

- Ruby の版を固定する
- Bundler の install 先を固定する
- DB を作って起動確認する
- `bin/rails server` が動くことを確認する
- `bin/rails test` が動くことを確認する

## 3. CI を最初に入れる

最低限、GitHub Actions に次を入れる。

- `test`
- `lint`
- `scan_ruby`
- `workflow_dispatch`

理由:

- 壊れていない基準を早く作れる
- 後から CI を足すより圧倒的に楽
- チーム開発でも push 時の期待値が揃う

## 4. Ruby / Rails 基本整備

- `rubocop` を通す
- `brakeman` を通す
- system test を最初から通る状態にする
- `db:prepare` が通る状態にする
- fixture または seed の最低限を作る

## 5. 本番運用を先に決める

次を最初に決める。

- 配置先ディレクトリ
- systemd サービス名
- 公開サブドメイン
- SSH ポート
- nginx を使うか
- Ruby の導入方法

この情報がないと deploy 自動化が後手になる。

## 6. server 側テンプレを早めに作る

本番サーバに対して、少なくとも次をテンプレ化する。

- systemd unit
- nginx config
- `scripts/deploy.sh`
- sudoers
- Secrets 一覧

本番 server で手作業しかない状態を長く放置しない。

## 7. deploy を自動化する

最小構成なら次で十分。

1. `main` push
2. GitHub Actions
3. SSH で EC2 に接続
4. `scripts/deploy.sh` 実行

deploy script の責務は絞る。

- `git pull`
- `bundle install`
- `db:migrate`
- `assets:precompile`
- `systemctl restart`

## 8. 本番依存のハマりどころを最初に潰す

- `sudoers` はコマンド完全一致
- SSH ポートは Security Group と合わせる
- server 上で tracked file を手で編集しない
- `bundle install --deployment` のような古い慣習を避ける
- `scripts/deploy.sh` の bootstrap を考える

## 9. ドキュメントをコードと一緒に持つ

最低限ほしいファイル:

- `README.md`
- `docs/deployment-automation.md`
- `docs/rails-project-bootstrap-checklist.md`

ドキュメントがないと、次のプロジェクトで毎回同じ罠を踏む。

## 10. 新規プロジェクトの実践順

おすすめ順はこれ。

1. `rails new`
2. git 初期化と最初の commit
3. `mise` などの開発環境固定
4. DB と test 起動確認
5. CI 追加
6. lint / security scan 追加
7. systemd / nginx / deploy script 雛形追加
8. 手動 deploy 成功
9. GitHub Actions deploy 成功
10. その後に本体機能開発

## 11. コピペ用メモ

新規案件で最初に埋める値:

- アプリ名:
- 配置先:
- サービス名:
- サブドメイン:
- SSH ポート:
- Ruby 版:
- DB:

## 12. 判断基準

CI や deploy が面倒に見えても、後からやる方がもっと面倒になる。

迷ったら次を優先する。

- 早く固定する
- 手順をコードにする
- server に状態を溜めない
- bootstrap を 1 回で済むようにする
