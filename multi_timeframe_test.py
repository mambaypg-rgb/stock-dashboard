#!/usr/bin/env python3
"""
Multi-timeframe SPX Data and Projection Endpoint Testing
Tests the specific endpoints requested in the review:
1. GET /api/market/spx-data?interval=1d&period=3mo
2. GET /api/market/spx-data?interval=1mo&period=2y  
3. GET /api/market/projection?weeks=10&interval=1d
"""

import requests
import json
import time
from datetime import datetime

# Backend URL from frontend .env
BACKEND_URL = "https://funny-goldberg-1.preview.emergentagent.com"
TIMEOUT = 30  # 30 second timeout as requested

def test_spx_data_endpoint(interval, period, description):
    """Test the multi-timeframe SPX data endpoint."""
    url = f"{BACKEND_URL}/api/market/spx-data"
    params = {"interval": interval, "period": period}
    
    print(f"\n{'='*60}")
    print(f"Testing: {description}")
    print(f"URL: {url}")
    print(f"Params: {params}")
    print(f"{'='*60}")
    
    try:
        start_time = time.time()
        response = requests.get(url, params=params, timeout=TIMEOUT)
        response_time = time.time() - start_time
        
        print(f"Status Code: {response.status_code}")
        print(f"Response Time: {response_time:.2f}s")
        
        if response.status_code != 200:
            print(f"❌ FAILED - HTTP {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
        try:
            data = response.json()
        except json.JSONDecodeError as e:
            print(f"❌ FAILED - Invalid JSON response: {e}")
            print(f"Raw response: {response.text[:500]}")
            return False
            
        print(f"Response Keys: {list(data.keys())}")
        
        # Validate required keys
        required_keys = ['data', 'symbol', 'interval']
        for key in required_keys:
            if key not in data:
                print(f"❌ FAILED - Missing required key: {key}")
                return False
                
        # Validate data array
        if not isinstance(data['data'], list):
            print(f"❌ FAILED - 'data' is not a list")
            return False
            
        data_array = data['data']
        print(f"Data Array Length: {len(data_array)}")
        
        if len(data_array) == 0:
            print(f"❌ FAILED - Empty data array")
            return False
            
        # Validate OHLC structure
        sample_item = data_array[0]
        required_fields = ['date', 'open', 'high', 'low', 'close', 'volume']
        for field in required_fields:
            if field not in sample_item:
                print(f"❌ FAILED - Missing field in data item: {field}")
                return False
                
        print(f"Sample Data Item: {sample_item}")
        print(f"Symbol: {data['symbol']}")
        print(f"Interval: {data['interval']}")
        
        # Check for error field
        if 'error' in data:
            print(f"❌ FAILED - API returned error: {data['error']}")
            return False
            
        print(f"✅ PASSED - Valid SPX {interval} data for {period}")
        return True
        
    except requests.exceptions.Timeout:
        print(f"❌ FAILED - Request timeout after {TIMEOUT}s")
        return False
    except requests.exceptions.ConnectionError as e:
        print(f"❌ FAILED - Connection error: {e}")
        return False
    except Exception as e:
        print(f"❌ FAILED - Unexpected error: {e}")
        return False

def test_projection_endpoint(weeks, interval, description):
    """Test the projection endpoint with interval parameter."""
    url = f"{BACKEND_URL}/api/market/projection"
    params = {"weeks": weeks, "interval": interval}
    
    print(f"\n{'='*60}")
    print(f"Testing: {description}")
    print(f"URL: {url}")
    print(f"Params: {params}")
    print(f"{'='*60}")
    
    try:
        start_time = time.time()
        response = requests.get(url, params=params, timeout=TIMEOUT)
        response_time = time.time() - start_time
        
        print(f"Status Code: {response.status_code}")
        print(f"Response Time: {response_time:.2f}s")
        
        if response.status_code != 200:
            print(f"❌ FAILED - HTTP {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
        try:
            data = response.json()
        except json.JSONDecodeError as e:
            print(f"❌ FAILED - Invalid JSON response: {e}")
            print(f"Raw response: {response.text[:500]}")
            return False
            
        print(f"Response Keys: {list(data.keys())}")
        
        # Validate required keys
        required_keys = ['projection', 'model_info', 'interval']
        for key in required_keys:
            if key not in data:
                print(f"❌ FAILED - Missing required key: {key}")
                return False
                
        # Validate projection array
        if not isinstance(data['projection'], list):
            print(f"❌ FAILED - 'projection' is not a list")
            return False
            
        projection_array = data['projection']
        print(f"Projection Array Length: {len(projection_array)}")
        
        if len(projection_array) == 0:
            print(f"❌ FAILED - Empty projection array")
            return False
            
        # Validate projection structure
        sample_item = projection_array[0]
        required_fields = ['date', 'price', 'upper', 'lower']
        for field in required_fields:
            if field not in sample_item:
                print(f"❌ FAILED - Missing field in projection item: {field}")
                return False
                
        print(f"Sample Projection Item: {sample_item}")
        print(f"Interval: {data['interval']}")
        
        # Validate model_info
        model_info = data['model_info']
        if not isinstance(model_info, dict):
            print(f"❌ FAILED - model_info is not a dictionary")
            return False
            
        print(f"Model Info Keys: {list(model_info.keys())}")
        
        # Check for error in model_info
        if 'error' in model_info:
            print(f"❌ FAILED - Model returned error: {model_info['error']}")
            return False
            
        print(f"✅ PASSED - Valid projection for {weeks} weeks with {interval} interval")
        return True
        
    except requests.exceptions.Timeout:
        print(f"❌ FAILED - Request timeout after {TIMEOUT}s")
        return False
    except requests.exceptions.ConnectionError as e:
        print(f"❌ FAILED - Connection error: {e}")
        return False
    except Exception as e:
        print(f"❌ FAILED - Unexpected error: {e}")
        return False

def main():
    """Run the specific tests requested in the review."""
    print("🚀 Testing Multi-timeframe SPX Data and Projection Endpoints")
    print(f"Backend URL: {BACKEND_URL}")
    print(f"Timeout: {TIMEOUT}s")
    print(f"Test Time: {datetime.now().isoformat()}")
    
    test_results = []
    
    # Test 1: Daily SPX data for 3 months
    test_results.append(test_spx_data_endpoint(
        "1d", "3mo", 
        "Daily SPX OHLC data for 3 months"
    ))
    
    # Test 2: Monthly SPX data for 2 years
    test_results.append(test_spx_data_endpoint(
        "1mo", "2y",
        "Monthly SPX OHLC data for 2 years"
    ))
    
    # Test 3: Daily projection for 10 weeks
    test_results.append(test_projection_endpoint(
        10, "1d",
        "Daily projection data for 10 weeks"
    ))
    
    # Summary
    print(f"\n{'='*60}")
    print("TEST SUMMARY")
    print(f"{'='*60}")
    
    passed = sum(test_results)
    total = len(test_results)
    
    test_names = [
        "Daily SPX data (3mo)",
        "Monthly SPX data (2y)", 
        "Daily projection (10w)"
    ]
    
    for i, (name, result) in enumerate(zip(test_names, test_results)):
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{name:25} {status}")
    
    print(f"\nTests Passed: {passed}/{total}")
    
    if passed == total:
        print("🎉 ALL MULTI-TIMEFRAME TESTS PASSED!")
    else:
        print("❌ SOME TESTS FAILED")
        
    print(f"Test completed at: {datetime.now().isoformat()}")
    
    return passed == total

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)