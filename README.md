# Drink Water API

> **Note:** This is a learning project — not a reference for best practices, performance, or architecture. The goal is to explore Elixir/Phoenix by building something real. Contributions and PRs are welcome!

Hydration monitoring REST API built with Phoenix. Track water intake, manage personalized alarm settings, and monitor hydration goals.

Built to learn Elixir/Phoenix.

## Tech Stack

| Component     | Technology                |
| ------------- | ------------------------- |
| Framework     | Phoenix 1.8, Elixir 1.15+ |
| Database      | PostgreSQL 17 (Docker)    |
| Rate Limiting | Hammer 7 (ETS backend)    |
| Error Format  | RFC 9457 Problem Details  |

## Prerequisites

- Elixir 1.15+
- Erlang/OTP 26+
- Docker (for PostgreSQL)

## Setup

```bash
# Start PostgreSQL
docker compose up -d

# Install deps, create DB, run migrations, seed data
mix setup

# Start the server
mix phx.server
```

The API is available at `http://localhost:4000/api`.

Seeds create 3 users (John, Jane, Alex) with alarm settings and water intake records. IDs start from 1.

## API Endpoints

### Users

| Method | Path             | Description                          | Rate Limit |
| ------ | ---------------- | ------------------------------------ | ---------- |
| POST   | `/api/users`     | Create user                          | 30/min     |
| GET    | `/api/users/:id` | Get user                             | 30/min     |
| PUT    | `/api/users/:id` | Update user                          | 30/min     |
| DELETE | `/api/users/:id` | Delete user (idempotent, always 204) | 30/min     |

### Alarm Settings (one per user)

| Method | Path                                 | Description     | Rate Limit |
| ------ | ------------------------------------ | --------------- | ---------- |
| GET    | `/api/users/:user_id/alarm_settings` | Get settings    | 30/min     |
| POST   | `/api/users/:user_id/alarm_settings` | Create settings | 30/min     |
| PUT    | `/api/users/:user_id/alarm_settings` | Update settings | 30/min     |
| DELETE | `/api/users/:user_id/alarm_settings` | Delete settings | 30/min     |

### Water Intakes

| Method | Path                                    | Description                      | Rate Limit |
| ------ | --------------------------------------- | -------------------------------- | ---------- |
| GET    | `/api/users/:user_id/water_intakes`     | Search with filters + pagination | 20/min     |
| POST   | `/api/users/:user_id/water_intakes`     | Create intake                    | 60/min     |
| GET    | `/api/users/:user_id/water_intakes/:id` | Get intake                       | 60/min     |
| PUT    | `/api/users/:user_id/water_intakes/:id` | Update intake                    | 60/min     |
| DELETE | `/api/users/:user_id/water_intakes/:id` | Delete intake                    | 60/min     |

#### Search Parameters

| Parameter        | Required | Default         | Description                                           |
| ---------------- | -------- | --------------- | ----------------------------------------------------- |
| `start_date`     | yes      | -               | UTC datetime (e.g. `2024-08-14T00:00:00Z`)            |
| `end_date`       | yes      | -               | UTC datetime, must be >= start_date                   |
| `min_volume`     | no       | -               | 1-5000 ml                                             |
| `max_volume`     | no       | -               | 1-5000 ml, must be >= min_volume                      |
| `sort_field`     | no       | `date_time_utc` | `date_time_utc`, `volume`, or `id`                    |
| `sort_direction` | no       | `desc`          | `asc` or `desc`                                       |
| `size`           | no       | 10              | 1-50 items per page                                   |
| `cursor`         | no       | -               | Opaque cursor from `next_cursor` in previous response |

## Error Handling

All errors follow [RFC 9457 Problem Details](https://www.rfc-editor.org/rfc/rfc9457) with `application/problem+json` content type:

```json
{
  "type": "https://www.drinkwater.com.br/user-not-found",
  "title": "Not Found",
  "status": 404,
  "detail": "The requested user account was not found.",
  "instance": "/api/users/999"
}
```

| Status | Type Slug                        | When                                            |
| ------ | -------------------------------- | ----------------------------------------------- |
| 400    | `invalid-argument`               | Invalid cursor or query params                  |
| 400    | `parsing-error`                  | Malformed JSON body                             |
| 404    | `user-not-found`                 | User does not exist                             |
| 404    | `alarm-settings-not-found`       | Alarm settings not found                        |
| 404    | `waterintake-not-found`          | Water intake not found                          |
| 409    | `user-already-exists`            | Duplicate email                                 |
| 409    | `alarm-settings-already-exists`  | User already has settings                       |
| 409    | `waterintake-duplicate-datetime` | Duplicate datetime for user                     |
| 422    | `validation-error`               | Field validation failed (includes `errors` map) |
| 429    | `rate-limit-exceeded`            | Rate limit hit (includes `Retry-After` header)  |

## Validation Rules

### User

| Field                  | Rules                                                                   |
| ---------------------- | ----------------------------------------------------------------------- |
| email                  | Required, format `x@x`, max 255, unique                                 |
| first_name / last_name | Required, 2-50 chars, Unicode letters + spaces/hyphens/apostrophes only |
| birth_date             | Required, age 13-99                                                     |
| biological_sex         | Required, `male` or `female`                                            |
| weight                 | Required, 45-500 (kg)                                                   |
| height                 | Required, 50-250 (cm)                                                   |

### Alarm Settings

| Field            | Rules                                      |
| ---------------- | ------------------------------------------ |
| goal             | Required, 50-10000 ml                      |
| interval_minutes | Required, 15-240                           |
| daily_start_time | Required, 06:00-22:00                      |
| daily_end_time   | Required, 06:00-22:00, must be after start |

### Water Intake

| Field         | Rules                               |
| ------------- | ----------------------------------- |
| date_time_utc | Required, must not be in the future |
| volume        | Required, 1-5000 ml                 |
| volume_unit   | Required, `ml`                      |

## Security

- **Input sanitization:** Null bytes removed, whitespace trimmed on all string inputs
- **Rate limiting:** Per-user, per-endpoint-group (Hammer ETS)
- **Name validation:** Unicode `\p{L}` regex prevents injection via name fields
- **Idempotent delete:** Always returns 204, prevents user enumeration
- **Cursor validation:** Sort-field binding prevents cross-sort cursor reuse

## Project Structure

```text
lib/
  drink_water/
    user_management/          # Context: User + AlarmSettings
      user.ex                 # Schema + changeset
      alarm_settings.ex       # Schema + changeset
    user_management.ex        # Context API (public functions)
    hydration_tracking/       # Context: WaterIntake
      water_intake.ex         # Schema + changeset
      water_intake_filter.ex  # Embedded schema for search params
    hydration_tracking.ex     # Context API (query composition, pagination)
  drink_water_web/
    controllers/              # REST controllers + JSON views
    plugs/
      input_sanitizer.ex      # Null byte + whitespace sanitization
      rate_limiter.ex         # Per-user rate limiting (Hammer)
    problem_detail.ex         # RFC 9457 error catalog
    router.ex                 # API routes + rate limit pipelines
```

Contexts follow DDD bounded contexts. `HydrationTracking` references users by ID, not by association (`belongs_to`).

## Development

```bash
# Run tests
mix test

# Run tests with coverage
mix test --cover

# Pre-commit check (compile warnings + format + tests)
mix precommit

# Reset database and re-seed
mix ecto.reset

# Manual API testing (VSCode REST Client)
# Open requests.http
```

## Current Status

REST API complete with LiveView dashboard, observability stack (Telemetry, PromEx, OpenTelemetry, Sentry, Grafana), and production-quality error handling.
