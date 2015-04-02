module ConsoleHelper
  def prompt
    ENV["PROMPT"].presence || Rails.application.secrets.prompt
  end
end
