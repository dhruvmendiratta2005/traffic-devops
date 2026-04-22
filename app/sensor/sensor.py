import time
import random
import requests
import os

OPTIMIZER_URL = os.environ.get('OPTIMIZER_URL', 'http://localhost:5000/update_traffic')

def simulate_traffic():
    while True:
        data = {
            "North": random.randint(0, 50),
            "South": random.randint(0, 50),
            "East": random.randint(0, 30),
            "West": random.randint(0, 30)
        }
        try:
            response = requests.post(OPTIMIZER_URL, json=data)
            print(f"Sent traffic data: {data}, Response: {response.status_code}")
        except Exception as e:
            print(f"Failed to send data: {e}")
        
        time.sleep(5) # Send updates every 5 seconds

if __name__ == '__main__':
    print(f"Starting sensor simulation, sending to {OPTIMIZER_URL}")
    simulate_traffic()
