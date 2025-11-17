# Redmine Extended API

Adds missing REST API endpoints to Redmine 6.1.x (globally available):
- **Custom Fields CRUD**: Full management of custom fields
- **Queries CRUD**: Create, update, and delete queries (saved filters)
- **Time Entries Bulk**: Create multiple time entries in one request

## Requirements
- Redmine 6.1.0 or higher

## Installation

```bash
cd /path/to/redmine/plugins
git clone https://github.com/agileware/redmine_extended_api.git
cd /path/to/redmine
bundle install
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
systemctl restart redmine
```

## API Endpoints

### 1. Custom Fields CRUD

**POST /custom_fields.json** - Create custom field
**PUT /custom_fields/:id.json** - Update custom field
**DELETE /custom_fields/:id.json** - Delete custom field

**Requires**: Admin privileges

**Create Example**:
```bash
curl -X POST \
  -H "X-Redmine-API-Key: ADMIN_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "custom_field": {
      "type": "IssueCustomField",
      "name": "Priority Level",
      "field_format": "list",
      "possible_values": ["Low", "Medium", "High"],
      "is_required": false,
      "is_for_all": true
    }
  }' \
  https://redmine.example.com/custom_fields.json
```

**Update Example**:
```bash
curl -X PUT \
  -H "X-Redmine-API-Key": ADMIN_KEY" \
  -H "Content-Type: application/json" \
  -d '{"custom_field":{"name":"Updated Name","is_required":true}}' \
  https://redmine.example.com/custom_fields/5.json
```

**Delete Example**:
```bash
curl -X DELETE \
  -H "X-Redmine-API-Key: ADMIN_KEY" \
  https://redmine.example.com/custom_fields/5.json
```

### 2. Queries CRUD

**POST /extended_api/queries.json** - Create query
**PUT /extended_api/queries/:id.json** - Update query
**DELETE /extended_api/queries/:id.json** - Delete query

**Permissions**: Users can create/update/delete their own private queries. Users with `manage_public_queries` permission can manage public project queries. Only admins can manage global public queries.

**Create Private Query Example**:
```bash
curl -X POST \
  -H "X-Redmine-API-Key: YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "name": "Late Issues Before May",
      "type": "IssueQuery",
      "visibility": 0,
      "filters": {
        "due_date": {"operator": "<=", "values": ["2025-05-01"]},
        "status_id": {"operator": "o"}
      }
    }
  }' \
  https://redmine.example.com/extended_api/queries.json
```

**Create Public Project Query Example**:
```bash
curl -X POST \
  -H "X-Redmine-API-Key: YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "name": "My Team Issues",
      "type": "IssueQuery",
      "project_id": 5,
      "visibility": 2,
      "filters": {
        "assigned_to_id": {"operator": "=", "values": ["me"]}
      },
      "column_names": ["id", "subject", "status", "assigned_to", "due_date"],
      "sort_criteria": [["due_date", "asc"]]
    }
  }' \
  https://redmine.example.com/extended_api/queries.json
```

**Update Query Example**:
```bash
curl -X PUT \
  -H "X-Redmine-API-Key: YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "name": "Updated Query Name",
      "filters": {
        "priority_id": {"operator": "=", "values": ["4", "5"]}
      }
    }
  }' \
  https://redmine.example.com/extended_api/queries/10.json
```

**Delete Query Example**:
```bash
curl -X DELETE \
  -H "X-Redmine-API-Key: YOUR_KEY" \
  https://redmine.example.com/extended_api/queries/10.json
```

**Query Parameters**:
- `name` (required): Query name
- `type`: Query type (default: "IssueQuery"). Options: IssueQuery, ProjectQuery, TimeEntryQuery
- `project_id`: Project ID (null = global query)
- `visibility`: 0=Private, 1=Roles, 2=Public
- `filters`: Hash of filters with operators and values
- `column_names`: Array of column names to display
- `sort_criteria`: Array of [field, order] pairs
- `role_ids`: Array of role IDs (required when visibility=1)

