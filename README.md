# DividendLab - Probabilistic Portfolio & Macro-Regime Simulation Framework

## Overview

DividendLab is a **local-first probabilistic financial modeling framework** designed to simulate long-term portfolio behavior under changing macroeconomic and market conditions.

The project focuses on:

* Modeling portfolio growth and dividend sustainability under uncertainty
* Simulating market behavior across different economic regimes
* Incorporating macroeconomic indicators into probabilistic simulations
* Retrieving historically similar market environments for contextual analysis
* Explicitly documenting assumptions, limitations, and modeling methodology

Unlike traditional portfolio calculators that rely on fixed growth assumptions, DividendLab treats markets as:

* stochastic
* regime-dependent
* non-stationary
* subject to structural breaks and tail risk

The goal is **not** to predict markets with certainty.

The goal is to build a transparent framework for:

* probabilistic scenario analysis
* historical analog comparison
* macro-aware portfolio simulation
* dividend sustainability analysis

---

# Project Philosophy

DividendLab is built around several core principles:

## 1. Probabilistic Modeling Over Deterministic Forecasting

Financial markets are uncertain.

Single-point forecasts are often misleading because they ignore:

* volatility
* regime shifts
* tail events
* changing correlations
* liquidity crises

DividendLab focuses on:

* probability distributions
* downside risk
* scenario analysis
* uncertainty modeling

rather than attempting to produce a single “correct” forecast.

---

## 2. Explicit Assumptions

All models contain assumptions.

One of the primary goals of the project is to make assumptions:

* transparent
* configurable
* documented
* testable

This includes assumptions related to:

* return generation
* inflation behavior
* dividend growth
* volatility
* macroeconomic relationships
* market regimes
* correlation structures

---

## 3. Regime-Aware Financial Modeling

Markets do not behave identically across time.

DividendLab aims to model different market environments such as:

* economic expansion
* recession
* inflationary tightening
* liquidity crises
* speculative bubbles
* deleveraging periods

Simulation parameters may dynamically adjust based on identified macroeconomic conditions.

---

## 4. Historical Context Without Deterministic Historical Repetition

Historical periods can provide useful context.

However:

* historical similarity does not guarantee future equivalence
* macroeconomic structures evolve
* markets are non-stationary
* structural breaks occur

Historical analog retrieval is therefore treated as:

* contextual information
* probabilistic guidance
* scenario comparison

—not deterministic prediction.

---

## 5. Local-First Architecture

The project is designed to operate locally whenever possible.

This allows:

* data ownership
* transparency
* reproducibility
* offline experimentation
* reduced reliance on external services

---

# Core System Architecture

```text
Macroeconomic Indicators
        ↓
Regime Classification Engine
        ↓
Historical Analog Retrieval
        ↓
Monte Carlo Simulation Engine
        ↓
Portfolio Outcome Distributions
        ↓
LLM Explanation & Reporting Layer
```

The language model is intended to function primarily as:

* an interpretation layer
* a reporting interface
* a contextual reasoning system

—not as the primary statistical forecasting engine.

---

# Core Components

## Portfolio Modeling Engine

Handles deterministic portfolio mechanics including:

* asset allocation
* dividend income
* dividend reinvestment (DRIP)
* contribution schedules
* rebalancing
* portfolio tracking
* cash flow modeling

---

## Macro-Regime Classification Engine

Classifies current or simulated economic conditions into probabilistic market regimes.

Potential inputs include:

* CPI / inflation
* unemployment
* yield curve slope
* credit spreads
* VIX
* GDP growth
* PMI
* interest rates
* money supply growth
* debt metrics

Potential methodologies:

* Hidden Markov Models (HMMs)
* Bayesian regime-switching models
* clustering algorithms
* factor models
* probabilistic state-space methods

---

## Historical Analog Retrieval System

Identifies historically similar macroeconomic and market environments.

The system may compare:

* inflation conditions
* interest rate environments
* valuation levels
* volatility regimes
* credit stress
* economic growth conditions

Potential similarity methods:

* cosine similarity
* Euclidean distance
* Mahalanobis distance
* embedding/vector search

Historical analogs are intended for:

* contextual understanding
* stress testing
* scenario comparison

—not deterministic forecasting.

---

## Monte Carlo Simulation Engine

The simulation engine models probabilistic future portfolio outcomes.

Planned modeling features include:

* stochastic return generation
* volatility clustering
* regime-dependent return distributions
* inflation-adjusted simulations
* dynamic correlation structures
* fat-tail modeling
* dividend growth variability
* dividend cut probability modeling
* jump-risk events

The framework aims to move beyond simplistic assumptions such as:

* constant returns
* static volatility
* normally distributed outcomes
* stationary market conditions

---

## LLM Interpretation Layer

A local LLM layer (via Ollama or similar tooling) may be used for:

* simulation interpretation
* report generation
* historical context summarization
* natural language explanations
* research assistance

The LLM layer is not intended to directly generate market predictions.

---

# Research-Driven Development Approach

DividendLab is being designed as a research-first project.

Before implementation, the project aims to formally document:

