# FaultyTower MCP Server

This document describes the Model Context Protocol (MCP) server implementation for FaultyTower, which allows AI assistants to interact with your error tracking data.

## Overview

The FaultyTower MCP server provides tools that allow authenticated users to:
- Query their organizations and projects
- List and analyze errors with AI-friendly formatting
- Resolve or reopen errors
- Create GitHub issues for errors

## Authentication

The MCP server uses Bearer token authentication. You need to provide a valid FaultyTower session token in the Authorization header:

```
Authorization: Bearer YOUR_SESSION_TOKEN
```

### Getting Your Session Token

1. Log in to your FaultyTower account
2. Navigate to "Account Settings" (`/users/settings`)
3. Scroll down to the "MCP Server Access" section
4. Copy the displayed session token

This token is the same one used for your current browser session and will remain valid as long as your session is active.

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

### 4. get_error_details
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
      "id": "uuid",
      "name": "Project Name",
      "key": "project-key",
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

### 5. resolve_error
Marks an error as resolved.

**Input:**
- `error_id` (required): The error ID
- `resolution_note` (optional): Note about how the error was resolved

**Output:**
```json
{
  "success": true,
  "error": {
    "id": "uuid",
    "status": "resolved",
    "resolved_at": "2024-01-02T00:00:00Z",
    "resolution_note": "Fixed in commit abc123"
  }
}
```

### 6. reopen_error
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

### 7. create_github_issue
Creates a GitHub issue for an error (requires GitHub to be configured for the project).

**Input:**
- `error_id` (required): The error ID
- `title` (optional): Issue title (defaults to error reason)
- `body` (optional): Issue body (defaults to formatted error details)

**Output:**
```json
{
  "success": true,
  "github_issue_url": "https://github.com/owner/repo/issues/123",
  "error_id": "uuid"
}
```

## Configuration for AI Assistants

### Claude Desktop

Add to your Claude Desktop configuration:

```json
{
  "mcpServers": {
    "FaultyTower": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "http://localhost:4000/mcp"
      ],
      "env": {
        "AUTHORIZATION": "Bearer YOUR_SESSION_TOKEN"
      }
    }
  }
}
```

### Other MCP Clients

The MCP server is available at `http://your-faulty-tower-domain/mcp` and follows the standard MCP protocol over HTTP with Server-Sent Events (SSE) transport.

## Example Usage

1. **Finding and analyzing an error:**
   ```
   1. Use list_projects to find the project
   2. Use list_errors with the project_id to see recent errors
   3. Use get_error_details to get the full stacktrace and context
   4. The AI can analyze the error using the provided prompt
   ```

2. **Creating a GitHub issue:**
   ```
   1. Use get_error_details to understand the error
   2. Use create_github_issue to create an issue with a custom title/body
   3. The error will be automatically linked to the GitHub issue
   ```

3. **Managing error status:**
   ```
   1. Use resolve_error when an error is fixed
   2. Use reopen_error if the error reoccurs
   ```