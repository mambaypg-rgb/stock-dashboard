#!/bin/bash
# ============================================================
# PATHFINDER - Full Project Setup Script
# ============================================================
# This script recreates the entire Pathfinder project locally.
# 
# Prerequisites:
#   - Node.js 18+ and Yarn installed
#   - Python 3.11+ installed
#   - MongoDB running locally on port 27017
#
# Usage:
#   chmod +x setup_pathfinder.sh
#   ./setup_pathfinder.sh
# ============================================================

set -e
echo "🚀 Setting up Pathfinder Trading Platform..."

# ---- Create directory structure ----
mkdir -p pathfinder/backend
mkdir -p pathfinder/frontend/src/components/ui
mkdir -p pathfinder/frontend/src/pages
mkdir -p pathfinder/frontend/src/services
mkdir -p pathfinder/frontend/src/data
mkdir -p pathfinder/frontend/public

cd pathfinder

# ============================================================
# BACKEND FILES
# ============================================================

cat > backend/.env << 'ENVEOF'
MONGO_URL="mongodb://localhost:27017"
DB_NAME="pathfinder_db"
CORS_ORIGINS="*"
EMERGENT_LLM_KEY=YOUR_KEY_HERE
ENVEOF

cat > backend/requirements.txt << 'REQEOF'
fastapi==0.110.1
uvicorn==0.25.0
python-dotenv>=1.0.1
pymongo==4.5.0
motor==3.3.1
pydantic>=2.6.4
yfinance>=1.2.0
numpy>=1.26.0
scipy>=1.12.0
emergentintegrations
REQEOF

cat > backend/server.py << 'PYEOF'
from fastapi import FastAPI, APIRouter, Query
from dotenv import load_dotenv
from starlette.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
import os
import logging
from pathlib import Path
from pydantic import BaseModel, Field
from typing import List, Optional
import uuid
from datetime import datetime

from market_data import (
    get_spx_weekly_data,
    get_spx_data,
    get_market_indices,
    get_stock_data,
    get_sector_performance
)
from projection_model import compute_probability_weighted_path
from llm_service import generate_market_commentary

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

mongo_url = os.environ['MONGO_URL']
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ['DB_NAME']]

app = FastAPI()
api_router = APIRouter(prefix="/api")

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class StatusCheck(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    client_name: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)

class StatusCheckCreate(BaseModel):
    client_name: str

@api_router.get("/")
async def root():
    return {"message": "Pathfinder API v1.0"}

@api_router.post("/status", response_model=StatusCheck)
async def create_status_check(input: StatusCheckCreate):
    status_dict = input.dict()
    status_obj = StatusCheck(**status_dict)
    _ = await db.status_checks.insert_one(status_obj.dict())
    return status_obj

@api_router.get("/status", response_model=List[StatusCheck])
async def get_status_checks():
    status_checks = await db.status_checks.find().to_list(1000)
    return [StatusCheck(**sc) for sc in status_checks]

@api_router.get("/market/spx-weekly")
async def get_spx_weekly(period: str = Query("8mo")):
    data = get_spx_weekly_data(period)
    if not data:
        return {"data": [], "symbol": "SPX", "error": "Unable to fetch data"}
    return {"data": data, "symbol": "SPX", "count": len(data)}

@api_router.get("/market/spx-data")
async def get_spx_data_endpoint(
    period: str = Query("8mo"),
    interval: str = Query("1wk")
):
    valid_intervals = {"1d": "1d", "1wk": "1wk", "1mo": "1mo", "daily": "1d", "weekly": "1wk", "monthly": "1mo"}
    yf_interval = valid_intervals.get(interval, "1wk")
    if yf_interval == "1d" and period in ("1y", "2y"):
        period = "6mo"
    elif yf_interval == "1mo" and period in ("3mo", "6mo"):
        period = "2y"
    data = get_spx_data(period=period, interval=yf_interval)
    if not data:
        return {"data": [], "symbol": "SPX", "interval": yf_interval, "error": "Unable to fetch data"}
    return {"data": data, "symbol": "SPX", "interval": yf_interval, "count": len(data)}

