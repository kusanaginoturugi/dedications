class OrdersController < ApplicationController
  before_action :require_sign_in!
  before_action :set_order, only: [ :show, :edit, :update, :destroy ]
  helper_method :sort_column, :sort_direction, :sort_arrow, :next_direction

  def index
    @orders = Order.includes(:congregation, :user).order(sort_column => sort_direction)
  end

  def summary
    orders = scoped_orders.includes(:congregation, :user).order(sort_column => sort_direction)
    @order_summaries = Order::FORM_DEFINITIONS.keys.filter_map do |form_type|
      matches = orders.select { |order| order.form_type == form_type }
      next if matches.empty?

      {
        form_type:,
        label: Order.form_definition_for(form_type).fetch(:label),
        total_quantity: matches.sum { |order| order.total_quantity.to_i },
        paid_quantity: matches.select(&:paid?).sum { |order| order.total_quantity.to_i },
        paid_amount: matches.select(&:paid?).sum { |order| order.total_amount.to_i },
        unpaid_quantity: matches.reject(&:paid?).sum { |order| order.total_quantity.to_i },
        unpaid_amount: matches.reject(&:paid?).sum { |order| order.total_amount.to_i },
        total_amount: matches.sum { |order| order.total_amount.to_i },
        orders: matches
      }
    end
  end

  def personal_summary
    @orders = Order.includes(:congregation, :user).order(sort_column => sort_direction)
    @user_summaries = @orders.group_by(&:user).map do |user, orders|
      {
        user:,
        order_count: orders.size,
        total_amount: orders.sum { |order| order.total_amount.to_i },
        unpaid_count: orders.count { |order| !order.paid? }
      }
    end.sort_by { |summary| [ -summary[:total_amount], summary[:user].display_name ] }
  end

  def new
    @order = current_user.orders.build(
      form_type: selected_form_type,
      fax_received_on: Date.current,
      event: current_event
    )
  end

  def create
    @order = current_user.orders.build(order_params.merge(event: current_event))

    if @order.save
      redirect_to @order, notice: "申込を登録しました。"
    else
      flash.now[:alert] = "入力内容を確認してください。"
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    if @order.update(order_params)
      redirect_to orders_path, notice: "申込を更新しました。"
    else
      flash.now[:alert] = "入力内容を確認してください。"
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @order.destroy!
    redirect_to orders_path, notice: "申込を削除しました。"
  end

  private

  def set_order
    @order = Order.includes(:congregation, :user).find(params[:id])
  end

  def scoped_orders
    return Order.all unless current_event

    Order.where(event: current_event).or(Order.where(event_id: nil))
  end

  def selected_form_type
    form_type = params.dig(:order, :form_type).presence || params[:form_type].presence
    Order::FORM_DEFINITIONS.key?(form_type) ? form_type : Order::FORM_DEFINITIONS.keys.first
  end

  def sort_column
    # 並べ替え可能な項目リスト（データベース上の名前）
    columns = {
      "番号" => "page_number",
      "奉納者名" => "offerer_name",
      "入力日" => "created_at",
      "FAX受信日" => "fax_received_on",
      "種類" => "form_type",
      "本数" => "serial_number_end - serial_number_start", # 合計本数
      "金額" => "total_amount",
      "入金状態" => "paid"
    }
    # 特殊な計算が必要な項目は簡易化、またはデフォルトの page_number にします
    valid_columns = %w[page_number offerer_name created_at fax_received_on form_type paid]
    valid_columns.include?(params[:sort]) ? params[:sort] : "page_number"
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "desc"
  end

  def sort_arrow(column)
    return "" unless sort_column == column
    sort_direction == "asc" ? " ▲" : " ▼"
  end

  def next_direction(column)
    (sort_column == column && sort_direction == "asc") ? "desc" : "asc"
  end

  def order_params
    params.require(:order).permit(
      :page_number,
      :fax_received_on,
      :form_type,
      :paid,
      :congregation_id,
      :serial_number_start,
      :serial_number_end,
      :offerer_name
    )
  end
end
