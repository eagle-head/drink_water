# Migration Roadmap: Java Spring Boot → Phoenix

Migrating [drink-water-api](https://github.com/eduardodsaraujo/drink-water-api) from Java/Spring Boot to Elixir/Phoenix.

Strategy: incremental, small steps, testing everything along the way. No OAuth2 initially. Learning Phoenix and Elixir in the process.

## Source Project (Java)

- **Framework:** Spring Boot 3.5.11, Java 25
- **Database:** PostgreSQL 16 (Flyway migrations)
- **Auth:** Keycloak OAuth2 Resource Server (fine-grained scopes)
- **Observability:** Prometheus, Grafana, Loki
- **Resilience:** Resilience4j (circuit breaker, retry, rate limiter)
- **Caching:** Caffeine (publicId → userId)

## Target Project (Phoenix)

- **Framework:** Phoenix 1.8.5, Elixir 1.15+
- **Database:** PostgreSQL 17 (Ecto migrations)
- **Frontend:** LiveView + Tailwind + daisyUI
- **Transport:** REST (external clients) + Channels/WebSocket (real-time)

## Domain Entities

### User (migrated)

| Field          | Java Type            | Elixir Type  | Notes                                |
| -------------- | -------------------- | ------------ | ------------------------------------ |
| id             | Long                 | :id (bigint) | Auto-generated                       |
| public_id      | UUID                 | -            | Deferred (Keycloak)                  |
| email          | String (255, unique) | :string      | Unique constraint, format validation |
| first_name     | String (2-50)        | :string      | Length 2-50                          |
| last_name      | String (2-50)        | :string      | Length 2-50                          |
| birth_date     | LocalDate            | :date        | Age validation (13-99)               |
| biological_sex | int (enum)           | Ecto.Enum    | :male, :female                       |
| weight         | BigDecimal (45-500)  | :decimal     | Range 45-500                         |
| weight_unit    | int (enum)           | Ecto.Enum    | :kg                                  |
| height         | BigDecimal (50-250)  | :decimal     | Range 50-250                         |
| height_unit    | int (enum)           | Ecto.Enum    | :cm                                  |

### AlarmSettings (migrated)

| Field            | Java Type               | Elixir Type      | Notes                                   |
| ---------------- | ----------------------- | ---------------- | --------------------------------------- |
| id               | Long                    | :id              | Auto-generated                          |
| goal             | int (50-10000)          | :integer         | Range 50-10000 ml                       |
| interval_minutes | int (15-240)            | :integer         | Range 15-240 min                        |
| daily_start_time | LocalTime (06:00-22:00) | :time            | Must be within 06:00-22:00              |
| daily_end_time   | LocalTime (06:00-22:00) | :time            | Must be within 06:00-22:00, after start |
| user_id          | Long FK                 | belongs_to :user | CASCADE delete, unique (one-to-one)     |

### WaterIntake (migrated)

| Field         | Java Type    | Elixir Type   | Notes                                              |
| ------------- | ------------ | ------------- | -------------------------------------------------- |
| id            | Long         | :id           | Auto-generated                                     |
| date_time_utc | Instant      | :utc_datetime | Must not be in the future                          |
| volume        | int (1-5000) | :integer      | Range 1-5000                                       |
| volume_unit   | int (enum)   | Ecto.Enum     | :ml                                                |
| user_id       | Long FK      | field :id     | Cross-context ref (not belongs_to), CASCADE delete |
|               |              |               | Unique: (user_id, date_time_utc)                   |

## Enums

| Enum          | Values       | Code |
| ------------- | ------------ | ---- |
| BiologicalSex | MALE, FEMALE | 1, 2 |
| WeightUnit    | KG           | 1    |
| HeightUnit    | CM           | 1    |
| VolumeUnit    | ML           | 1    |

## Migration Steps

### Phase 1: Foundation (done)

- [x] Phoenix project setup with LiveView
- [x] PostgreSQL + Docker Compose
- [x] Environment config (.env.example, .gitignore)
- [x] User schema and CRUD (generated)
- [x] Step 1: User validations + Ecto.Enum (email unique, field ranges, birth_date 13-99, BiologicalSex/WeightUnit/HeightUnit as Ecto.Enum)

### Phase 2: Core Domain (done)

- [x] Step 2: AlarmSettings (schema, context, belongs_to User, nested singleton resource, cascade delete)
- [x] Step 3: WaterIntake + VolumeUnit Ecto.Enum (HydrationTracking context, cross-context user_id, CRUD endpoints, cascade delete)
- [x] Step 4: WaterIntake search with cursor-based pagination (embedded_schema filter, keyset pagination, date/volume filters)

### Phase 3: Production Quality (done)

- [x] Step 5: Standardized error handling (RFC 7807 Problem Details, application/problem+json content-type)
- [x] Step 6: Rate limiting (Hammer v7 ETS, per-user per-endpoint-group, 429 RFC 7807 + Retry-After)
- [x] Step 7: Input sanitization and security hardening (null byte removal, whitespace trimming, cursor length limit)
- [x] Step 7a: Name format validation (Unicode letters, accents, apostrophes, hyphens, spaces only)
- [x] Step 7b: Separate search rate limit (20/min for search vs 60/min for CRUD)
- [x] Step 7c: Configurable sort field/direction in water intake search (keyset pagination sort-aware)
- [x] Step 7d: Idempotent user delete (204 for nonexistent users)

### Phase 4: Phoenix Ecosystem (next)

- [ ] Step 8: LiveView dashboard with PubSub (real-time hydration tracking)
  - [ ] 8a: Base structure (DashboardLive, route, layout, PubSub subscribe)
  - [ ] 8b: Daily progress (ProgressComponent, SVG ring)
  - [ ] 8c: Today's history (HistoryComponent, delete with broadcast)
  - [ ] 8d: Log water (IntakeFormComponent, broadcast, real-time updates)
  - [ ] 8e: Weekly summary (WeeklySummaryComponent, CSS bars)
  - [ ] 8f: Next alarm (NextAlarmComponent)
  - [ ] 8g: Edit alarm settings (AlarmSettingsComponent, modal, broadcast)
- [ ] Step 9: Background jobs with Oban (hydration reminders)

### Phase 5: Auth (when ready)

- [ ] Step 10: Keycloak/OAuth2 integration
- [ ] Step 11: public_id field on User
- [ ] Step 12: Scope-based authorization

## Architecture Decisions

- **REST for external clients** (mobile app, third-party integrations)
- **LiveView for web UI** (admin dashboard, hydration tracking)
- **Channels/WebSocket for real-time** (notifications with app open)
- **Push notifications** (APNs/FCM via Pigeon, for app closed)
- **Contexts as bounded contexts** (UserManagement, HydrationTracking)
- **No premature optimization** — this project is for learning, not going to prod this year
