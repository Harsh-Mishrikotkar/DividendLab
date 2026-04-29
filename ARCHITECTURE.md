## Project Architecture & File Linkage

### Full Project Tree

```
dividendlab/

├── backend/
│   │
│   ├── main.py                    # Entry point for FastAPI app
│   │
│   ├── api/                       # API layer (interface to frontend)
│   │   ├── routes.py              # Main route aggregator
│   │   ├── portfolio_routes.py    # Portfolio endpoints
│   │   ├── simulation_routes.py   # Simulation endpoints
│   │
│   ├── portfolio/                 # Deterministic portfolio logic
│   │   ├── dividend_model.py      # Dividend calculations
│   │   ├── dividend_growth.py     # Growth assumptions
│   │   ├── rebalancing.py         # Portfolio weight updates
│   │   ├── valuation.py           # Portfolio value computation
│   │
│   ├── simulation/                # Stochastic modeling engine
│   │   ├── return_model.py        # Generate market returns
│   │   ├── risk_model.py          # Volatility handling
│   │   ├── covariance_model.py    # Correlation (future)
│   │   ├── inflation_model.py     # Inflation simulation
│   │   ├── monte_carlo.py         # Simulation loop
│   │   ├── simulation_runner.py   # Orchestrates full simulation
│   │
│   ├── data/                      # Data access layer
│   │   ├── database.py            # SQLite interface
│   │   ├── market_data.py         # External data (yfinance)
│   │   ├── schemas.py             # Data models (optional)
│   │
│   ├── utils/                     # Shared helpers
│   │   ├── math_utils.py
│   │   ├── validation.py
│   │
│   └── config.py                  # Global settings
│
├── frontend/
│   ├── react-app/                 # React UI (planned)
│   │   ├── components/
│   │   ├── pages/
│   │   ├── services/              # API calls
│
├── database/
│   ├── schema.sql
│   ├── seed_data.sql (optional)
│
├── notebooks/                     # Testing / experimentation
│   ├── simulation_tests.ipynb
│
├── tests/                         # Unit tests
│   ├── test_portfolio.py
│   ├── test_simulation.py
│
├── requirements.txt
├── README.md
└── .gitignore
```

---

## Data Flow

### 1. User Input → API

```
React / Streamlit UI
        ↓
FastAPI endpoint (/simulation/run)
```

---

### 2. API → Simulation Runner

```
simulation_routes.py
        ↓
simulation_runner.py
```

This is your **central orchestrator**.

---

### 3. Simulation Runner → Models

The runner pulls in all components:

```
simulation_runner.py
    ├── return_model.py
    ├── inflation_model.py
    ├── monte_carlo.py
    └── portfolio/ (deterministic logic)
```

---

### 4. Portfolio Model Integration

Inside each simulation step:

```
dividend_model.py
        ↓
dividend_growth.py
        ↓
valuation.py
        ↓
rebalancing.py
```

This is your **deterministic engine**.

---

### 5. Data Layer Interaction

When real assets are used:

```
market_data.py → fetch prices/dividends
database.py → store/retrieve portfolios
```

---

## Core Simulation Flow (End-to-End)

```
1. Load portfolio (database.py)
2. Fetch market assumptions (market_data.py or inputs)
3. Initialize simulation parameters
4. FOR each simulation:
       FOR each time step:
           → generate return (return_model.py)
           → update price
           → grow dividend (dividend_growth.py)
           → calculate dividend (dividend_model.py)
           → apply inflation (inflation_model.py)
           → reinvest (portfolio logic)
5. Aggregate results (monte_carlo.py)
6. Return results → API → Frontend
```

---

## Separation of Responsibilities

### Portfolio Layer (Deterministic)

```
Input: prices, dividends
Output: portfolio value, income
```

Files:

```
portfolio/*
```

---

### Simulation Layer (Stochastic)

```
Input: distributions, assumptions
Output: simulated market paths
```

Files:

```
simulation/*
```

---

### Data Layer

```
Input/Output: persistent storage + market data
```

Files:

```
data/*
```

---

### API Layer

```
Input: user requests
Output: JSON responses
```

Files:

```
api/*
```

---

## Critical Design Rules

### 1. Simulation NEVER touches database directly

Bad:

```
monte_carlo.py → database.py
```

Correct:

```
API → database → simulation
```

---

### 2. Portfolio logic must be reusable

You should be able to run:

```
simulation_runner.py
```

without:

* API
* database
* frontend

---

### 3. Keep stochastic and deterministic separate

```
portfolio/  → deterministic
simulation/ → stochastic
```

Mixing these = bugs.

---

## Minimal Execution Path

To get something running quickly, you only need:

```
simulation_runner.py
return_model.py
dividend_model.py
monte_carlo.py
```
