Rails.application.routes.draw do
  root "dashboard#index"

  resources :documents, only: %i[index new create show]
  resources :query_traces, only: %i[index new create show]
  resources :eval_runs, only: %i[index] do
    collection do
      post :offline, action: :create_offline
    end
  end

  get "up" => "health#show", as: :rails_health_check
end
