class HealthController < ApplicationController
  skip_forgery_protection

  def show
    render json: { status: "ok" }
  end
end
