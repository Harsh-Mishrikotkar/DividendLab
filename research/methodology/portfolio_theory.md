# Portfolio Theory for DividendLab Portfolio Engine (V1)

---

## 1. Purpose

This document defines the portfolio theory used by DividendLab’s Portfolio Engine in V1.  
It specifies how we model risk, return, diversification, and cash flows (dividends, contributions, withdrawals) for dividend-focused portfolios.  
The goal is to give developers an unambiguous blueprint for how the engine should construct, rebalance, and evaluate portfolios under uncertainty.  
This theory is the conceptual foundation for the Monte Carlo engine, validation framework, and stress-testing framework.

---

## 2. Executive Summary

Portfolio theory provides a structured way to balance risk and return across multiple assets, instead of treating each holding in isolation.  
DividendLab adapts standard portfolio theory (expected return, volatility, correlations, diversification) to a dividend-centric use case where recurring income and income growth are as important as terminal wealth.

High level:

- We model each asset with total return, dividend yield, and dividend growth.
- We model portfolios as weighted combinations of assets, with risk captured primarily via covariance of returns.
- We evaluate portfolios using both total-return metrics (expected return, volatility, Sharpe, drawdown) and income metrics (current yield, projected income growth, income volatility).
- V1 uses relatively simple, transparent models (mean-variance-style logic plus conservative heuristics) rather than exotic optimization; complexity is deferred to later versions.
- The Portfolio Engine uses this framework to:
  - Evaluate current portfolio risk/return and income characteristics.
  - Simulate future outcomes (via Monte Carlo).
  - Provide guidance on rebalancing, contributions, and withdrawals in line with a user’s risk/income goals.

---

## 3. Definitions

Core terms (used consistently across the engine):

- **Asset / Security**  
  A tradable instrument (stock, ETF, fund) with a price, total return, and dividend stream.

- **Total Return**  
  The combination of price change and reinvested dividends over a period.  
  For period \( t \): \( R_{t} = \frac{P_{t} - P_{t-1} + D_{t}}{P_{t-1}} \).

- **Dividend Yield**  
  Annualized dividends per share divided by current price.

- **Dividend Growth Rate**  
  The rate at which dividends per share grow over time; can be historical (realized) or assumed (forward).

- **Expected Return**  
  The model’s estimate of average total return per period for an asset or portfolio.

- **Volatility**  
  The standard deviation of returns over a given horizon.

- **Correlation / Covariance**  
  Measures of how assets move together; covariance matrix is the core object in mean-variance-style reasoning.

- **Portfolio Weights**  
  Fractions of total portfolio value allocated to each asset (sum to 1, long-only in V1).

- **Risk**  
  In V1, primarily modeled as volatility and drawdown risk of total return, with additional focus on income volatility and risk of dividend cuts.

- **Diversification**  
  Reduction of portfolio risk via imperfect correlations among assets.

- **Rebalancing**  
  Trading actions that move actual weights back toward target weights according to a defined rule (calendar-based, threshold-based, or hybrid).

- **Contribution Schedule**  
  Planned cash inflows to the portfolio (e.g., monthly deposits).

- **Withdrawal Schedule**  
  Planned cash outflows from the portfolio (e.g., retirement spending).

- **Income Objective**  
  User’s target level and growth path of portfolio income (dividends, plus optional systematic withdrawals).

- **Risk Tolerance**  
  User’s willingness to accept volatility and drawdown; modeled as constraints/targets on volatility, drawdown probabilities, and income stability.

---

## 4. Core Concepts

### 4.1 Risk–Return Trade-off

- Every asset has an expected return and an uncertainty around that return.
- Higher expected returns typically come with higher volatility and larger drawdowns.
- For DividendLab, the trade-off is not just “more return vs more volatility” but also “higher income vs higher risk of income decline.”

### 4.2 Diversification and Correlation

