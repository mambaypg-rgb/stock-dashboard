#!/usr/bin/env python3
"""
Backend API Testing for Portfolio Endpoints
Tests the new portfolio, watchlist, accuracy, and multi-asset endpoints
"""

import requests
import json
import time
from datetime import datetime, timedelta

# Backend URL from environment
BACKEND_URL = "https://funny-goldberg-1.preview.emergentagent.com"
TIMEOUT = 30

def test_endpoint(method, endpoint, data=None, expected_status=200, description=""):
    """Test an API endpoint and return response data."""
    url = f"{BACKEND_URL}{endpoint}"
    print(f"\n🧪 Testing {method} {endpoint}")
    if description:
        print(f"   Description: {description}")
    
    start_time = time.time()
    
    try:
        if method == "GET":
            response = requests.get(url, timeout=TIMEOUT)
        elif method == "POST":
            response = requests.post(url, json=data, timeout=TIMEOUT)
        elif method == "DELETE":
            response = requests.delete(url, timeout=TIMEOUT)
        else:
            print(f"❌ Unsupported method: {method}")
            return None
            
        elapsed = time.time() - start_time
        
        print(f"   Status: {response.status_code} (Expected: {expected_status})")
        print(f"   Response time: {elapsed:.2f}s")
        
        if response.status_code == expected_status:
            try:
                json_data = response.json()
                print(f"   ✅ SUCCESS - Valid JSON response")
                return json_data
            except json.JSONDecodeError:
                print(f"   ❌ FAILED - Invalid JSON response")
                print(f"   Response text: {response.text[:200]}")
                return None
        else:
            print(f"   ❌ FAILED - Wrong status code")
            print(f"   Response: {response.text[:200]}")
            return None
            
    except requests.exceptions.Timeout:
        print(f"   ❌ FAILED - Request timeout after {TIMEOUT}s")
        return None
    except requests.exceptions.RequestException as e:
        print(f"   ❌ FAILED - Request error: {e}")
        return None

