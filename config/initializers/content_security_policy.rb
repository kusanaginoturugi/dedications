# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data
    policy.object_src  :none
    policy.script_src  :self
    # 画面に style 属性を使っているため inline style は許可する
    policy.style_src   :self, :unsafe_inline
    policy.connect_src :self
    policy.base_uri    :self
    policy.form_action :self
    policy.frame_ancestors :none
  end

  # inline script は javascript_tag nonce: true で出力する
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