@api_router.get("/market/projection")
async def get_projection(
    weeks: int = Query(10, ge=1, le=26),
    confidence: float = Query(0.7, ge=0.5, le=0.95),
    interval: str = Query("1wk")
):
    valid_intervals = {"1d": "1d", "1wk": "1wk", "1mo": "1mo", "daily": "1d", "weekly": "1wk", "monthly": "1mo"}
    yf_interval = valid_intervals.get(interval, "1wk")
    if yf_interval == "1d":
        historical = get_spx_data("6mo", "1d")
        num_periods = weeks * 5
    elif yf_interval == "1mo":
        historical = get_spx_data("5y", "1mo")
        num_periods = weeks
    else:
        historical = get_spx_weekly_data("1y")
        num_periods = weeks
    if not historical:
        return {"projection": [], "model_info": {"error": "No historical data available"}}
    result = compute_probability_weighted_path(historical_data=historical, num_weeks=num_periods, confidence_level=confidence)
    result['interval'] = yf_interval
    return result

@api_router.get("/market/indices")
async def get_indices():
    data = get_market_indices()
    return {"indices": data}

@api_router.get("/market/stocks")
async def get_stocks(symbols: str = Query("AAPL,MSFT,NVDA,TSLA,AMZN,META,GOOGL,JPM")):
    symbol_list = [s.strip().upper() for s in symbols.split(",") if s.strip()]
    data = get_stock_data(symbol_list)
    return {"stocks": data}

@api_router.get("/market/sectors")
async def get_sectors():
    data = get_sector_performance()
    return {"sectors": data}

@api_router.get("/market/analysis")
async def get_analysis():
    historical = get_spx_weekly_data("1y")
    if not historical:
        return {"commentary": "Market data unavailable.", "generated_at": datetime.utcnow().isoformat()}
    result = compute_probability_weighted_path(historical)
    indices = get_market_indices()
    commentary = await generate_market_commentary(
        model_info=result.get('model_info', {}),
        projection=result.get('projection', []),
        indices=indices
    )
    return {"commentary": commentary, "generated_at": datetime.utcnow().isoformat(), "model_info": result.get('model_info', {})}

app.include_router(api_router)
app.add_middleware(CORSMiddleware, allow_credentials=True, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

@app.on_event("shutdown")
async def shutdown_db_client():
    client.close()
PYEOF

cat > backend/market_data.py << 'PYEOF'
import yfinance as yf
import numpy as np
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)
_cache = {}
_cache_ttl = 300

def _is_cache_valid(key):
    if key not in _cache:
        return False
    return (datetime.now().timestamp() - _cache[key].get('timestamp', 0)) < _cache_ttl

def get_spx_data(period="8mo", interval="1wk"):
    cache_key = f"spx_{interval}_{period}"
    if _is_cache_valid(cache_key):
        return _cache[cache_key]['data']
    try:
        ticker = yf.Ticker("^GSPC")
        hist = ticker.history(period=period, interval=interval)
        if hist.empty:
            return []
        data = []
        for idx, row in hist.iterrows():
            data.append({
                'date': idx.strftime('%Y-%m-%d'),
                'open': round(float(row['Open']), 2),
                'high': round(float(row['High']), 2),
                'low': round(float(row['Low']), 2),
                'close': round(float(row['Close']), 2),
                'volume': int(row['Volume']) if not np.isnan(row['Volume']) else 0
            })
        _cache[cache_key] = {'data': data, 'timestamp': datetime.now().timestamp()}
        return data
    except Exception as e:
        logger.error(f"Error fetching SPX data: {e}")
        return []

def get_spx_weekly_data(period="8mo"):
    return get_spx_data(period=period, interval="1wk")

