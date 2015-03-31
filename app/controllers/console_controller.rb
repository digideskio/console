class ConsoleController < ApplicationController
  before_action :validate_skey

  def show
  end

  def command
    argv = (params[:command] || "").shellsplit
    command_name = argv.shift

    options = Command::Options.parse(argv)
    command = Command.new(skey, options)

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

  def validate_skey
    return if params[:skey].blank?

    if params[:skey].start_with?("skey_test_")
      redirect_to root_url(skey: skey.split(?_).last)
      return
    end

    if params[:skey].start_with?("skey_")
      flash.notice = "please use a test secret key."
      redirect_to root_url
      return
    end
  end

  def skey
    "skey_test_#{params[:skey]}"
  end
end
