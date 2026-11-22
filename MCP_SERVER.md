# FaultyTower MCP Server

This document describes the Model Context Protocol (MCP) server implementation for FaultyTower, which allows AI assistants to interact with your error tracking data.

## Overview

The FaultyTower MCP server provides tools that allow authenticated users to:
- Query their organizations and projects
- List and search errors with AI-friendly formatting
- Resolve or reopen errors
- Create issues in GitHub or Forgejo for errors
- Assign existing issues to errors (useful when multiple errors share the same root cause)

## Authentication

The MCP server uses Bearer token authentication. You need to provide a valid FaultyTower MCP token in the Authorization header:

```
Authorization: Bearer YOUR_MCP_TOKEN
```

### Getting Your MCP Token

1. Log in to your FaultyTower account
2. Navigate to "Account Settings" (`/users/settings`)
3. Scroll down to the "MCP Server Access" section
4. Copy the displayed MCP token

This token remains valid until it expires (shown in settings) or you regenerate it.

## Available Tools

### 1. list_organizations
Lists all organizations the authenticated user has access to.

**Input:** None required

**Output:**
```json
{
  "organizations": [
    {
      "id": "uuid",
      "name": "Organization Name",
      "inserted_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

### 2. list_projects
Lists all projects the authenticated user has access to.

**Input:**
- `organization_id` (optional): Filter projects by organization

**Output:**
```json
{
  "projects": [
    {
      "id": "uuid",
      "key": "project-key",
      "name": "Project Name",
      "organization_id": "uuid",
      "organization_name": "Org Name",
      "otp_app": "app_name",
      "github_repo": "owner/repo",
      "ntfy_topic": "topic",
      "error_count": 5
    }
  ]
}
```

### 3. list_errors
Lists errors for a specific project.

**Input:**
- `project_id` (required): The project ID
- `status` (optional): "unresolved", "resolved", or "all" (default: "unresolved")
- `limit` (optional): Maximum number of errors (default: 20)

**Output:**
```json
{
  "project": {
    "id": "uuid",
    "name": "Project Name",
    "key": "project-key"
  },
  "errors": [
    {
      "id": "uuid",
      "fingerprint": "hash",
      "reason": "Error reason",
      "status": "unresolved",
      "occurrence_count": 10,
      "first_occurrence": "2024-01-01T00:00:00Z",
      "last_occurrence": "2024-01-02T00:00:00Z",
      "github_issue_url": "https://github.com/owner/repo/issues/123",
      "context_summary": {
        "environment": "production",
        "request_info": {...},
        "user_info": {...}
      }
    }
  ]
}
```

### 4. search_errors
Search for errors across all user projects by reason text.

**Input:**
- `search_text` (required): Text to search for in error reasons
- `status` (optional): "unresolved", "resolved", or "all" (default: "unresolved")
- `limit` (optional): Maximum number of errors to return (default: 50)

**Output:**
```json
{
  "search_text": "connection",
  "total_found": 3,
  "errors": [
    {
      "id": "uuid",
      "reason": "Connection refused",
      "status": "unresolved",
      "fingerprint": "hash",
      "occurrence_count": 5,
      "first_occurrence": "2024-01-01T00:00:00Z",
      "last_occurrence": "2024-01-02T00:00:00Z",
      "project": {
        "project_id": "project-key",
        "name": "Project Name",
        "organization": "Org Name"
      }
    }
  ]
}
```

### 5. get_error_details
Gets detailed information about a specific error, including stacktrace formatted for AI analysis.

**Input:**
- `error_id` (required): The error ID
- `include_occurrences` (optional): Include all occurrences (default: false, only latest)

**Output:**
```json
{
  "error": {
    "id": "uuid",
    "fingerprint": "hash",
    "reason": "Error reason",
    "status": "unresolved",
    "occurrence_count": 10,
    "first_occurrence": "2024-01-01T00:00:00Z",
    "last_occurrence": "2024-01-02T00:00:00Z",
    "github_issue_url": "https://github.com/owner/repo/issues/123",
    "project": {
      "project_id": "project-key",
      "name": "Project Name",
      "otp_app": "app_name"
    }
  },
  "occurrences": [
    {
      "id": "uuid",
      "timestamp": "2024-01-02T00:00:00Z",
      "stacktrace": [...],
      "context": {...},
      "reason": "Detailed error message"
    }
  ],
  "ai_analysis_prompt": "Error Analysis Request:\n\nApplication: Project Name (app_name)\n..."
}
```

### 6. resolve_error
Marks an error as resolved.

**Input:**
- `error_id` (required): The error ID

**Output:**
```json
{
  "success": true,
  "error": {
    "id": "uuid",
    "status": "resolved"
  }
}
```

### 7. reopen_error
Reopens a resolved error.

**Input:**
- `error_id` (required): The error ID

**Output:**
```json
{
  "success": true,
  "error": {
    "id": "uuid",
    "status": "unresolved"
  }
}
```

### 8. create_issue
Creates an issue for an error in the project's configured git provider (GitHub or Forgejo).

**Input:**
- `error_id` (required): The error ID

**Output:**
```json
{
  "success": true,
  "provider": "github",
  "issue_number": 123,
  "error_id": "uuid"
}
```

### 9. assign_issue
Assigns an existing issue to an error. This is useful when multiple errors share the same root cause and you want to link them all to a single issue instead of creating duplicate issues.

**Input:**
- `error_id` (required): The error ID to assign the issue to
- `issue_number` (required): The issue number (integer)

**Output:**
```json
{
  "success": true,
  "provider": "github",
  "issue_number": 123,
  "error_id": "uuid",
  "message": "Issue #123 successfully assigned to error"
}
```

## Configuration for AI Assistants

### Claude Code

Add to your Claude Code settings (`~/.claude/settings.json`):

```json
{
  "mcpServers": {
    "FaultyTower": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "https://your-faulty-tower-domain/mcp"
      ],
      "env": {
        "AUTHORIZATION": "Bearer YOUR_MCP_TOKEN"
      }
    }
  }
}
```

### Claude Desktop

Add to your Claude Desktop configuration:

```json
{
  "mcpServers": {
    "FaultyTower": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "https://your-faulty-tower-domain/mcp"
      ],
      "env": {
        "AUTHORIZATION": "Bearer YOUR_MCP_TOKEN"
      }
    }
  }
}
```

### Other MCP Clients

The MCP server is available at `https://your-faulty-tower-domain/mcp` and follows the standard MCP protocol over HTTP with Server-Sent Events (SSE) transport.

## Example Usage

1. **Finding and analyzing an error:**
   ```
   1. Use list_projects to find the project
   2. Use list_errors with the project_id to see recent errors
   3. Use get_error_details to get the full stacktrace and context
   4. The AI can analyze the error using the provided prompt
   ```

2. **Searching for specific errors:**
   ```
   1. Use search_errors with a keyword to find errors across all projects
   2. Use get_error_details on any matching error for full context
   ```

3. **Creating an issue:**
   ```
   1. Use get_error_details to understand the error
   2. Use create_issue to create an issue in GitHub/Forgejo
   3. The error will be automatically linked to the issue
   ```

4. **Managing error status:**
   ```
   1. Use resolve_error when an error is fixed
   2. Use reopen_error if the error reoccurs
   ```

5. **Linking multiple errors to the same issue:**
   ```
   1. Use list_errors or search_errors to find errors with the same root cause
   2. Use create_issue on the first error to create a new issue
   3. Use assign_issue on the other errors to link them to the same issue
   4. All errors will now be associated with the single issue
   ```