def get_market_indices():
    cache_key = "market_indices"
    if _is_cache_valid(cache_key):
        return _cache[cache_key]['data']
    symbols = {
        '^GSPC': {'symbol': 'SPX', 'name': 'S&P 500'},
        '^NDX': {'symbol': 'NDX', 'name': 'NASDAQ 100'},
        '^DJI': {'symbol': 'DJI', 'name': 'Dow Jones'},
        '^RUT': {'symbol': 'RUT', 'name': 'Russell 2000'},
        '^VIX': {'symbol': 'VIX', 'name': 'CBOE VIX'},
        '^TNX': {'symbol': 'TNX', 'name': '10Y Treasury'},
    }
    indices = []
    try:
        for yf_symbol, info in symbols.items():
            try:
                ticker = yf.Ticker(yf_symbol)
                hist = ticker.history(period="5d")
                if len(hist) >= 2:
                    current = float(hist['Close'].iloc[-1])
                    prev = float(hist['Close'].iloc[-2])
                    change = round(current - prev, 2)
                    change_pct = round((change / prev) * 100, 2) if prev != 0 else 0
                    indices.append({'symbol': info['symbol'], 'name': info['name'], 'price': round(current, 2), 'change': change, 'changePercent': change_pct})
            except Exception as e:
                logger.warning(f"Error fetching {yf_symbol}: {e}")
        _cache[cache_key] = {'data': indices, 'timestamp': datetime.now().timestamp()}
        return indices
    except Exception as e:
        logger.error(f"Error fetching indices: {e}")
        return []

def get_stock_data(symbols):
    cache_key = f"stocks_{'_'.join(sorted(symbols))}"
    if _is_cache_valid(cache_key):
        return _cache[cache_key]['data']
    stocks = []
    try:
        for symbol in symbols:
            try:
                ticker = yf.Ticker(symbol)
                hist = ticker.history(period="5d")
                info = ticker.info
                if len(hist) >= 2:
                    current = float(hist['Close'].iloc[-1])
                    prev = float(hist['Close'].iloc[-2])
                    change = round(current - prev, 2)
                    change_pct = round((change / prev) * 100, 2) if prev != 0 else 0
                    volume = int(hist['Volume'].iloc[-1]) if not np.isnan(hist['Volume'].iloc[-1]) else 0
                    if volume >= 1_000_000_000: vol_str = f"{volume / 1_000_000_000:.1f}B"
                    elif volume >= 1_000_000: vol_str = f"{volume / 1_000_000:.1f}M"
                    elif volume >= 1_000: vol_str = f"{volume / 1_000:.1f}K"
                    else: vol_str = str(volume)
                    stocks.append({'symbol': symbol, 'name': info.get('shortName', symbol), 'price': round(current, 2), 'change': change, 'changePercent': change_pct, 'volume': vol_str})
            except Exception as e:
                logger.warning(f"Error fetching {symbol}: {e}")
        _cache[cache_key] = {'data': stocks, 'timestamp': datetime.now().timestamp()}
        return stocks
    except Exception as e:
        logger.error(f"Error fetching stocks: {e}")
        return []

def get_sector_performance():
    cache_key = "sectors"
    if _is_cache_valid(cache_key):
        return _cache[cache_key]['data']
    sector_etfs = {'XLK': 'Technology', 'XLV': 'Healthcare', 'XLF': 'Financials', 'XLY': 'Consumer Disc.', 'XLC': 'Communication', 'XLI': 'Industrials', 'XLE': 'Energy', 'XLU': 'Utilities', 'XLB': 'Materials', 'XLRE': 'Real Estate'}
    sectors = []
    try:
        for etf, name in sector_etfs.items():
            try:
                ticker = yf.Ticker(etf)
                hist = ticker.history(period="5d")
                if len(hist) >= 2:
                    current = float(hist['Close'].iloc[-1])
                    prev = float(hist['Close'].iloc[-2])
                    change_pct = round(((current - prev) / prev) * 100, 2) if prev != 0 else 0
                    sectors.append({'name': name, 'change': change_pct, 'color': '#22C55E' if change_pct >= 0 else '#EF4444'})
            except Exception as e:
                logger.warning(f"Error fetching sector {etf}: {e}")
        sectors.sort(key=lambda x: x['change'], reverse=True)
        _cache[cache_key] = {'data': sectors, 'timestamp': datetime.now().timestamp()}
        return sectors
    except Exception as e:
        logger.error(f"Error fetching sectors: {e}")
        return []
