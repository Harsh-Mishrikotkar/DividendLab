# Model Validation Framework

***

## 1. Purpose

This document defines DividendLab’s standardized framework for validating forecasting and simulation models, including deterministic projections and probabilistic Monte Carlo engines. 
It specifies what “good” model behavior means, how we measure it, how we compare alternative approaches, and when a model fails hard enough that it should be rejected or revised.  

Used In:  
- V1  
- V2  
- V3  
- V4  

Dependent Systems:  
- Portfolio Engine  
- Simulation Engine  
- Monte Carlo engine (`monte_carlo.md`)  
- Stress testing framework (`stress_testing.md`)  

Goal:  
Create a reusable, version‑independent framework for evaluating model quality across all forecasting systems. 

***

## 2. Executive Summary

DividendLab does not treat models as black boxes; every forecasting methodology must be validated against historical data, benchmark models, and clearly defined performance and calibration criteria. 
This document establishes a common set of metrics (error measures, risk measures, calibration measures) and evaluation protocols (rolling windows, walk‑forward testing, historical simulation) that apply to both deterministic and probabilistic engines.  

High level:

- V1: validate deterministic projections against realized portfolio behavior and simple benchmarks.  
- V2–V4: validate Monte Carlo and advanced simulation models for calibration, tail behavior, and robustness vs alternative methods.  

The framework emphasizes transparency, reproducibility, and explicit success/failure criteria so future developers can judge model quality without guesswork. 

***

## 3. Definitions

For each term we include definition, formula (if applicable), interpretation, example, and notes. 

### Mean Absolute Error (MAE)

- Definition: Average absolute difference between forecasts and realized values.  
- Formula:
$$
\text{MAE} = \frac{1}{N} \sum_{t=1}^N \lvert \hat{y}_t - y_t \rvert
$$
- Interpretation: Measures typical absolute forecast error; less sensitive to outliers than RMSE.  
- Example: Comparing projected annual portfolio values to realized values over backtest periods.  
- Notes: Good baseline error metric; always include.

### Root Mean Squared Error (RMSE)

- Definition: Square root of average squared error.  
- Formula:
$$
\text{RMSE} = \sqrt{ \frac{1}{N} \sum_{t=1}^N (\hat{y}_t - y_t)^2 }
$$
- Interpretation: Penalizes large errors more heavily; useful when big misses are especially bad.  

### Mean Absolute Percentage Error (MAPE)

- Definition: Average absolute error as a percentage of actual values.  
- Formula:
$$
\text{MAPE} = \frac{100}{N} \sum_{t=1}^N \left\lvert \frac{\hat{y}_t - y_t}{y_t} \right\rvert
$$
- Interpretation: Normalizes error; useful when scale changes over time.  
- Notes: Handle zeros carefully; may be unstable for very small \(y_t\).

### Sharpe Ratio (Forecasted vs Realized)

- Definition: Risk‑adjusted performance measure: excess return divided by volatility.  
- Formula:
$$
\text{Sharpe} = \frac{\mathbb{E}[R_p - R_f]}{\sigma(R_p - R_f)}
$$
- Interpretation: Measures efficiency of risk vs return; compare realized Sharpe to forecast‑implied expectations.  

### Calibration Error (Quantile Coverage)

- Definition: Difference between nominal coverage (e.g., 95%) and empirical coverage of forecast intervals.  
- Interpretation: Measures whether Monte Carlo confidence intervals actually contain realized outcomes at the expected rate.  
- Example: If 95% intervals only contain realized wealth 80% of the time, calibration is poor.

Additional terms:

- **Backtest Window**: historical period used for evaluation.  
- **Walk‑Forward Test**: train‑on‑past, test‑on‑future procedure repeated over multiple windows.  
- **Benchmark Model**: simple alternative (e.g., “fixed historical average return” or “random walk”) used as comparison.  

***

## 4. Core Concepts

### 4.1 Forecast vs Realized Outcomes

Description:  
Models produce forecasts (deterministic point values or distributions); reality produces realized paths.  

Purpose:  
Validation measures how close forecasts are to realized outcomes and whether uncertainty bands are honest.  

Practical Relevance:  
Decides whether a model is usable in production or only as a conceptual toy.

Implementation Notes:  
Standardize how we align forecast horizons and realized data (e.g., monthly vs annual, wealth vs income).

### 4.2 Calibration vs Accuracy

Description:  
Accuracy measures how close point forecasts are to realized values (MAE, RMSE, MAPE); calibration measures whether probabilistic forecasts represent uncertainty correctly (e.g., 95% intervals contain reality ≈95% of the time).  

Purpose:  
Avoid models that are “accurate” in average but lie about risk, or vice versa.  

Implementation Notes:  
Keep separate metrics and decisions for accuracy and calibration.

### 4.3 Benchmarking

