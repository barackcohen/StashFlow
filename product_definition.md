# Product Definition: Privacy-First iOS Stock Portfolio Tracker (Finalized)

A privacy-focused, local-first iOS application that allows users to create and manage multiple stock portfolios, manually log positions, view calculated values (portfolio and grand totals), and access an interactive Home Screen widget.

---

## 1. Product Goals & Core Value Proposition
- **Privacy First**: 100% of portfolio data (tickers, quantities, portfolio names) is stored locally on the user's device via standard SwiftData sandboxed storage. No cloud sync or third-party servers storing user assets.
- **Simplicity**: Fast manual entry for positions without requiring broker account linking.
- **Convenience**: A Home Screen widget showing the total value of portfolios with an on-demand refresh button.

---

## 2. Target Tech Stack
- **Minimum iOS Version**: iOS 17.0+ (Required for SwiftData and interactive widgets with App Intents).
- **UI Framework**: SwiftUI.
- **Data Persistence**: SwiftData (local sandbox storage, protected by default iOS hardware encryption when locked).
- **Widget**: WidgetKit with App Intents (for the interactive 'Refresh' button).
- **Stock Price Data**: Real-time or delayed stock prices retrieved directly from a public financial API (e.g., Yahoo Finance/unoffical API, or Finnhub/Alpha Vantage with optional user API keys in settings).

---

## 3. Key Feature Specifications

### A. Multi-Portfolio Management
- Create, rename, and delete portfolios.
- Assign custom colors or icons to distinguish between portfolios (e.g., "Retirement", "Active Trading", "Crypto/Speculative").

### B. Position Management
- Add position: Stock Ticker (e.g., AAPL, TSLA) and quantity of shares (supports decimals for fractional shares).
- Edit position: Update quantity.
- Delete position.
- Automatic fetch of current stock prices using the ticker.

### C. Financial Calculations & Views
- **Dashboard**:
  - Total assets value across all portfolios (Grand Total).
  - List of portfolios with their individual total values and 24h/historical changes.
- **Portfolio Detail View**:
  - Breakdown of positions (shares, current price, total value, percentage of portfolio).
  - Simple visual distribution chart (e.g., pie chart or donut chart using Swift Charts).

### D. Interactive iOS Widget
- Displays the Grand Total across all portfolios or a selected portfolio.
- Shows the last updated timestamp.
- **Interactive Refresh Button**: Invokes a WidgetKit App Intent to fetch the latest stock prices in the background and update the displayed values immediately.

---

## 4. Design & Aesthetics
- **Theme**: Glassmorphic styling with a premium dark and light mode.
- **Visuals**: Translucent card designs, colorful background glows (e.g., neon/pastel gradients), smooth SwiftUI transition animations, and modern typography.
- **Charts**: Interactive Swift Charts for asset allocation and portfolio performance.

---

## 5. Visual Dashboard Mockup

![Premium Glassmorphic Dashboard Mockup](/Users/barackcohen/my_portfolios/portfolio_dashboard_mockup.png)
