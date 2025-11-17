# frozen_string_literal: true

# Extended API routes with /extended_api prefix to avoid conflicts with core Redmine routes
scope '/extended_api', as: 'extended_api' do
  # Custom fields CRUD (admin only)
  resources :custom_fields, only: %i[create update destroy], controller: 'extended_custom_fields'

  # Queries CRUD (authenticated users)
  resources :queries, only: %i[create update destroy], controller: 'extended_queries'

  # Time entries bulk operations
  post 'time_entries/bulk_create', to: 'extended_time_entries#bulk_create'
end