Description:  
Compare complex models to simple baselines to ensure added complexity actually improves performance.  

Purpose:  
Prevent overfitting and “fancy but useless” models.  

Implementation Notes:  
Define a standard set of benchmarks for portfolio forecasting (e.g., historical average return, naive random walk, simple bootstrap).

### 4.4 Robustness and Stability

Description:  
Assess sensitivity of metrics to choice of window, asset universe, parameter estimation method.  

Purpose:  
Ensure models don’t behave well only in cherry‑picked periods.  

Implementation Notes:  
Include variability analysis of metrics across different backtest configurations.

***

## 5. Mathematical Foundation

For each equation we document purpose, formula, variables, interpretation, assumptions, limitations, and implementation considerations. 

Key components:

### 5.1 Error Metrics (MAE, RMSE, MAPE)

Purpose:  
Quantify point forecast error for wealth, income, or returns.  

Implementation Considerations:  
Handle zero and negative values carefully (especially for MAPE); choose appropriate aggregation (per period, per horizon).

### 5.2 Calibration Metrics

Purpose:  
Quantify how well predicted quantiles match empirical outcomes.  

Example:  
If the model predicts a 10th percentile terminal wealth \(Q_{0.10}\), track the fraction of realized outcomes below that value across many backtests; ideal is ≈ 10%.  

Implementation Considerations:  
Need sufficient number of backtest runs; Monte Carlo sampling error must be accounted for.

### 5.3 Risk Metrics (Drawdowns, Shortfall Probability)

Drawdown:  
$$
\text{MaxDD} = \max_{t} \left( \frac{V_{\text{peak}} - V_t}{V_{\text{peak}}} \right)
$$

Shortfall Probability:  
$$
\mathbb{P}(V_T < V_{\text{target}})
$$

Purpose:  
Measure tail behavior and severity of worst‑case scenarios.

Implementation Notes:  
Use same definitions across models so comparisons are meaningful.

***

## 6. Industry Standard Approaches

We summarize how professionals typically validate forecasting and simulation models. 

For each methodology we include description, advantages, disadvantages, complexity, use cases, industry adoption, and suitability for DividendLab:

- **Rolling Window Backtesting**  
  - Description: Train/estimate parameters on a fixed window, evaluate on subsequent period, roll forward.  
  - Advantages: Mimics real‑time use, captures changing regimes.  
  - Disadvantages: Data‑intensive; metrics vary with window choice.  
  - Suitability: Core approach for all versions.

- **Walk‑Forward Testing**  
  - Description: Sequence of train→test blocks that never use future data for parameter estimation.  
  - Advantages: Avoids look‑ahead bias; closer to production behavior.  
  - Suitability: Required for Monte Carlo and advanced models.

- **Historical Simulation and Benchmark Comparison**  
  - Description: Compare complex models to simple baselines using historical data (e.g., average return, naive bootstrap).  
  - Advantages: Forces complexity to prove its value.  
  - Suitability: Mandatory for accepting advanced models beyond V2.

- **Calibration Checks (Coverage Tests, PIT Histograms)**  
  - Description: Evaluate whether probability forecasts are calibrated using coverage tests and probability integral transform diagnostics.  
  - Suitability: Important for probabilistic engines (V2+).

***

## 7. Candidate DividendLab Approaches

We list realistic validation frameworks for DividendLab and assign recommended versions. 

### Approach A: Basic Error + Sharpe Evaluation (V1)

- Description: Evaluate deterministic forecasts using MAE, RMSE, MAPE, and realized Sharpe vs forecast‑implied expectations.  
- Advantages: Simple, transparent, easy to implement.  
- Disadvantages: No probabilistic calibration metrics.  
- Data Requirements: Historical portfolio histories and benchmark series.  
- Computational Requirements: Low.  
- Implementation Difficulty: Low.  
- Recommended Version: V1 baseline.

### Approach B: Full Backtesting + Calibration (V2–V3)

- Description: Apply rolling and walk‑forward tests to Monte Carlo engines, computing error metrics plus coverage of forecast intervals and shortfall probabilities.  
- Advantages: Proper evaluation of probabilistic forecasts.  
- Disadvantages: More complex; requires disciplined data handling.  
- Recommended Version: V2 and V3.

### Approach C: Regime‑Aware Validation (V3–V4)

- Description: Evaluate performance separately in different market regimes (bull, bear, high inflation, recession) and under stress tests.  
- Advantages: Reveals model weaknesses in specific environments.  
- Recommended Version: V3–V4.

***

## 8. Proposed DividendLab Methodology

This section defines the validation methodology currently planned for implementation.

### Description

DividendLab will implement a multi‑stage validation framework:

- V1: deterministic models validated primarily via error metrics and basic benchmarking.  
- V2+: probabilistic models validated via both error and calibration metrics, using rolling and walk‑forward backtests and benchmark comparison. 

