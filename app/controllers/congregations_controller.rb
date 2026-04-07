class CongregationsController < ApplicationController
  before_action :require_sign_in!

  def index
    results = if params[:query].to_s.gsub(/\D/, "").length >= 2
      Congregation.search_by_code_prefix(params[:query]).limit(20)
    else
      Congregation.none
    end

    render json: results.as_json(only: [ :id, :code, :name ])
  end
end
