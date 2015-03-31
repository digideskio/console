Rails.application.routes.draw do
  post "/", to: 'console#update'
  root to: 'console#show'
end
