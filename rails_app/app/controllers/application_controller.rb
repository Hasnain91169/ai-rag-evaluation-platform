class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  private

  def render_service_error(error)
    flash[:alert] = "Service error: #{error.message}"
    redirect_back fallback_location: root_path
  end
end
