class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_user, :signed_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def signed_in?
    current_user.present?
  end

  def require_sign_in!
    return if signed_in?

    redirect_to new_session_path, alert: "サインインが必要です。"
  end

  def require_admin!
    return if current_user&.is_admin?

    redirect_to orders_path, alert: "管理者のみ利用できます。"
  end
end
