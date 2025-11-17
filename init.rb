# frozen_string_literal: true

Redmine::Plugin.register :redmine_extended_api do
  name 'Redmine Extended API'
  author 'ZHware Co.'
  description 'Adds missing REST API endpoints: custom fields CRUD, queries CRUD, time entries bulk operations (globally available)'
  version '1.0.0'
  url 'https://github.com/zh/redmine_extended_api'
  author_url 'https://github.com/zh'

  requires_redmine version_or_higher: '6.1.0'

  # Global permissions
  permission :bulk_create_time_entries, { extended_time_entries: [:bulk_create] }, global: true
  permission :manage_custom_fields_via_api, { extended_custom_fields: %i[create update destroy] }, require: :admin
  permission :manage_queries_via_api, { extended_queries: %i[create update destroy] }, global: true
end
