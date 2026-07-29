# V1 Developer Specification

## Purpose

This document serves as the technical implementation guide for Version 1 (V1) of the project.

Unlike the implementation roadmap, which tracks overall progress, this document defines the responsibilities, dependencies, interfaces, and implementation order of every remaining component required to complete V1.

Its goals are to:

- Define the responsibility of every file.
- Prevent architectural drift.
- Keep business logic separate from data access.
- Provide a consistent blueprint for future development.
- Serve as context for AI-assisted code generation.

---

# V1 Scope

Version 1 is a deterministic portfolio management application.

It will allow users to:

- Create and manage portfolios
- Record transactions
- Track holdings
- Record dividend payments
- Calculate portfolio metrics
- Produce deterministic future projections
- View everything through a Streamlit interface

No probabilistic modeling or Monte Carlo simulations are included in V1.

---

# Architectural Overview

```text
                 Streamlit Frontend
                        │
                        ▼
               Portfolio Service Layer
                        │
                        ▼
                 Repository Layer
                        │
                        ▼
               Database Infrastructure
                        │
                        ▼
                    SQLite Database
```

Each layer has a single responsibility and may only communicate with the layer directly beneath it.

---

# Dependency Rules

## Allowed Dependencies

```text
Frontend
    ↓
Services
    ↓
Repositories
    ↓
Database Manager
    ↓
SQLite
```

---

## Forbidden Dependencies

The following dependencies are not permitted.

```text
Frontend → Database

Frontend → SQL

Repository → UI

Repository → Repository

Database → Business Logic

Database → UI

Services → SQL
```

Repositories own all SQL.

Services own all business logic.

The frontend never accesses the database directly.

---

# Project Structure

```text
backend/

│
├── data/
│
│   ├── database.py
│   ├── database_initializer.py
│
│   └── repositories/
│       ├── app_settings_repository.py
│       ├── portfolio_repository.py
│       ├── holdings_repository.py
│       ├── transaction_repository.py
│       ├── dividend_repository.py
│       └── contribution_repository.py
│
├── portfolio/
│
│   ├── portfolio_service.py
│   ├── transaction_service.py
│   ├── holdings_service.py
│   ├── dividend_service.py
│   ├── contribution_service.py
│   ├── projection_service.py
│   ├── metrics.py
│   └── validation.py
│
└── frontend/
    └── streamlit/
```

---

# Database Infrastructure

## database.py

### Purpose

Provides the core database infrastructure.

### Responsibilities

- Open SQLite connections
- Manage transactions
- Manage savepoints
- Execute SQL safely
- Connection lifecycle management

### Called By

- All repositories

### Depends On

- sqlite3

---

## database_initializer.py

### Purpose

Creates and initializes the database.

### Responsibilities

- Create database
- Execute schema files
- Verify initialization
- Run startup tasks

### Called By

- Application startup

### Depends On

- database.py
- SQL schema files

---

# Repository Layer

Repositories are responsible only for interacting with the database.

They contain SQL and nothing else.

Business rules must never exist inside repositories.

---

## PortfolioRepository

### Purpose

Owns all portfolio-related SQL.

### Functions

- create_portfolio()
- update_portfolio()
- delete_portfolio()
- get_portfolio()
- list_portfolios()

### Called By

- PortfolioService

### Depends On

- database.py

---

## HoldingsRepository

### Purpose

Manages portfolio holdings.

### Functions

- add_holding()
- update_holding()
- delete_holding()
- get_holdings()
- get_holding()

### Called By

- HoldingsService
- TransactionService

### Depends On

- database.py

---

## TransactionRepository

### Purpose

Stores and retrieves transactions.

### Functions

- add_transaction()
- edit_transaction()
- delete_transaction()
- get_transaction()
- list_transactions()

### Called By

- TransactionService

### Depends On

- database.py

---

## DividendRepository

### Purpose

Stores dividend history.

### Functions

- record_dividend()
- update_dividend()
- delete_dividend()
- list_dividends()

### Called By

- DividendService

### Depends On

- database.py

---

## ContributionRepository

### Purpose

Stores recurring contribution schedules.

### Functions

- create_schedule()
- update_schedule()
- delete_schedule()
- get_schedule()

### Called By

- ContributionService

### Depends On

- database.py

---

# Business Logic Layer

Business logic coordinates repositories.

Business logic never executes SQL directly.

---

## PortfolioService

### Purpose

Coordinates all portfolio operations.

### Responsibilities

- Create portfolios
- Delete portfolios
- Rename portfolios
- Generate portfolio summaries
- Coordinate other services

### Uses

