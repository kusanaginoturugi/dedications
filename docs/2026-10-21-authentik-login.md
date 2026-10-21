# Authentik サインイン

## 作業計画

- アプリ内のメールアドレス + パスワード認証を Authentik (OIDC) サインインに切り替える。
- `AUTHENTIK_CLIENT_ID` と `AUTHENTIK_CLIENT_SECRET` が両方あるときだけ有効にし、未設定の環境は従来のパスワードサインインのままにする。
- 実装は liberation の `AuthentikClient` / `SessionsController` に揃える。
- 既存ユーザーと申込の紐付けは壊さない。

## 作業記録

- `app/services/authentik_client.rb` を追加した。Redirect URI は `https://dedications.showway.biz/auth/callback`。
- `users.authentik_subject` (unique) を追加した。
- callback では `sub` → メールアドレスの順で既存ユーザーを探し、なければ作る。新規ユーザーのパスワードはランダム。
- `myouou-admins` / `dedications-admin` グループにいれば `is_admin` を立てる。サインインのたびに上書きする。
- Authentik が有効なときはパスワードサインインを拒否し、サインイン画面は Authentik のボタンだけにする。
- CI の `bin/brakeman --ensure-latest` が通るよう brakeman を 8.1.0 に上げた。
- Authentik 側に provider `dedications-oidc` とアプリケーション `dedications` (代理奉納) を作り、`myouou` / `myouou-admins` / `聖明王院` グループにバインドした。

## 引き継ぎ

- 確認済み: `bin/rails test`、`bin/rubocop`、`bin/brakeman`
- 有効化前に、本番 `users.email` と Authentik 側のメールアドレスが一致しているか確認する。一致しないと別ユーザーが作られ、過去の申込と紐付かない。
- 管理者は Authentik の `myouou-admins` で決まる。アプリのユーザー管理画面で `is_admin` を立てても、次のサインインで上書きされる。
- 本番は `/etc/dedications/authentik.env` と `dedications.service` の drop-in (`authentik.conf`) で値を渡す。無効化は drop-in を外して `daemon-reload` → restart。
- Workers 移植版 (`kusanaginoturugi/dedications-worker`) は 2026-06-21 の骨組みで止まっている。移るときは Authentik のアプリケーション `dedications` をそちらへ向け直す。