PYEOF

cat > backend/projection_model.py << 'PYEOF'
import numpy as np
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

def compute_probability_weighted_path(historical_data, num_weeks=10, num_simulations=5000, confidence_level=0.7):
    if len(historical_data) < 10:
        return {'projection': [], 'model_info': {'error': 'Insufficient data'}}
    try:
        closes = np.array([d['close'] for d in historical_data])
        returns = np.diff(np.log(closes))
        mu = np.mean(returns)
        sigma = np.std(returns)
        last_price = closes[-1]
        last_date_str = historical_data[-1]['date']
        last_date = datetime.strptime(last_date_str, '%Y-%m-%d')
        recent_returns = returns[-8:] if len(returns) >= 8 else returns
        recent_mu = np.mean(recent_returns)
        blended_mu = 0.6 * recent_mu + 0.4 * mu
        ma20 = np.mean(closes[-20:]) if len(closes) >= 20 else np.mean(closes)
        mean_reversion_speed = 0.05
        np.random.seed(42)
        simulated_paths = np.zeros((num_simulations, num_weeks + 1))
        simulated_paths[:, 0] = last_price
        for sim in range(num_simulations):
            for week in range(1, num_weeks + 1):
                current_price = simulated_paths[sim, week - 1]
                reversion = mean_reversion_speed * (np.log(ma20) - np.log(current_price))
                drift = blended_mu + reversion
                shock = np.random.normal(0, sigma)
                simulated_paths[sim, week] = current_price * np.exp(drift + shock)
        expected_path = np.median(simulated_paths, axis=0)
        upper_band = np.percentile(simulated_paths, 50 + confidence_level * 50, axis=0)
        lower_band = np.percentile(simulated_paths, 50 - confidence_level * 50, axis=0)
        projection = []
        for week in range(num_weeks + 1):
            proj_date = last_date + timedelta(weeks=week)
            projection.append({'date': proj_date.strftime('%Y-%m-%d'), 'price': round(float(expected_path[week]), 2), 'upper': round(float(upper_band[week]), 2), 'lower': round(float(lower_band[week]), 2)})
        final_prices = simulated_paths[:, -1]
        prob_up = float(np.mean(final_prices > last_price) * 100)
        expected_return = float((expected_path[-1] / last_price - 1) * 100)
        model_info = {
            'num_simulations': num_simulations, 'confidence_level': confidence_level,
            'weekly_volatility': round(float(sigma * 100), 2),
            'annualized_volatility': round(float(sigma * np.sqrt(52) * 100), 2),
            'mean_weekly_return': round(float(blended_mu * 100), 4),
            'probability_up': round(prob_up, 1), 'expected_return': round(expected_return, 2),
            'max_projected': round(float(np.max(upper_band)), 2),
            'min_projected': round(float(np.min(lower_band)), 2),
            'current_price': round(float(last_price), 2),
            'projection_weeks': num_weeks, 'last_data_date': last_date_str,
            'mean_reversion_target': round(float(ma20), 2)
        }
        return {'projection': projection, 'model_info': model_info}
    except Exception as e:
        logger.error(f"Error computing projection: {e}")
        return {'projection': [], 'model_info': {'error': str(e)}}
PYEOF