- Combining imperfectly correlated assets can reduce portfolio volatility for a given level of expected return.
- For income investors, diversification also spreads dividend risk (e.g., a few cuts will not collapse total income if the portfolio is diversified across sectors, geographies, and payout policies).
- The covariance matrix of asset returns is the quantitative representation of diversification.

### 4.3 Capital Allocation and Constraints

- Portfolio weights must respect constraints:
  - Long-only (no shorting) in V1.
  - Position size limits (e.g., max 10% or 20% per name).
  - Sector/industry caps (optional in V1, more formal in later versions).
- Practical constraints (like minimum trade size, transaction costs, tax considerations) are modeled in a simplified way in V1 and refined later.

### 4.4 Income-Focused Portfolio Objectives

- Traditional portfolio theory focuses on total return; DividendLab adds explicit objectives for:
  - Current income level.
  - Expected income growth rate.
  - Income volatility and probability of income drops beyond certain thresholds.
- These objectives guide portfolio evaluation and suggested rebalancing actions.

### 4.5 Time Horizon and Path Dependence

- Investor horizon (e.g., 5, 10, 30 years) affects:
  - Tolerance for short-term volatility.
  - Importance of sequence-of-returns risk (especially during withdrawal).
- For accumulation phases, emphasis is on long-term growth and income growth.  
  For decumulation phases, emphasis is on limiting drawdowns and income cuts.

### 4.6 Rebalancing Policies

- Rebalancing logic translates portfolio theory into actual trades:
  - Calendar-based (e.g., annual or quarterly).
  - Threshold-based (trade only when deviations exceed a band).
  - Hybrid (check frequently, trade only if deviation is material).
- V1 will support simple, transparent rules, with more sophisticated policies reserved for later versions.

---

## 5. Mathematical Foundation

### 5.1 Asset-Level Returns

- Periodic total return for asset \( i \) at time \( t \):  
  $$
  R_{i,t} = \frac{P_{i,t} - P_{i,t-1} + D_{i,t}}{P_{i,t-1}}
  $$
- Expected return (per period):  
  $$
  \mu_i = E[R_{i}]
  $$
- Volatility (standard deviation of returns):  
  $$
  \sigma_i = \sqrt{\operatorname{Var}(R_{i})}
  $$

### 5.2 Covariance and Correlation

- Covariance between assets \( i \) and \( j \):  
  $$
  \sigma_{ij} = \operatorname{Cov}(R_i, R_j)
  $$
- Correlation:  
  $$
  \rho_{ij} = \frac{\sigma_{ij}}{\sigma_i \sigma_j}
  $$
- Covariance matrix \( \Sigma \) is the core input for portfolio risk.

### 5.3 Portfolio Expected Return and Risk

- Let weights vector \( w \) (size \( n \)), asset expected returns \( \mu \) (size \( n \)), covariance matrix \( \Sigma \) (size \( n \times n \)).
- Portfolio expected return:  
  $$
  \mu_p = w^{\top} \mu
  $$
- Portfolio variance:  
  $$
  \sigma_p^{2} = w^{\top} \Sigma w
  $$
- Portfolio volatility:  
  $$
  \sigma_p = \sqrt{w^{\top} \Sigma w}
  $$

### 5.4 Risk-Adjusted Return Metrics

- Sharpe ratio (using a risk-free rate \( r_f \)):  
  $$
  \text{Sharpe} = \frac{\mu_p - r_f}{\sigma_p}
  $$
- Other possible metrics (not all needed in V1 but useful conceptually):
  - Sortino ratio (downside volatility only).
  - Maximum drawdown (path-dependent, computed in simulation).

### 5.5 Dividend and Income Metrics

- Dividend yield for asset \( i \):  
  $$
  y_i = \frac{D_{i}^{\text{annual}}}{P_{i}}
  $$
- Portfolio dividend yield:  
  $$
  y_p = \sum_{i=1}^{n} w_i y_i
  $$
- Dividend growth rate:
  - Historical estimate from time series of dividends.
  - Forward assumption used in simulations.

