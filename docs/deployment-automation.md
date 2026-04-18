# Deployment Automation Template

このプロジェクトでは、`main` への push を契機に GitHub Actions から EC2 へ SSH 接続し、Rails アプリを自動デプロイする。

別プロジェクトへ適用する時に変えるのは、基本的に次の値だけ。

- アプリ配置先
- systemd サービス名
- 公開サブドメイン
- SSH ポート

## 全体構成

1. GitHub Actions が `main` への push で起動する
2. EC2 に SSH 接続する
3. server 上で `scripts/deploy.sh` を実行する
4. `deploy.sh` が `git pull`、`bundle install`、`db:migrate`、`assets:precompile`、`systemctl restart` を行う

## 前提

- EC2 上に Rails アプリが配置済みである
- systemd で Puma などのアプリプロセスを起動している
- `ubuntu` ユーザーで SSH ログインできる
- GitHub から到達できるように Security Group で SSH ポートを開けている
- 本番サーバ上で `bundle install` と `bin/rails assets:precompile` が成功する

## GitHub Secrets

GitHub の repository secrets に次を登録する。

- `EC2_HOST`
- `EC2_PORT`
- `EC2_SSH_KEY`

`EC2_SSH_KEY` には `.pem` のファイル名ではなく秘密鍵の中身をそのまま入れる。

## systemd 例

`/etc/systemd/system/YOUR_APP.service`

```ini
[Unit]
Description=YOUR_APP
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/YOUR_APP
Environment=HOME=/home/ubuntu
Environment=PATH=/home/ubuntu/.local/share/mise/installs/ruby/3.4.8/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=RAILS_ENV=production
Environment=BUNDLE_GEMFILE=/home/ubuntu/YOUR_APP/Gemfile
Environment=BUNDLE_PATH=/home/ubuntu/YOUR_APP/vendor/bundle
ExecStart=/home/ubuntu/.local/share/mise/installs/ruby/3.4.8/bin/bundle exec puma -e production -C /home/ubuntu/YOUR_APP/config/puma.rb
Restart=always

[Install]
WantedBy=multi-user.target
```

反映:

```bash
sudo systemctl daemon-reload
sudo systemctl enable YOUR_APP.service
sudo systemctl restart YOUR_APP.service
```

## sudoers

GitHub Actions 経由では `sudo` が対話できないので、`systemctl` だけ passwordless にする。

```bash
sudo visudo -f /etc/sudoers.d/YOUR_APP
```

内容:

```sudoers
ubuntu ALL=NOPASSWD: /usr/bin/systemctl restart YOUR_APP.service, /usr/bin/systemctl is-active YOUR_APP.service
```

確認:

```bash
sudo -n /usr/bin/systemctl restart YOUR_APP.service
sudo -n /usr/bin/systemctl is-active YOUR_APP.service
```

## deploy script

`scripts/deploy.sh`

```bash
#!/usr/bin/env bash
set -euxo pipefail

APP_ROOT="/home/ubuntu/YOUR_APP"
RUBY_BIN="/home/ubuntu/.local/share/mise/installs/ruby/3.4.8/bin"
SERVICE_NAME="YOUR_APP.service"

cd "$APP_ROOT"

export HOME="/home/ubuntu"
export PATH="$RUBY_BIN:$PATH"
export RAILS_ENV="production"
export BUNDLE_GEMFILE="$APP_ROOT/Gemfile"
export BUNDLE_PATH="$APP_ROOT/vendor/bundle"

# サーバ上で execute bit 差分が deploy を止めないようにする
git config core.fileMode false

git fetch origin
git pull --ff-only origin main

bundle config set deployment true
bundle config set without 'development test'
bundle install

bin/rails db:migrate
bin/rails assets:precompile

sudo -n /usr/bin/systemctl restart "$SERVICE_NAME"
sudo -n /usr/bin/systemctl is-active "$SERVICE_NAME"
```

実行権限を付ける:

```bash
chmod +x scripts/deploy.sh
git update-index --chmod=+x scripts/deploy.sh
```

## GitHub Actions 例

`.github/workflows/ci.yml`

```yaml
name: CI

on:
  workflow_dispatch:
  pull_request:
  push:
    branches: [ main ]

jobs:
  scan_ruby:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version
          bundler-cache: true

      - name: Scan for common Rails security vulnerabilities using static analysis
        run: bin/brakeman --no-pager

  lint:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version
          bundler-cache: true

      - name: Lint code for consistent style
        run: bin/rubocop -f github

  test:
    runs-on: ubuntu-latest
    steps:
      - name: Install packages
        run: sudo apt-get update && sudo apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config

      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version
          bundler-cache: true

      - name: Set up Chrome
        uses: browser-actions/setup-chrome@v1

      - name: Run tests
        env:
          RAILS_ENV: test
        run: bin/rails db:test:prepare test test:system

  deploy:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    needs:
      - scan_ruby
      - lint
      - test
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to production server
        uses: appleboy/ssh-action@v1.2.2
        with:
          host: ${{ secrets.EC2_HOST }}
          port: ${{ secrets.EC2_PORT }}
          username: ubuntu
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            cd /home/ubuntu/YOUR_APP
            git config core.fileMode false
            git fetch origin
            git checkout origin/main -- scripts/deploy.sh
            bash /home/ubuntu/YOUR_APP/scripts/deploy.sh
```

## nginx 例

サブドメインだけ変えるなら、server_name だけ差し替える。

```nginx
server {
  listen 80;
  server_name your-subdomain.example.com;

  root /home/ubuntu/YOUR_APP/public;

  location /assets/ {
    expires max;
    add_header Cache-Control public;
  }

  location / {
    proxy_pass http://127.0.0.1:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
```

## サーバでの初回確認

まず server 上で deploy script 単体が通ることを確認する。

```bash
cd /home/ubuntu/YOUR_APP
bash scripts/deploy.sh
```

成功したら次を確認する。

```bash
systemctl status YOUR_APP.service
git rev-parse HEAD
```

## よくあるハマりどころ

### `sudo: a password is required`

`sudoers` の許可と実行コマンドが一致していない。

`/usr/bin/systemctl` と `systemctl` は別扱い。引数も含めて一致させる。

### `Your local changes would be overwritten by merge`

server 上で tracked file が汚れている。

今回の構成では、workflow の入口で最新の `scripts/deploy.sh` を checkout してから deploy を始めることで吸収している。

### `Permission denied` で `scripts/deploy.sh` が実行できない

workflow 側は `bash scripts/deploy.sh` で呼ぶ。execute bit に依存させない。

### `dial tcp ... i/o timeout`

SSH ポートや Security Group を確認する。

- `EC2_HOST`
- `EC2_PORT`
- inbound rule
- `sshd` がそのポートで listen しているか

### `bundle install --deployment` で失敗する

Bundler の新しい版では `--deployment` を直接使わず、config に設定する。

```bash
bundle config set deployment true
bundle config set without 'development test'
bundle install
```

## 差し替え項目一覧

別プロジェクトへ流用する時は、次を一括置換すれば足りる。

- `YOUR_APP`
- `YOUR_APP.service`
- `/home/ubuntu/YOUR_APP`
- `your-subdomain.example.com`
- SSH ポート

## 今回の実運用ポイント

- deploy の入口は GitHub Actions から `bash scripts/deploy.sh` の 1 本に寄せる
- 本番 server 上で tracked file を手で編集しない
- `deploy.sh` 自体の自己更新に備えて、workflow 側で `origin/main` の `scripts/deploy.sh` を先に取り込む
- `sudoers` はコマンド文字列を厳密一致で考える
