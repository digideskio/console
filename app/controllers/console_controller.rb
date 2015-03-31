class ConsoleController < ApplicationController
  before_action :user_required

  def show
  end

  def update
    argv = (params[:command] || "").shellsplit
    command_name = argv.shift

    options = Command::Options.parse(argv)
    command = Command.new(user, options)

    if command.respond_to?(command_name)
      result = command.send(command_name, argv)
      render plain: ERB::Util.html_escape(result)
    else
      render plain: "command not found: #{command_name}", status: :not_found
    end
  rescue => e
    render plain: ERB::Util.html_escape(e.message), status: :bad_request
  end

  private

  def user_required
    valid, notice = validate_user(params[:u])

    flash.now.notice = notice if notice

    if request.xhr? && !valid
      render plain: ERB::Util.html_escape(notice), status: :bad_request
    elsif !valid
      render :login
    end

    @user = params[:u]
  end

  def validate_user(user)
    if user.blank?
      [false, nil]
    elsif user.start_with?("skey_test_")
      [true, "[login] #{user}"]
    elsif user.start_with?("skey_")
      [false, "[logout] live key detected."]
    else
      [false, "[logout] invalid secret key."]
    end
  end

  def user
    params[:u]
  end
end