### 5.6 Constraints and Feasible Set (V1)

- Long-only: \( w_i \ge 0 \) for all \( i \).  
- Fully invested: \( \sum_{i=1}^{n} w_i = 1 \).  
- Optional additional constraints (configurable):
  - \( w_i \le w_{\max} \) per asset.
  - Sector-level caps.

These constraints define the feasible set of portfolios the engine considers or recommends.

---

## 6. Industry Standard Approaches

### 6.1 Classical Mean–Variance Optimization

- Optimize weights to maximize expected return for a given level of volatility (or minimize volatility for given expected return).
- Pros: mathematically clean, widely understood, directly uses covariance matrix.  
- Cons: extremely sensitive to estimated inputs; can produce unstable, concentrated portfolios.

### 6.2 Black–Litterman and Bayesian Approaches

- Start from an implied equilibrium portfolio and update with investor views using Bayesian methods.
- Pros: more stable portfolios, integrates subjective views.  
- Cons: conceptually and computationally heavier; requires additional assumptions about equilibrium and views.

### 6.3 Factor and Risk-Based Portfolios

- Construct portfolios based on exposure to systematic factors (value, quality, low volatility, yield, etc.).
- Pros: ties directly to empirical drivers of returns; can be more robust than raw mean–variance.  
- Cons: requires factor model infrastructure and maintenance; may be overkill for V1.

### 6.4 Risk Parity and Volatility Targeting

- Allocate capital such that each asset or asset class contributes similar risk to the portfolio, or target a specific volatility level.
- Pros: robust diversification of risk; less sensitive to expected returns.  
- Cons: can underemphasize income objectives; still reliant on covariance estimates.

### 6.5 Liability-Driven and Income-Focused Strategies

- Design portfolios to fund specific cash flow obligations (e.g., retirement spending), often emphasizing stable income sources.
- Pros: aligned with real-world goals like retirement income.  
- Cons: modeling liability side is complex; requires richer scenario modeling.

For V1, DividendLab borrows ideas primarily from mean–variance thinking and basic risk-based diversification, with explicit emphasis on dividend income and simplicity of implementation.

---

## 7. Candidate DividendLab Approaches

### 7.1 Heuristic, Rule-Based Allocation (V1-Ready)

- Description:  
  Use simple, transparent rules to construct portfolios: sector caps, single-name caps, minimum diversification, and a small set of risk profiles (e.g., conservative, balanced, aggressive) with pre-defined target vol ranges and yield ranges.
- Pros: easy to explain; low parameter risk; simple to maintain.  
- Cons: less “optimal” in the strict mean–variance sense; may leave some efficiency on the table.
- Requirements: basic return/yield estimates, covariance matrix, simple constraint logic.
- Recommended for: V1.

### 7.2 Robust Mean–Variance with Shrinkage (V2+)

- Description:  
  Use mean–variance optimization with regularized inputs (e.g., shrink covariance to a structured prior, constrain weights, limit turnover).
- Pros: more formally grounded; can produce more efficient portfolios than heuristic rules.  
- Cons: more sensitive to modeling choices; harder to explain to non-experts.
- Requirements: robust covariance estimation, optimization solver, guardrails against instability.
- Recommended for: V2 and later.

### 7.3 Factor-Tilted Dividend Portfolios (V3+)

- Description:  
  Overlay factor exposures (quality, value, low volatility, yield stability) to tilt portfolios toward empirically favorable traits.
- Pros: better alignment with academic evidence; more nuanced risk control.  
- Cons: requires factor model infrastructure and more complex explanations.
- Requirements: factor returns data, regression infrastructure, extended data pipeline.
- Recommended for: V3 and later.

### 7.4 Liability-/Income-Driven Optimization (V3+/V4)

- Description:  
  Optimization directly in terms of matching income paths and spending needs, not just return and volatility.
- Pros: highly aligned with user goals (retirement income, spending stability).  
- Cons: complex, heavy modeling, high risk of overfitting/overconfidence if done poorly.
- Requirements: robust simulation engine, dynamic programming or similar, rich scenario modeling.
- Recommended for: V3–V4.

