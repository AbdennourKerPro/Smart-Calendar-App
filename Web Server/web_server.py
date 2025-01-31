from flask import Flask, request, jsonify
import pymongo
import duration_estimation as de
import remplissage
import uuid

# Connexion à la base de données MongoDB (assurez-vous que MongoDB est en cours d'exécution sur localhost)
client = pymongo.MongoClient("mongodb+srv://abdkerjds:QmZpHwyEtbWzTPVr@data1.qv0nbfc.mongodb.net/")
# client_testadrien = pymongo.MongoClient("mongodb://localhost:27017")
db = client["tasks_database"]
collection = db["daily_tasks"]


app = Flask(__name__)

current_free_interval = [0.0,24.0]
free_interval = [[0.0,24.0]]
tasks = []
users = {}

@app.route('/authenticate', methods=['POST'])
def add_user():
    data = request.json
    username = data.get('username')

    if not username:
        return jsonify({"success" : False,"error": "Username is required"}), 400
    
    #Générer un mot de passe unique
    password = str(uuid.uuid4())
    
    users[password] = username

    # Retourner true et le mot de passe généré
    return jsonify({"success": True, "password": password})

@app.route('/test', methods=['GET'])
def test():
    print("Test réussi !")
    return "Test réussi !", 200

@app.route('/delete_task', methods=['POST'])
def delete_task():
    taskToDelete = request.json
    for task in taskToDelete:
        _ = collection.delete_many({"id":task['id']})
    return


@app.route('/tasks', methods=['POST'])
def update_tasks():
    global tasks
    correspo_prio={"Urgent":1,"Normal":2,"Paut attendre":3}
    tasks = request.json
    print(f"Updated tasks: {tasks}")
    for e in tasks:
        new = True
        for tas in collection.find():
            if tas['id'] == e['id']: new = False
        if new == True:
            new_task = {
        "id": e['id'],
        "task": e['title'],
        "duration": -1.0,
        "description": e['description'],
        "category": None,
        "available_times": [(0.0,24.0)],
        "priorité": correspo_prio[e['priority']]
        }
            collection.insert_one(new_task)
    de.maj_duration_bdd(db,"daily_tasks")
    return jsonify(tasks), 200

@app.route('/free_interval', methods=['POST'])
def maj_free_interval():
    global free_interval
    response = request.json
    free_interval = []
    for e in response:
        new_interval = [e['debut'],e['fin']]
        free_interval.append(new_interval)
    print(free_interval)
    return jsonify(free_interval), 200

@app.route('/current_free_interval', methods=['POST'])
def maj_current_free_interval():
    global current_free_interval
    response = request.json
    current_free_interval = [response['debut'],response['fin']]
    print(current_free_interval)
    return jsonify(current_free_interval), 200

@app.route('/fill_one_slot', methods=['GET'])
def fill_one_slot():
    global current_free_interval
    calendrier = remplissage.fill([current_free_interval])
    return jsonify(calendrier), 200

@app.route('/fill_day', methods=['GET'])
def fill_day():
    global free_interval
    calendrier = remplissage.fill(free_interval)
    return jsonify(calendrier), 200

if __name__ == '__main__':
    app.run(port=4000,debug=True)
