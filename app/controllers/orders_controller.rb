class OrdersController < ApplicationController
  before_action :require_sign_in!

  def index
    @orders = Order.includes(:congregation, :user, :order_items).order(created_at: :desc)
  end

  def new
    @order = current_user.orders.build(form_type: selected_form_type)
    @order.build_detail_rows
  end

  def create
    @order = current_user.orders.build(order_params)

    if @order.save
      redirect_to @order, notice: "注文を登録しました。"
    else
      @order.build_detail_rows
      flash.now[:alert] = "入力内容を確認してください。"
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @order = Order.includes(:congregation, :user, :order_items).find(params[:id])
  end

  private

  def selected_form_type
    form_type = params.dig(:order, :form_type).presence || params[:form_type].presence
    Order::FORM_DEFINITIONS.key?(form_type) ? form_type : Order::FORM_DEFINITIONS.keys.first
  end

  def order_params
    params.require(:order).permit(
      :page_number,
      :form_type,
      :paid,
      :congregation_id,
      :contact_name,
      :phone,
      order_items_attributes: [ :entry_number, :donor_name, :wish, :quantity, :position ]
    )
  end
end
