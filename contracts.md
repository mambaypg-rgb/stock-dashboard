# API Contracts - PathFinder Trading Platform

## Backend Endpoints

### 1. GET /api/market/spx-weekly
- **Purpose**: Fetch real SPX weekly OHLC candlestick data
- **Response**: `{ data: [{ date, open, high, low, close, volume }], symbol: "SPX" }`
- **Source**: yfinance (^GSPC)

### 2. GET /api/market/projection
- **Purpose**: Compute probability-weighted weekly path projection
- **Query**: `?weeks=10` (default 10 weeks ahead)
- **Response**: `{ projection: [{ date, price, upper, lower }], model_info: {...} }`
- **Method**: Monte Carlo simulation + statistical analysis of historical returns

### 3. GET /api/market/indices
- **Purpose**: Get current major market indices
- **Response**: `{ indices: [{ symbol, name, price, change, changePercent }] }`

### 4. GET /api/market/stocks
- **Purpose**: Get watchlist stock data
- **Query**: `?symbols=AAPL,MSFT,NVDA,...`
- **Response**: `{ stocks: [{ symbol, name, price, change, changePercent, volume }] }`

### 5. GET /api/market/sectors
- **Purpose**: Get sector ETF performance
- **Response**: `{ sectors: [{ name, change, color }] }`

### 6. GET /api/market/analysis
- **Purpose**: LLM-generated market commentary for the projection
- **Response**: `{ commentary: "string", generated_at: "datetime" }`

## Mock Data to Replace
- `spxWeeklyData` → /api/market/spx-weekly
- `projectionData` → /api/market/projection
- `marketIndices` → /api/market/indices
- `watchlistData` → /api/market/stocks
- `sectorPerformance` → /api/market/sectors

## Frontend Integration
- Add API service layer using axios
- Replace mock imports with API calls in Dashboard, Markets, Analysis pages
- Add loading states and error handling
- Cache data in React state to avoid redundant requests
