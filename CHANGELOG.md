# Changelog

All notable changes to the Redmine Extended API plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Queries CRUD API**
  - `POST /extended_api/queries.json` - Create queries (saved filters)
  - `PUT /extended_api/queries/:id.json` - Update existing queries
  - `DELETE /extended_api/queries/:id.json` - Delete queries
  - Supports IssueQuery, ProjectQuery, TimeEntryQuery, and other query types
  - Permission-based access: users manage own private queries, admins manage all
  - `manage_queries_via_api` global permission
  - Full filter support with all Redmine operators (<=, >=, ~, t, w, m, etc.)
  - Comprehensive test coverage (23 examples)

### Changed
- Made all API features globally available (removed per-project module requirement)
- `bulk_create_time_entries` is now a global permission instead of project-scoped
- Added permission enforcement for `bulk_create_time_entries` in the controller
- Migrated test suite from Test::Unit to RSpec for consistency with other Agileware plugins
- Replaced fixture-based testing with FactoryBot for more flexible and maintainable test data
- Implemented HTTP Basic authentication in tests to match Redmine API patterns
- Enhanced permission checking to require explicit project membership for time logging
- Improved validation error responses with direct JSON rendering for better test compatibility

### Fixed
- Fixed hours format in time entry responses (now returns Float instead of Rational)
- Fixed permission checks to properly return 403 Forbidden when users lack required permissions
- Fixed validation error rendering to return proper JSON in all scenarios
- Fixed test isolation issues with User.current state management

### Technical
- Added 10 FactoryBot factories (users, projects, roles, issues, trackers, members, etc.)
- Created comprehensive test infrastructure:
  - `spec/rails_helper.rb` - Main RSpec configuration with authentication helpers
  - `spec/spec_helper.rb` - RSpec base configuration
  - `spec/factories/` - FactoryBot factory definitions
  - `spec/support/` - Test helpers (FactoryBot config, test data loading)
- Implemented `credentials()` helper for HTTP Basic authentication in controller tests
- Added REST API enablement and User.current reset hooks for proper test isolation
- All 27 tests passing (100% pass rate): 16 custom field tests, 11 time entry tests

## [1.0.0] - 2025-01-06

### Added
- **Custom Fields Management API**
  - `POST /custom_fields.json` - Create custom fields (all types)
  - `PUT /custom_fields/:id.json` - Update existing custom fields
  - `DELETE /custom_fields/:id.json` - Delete custom fields
  - Supports IssueCustomField, ProjectCustomField, and all other types
  - Admin-only access control

- **Time Entries Bulk Create API** (`POST /time_entries/bulk_create.json`)
  - Create multiple time entries in a single request
  - Supports both issue_id and project_id
  - Returns detailed success/failure report with 207 Multi-Status for partial success
  - Validates all entries and provides specific error messages

### Technical Details
- Requires Redmine 6.1.0 or higher
- Full RSpec test coverage (3 controller specs with comprehensive tests)
- Follows Redmine plugin development best practices
- RESTful API design with proper HTTP status codes
- JSON-only endpoints for consistency

### Permissions
- `manage_custom_fields_via_api`: Admin permission for custom fields management (global)
- `bulk_create_time_entries`: Global permission for bulk time entry creation

### Documentation
- Complete API documentation in README.md
- cURL examples for all endpoints
- Detailed parameter descriptions
- HTTP status code reference

[1.0.0]: https://github.com/agileware/redmine_extended_api/releases/tag/v1.0.0