cat > backend/llm_service.py << 'PYEOF'
import os
import logging
from emergentintegrations.llm.chat import LlmChat, UserMessage

logger = logging.getLogger(__name__)

async def generate_market_commentary(model_info, projection, indices=None):
    api_key = os.environ.get('EMERGENT_LLM_KEY', '')
    if not api_key:
        return "Market commentary unavailable - API key not configured."
    try:
        chat = LlmChat(api_key=api_key, session_id="market-commentary-session",
            system_message="You are a professional market analyst providing concise, data-driven commentary on stock market projections. Keep your analysis under 150 words. Be specific with numbers. Do not use emojis. Use a professional, measured tone. Focus on actionable insights.")
        chat.with_model("openai", "gpt-4.1-mini")
        current_price = model_info.get('current_price', 'N/A')
        prob_up = model_info.get('probability_up', 'N/A')
        expected_return = model_info.get('expected_return', 'N/A')
        volatility = model_info.get('annualized_volatility', 'N/A')
        max_proj = model_info.get('max_projected', 'N/A')
        min_proj = model_info.get('min_projected', 'N/A')
        weeks = model_info.get('projection_weeks', 10)
        end_price = projection[-1].get('price', 'N/A') if projection and len(projection) > 1 else 'N/A'
        mid_price = projection[len(projection)//2].get('price', 'N/A') if projection and len(projection) > 1 else 'N/A'
        prompt = f"Analyze this SPX {weeks}-week probability-weighted projection:\n- Current SPX: {current_price}\n- Projected end price: {end_price} (mid-period: {mid_price})\n- Probability of upside: {prob_up}%\n- Expected return: {expected_return}%\n- Annualized volatility: {volatility}%\n- Projected range: {min_proj} to {max_proj}\n\nProvide a concise market outlook with key levels to watch and risk factors."
        response = await chat.send_message(UserMessage(text=prompt))
        return response
    except Exception as e:
        logger.error(f"Error generating commentary: {e}")
        return "Market commentary temporarily unavailable."
PYEOF

echo "✅ Backend files created"

# ============================================================
# SETUP INSTRUCTIONS
# ============================================================

cat > README.md << 'MDEOF'
# Pathfinder - Probability Weighted Trading Platform

## Quick Start

### Backend
```bash
cd backend
pip install -r requirements.txt
uvicorn server:app --host 0.0.0.0 --port 8001 --reload
```

### Frontend
```bash
cd frontend
yarn install
yarn start
```

### Environment Variables
- Backend: Edit `backend/.env` with your MONGO_URL and EMERGENT_LLM_KEY
- Frontend: Create `frontend/.env` with:
  ```
  REACT_APP_BACKEND_URL=http://localhost:8001
  ```

## Features
- Real SPX data from Yahoo Finance (daily/weekly/monthly)
- Monte Carlo probability-weighted price projections (5,000 simulations)
- AI-powered market commentary (GPT-4.1-mini)
- Live market indices, stocks, and sector performance
- Custom canvas-based candlestick chart with projection curves
- 4 pages: Landing, Dashboard, Markets, Analysis

## Tech Stack
- **Frontend**: React, Tailwind CSS, Recharts, Lucide Icons
- **Backend**: FastAPI, yfinance, NumPy/SciPy, Motor (MongoDB)
- **AI**: OpenAI GPT-4.1-mini via Emergent Integrations
MDEOF

echo ""
echo "============================================"
echo "  ✅ Pathfinder project created!"
echo "============================================"
echo ""
echo "  Frontend code was printed above from the"
echo "  live app. Use the Emergent VS Code editor"
echo "  or Save to GitHub to get frontend files."
echo ""
echo "  To run locally:"
echo "    cd pathfinder/backend"
echo "    pip install -r requirements.txt"
echo "    uvicorn server:app --port 8001 --reload"
echo ""
echo "  Then set up React frontend separately."
echo "============================================"
