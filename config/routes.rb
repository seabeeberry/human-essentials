def set_up_flipper
  flipper_app = Flipper::UI.app(Flipper.instance, rack_protection: {except: :http_origin}) do |builder|
    builder.use Rack::Auth::Basic do |username, password|
      username == ENV["FLIPPER_USERNAME"] && password == ENV["FLIPPER_PASSWORD"]
    end
  end
  mount flipper_app, at: "/flipper"
end

Rails.application.routes.draw do
  get 'distributions_by_county/report'
  devise_for :users, controllers: {
    sessions: "users/sessions",
    omniauth_callbacks: 'users/omniauth_callbacks'
  }

  #
  # Mount web interface to see delayed job status and queue length.
  # Visible only to logged in users with the `super_admin` role
  #
  authenticated :user, ->(user) { user.has_role?(Role::SUPER_ADMIN) } do
    mount DelayedJobWeb, at: "/delayed_job"
  end

  set_up_flipper

  # Add route partners/dashboard so that we can define it as partner_user_root
  get 'partners/dashboard' => 'partners/dashboards#show', as: :partner_user_root
  namespace :partners do
    resource :dashboard, only: [:show]
    resource :help, only: [:show]
    resources :requests, only: [:show, :new, :index, :create] do
      post :validate, on: :collection
    end
    resources :individuals_requests, only: [:new, :create] do
      post :validate, on: :collection
    end
    resources :family_requests, only: [:new, :create] do
      post :validate, on: :collection
    end
    resources :users, only: [:index, :new, :create, :edit, :update]
    resource :profile, only: [:show, :edit, :update]
    resource :approval_request, only: [:create]

    resources :children, except: [:destroy] do
      post :active
    end
    resources :families
    resources :authorized_family_members
    resources :distributions, only: [:index] do
      get :print, on: :member
    end
    resources :donations, only: [:index] do
      get :print, on: :member
    end
  end

  # This is where a superadmin CRUDs all the things
  get :admin, to: "admin#dashboard"
  namespace :admin do
    get :dashboard
    resources :base_items
    resources :organizations, except: %i[edit update]
    resources :partners, except: %i[new create]
    resources :users do
      delete :remove_role
      post :add_role
      get :resource_ids, on: :collection
    end
    resources :barcode_items
    resources :account_requests, only: [:index] do
      post :reject, on: :collection
      post :close, on: :collection
      get :for_rejection, on: :collection
    end
    resources :questions
    resources :broadcast_announcements
    resources :ndbn_members, only: :index do
      post :upload_csv, on: :collection
    end
  end

  resources :users do
    get :switch_to_role, on: :collection
    post :partner_user_reset_password, on: :collection
  end

  # Users that are organization admins can manage the organization itself
  resource :organization, only: [:show]
  resource :organization, path: :manage, only: %i(edit update) do
    collection do
      post :invite_user
      post :remove_user
      post :resend_user_invitation
      post :promote_to_org_admin
      post :demote_to_user
    end
  end

  resources :events, only: %i(index)

  resources :adjustments, except: %i(edit update)

  resources :audits do
    post :finalize
  end

  namespace :reports do
    resources :annual_reports, only: [:index, :show], param: :year do
      post :recalculate, on: :member
    end
    get :donations_summary
    get :manufacturer_donations_summary
    get :product_drives_summary
    get :purchases_summary
    get :itemized_donations
    get :itemized_distributions
    get :distributions_summary
    get :activity_graph
  end

  resources :transfers, only: %i(index create new show destroy)

  resources :storage_locations do
    put :deactivate
    put :reactivate
    collection do
      post :import_csv
      post :import_inventory
    end
    member do
      get :inventory
    end
  end

  resources :distributions do
    get :print, on: :member
    collection do
      post :validate
      get :calendar
      get :schedule
      get :pickup_day
      get :itemized_breakdown
    end
    patch :picked_up, on: :member
  end

  resources :barcode_items do
    get :find, on: :collection
    get :font, on: :collection
  end

  resources :donation_sites, except: [:destroy] do
    collection do
      post :import_csv
    end
    member do
      put :deactivate
      put :reactivate
    end
  end

  resources :product_drive_participants, except: [:destroy] do
    collection do
      post :import_csv
    end
  end

  resources :manufacturers, except: [:destroy] do
    collection do
      post :import_csv
    end
  end

  resources :vendors do
    collection do
      post :import_csv
    end
    member do
      put :deactivate
      put :reactivate
    end
  end

  resources :kits do
    member do
      get :allocations
      post :allocate
      put :deactivate
      put :reactivate
    end
  end

  resources :profiles, only: %i(edit update)

  resources :items do
    delete :deactivate, on: :member
    patch :restore, on: :member
    patch :remove_category, on: :member
  end

  resources :item_categories, except: [:index]

  resources :partners do
    resources :users, only: [:index, :create, :destroy], controller: 'partner_users' do
      member do
        post :resend_invitation
        post :reset_password
      end
    end

    collection do
      post :import_csv
    end
    member do
      get :profile
      patch :profile
      get :approve_application
      post :invite
      post :invite_and_approve
      post :recertify_partner
      put :deactivate
      put :reactivate
    end
  end

  resources :partner_groups, only: %i(new create edit update destroy)

  resources :product_drives

  resources :donations do
    get :print, on: :member
    patch :add_item, on: :member
    patch :remove_item, on: :member
  end

  resources :purchases

  resources :requests, only: %i(index new show) do
    member do
      post :start
    end
    get :print_unfulfilled, on: :collection
    get :print_picklist, on: :member
  end
  resources :requests, except: %i(destroy) do
    resource :cancelation, only: [:new, :create], controller: 'requests/cancelation'
    get :print, on: :member
    collection do
      get :partner_requests
    end
  end

  get "dashboard", to: "dashboard#index"

  get "historical_trends/distributions", to: "historical_trends/distributions#index"
  get "historical_trends/purchases", to: "historical_trends/purchases#index"
  get "historical_trends/donations", to: "historical_trends/donations#index"

  resources :attachments, only: %i(destroy)

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  get "help", to: "help#show"
  get "pages/:name", to: "static#page"
  get "/privacypolicy", to: "static#privacypolicy"
  resources :account_requests, only: [:new, :create] do
    collection do
      get 'confirmation'
      get 'confirm'
      get 'received'

      get 'invalid_token'
    end
  end
  resources :broadcast_announcements

  root "static#index"
end
