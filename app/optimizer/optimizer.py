from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Global state
traffic_state = {
    "North": {"cars": 0, "light": "Red", "duration": 0},
    "South": {"cars": 0, "light": "Red", "duration": 0},
    "East": {"cars": 0, "light": "Red", "duration": 0},
    "West": {"cars": 0, "light": "Red", "duration": 0}
}

current_green = "North"
current_mode = "auto" # 'auto' or 'manual'

def calculate_duration(cars):
    base = 10
    duration = base + (cars * 2)
    return min(duration, 60)

@app.route('/update_traffic', methods=['POST'])
def update_traffic():
    data = request.json
    for intersection, cars in data.items():
        if intersection in traffic_state:
            traffic_state[intersection]["cars"] = cars
            traffic_state[intersection]["duration"] = calculate_duration(cars)
            
    global current_green
    
    if current_mode == "auto":
        for d in traffic_state:
            traffic_state[d]["light"] = "Red"
        
        max_cars = -1
        for d, info in traffic_state.items():
            if info["cars"] > max_cars:
                max_cars = info["cars"]
                current_green = d
                
        traffic_state[current_green]["light"] = "Green"
    
    return jsonify({"status": "updated"})

@app.route('/set_mode', methods=['POST'])
def set_mode():
    data = request.json
    global current_mode
    if "mode" in data and data["mode"] in ["auto", "manual"]:
        current_mode = data["mode"]
    return jsonify({"status": "updated", "mode": current_mode})

@app.route('/override_light', methods=['POST'])
def override_light():
    data = request.json
    global current_green
    if current_mode == "manual" and "intersection" in data and data["intersection"] in traffic_state:
        for d in traffic_state:
            traffic_state[d]["light"] = "Red"
        current_green = data["intersection"]
        traffic_state[current_green]["light"] = "Green"
    return jsonify({"status": "updated", "current_green": current_green})

@app.route('/status', methods=['GET'])
def get_status():
    return jsonify({
        "mode": current_mode,
        "intersections": traffic_state
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
