Solitr::Application.routes.draw do
  root :to => "play#index"
  get ':action', :controller => :play
end
