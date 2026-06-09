class FellowshipsController < ApplicationController
  before_action :require_sign_in!
  before_action :require_admin!, only: %i[sync bulk_update_enabled]

  def index
    respond_to do |format|
      format.json do
        query = params[:query].to_s.strip
        results = if query.gsub(/\D/, "").length >= 2 || query.length >= 2
          Fellowship.search_by_query(query).limit(20)
        else
          Fellowship.none
        end
        render json: results.as_json(only: [ :id, :code, :name ])
      end
      format.html do
        @fellowships = Fellowship.where(enabled: true).order(:code)
        @all_fellowships = Fellowship.order(:code)
      end
    end
  end

  def sync
    result = MasterSync.run
    redirect_to fellowships_path, notice: "マスタから #{result.count} 件を同期しました。"
  rescue MasterSync::FetchError => e
    redirect_to fellowships_path, alert: "マスタ同期に失敗しました: #{e.message}"
  end

  def bulk_update_enabled
    enabled_ids = Array(params[:enabled]).map(&:to_i).to_set
    Fellowship.transaction do
      Fellowship.find_each do |fellowship|
        want = enabled_ids.include?(fellowship.id)
        fellowship.update!(enabled: want) if fellowship.enabled != want
      end
    end
    redirect_to fellowships_path, notice: "対象伝道会を更新しました。"
  end
end
