class OrdersController < ApplicationController
  before_action :require_sign_in!
  before_action :set_order, only: [ :show, :edit, :update ]

  def index
    @orders = Order.includes(:congregation, :user).order(page_number: :desc, created_at: :desc)
  end

  def summary
    orders = Order.includes(:congregation, :user).order(:page_number, :created_at)
    @order_summaries = Order::FORM_DEFINITIONS.keys.filter_map do |form_type|
      matches = orders.select { |order| order.form_type == form_type }
      next if matches.empty?

      {
        form_type:,
        label: Order.form_definition_for(form_type).fetch(:label),
        total_quantity: matches.sum { |order| order.total_quantity.to_i },
        total_amount: matches.sum { |order| order.total_amount.to_i },
        orders: matches
      }
    end
  end

  def personal_summary
    @orders = Order.includes(:congregation, :user).order(created_at: :desc, id: :desc)
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
    @order = current_user.orders.build(form_type: selected_form_type)
  end

  def create
    @order = current_user.orders.build(order_params)

    if @order.save
      redirect_to @order, notice: "注文を登録しました。"
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
      redirect_to orders_path, notice: "注文を更新しました。"
    else
      flash.now[:alert] = "入力内容を確認してください。"
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_order
    @order = Order.includes(:congregation, :user).find(params[:id])
  end

  def selected_form_type
    form_type = params.dig(:order, :form_type).presence || params[:form_type].presence
    Order::FORM_DEFINITIONS.key?(form_type) ? form_type : Order::FORM_DEFINITIONS.keys.first
  end

  def order_params
    params.require(:order).permit(
      :page_number,
      :fax_received_on,
      :form_type,
      :paid,
      :congregation_id,
      :serial_number_start,
      :serial_number_end
    )
  end
end