- PortfolioRepository
- Metrics
- Validation

### Called By

- Streamlit UI

---

## HoldingsService

### Purpose

Manages holdings.

### Responsibilities

- Calculate allocations
- Update holdings
- Retrieve holdings
- Calculate cost basis

### Uses

- HoldingsRepository
- Metrics

### Called By

- PortfolioService
- TransactionService

---

## TransactionService

### Purpose

Processes portfolio transactions.

### Responsibilities

- Buy shares
- Sell shares
- Validate trades
- Update holdings

### Uses

- TransactionRepository
- HoldingsRepository
- Validation

### Called By

- Streamlit UI

---

## DividendService

### Purpose

Processes dividends.

### Responsibilities

- Record dividends
- Calculate dividend income
- Handle DRIP
- Update holdings

### Uses

- DividendRepository
- HoldingsRepository
- Metrics

### Called By

- Streamlit UI

---

## ContributionService

### Purpose

Handles recurring investments.

### Responsibilities

- Monthly contributions
- Contribution schedules
- Cash balance updates

### Uses

- ContributionRepository

### Called By

- ProjectionService

---

## ProjectionService

### Purpose

Produces deterministic future projections.

### Responsibilities

- Portfolio growth
- Dividend projections
- Inflation adjustment
- Future portfolio values

### Uses

- PortfolioRepository
- Metrics
- ContributionService

### Called By

- Projection Page

---

## Metrics

### Purpose

Pure financial calculations.

### Contains No

- SQL
- Database access
- UI code

### Functions

- calculate_market_value()
- calculate_cost_basis()
- calculate_total_return()
- calculate_dividend_yield()
- calculate_allocation()
- calculate_unrealized_gain()
- calculate_realized_gain()

### Called By

- PortfolioService
- HoldingsService
- ProjectionService

---

## Validation

### Purpose

Provides reusable validation functions.

### Functions

- validate_shares()
- validate_price()
- validate_date()
- validate_portfolio()
- validate_ticker()

### Called By

- All services

---

# Frontend

The frontend communicates only with the service layer.

It never communicates with repositories or the database.

---

## Dashboard

Displays

- Portfolio summary
- Portfolio value
- Dividend income
- Asset allocation

---

## Portfolio Page

Uses

- PortfolioService

---

## Transactions Page

Uses

- TransactionService

---

## Dividends Page

Uses

- DividendService

---

## Projection Page

Uses

- ProjectionService

---

## Settings Page

Uses

- AppSettingsRepository

---

# Common Workflows

## Buying Shares

```text
Transaction Page

        │

        ▼

TransactionService

        │

        ▼

Validation

        │

        ▼

TransactionRepository

        │

        ▼

HoldingsRepository

        │

        ▼

Metrics

        │

        ▼

Updated Portfolio
```

---

## Future Projection

```text
Projection Page

        │

        ▼

ProjectionService

        │

        ▼

PortfolioRepository

        │

        ▼

ContributionService

        │

        ▼

Metrics

        │

        ▼

Projection Results
```

---

# Remaining Implementation Order

## Phase 1

Repository Layer

- PortfolioRepository
- HoldingsRepository
- TransactionRepository
- DividendRepository
- ContributionRepository

---

## Phase 2

Business Logic

- Validation
- Metrics
- PortfolioService
- HoldingsService
- TransactionService
- DividendService
- ContributionService

---

## Phase 3

Projection Engine

- ProjectionService

---

## Phase 4

Frontend

- Dashboard
- Portfolio Page
- Transaction Page
- Dividend Page
- Projection Page
- Settings Page

---

# Completion Checklist

## Repository Layer

- [ ] PortfolioRepository
- [ ] HoldingsRepository
- [ ] TransactionRepository
- [ ] DividendRepository
- [ ] ContributionRepository

---

## Business Logic

- [ ] Validation
- [ ] Metrics
- [ ] PortfolioService
- [ ] HoldingsService
- [ ] TransactionService
- [ ] DividendService
- [ ] ContributionService

---

## Projection

- [ ] ProjectionService

---

## Frontend

- [ ] Dashboard
- [ ] Portfolio Page
- [ ] Transaction Page
- [ ] Dividend Page
- [ ] Projection Page
- [ ] Settings Page

---

# Design Principles

The V1 architecture follows the following principles:

- Single Responsibility Principle
- Separation of Concerns
- Repository Pattern
- Service Layer Pattern
- Encapsulation
- Maintainability
- Testability
- Scalability

These principles provide a clean foundation for Version 2, where probabilistic simulations and Monte Carlo modeling will be added without requiring major changes to the portfolio management system.