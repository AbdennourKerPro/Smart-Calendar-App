import openai
import re

# Set your OpenAI API key
openai.api_key = 'Enter your GPT API Key'

def duration_estimation(s):
    # API parameters for response generation
    response = openai.ChatCompletion.create(
    model="gpt-3.5-turbo-0613",
    messages=[
        {"role": "user", "content": "What is the average duration needed to complete this task :" + s + "Answer with a number corresponding to your estimation in minutes without any additional words."},
    ]
    )
    return float(''.join(re.findall(r'\d', response['choices'][0]['message']['content'])))

def maj_duration_bdd(db,s):
    collection = db[s]
    for task in collection.find({"duration": {"$lt": 0}}):
        task_name = task["task"]
        estimated_time = duration_estimation(task_name)
        # Filtre de requête pour identifier le document à mettre à jour
        filtre = {"task": task_name}
        # Modifications à apporter
        new_values = {"$set": {"duration": estimated_time}}
        resultat = collection.update_one(filtre, new_values)
    return "Base de donnée mise à jour avec les durées estimées des tâches."