**Common Filter Operators**:
- `=`, `!`: Equals, not equals
- `>=`, `<=`: Greater/less than or equal
- `~`, `!~`: Contains, doesn't contain
- `o`, `c`: Open, closed (for status)
- `t`: Today, `w`: This week, `m`: This month
- `<t+N`: Less than N days from now
- `>t-N`: More than N days ago

### 3. Time Entries Bulk Create

**POST /time_entries/bulk_create.json**

Create multiple time entries at once.

**Request Body**:
```json
{
  "time_entries": [
    {
      "issue_id": 123,
      "spent_on": "2025-01-15",
      "hours": 2.5,
      "activity_id": 9,
      "comments": "Development work"
    },
    {
      "project_id": 5,
      "spent_on": "2025-01-15",
      "hours": 1.0,
      "activity_id": 9,
      "comments": "Meeting"
    }
  ]
}
```

**Response (201 Created)** - All succeeded:
```json
{
  "created": [
    {"id": 456, "hours": 2.5, "issue_id": 123},
    {"id": 457, "hours": 1.0, "project_id": 5}
  ],
  "failed": [],
  "summary": {
    "total": 2,
    "created": 2,
    "failed": 0
  }
}
```

**Response (207 Multi-Status)** - Partial success:
```json
{
  "created": [{"id": 456, "hours": 2.5}],
  "failed": [
    {
      "index": 1,
      "errors": ["Project or issue required"]
    }
  ],
  "summary": {
    "total": 2,
    "created": 1,
    "failed": 1
  }
}
```

**Example**:
```bash
curl -X POST \
  -H "X-Redmine-API-Key: YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "time_entries": [
      {"issue_id": 123, "spent_on": "2025-01-15", "hours": 2.5, "activity_id": 9, "comments": "Coding"},
      {"issue_id": 124, "spent_on": "2025-01-15", "hours": 1.0, "activity_id": 9, "comments": "Review"}
    ]
  }' \
  https://redmine.example.com/time_entries/bulk_create.json
```

## Permissions

Configure these permissions in Administration → Roles and permissions:

- **manage_custom_fields_via_api**: Create/update/delete custom fields (requires admin status)
- **manage_queries_via_api**: Create/update/delete queries (global permission)
- **bulk_create_time_entries**: Create multiple time entries in one request (global permission)

All permissions are global and do not require per-project module enabling.

## HTTP Status Codes

- **200 OK**: Successful update
- **201 Created**: Resource created successfully
- **204 No Content**: Successful deletion
- **207 Multi-Status**: Partial success (some items succeeded, some failed)
- **401 Unauthorized**: Missing or invalid API key
- **403 Forbidden**: Insufficient permissions
- **404 Not Found**: Resource not found
- **406 Not Acceptable**: Endpoint only accepts API requests
- **422 Unprocessable Entity**: Validation errors

## Development

### Testing

This plugin uses RSpec for testing. All tests are located in the `spec/` directory.

**Run all tests:**
```bash
cd /path/to/redmine
bundle exec rspec plugins/redmine_extended_api/spec
```

**Run specific test file:**
```bash
bundle exec rspec plugins/redmine_extended_api/spec/controllers/extended_projects_controller_spec.rb
```

**Run specific test:**
```bash
bundle exec rspec plugins/redmine_extended_api/spec/controllers/extended_projects_controller_spec.rb:16
```

### Test Structure

- **spec/controllers/** - Controller specs for API endpoints
  - `extended_custom_fields_controller_spec.rb` - Custom fields CRUD tests (16 examples)
  - `extended_queries_controller_spec.rb` - Queries CRUD tests (23 examples)
  - `extended_time_entries_controller_spec.rb` - Bulk time entries tests (12 examples)
- **spec/factories/** - FactoryBot factories for test data
- **spec/support/** - Test helpers and configuration

**Test Coverage:** 51 examples, 100% passing

### Testing Features

- ✅ HTTP Basic authentication testing
- ✅ Permission and authorization testing
- ✅ Validation error handling
- ✅ Success and failure scenarios
- ✅ Multi-status responses (207)
- ✅ Edge cases and boundary conditions
- ✅ FactoryBot for consistent test data
- ✅ Isolated test environment

## License

MIT License

## Author

Agileware - https://agileware.com

## Support

Report issues at: https://github.com/agileware/redmine_extended_api/issues