def main():
    print("=" * 80)
    print("🚀 PORTFOLIO ENDPOINTS TESTING")
    print("=" * 80)
    
    results = {}
    
    # Test 1: POST /api/portfolio/watchlist - Add AAPL to watchlist
    print("\n" + "="*50)
    print("TEST 1: Add to Watchlist")
    print("="*50)
    
    watchlist_data = {"symbol": "AAPL"}
    result = test_endpoint(
        "POST", 
        "/api/portfolio/watchlist", 
        data=watchlist_data,
        description="Should add AAPL to watchlist"
    )
    results["add_watchlist"] = result is not None
    if result:
        print(f"   Response: {json.dumps(result, indent=2)}")
    
    # Test 2: GET /api/portfolio/watchlist - Get watchlist items
    print("\n" + "="*50)
    print("TEST 2: Get Watchlist")
    print("="*50)
    
    result = test_endpoint(
        "GET", 
        "/api/portfolio/watchlist",
        description="Should return watchlist items including AAPL"
    )
    results["get_watchlist"] = result is not None
    if result:
        print(f"   Response: {json.dumps(result, indent=2)}")
        if "items" in result:
            print(f"   Watchlist contains {len(result['items'])} items")
    
    # Test 3: POST /api/portfolio/positions - Add position
    print("\n" + "="*50)
    print("TEST 3: Add Position")
    print("="*50)
    
    position_data = {
        "symbol": "AAPL",
        "shares": 10,
        "entry_price": 200,
        "entry_date": "2026-01-15",
        "notes": "Test position"
    }
    result = test_endpoint(
        "POST", 
        "/api/portfolio/positions", 
        data=position_data,
        description="Should add AAPL position with 10 shares at $200"
    )
    results["add_position"] = result is not None
    if result:
        print(f"   Response: {json.dumps(result, indent=2)}")
    
    # Test 4: GET /api/portfolio/positions - Get positions with enriched data
    print("\n" + "="*50)
    print("TEST 4: Get Positions")
    print("="*50)
    
    result = test_endpoint(
        "GET", 
        "/api/portfolio/positions",
        description="Should return positions with current_price, pnl, market_value"
    )
    results["get_positions"] = result is not None
    if result:
        print(f"   Response: {json.dumps(result, indent=2)}")
        if "positions" in result:
            print(f"   Found {len(result['positions'])} positions")
            for pos in result['positions']:
                if 'current_price' in pos and 'pnl' in pos and 'market_value' in pos:
                    print(f"   ✅ Position enriched with current_price: ${pos['current_price']}, PnL: ${pos['pnl']}, Market Value: ${pos['market_value']}")
                else:
                    print(f"   ❌ Position missing enriched data")
        if "summary" in result:
            print(f"   Portfolio summary: {result['summary']}")
    
    # Test 5: GET /api/portfolio/projection/AAPL - Get projection for AAPL
    print("\n" + "="*50)
    print("TEST 5: Asset Projection")
    print("="*50)
    
    result = test_endpoint(
        "GET", 
        "/api/portfolio/projection/AAPL?weeks=10",
        description="Should return projection for AAPL over 10 weeks"
    )
    results["asset_projection"] = result is not None
    if result:
        print(f"   Response keys: {list(result.keys())}")
        if "projection" in result:
            print(f"   Projection contains {len(result['projection'])} data points")
        if "model_info" in result:
            print(f"   Model info: {result['model_info']}")
        if "symbol" in result:
            print(f"   Symbol: {result['symbol']}")
    
    # Test 6: GET /api/portfolio/daily-breakdown/SPX - Get daily breakdown
    print("\n" + "="*50)
    print("TEST 6: Daily Breakdown")
    print("="*50)
    
    result = test_endpoint(
        "GET", 
        "/api/portfolio/daily-breakdown/SPX",
        description="Should return daily breakdown with daily_breakdown array"
    )
    results["daily_breakdown"] = result is not None
    if result:
        print(f"   Response keys: {list(result.keys())}")
        if "daily_breakdown" in result:
            print(f"   Daily breakdown contains {len(result['daily_breakdown'])} entries")
            print(f"   ✅ Daily breakdown array present")
        else:
            print(f"   ❌ Missing daily_breakdown array")
        if "symbol" in result:
            print(f"   Symbol: {result['symbol']}")
    
    # Test 7: POST /api/portfolio/accuracy/record - Record projection
    print("\n" + "="*50)
    print("TEST 7: Record Projection")
    print("="*50)
    
    # Calculate end date 10 weeks from now
    end_date = (datetime.now() + timedelta(weeks=10)).strftime("%Y-%m-%d")
    
    accuracy_data = {
        "symbol": "SPX",
        "projection_weeks": 10,
        "start_price": 6800,
        "projected_end_price": 6900,
        "direction_predicted": "bullish",
        "confidence": 55,
        "end_date": end_date
    }
    result = test_endpoint(
        "POST", 
        "/api/portfolio/accuracy/record", 
        data=accuracy_data,
        description="Should record projection for accuracy tracking"
    )
    results["record_accuracy"] = result is not None
    if result:
        print(f"   Response: {json.dumps(result, indent=2)}")
    
    # Test 8: GET /api/portfolio/accuracy/history - Get accuracy history
    print("\n" + "="*50)
    print("TEST 8: Accuracy History")
    print("="*50)
    
    result = test_endpoint(
        "GET", 
        "/api/portfolio/accuracy/history",
        description="Should return records and stats"
    )
    results["accuracy_history"] = result is not None
    if result:
        print(f"   Response keys: {list(result.keys())}")
        if "records" in result:
            print(f"   Found {len(result['records'])} projection records")
        if "stats" in result:
            print(f"   Accuracy stats: {result['stats']}")
            print(f"   ✅ Stats include total_projections, verified, correct, accuracy")
    
    # Summary
    print("\n" + "="*80)
    print("📊 TEST SUMMARY")
    print("="*80)
    
    passed = sum(1 for success in results.values() if success)
    total = len(results)
    
    for test_name, success in results.items():
        status = "✅ PASSED" if success else "❌ FAILED"
        print(f"{test_name:20} {status}")
    
    print(f"\nOverall: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 ALL PORTFOLIO ENDPOINTS WORKING!")
    else:
        print("⚠️  Some endpoints need attention")
    
    return results

if __name__ == "__main__":
    main()