---

## 8. Proposed DividendLab Methodology (V1)

### 8.1 Overview

V1 uses a **rule-based, diversification-first** portfolio construction framework inspired by mean–variance logic but implemented via simple constraints and heuristics:

- Inputs: expected asset returns (or proxies), dividend yield and growth estimates, covariance matrix, user risk profile, user income objectives.
- Outputs: suggested target weights, plus portfolio-level metrics (expected return, volatility, yield, income growth, diversification measures).

### 8.2 User Segmentation and Risk Profiles

- Define 3–5 discrete risk profiles (e.g., Conservative, Balanced, Growth, Aggressive).  
- For each profile, specify:
  - Target volatility range (approximate).
  - Minimum dividend yield and preferred income growth range.
  - Maximum allowable equity allocation vs fixed-income / low-volatility assets.

### 8.3 Allocation Rules

Given a user’s risk profile and investable universe:

1. Start from a naive diversified allocation (e.g., market-cap-like or equal-weight across eligible assets or categories).
2. Apply constraints:
   - Long-only, fully invested.
   - Single-name cap (e.g., 5–10%).
   - Sector/industry caps (e.g., 20–25%) where data exists.
3. Tilt allocations:
   - Slightly favor higher-quality, more stable dividend payers for conservative profiles.
   - Allow more cyclical, higher-yield, and higher-growth names for aggressive profiles within risk limits.
4. Check risk metrics:
   - Compute portfolio expected return and volatility.
   - Ensure volatility is within profile range (or as close as practical).
   - Ensure dividend yield and income characteristics are aligned with profile.

### 8.4 Rebalancing and Cash Flow Integration

- Rebalancing:
  - Default: periodic (e.g., annual) rebalancing for most users.
  - Optional: threshold rebalancing if weights drift beyond specified bands.
- Contributions:
  - New cash is deployed according to target weights (possibly favoring underweight assets to reduce drift).
- Withdrawals:
  - Prefer funding withdrawals from:
    1. Cash and dividends.
    2. Overweight positions relative to target.
  - This minimizes deviation from target risk profile.

### 8.5 Rationale vs Alternatives

- Chosen because:
  - It is robust to noisy inputs.
  - It is simple enough to explain to users and to test.
  - It aligns with the dividend/income narrative without pretending to optimize a complex utility function.
- Deferred:
  - Full-blown optimization and factor modeling are intentionally postponed to avoid overfitting and unnecessary complexity in V1.

---

## 9. Data Requirements

For the portfolio theory layer (before simulation):

- **Price History per Asset**
  - Use: compute returns, volatilities, correlations.
  - Requirements: sufficient history to estimate covariance (e.g., 3–5+ years where possible).
- **Dividend History per Asset**
  - Use: compute realized yield, dividend growth, stability metrics.
- **Sector/Industry Classification**
  - Use: implement sector caps, diversification constraints.
- **Basic Asset Metadata**
  - Tickers, names, country/region, currency.
- **Risk-Free Rate Proxy**
  - Use: Sharpe ratio and relative attractiveness of risk assets.
- **Quality/Health Proxies (optional in V1, but highly desirable)**
  - Payout ratio, earnings stability, interest coverage, etc., to avoid obviously unsustainable yield traps.

Each dataset must specify: provider, update frequency, coverage, and known limitations (e.g., survivorship bias, missing dividends, ADR quirks).

---

## 10. Edge Cases

Key edge cases that must be considered:

- **High-Yield, Unsustainable Payers**
  - Risk: portfolios overweight names likely to cut dividends.
  - Mitigation: simple filters/flags (e.g., extreme payout ratios, very short history, known distress sectors) and qualitative overrides where possible.

- **Sparse or Noisy Data**
  - Risk: unstable volatility/correlation estimates for thinly traded or newly listed assets.
  - Mitigation: minimum history requirements; fallbacks to category-level estimates; shrinkage toward broad-market or sector averages.