### Inputs

- Historical portfolio data (values, contributions, withdrawals, dividends).  
- Asset return and dividend histories.  
- Model forecasts (deterministic or probabilistic) for the same periods.  
- Benchmark model outputs.

### Outputs

- Summary metrics: MAE, RMSE, MAPE, Sharpe, coverage rates, shortfall probabilities, drawdown statistics.  
- Comparative reports: model vs benchmark, by version and regime.  

### Workflow

1. Define backtest windows and walk‑forward schedule.  
2. For each window, estimate model parameters (as the production system would).  
3. Generate forecasts for the test period (deterministic values or distributions).  
4. Compare forecasts to realized outcomes and benchmark models.  
5. Aggregate metrics across windows; compute average and variability.  
6. Evaluate against success/failure criteria.

### Dependencies

- Portfolio engine implementation and data pipeline.  
- Monte Carlo engine (`monte_carlo.md`) and any advanced models.  
- Stress testing scenarios for regime‑specific validation.

### Assumptions

- Sufficient historical data to support backtesting.  
- Data quality is good enough that validation focuses on model quality, not data errors.  

### Risks

- Overfitting validation criteria to existing models.  
- Silent data issues causing misleading validation metrics.

### Reason for Selection

This framework balances rigor with implementability across versions and makes model acceptance a transparent, metric‑driven decision instead of a subjective judgment. 

***

## 9. Data Requirements

For each dataset we document provider, coverage, frequency, availability, reliability, cost, fields used, purpose, and potential issues. 

Key datasets:

- **Historical Portfolio Records**  
  - Fields: holdings, weights, contributions, withdrawals, dividends, valuations.  
  - Purpose: evaluating portfolio‑level forecasts.

- **Asset Return and Dividend Histories**  
  - Purpose: parameter estimation and benchmark model construction.  

- **Benchmark Index Data**  
  - Purpose: comparison and context (e.g., broad equity/bond indexes).

Potential issues:

- Survivorship bias.  
- Missing values and stale quotes.  
- Corporate action handling.

***

## 10. Edge Cases

We document situations where validation may fail or mislead. 

Examples:

- **Limited Data History**  
  - Impact: unstable metrics and unreliable conclusions.  
  - Mitigation: minimum data requirements; conservative interpretation.

- **Regime Changes**  
  - Impact: backtests dominated by atypical regimes.  
  - Mitigation: regime‑aware validation; stress testing.

- **Highly Illiquid Assets**  
  - Impact: distorted prices and returns; validation metrics unreliable.  
  - Mitigation: exclusion rules; separate treatment.

***

## 11. Validation Strategy

This section summarizes the overall strategy and ties together goals, metrics, approaches, benchmarks, success and failure criteria. 

### Validation Goals

- Verify that forecasts are reasonably accurate and calibrated.  
- Confirm that models outperform or at least match simple benchmarks.  
- Detect pathological behavior (overly optimistic intervals, unrealistic tail behavior, unstable metrics).

### Metrics

- MAE, RMSE, MAPE.  
- Sharpe and other risk‑adjusted performance measures.  
- Calibration metrics (coverage, PIT diagnostics).  
- Drawdown and shortfall statistics.

### Backtesting Approach

- Rolling windows and walk‑forward testing as default.  
- Historical simulation for benchmarks and consistency checks. 

### Benchmark Models

- Deterministic fixed‑return models.  
- Simple historical average models.  
- Basic bootstrapping models.

### Success Criteria

- Error metrics below defined thresholds for key outputs (wealth, income).  
- Calibration metrics within acceptable tolerances (e.g., coverage within ±5% of nominal).  
- Consistent performance across regimes; no obvious pathological behavior.

### Failure Criteria

- Systematic underestimation of downside risk.  
- Large calibration errors, especially in tails.  
- Performance consistently worse than simple benchmarks.

***

## 12. Limitations

We explicitly document weaknesses of the validation framework. 

- Dependence on quality and length of historical data.  
- Difficulty capturing extremely rare events (crises) in backtests.  
- Potential misalignment between metrics and true user utility (e.g., MAE vs “sleep at night”).  
- Risk of overfitting models to validation metrics instead of genuine robustness.

***

## 13. Future Improvements

Organized by version and long‑term research. 

- **V2**  
  - Introduce more sophisticated calibration diagnostics (e.g., PIT histograms).  
  - Add regime‑specific performance reporting.

- **V3**  
  - Validate models under synthetic stress scenarios.  
  - Integrate user‑specific utility and risk preferences into evaluation.

- **V4**  
  - Macro‑aware validation where performance is assessed conditional on economic regimes.

- **Long‑Term Research**  
  - Bayesian model comparison and model averaging.  
  - Robustness analysis under multiple data sources and parameter estimation methods.