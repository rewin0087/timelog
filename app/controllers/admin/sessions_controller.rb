class Admin::SessionsController < Admin::BaseController
  skip_before_action :require_admin, only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_admin_session_path, alert: "Too many attempts. Try again later." }

  def new
    redirect_to admin_root_path if cookies.signed[:admin_session_id] && AdminSession.exists?(id: cookies.signed[:admin_session_id])
  end

  def create
    if (admin = Administrator.authenticate_by(params.permit(:email_address, :password)))
      session_record = admin.admin_sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip)
      admin.update_column(:last_signed_in_at, Time.current)
      cookies.signed[:admin_session_id] = { value: session_record.id, httponly: true, same_site: :strict, expires: 12.hours }
      redirect_to admin_root_path
    else
      redirect_to new_admin_session_path, alert: "Try another email address or password.", flash: { email_address: params[:email_address] }
    end
  end

  def destroy
    Current.admin_session.destroy
    cookies.delete(:admin_session_id)
    redirect_to new_admin_session_path, notice: "Signed out of the admin."
  end
end