- **Highly Concentrated Universes**
  - Risk: user portfolios with few holdings cannot be diversified efficiently.
  - Mitigation: clearly flag concentration risk; encourage additional holdings or use of diversified vehicles (ETFs).

- **Regime Shifts**
  - Risk: historical covariances and volatilities may underestimate future risk.
  - Mitigation: conservative overlays (e.g., volatility floors, correlation floors in stress testing), plus explicit stress-testing layer (separate doc).

- **Currency Risk (for international holdings)**
  - Risk: additional volatility and income variability due to FX.
  - Mitigation: at minimum, flag foreign currency exposure; in later versions, model FX explicitly.

- **Illiquidity and Execution**
  - Risk: rebalancing suggestions not realistically executable at scale or with low trading costs.
  - Mitigation: in V1, assume retail scale (liquidity generally available); later versions can add transaction cost modeling.

Each edge case should have explicit detection rules and flags in the engine, even if the mitigation in V1 is “warn, do not optimize around it.”

---

## 11. Validation Strategy

Portfolio theory validation for V1 focuses on sanity and robustness, not forecasting perfection:

- **Historical Backtests**
  - Apply the rule-based allocation logic on rolling historical windows.
  - Evaluate:
    - Realized total returns, volatility, drawdowns.
    - Realized dividend income and income growth.
  - Compare against simple benchmarks (e.g., broad market ETFs, basic dividend ETFs).

- **Cross-Sectional Tests**
  - Check that more conservative profiles had lower realized volatility and drawdowns than aggressive profiles.
  - Check that higher-yield portfolios actually delivered more income, without excessive catastrophic cuts.

- **Stability Tests**
  - Slightly perturb inputs (e.g., small changes in volatility estimates) and check that suggested allocations do not change wildly.

- **Success Criteria**
  - Portfolios behave directionally as intended across profiles.
  - No obvious pathological allocations (e.g., massive concentration in a single name purely due to noisy estimates).
  - Income behavior is broadly consistent with implied yields and growth.

Detailed metric definitions and backtest protocols are specified in `model_validation.md`; this doc defines what must be true conceptually.

---

## 12. Limitations

Key limitations to be documented clearly:

- **Input Estimation Error**
  - Expected returns, volatilities, and correlations are noisy, especially over short histories or small universes.

- **Ignoring Taxes and Frictions (V1)**
  - Taxes, transaction costs, and slippage are not fully modeled in V1; suggestions may be suboptimal after tax.

- **Simplistic Income Modeling**
  - Dividend growth assumptions may be crude in V1; true income paths can deviate significantly, especially in crisis regimes.

- **No Formal Optimization in V1**
  - Rule-based allocations are not guaranteed to be mathematically efficient; they aim for robustness and clarity over optimality.

- **Behavioral and Implementation Risk**
  - Users might not follow recommendations; real outcomes will differ from model expectations.

These limitations must be front-and-center in user-facing narratives and internal docs to avoid overconfidence.

---

## 13. Future Improvements

Potential enhancements, organized by version:

- **V2**
  - Introduce robust covariance estimation (e.g., shrinkage).
  - Add simple optimization under constraints to improve efficiency over rules.
  - Integrate basic tax-awareness (e.g., avoid excessive turnover).

- **V3**
  - Add factor modeling (quality, value, low vol, payout stability).
  - Introduce more advanced risk measures (expected shortfall, regime-dependent vol).
  - Enhance income modeling with scenario-based dividend cuts and recoveries.

- **V4**
  - Full liability- and income-driven optimization for retirement spending plans.
  - More sophisticated rebalancing policies that explicitly trade off transaction costs vs risk drift.

- **Long-Term Research**
  - Machine-learning-based return/income forecasts under strict validation and interpretability constraints.
  - Dynamic portfolio policies that adjust allocations based on evolving macro regimes and user behavior patterns.