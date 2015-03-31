Rails.application.routes.draw do
  post "/", to: 'console#command', as: :command
  root to: 'console#show'
end
