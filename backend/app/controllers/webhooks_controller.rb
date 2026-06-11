class WebhooksController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_webhook, only: [:show, :update, :destroy]

  def index
    webhooks = current_user.club.webhooks.order(created_at: :desc)
    render json: webhooks.map { |w| serialize(w) }
  end

  def show
    deliveries = @webhook.webhook_deliveries.recientes.limit(50)
    render json: serialize(@webhook).merge(
      deliveries: deliveries.map { |d| serialize_delivery(d) }
    )
  end

  def create
    webhook = current_user.club.webhooks.build(webhook_params)
    webhook.created_by = current_user
    webhook.secret    ||= SecureRandom.hex(32)

    if webhook.save
      render json: serialize(webhook), status: :created
    else
      render json: { errors: webhook.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @webhook.update(webhook_params)
      render json: serialize(@webhook)
    else
      render json: { errors: @webhook.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @webhook.destroy
    head :no_content
  end

  private

  def set_webhook
    @webhook = current_user.club.webhooks.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'No encontrado' }, status: :not_found
  end

  def webhook_params
    p = params.require(:webhook).permit(:nombre, :url, :active, events: [])
    p[:events] = p[:events].to_json if p[:events]
    p
  end

  def require_admin
    render json: { error: 'No autorizado' }, status: :forbidden unless current_user.admin?
  end

  def serialize(w)
    {
      id:          w.id,
      nombre:      w.nombre,
      url:         w.url,
      secret:      w.secret,
      events:      w.events_array,
      active:      w.active,
      created_at:  w.created_at,
      deliveries_count: w.webhook_deliveries.count,
      last_delivery_at: w.webhook_deliveries.maximum(:created_at),
    }
  end

  def serialize_delivery(d)
    {
      id:                d.id,
      event:             d.event,
      status:            d.status,
      http_code:         d.http_code,
      duration_ms:       d.duration_ms,
      error_message:     d.error_message,
      attempts:          d.attempts,
      last_attempted_at: d.last_attempted_at,
      created_at:        d.created_at,
    }
  end
end