* economic assumptions
* statistical assumptions
* equations and methodologies
* regime definitions
* simulation logic
* model limitations
* validation strategies
* overfitting risks
* non-stationarity concerns

The purpose of this process is to:

* reduce hidden assumptions
* improve transparency
* avoid invalid relationships
* prevent methodology drift
* create reproducible modeling logic

---

# Research Topics & Modeling Areas

The project may incorporate concepts from:

* portfolio theory
* stochastic processes
* econometrics
* Bayesian statistics
* time-series analysis
* regime-switching models
* volatility modeling
* macroeconomic analysis
* dividend sustainability analysis
* probabilistic simulation
* factor modeling

Potential techniques under evaluation include:

* Monte Carlo simulation
* geometric Brownian motion
* jump-diffusion processes
* Hidden Markov Models
* Kalman filtering
* covariance estimation
* volatility clustering models
* dynamic factor models

---

# Project Structure

```text
Dividendlab/
│
├── backend/
│   │
│   ├── api/                         # API layer
│   ├── portfolio/                  # Portfolio mechanics
│   ├── simulation/                 # Monte Carlo & stochastic models
│   ├── macro/                      # Macro regime logic
│   ├── analogs/                    # Historical similarity engine
│   ├── llm/                        # LLM interfaces & prompts
│   ├── data/                       # Data ingestion & storage
│   ├── utils/                      # Shared utilities
│   └── config.py
│
├── frontend/
│   ├── react-app/                  # Planned frontend
│
├── research/
│   ├── assumptions/
│   ├── methodology/
│   ├── simulations/
│   ├── validation/
│   ├── limitations/
│   ├── references/
│   └── future_research/
│
├── notebooks/                      # Experimental modeling notebooks
│
├── tests/
│   ├── statistical/
│   ├── simulation/
│   ├── portfolio/
│   └── validation/
│
├── database/
│
├── README.md
├── RESEARCH.md
└── requirements.txt
```

---

# Tech Stack

## Backend

* Python
* NumPy
* Pandas
* SciPy
* statsmodels
* scikit-learn
* PyMC *(possible)*
* FastAPI *(planned)*

---

## Frontend

* React *(planned)*
* Streamlit *(for prototyping)*

---

## Data Storage

* SQLite
* Parquet *(possible)*

---

## Data Sources

Potential sources include:

* yfinance
* FRED
* SEC filings
* macroeconomic datasets

---

## AI / Retrieval Tooling

Potential tooling includes:

* Ollama
* FAISS
* ChromaDB
* vector embeddings

---

# Example Use Cases

## Dividend Sustainability Analysis

> “What is the probability that my portfolio maintains dividend growth during prolonged inflationary periods?”

---

## Regime-Based Portfolio Stress Testing

> “How does this portfolio historically behave during tightening cycles or liquidity crises?”

---

## Historical Analog Comparison

> “Which historical macroeconomic environments most closely resemble current conditions?”

---

## Long-Term Retirement Simulation

> “What is the probability of sustaining inflation-adjusted income over a 30-year retirement horizon?”

---

# Current Development Priorities

## Current Focus

* [ ] Research methodology documentation
* [ ] Assumption formalization
* [ ] Statistical framework design
* [ ] Regime-model research
* [ ] Monte Carlo architecture planning
* [ ] Historical analog framework research
* [ ] Validation methodology planning

---

## Near-Term Development Goals

* [ ] Core portfolio engine
* [ ] Deterministic simulation layer
* [ ] Regime-aware Monte Carlo framework
* [ ] Inflation-adjusted modeling
* [ ] Dynamic volatility modeling
* [ ] Historical data ingestion pipeline
* [ ] Initial frontend prototype

---

## Long-Term Goals

* [ ] Regime-switching models
* [ ] Dynamic covariance modeling
* [ ] Historical analog retrieval system
* [ ] Portfolio optimization tools
* [ ] Scenario-based stress testing
* [ ] Advanced reporting dashboards
* [ ] LLM-assisted explanation layer
* [ ] Multi-asset macro simulation

---

# Design Principles

## Separation of Concerns

Portfolio mechanics, macro modeling, simulation logic, and LLM interpretation remain modular and independently testable.

---

## Statistical Transparency

Model assumptions and limitations should be explicit and reviewable.

---

## Research Over Hype

The project prioritizes:

* methodological rigor
* probabilistic reasoning
* transparency
* reproducibility

over unsupported “AI prediction” claims.

---

## Local-First Infrastructure

Financial data and experimentation should remain under user control whenever practical.

---

# Known Challenges

Several major modeling challenges are explicitly acknowledged:

* non-stationary markets
* structural economic shifts
* limited historical samples
* survivorship bias
* look-ahead bias
* overfitting
* changing macroeconomic relationships
* uncertainty in future policy responses

These challenges are considered core research problems within the project.

---

# Disclaimer

DividendLab is an educational and analytical research project.

The framework is intended for:

* experimentation
* probabilistic analysis
* portfolio research
* financial modeling education

It is not intended to provide financial advice or guaranteed forecasts.

---

# Author

Harsh Mishrikotkar

* BS in Statistics (Expected)
* CFA Level 1 Candidate