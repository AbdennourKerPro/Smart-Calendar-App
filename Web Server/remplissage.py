import math
import pymongo
from itertools import combinations

client = pymongo.MongoClient("mongo-server-link")
db = client["tasks_database"]
collection = db["daily_tasks"]

# Utilise l'implémentation d'une solution du problème du sac à dos pour optimiser le remplissage du calendrier
def best_comb(target_duration, durations):
    best_combination = []
    best_sum = 0

    # Iterate over all possible combinations of durations
    for r in range(1, len(durations) + 1):
        for comb in combinations(durations, r):
            current_sum = sum(comb)
            if current_sum <= target_duration and current_sum > best_sum:
                best_combination = comb
                best_sum = current_sum

    return best_combination

def fill(intervalle):
    calendrier = []
    for inter in intervalle:    
        deb, fin = inter
        deb_m, deb_h = math.modf(deb)
        fin_m, fin_h = math.modf(fin)
        deb_h, fin_h = int(deb_h),int(fin_h)
        deb_m, fin_m = int(deb_m * 100), int(fin_m*100)
        print(deb_h,deb_m,fin_h,fin_m)
        duree_dispo = (fin_h*60 + fin_m) - (deb_h*60 + deb_m)
        print(duree_dispo)
        durees_valides = []
        for task in collection.find():
            taskdur = task["duration"]
            if taskdur>0 and taskdur < duree_dispo:
                if taskdur not in durees_valides:
                    durees_valides.append(taskdur)
        bc = best_comb(duree_dispo,durees_valides)
        for duration in bc:
            query = {"duration": duration}
            task = collection.find(query).sort("priorité", 1)[0]
            h,m = duration//60, duration %60
            if deb_m + m >= 60:
                fin_task_h = deb_h + h + 1
                fin_task_m = (deb_m + m)%60
            else:
                fin_task_h = deb_h + h
                fin_task_m = deb_m + m
            debut = float(deb_h) + float(deb_m)/100
            fin = float(fin_task_h) + float(fin_task_m)/100
            deb_h = fin_task_h
            deb_m = fin_task_m
            calendrier.append({"title":task["task"], "description":task["description"], "debut": debut, "fin": fin, "id":task["id"]})
            collection.delete_one({"id":task["id"]})
    return calendrier
