class SessionsController < ApplicationController
  AUTHENTIK_ADMIN_GROUPS = [ "dedications-admin", "myouou-admins" ].freeze

  def new
    redirect_to orders_path if signed_in?
  end

  def create
    if AuthentikClient.configured?
      redirect_to new_session_path, alert: "Authentikでサインインしてください。"
      return
    end

    user = User.find_by(email: params[:email].to_s.strip.downcase)

    if user&.authenticate(params[:password])
      start_session_for(user)
      redirect_to orders_path, notice: "サインインしました。"
    else
      flash.now[:alert] = "メールアドレスまたはパスワードが違います。"
      render :new, status: :unprocessable_entity
    end
  end

  def authentik
    unless AuthentikClient.configured?
      redirect_to new_session_path, alert: "Authentikサインインはまだ準備中です。"
      return
    end

    state = SecureRandom.urlsafe_base64(32)
    session[:authentik_state] = state
    redirect_to AuthentikClient.authorization_url(state: state), allow_other_host: true
  end

  def callback
    unless valid_authentik_state?
      redirect_to new_session_path, alert: "Authentikサインインの確認に失敗しました。もう一度お試しください。"
      return
    end

    if params[:error].present?
      redirect_to new_session_path, alert: "Authentikサインインを完了できませんでした。"
      return
    end

    access_token = AuthentikClient.exchange_code(params[:code].to_s)
    user = authentik_user_from(AuthentikClient.userinfo(access_token))
    start_session_for(user)
    redirect_to orders_path, notice: "Authentikでサインインしました。"
  rescue AuthentikClient::Error => error
    redirect_to new_session_path, alert: error.message
  end

  def destroy
    reset_session
    redirect_to new_session_path, notice: "サインアウトしました。"
  end

  private

  def start_session_for(user)
    reset_session
    session[:user_id] = user.id
  end

  def valid_authentik_state?
    expected_state = session.delete(:authentik_state).to_s
    returned_state = params[:state].to_s
    expected_state.present? && returned_state.present? &&
      ActiveSupport::SecurityUtils.secure_compare(expected_state, returned_state)
  end

  def authentik_user_from(claims)
    subject = claims["sub"].to_s
    email = claims["email"].to_s.strip.downcase
    raise AuthentikClient::Error, "Authentikから利用者情報を受け取れませんでした" if subject.blank? || email.blank?

    user = find_authentik_user(subject, email)
    user.assign_attributes(
      authentik_subject: subject,
      email: email,
      name: claims["name"].presence || claims["preferred_username"].presence || email,
      is_admin: Array(claims["groups"]).map(&:to_s).intersect?(AUTHENTIK_ADMIN_GROUPS)
    )
    assign_random_password(user) if user.new_record?
    user.save!
    user
  rescue ActiveRecord::RecordInvalid => error
    raise AuthentikClient::Error, "利用者情報を保存できませんでした: #{error.record.errors.full_messages.to_sentence}"
  end

  def find_authentik_user(subject, email)
    user_by_subject = User.find_by(authentik_subject: subject)
    user_by_email = User.find_by(email: email)
    if user_by_subject && user_by_email && user_by_subject != user_by_email
      raise AuthentikClient::Error, "Authentikの利用者情報が既存の利用者と一致しません"
    end

    user_by_subject || user_by_email || User.new
  end

  def assign_random_password(user)
    password = SecureRandom.urlsafe_base64(32)
    user.password = password
    user.password_confirmation = password
  end
end
