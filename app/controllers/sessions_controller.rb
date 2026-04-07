class SessionsController < ApplicationController
  def new
    redirect_to orders_path if signed_in?
  end

  def create
    user = User.find_by(email: params[:email].to_s.strip.downcase)

    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to orders_path, notice: "サインインしました。"
    else
      flash.now[:alert] = "メールアドレスまたはパスワードが違います。"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to new_session_path, notice: "サインアウトしました。"
  end
end
