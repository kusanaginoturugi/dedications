# 2026-10-24 セキュリティ点検

[www の共通手順](https://github.com/kusanaginoturugi/www/blob/main/docs/security-runbook.md) を Rails 向けに置き換えて実施した。

## master.key の公開と差し替え

- `config/master.key` が最初のコミット (`d03e3b4`) から公開リポジトリに入っていた。`config/credentials.yml.enc` の中身は `secret_key_base` だけ。
- 影響: この鍵があれば暗号化されたセッション Cookie を作れるので、`session[:user_id]` を管理者の ID にして管理者としてサインインできた。Authentik の client secret などは環境変数にあり、credentials には入っていない。
- 対策: 新しい `master.key` と `secret_key_base` を作り直し、`config/master.key` を git の管理から外して `.gitignore` に入れた。古い鍵は履歴に残るが、復号できるのは古い `secret_key_base` だけで、差し替え後は使えない。履歴の書き換えはしていない。
- `encrypts` / `signed_id` / `generates_token_for` は使っていないので、差し替えで失われるのは既存のサインイン状態だけ (全員サインアウトされる)。
- `scripts/deploy.sh` は `git reset --hard origin/main` の後に `/home/admin/.config/dedications/master.key` を `config/master.key` へコピーする。このファイルがないと、コードを更新する前に止まる。
- 新しい鍵は手元の `config/master.key` にある。パスワードマネージャーにも保存しておく。

サーバーへの配置 (push 前に1回だけ):

```sh
ssh -p 65522 admin@showway-t4g.tailb46b1.ts.net 'install -d -m 700 ~/.config/dedications'
scp -P 65522 config/master.key admin@showway-t4g.tailb46b1.ts.net:.config/dedications/master.key
ssh -p 65522 admin@showway-t4g.tailb46b1.ts.net 'chmod 600 ~/.config/dedications/master.key'
```

## gem

- bundler-audit の指摘 (更新前): activestorage、concurrent-ruby (High)、crass、json、loofah、mail、net-imap、nokogiri、rails-html-sanitizer、rubyzip (High)、sqlite3、websocket-driver (High)。
- Gemfile の範囲で `bundle update` した (Rails 8.1.3 → 8.1.4)。更新後の指摘は 0 件。
- Brakeman は更新前後とも警告 0 件。

## CSP

- これまで CSP は付いていなかった。`config/initializers/content_security_policy.rb` で有効にした。
- `script-src 'self'` と nonce。画面内の `<script>` は `javascript_tag nonce: true` にした。新しく inline script を書くときも同じようにする。
- `style-src` は画面が `style=` 属性を使っているため `'unsafe-inline'` を許可している。
- ヘッドレス Chrome でサインイン後の全画面を開き、CSP 違反が出ないこと、nonce 付きの script が動いて nonce なしの script が止まることを確認した。
- HSTS は `force_ssl` が付ける。`X-Frame-Options` などは Rails の既定で付いている。

## GitHub

- CI: Actions を commit SHA で固定、`permissions: contents: read`、checkout は `persist-credentials: false`。Brakeman の後に `bundler-audit check --update` を追加。週次 (月曜 9:00 JST) でも実行する。deploy ジョブは push / workflow_dispatch のときだけ動く。
- tailscale/github-action は v3、upload-artifact は v4 のまま (メジャー更新は Dependabot の PR で個別に確認する)。
- CodeQL (actions / javascript-typescript / ruby、security-extended) と Dependency Review を追加。
- Dependabot alerts と private vulnerability reporting を有効化。`SECURITY.md` をテンプレートから書き換えた。
- Dependabot security updates と main の保護設定は変えていない。

## 見送ったこと

- `config.hosts`: サーバー側でどのホスト名で受けているか確認できなかったため設定していない。設定するなら `dedications.showway.biz` を許可し、`/up` を除外する (deploy.sh が `127.0.0.1:3003/up` を見るため)。
- 申込はサインインした利用者なら誰でも編集・削除できる。共同入力のための仕様として扱う。
- 鍵が公開されていた期間に不正なサインインがあったかは、本番のログと利用者一覧で確認する。
