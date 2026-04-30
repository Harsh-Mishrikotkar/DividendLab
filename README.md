# DividendLab - Portfolio Simulation & Financial Modeling Engine

## Overview

DividendLab is a **local-first financial simulation platform** designed to model long-term portfolio growth and dividend income under realistic market conditions.

The system combines:

* A **Portfolio Model** for tracking assets, dividends, and reinvestment
* An **Economic Simulation Engine** for modeling uncertainty using probabilistic methods

Unlike basic financial calculators, DividendLab focuses on **stochastic modeling**, allowing users to evaluate **risk, variability, and probability of outcomes** rather than relying on single deterministic projections.

---

## Key Features

### Portfolio Modeling

* Multi-asset portfolio support
* Dividend income calculation
* Dividend reinvestment (DRIP) logic
* Portfolio value tracking over time

### Economic Simulation Engine

* Stochastic return generation
* Dividend growth modeling
* Inflation-adjusted results
* Monte Carlo simulation framework *(in progress)*

### Output & Analysis

* Portfolio value over time
* Dividend income growth
* Distribution of outcomes (Monte Carlo)
* Probability-based insights *(planned)*

### Local-First Design

* All user data stored locally using SQLite
* No cloud storage or external account required

---

## Tech Stack

### Backend

* Python
* FastAPI *(planned)*
* NumPy / Pandas

### Frontend

* React *(planned)*
* Streamlit *(for rapid prototyping)*

### Database

* SQLite

### Data Sources

* yfinance *(planned)*

### Tooling

* Git / GitHub

---

## Project Structure

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

## Core Modeling Concepts

This project implements concepts from financial theory and quantitative modeling, including:

* Portfolio return and variance
* Dividend growth and sustainability
* Total return decomposition
* Inflation-adjusted returns
* Monte Carlo simulation
* Correlation and covariance (planned)

---

## Example Use Case

Simulate a portfolio to answer:

> “What is the probability of reaching a target level of dividend income over a 30-year horizon?”

Instead of a single projection, the system generates:

* Median outcome
* Downside scenarios
* Upside scenarios
* Probability of success

---

## Current Status

### Completed

* [x] Initial research regarding dividends and reinvestment

### In Progress

* [ ] Core portfolio model
* [ ] Dividend reinvestment logic
* [ ] Deterministic simulation engine

### Planned

* [ ] Monte Carlo simulation engine
* [ ] Inflation modeling
* [ ] Real asset integration
* [ ] Correlated multi-asset simulation
* [ ] Efficient Frontier optimization
* [ ] React-based frontend
* [ ] Portfolio tracking system
* [ ] Advanced visualization dashboard

---

## Design Principles

* **Separation of concerns**
  Portfolio logic is independent from simulation logic

* **Deterministic vs stochastic modeling**
  Core portfolio mechanics are deterministic
  Market behavior is probabilistic

* **Local-first architecture**
  All financial data remains on the user’s machine

* **Transparency of assumptions**
  Model assumptions are explicit and configurable

---

## Installation (Planned)

```bash
git clone https://github.com/yourusername/dividendlab.git
cd dividendlab
pip install -r requirements.txt
```

---

## Future Enhancements

* Multi-asset correlation modeling
* Dividend cut probability modeling
* Historical scenario backtesting
* Portfolio optimization (Efficient Frontier)
* Retirement income simulation

---

## Motivation

Most online dividend calculators rely on **constant growth assumptions** and produce overly optimistic projections.

DividendLab aims to provide a more realistic framework by incorporating:

* Market volatility
* Uncertainty in returns
* Variability in dividend growth

---

## Disclaimer

This project is for educational and analytical purposes only.
It is not intended to provide financial advice.

---

## Author

Harsh Mishrikotkar

* BS in Statistics (Expected)
* CFA Level 1 Candidate
