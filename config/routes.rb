Rails.application.routes.draw do
  devise_for :users, controllers: {
      sessions: 'v1/sessions'
  }
  namespace :v1, defaults: { format: :json } do
    resources :sessions, only: [:create, :show, :destroy]
    resources :users, only:[:index, :create, :update]
    resources :kids, only:[:index, :create, :show, :update]
    resources :devices
    post 'campus/grades/by_name', to: 'campus#show_by_name'
    post 'campus/groups/by_name_and_grade', to: 'campus#show_groups_by_campus_and_grades'
    delete 'campus/by_name', to: 'campus#delete_campus_by_name'
    resources :campus

    get 'kids/by_family_key/:family_key', to: 'kids#show_by_family_key'
    get 'all_family_keys', to: 'kids#all_family_keys'
    post 'kids/create_kids_from_xls', to: 'kids#import_data_from_excel'
    post 'users/create_users_from_xls', to: 'users#import_data_from_excel'
    resources :notifications, only:[:index, :create, :update]
    get 'notifications/by_user_id/:user_id', to: 'notifications#show_by_user_id'
    post 'notifications/by_parameter', to: 'notifications#notifications_group'
    post 'notifications/update_notification/:notification_id', to: 'notifications#update_notification'
    post 'notifications/create_notifications_from_excel', to: 'notifications#create_notification_from_excel'
    get 'notifications/notification_counters/:user_id', to: 'notifications#notification_counter_by_user_id'
    post 'notifications/create_notifications_from_excel', to: 'notifications#create_notification_from_excel'
    post 'notifications/parents_by_event_and_page', to: 'events#show_users_by_page'

  end
end
