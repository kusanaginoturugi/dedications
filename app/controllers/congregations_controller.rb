class CongregationsController < ApplicationController
  before_action :require_sign_in!

  def index
    query = params[:query].to_s.strip
    results = if query.gsub(/\D/, "").length >= 2 || query.length >= 2
      Congregation.search_by_query(query).limit(20)
    else
      Congregation.none
    end

    render json: results.as_json(only: [ :id, :code, :name ])
  end
end
