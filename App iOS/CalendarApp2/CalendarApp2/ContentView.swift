import SwiftUI
import UniformTypeIdentifiers
import UIKit
import EventKit
import MobileCoreServices
import Foundation
import FSCalendar

struct ContentView: View {
    @State private var events: [Date: [Event]] = loadEvents()
    @State private var tasks: [Task] = loadTasks()
    @State private var selectedDate: Date = Date()
    @State private var isAddingEvent = false
    @State private var showTaskList = false
    @State private var isExporting = false
    @State private var freeIntervals: [Interval] = []
    @State private var nextFreeInterval: Interval = Interval(debut: 0.0, fin: 24.0)

    var body: some View {
        TabView {
            CalendarView(events: $events, selectedDate: $selectedDate,tasks: $tasks, isAddingEvent: $isAddingEvent, freeIntervals: $freeIntervals, majFreeIntervals: majFreeIntervals)
                .tabItem {
                    Image(systemName: "calendar.day.timeline.leading").symbolRenderingMode(.multicolor)
                    Text("Calendar")
                }

            TaskListView(tasks: $tasks)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Task List")
                }
        }
        .onAppear {
            majFreeIntervals()
        }
    }
    
    private func majFreeIntervals() {
        guard let eventsForDay = events[selectedDate] else {
            let now = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH.mm"
            let currentHour = Double(dateFormatter.string(from: now)) ?? 0.0
            freeIntervals = [Interval(debut: currentHour, fin: 24.0)]
            nextFreeInterval = Interval(debut: currentHour, fin: 24.0)
            return
        }
        
        var intervals = [Interval]()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH.mm"
        
        let startOfDay = 0.0
        let endOfDay = 24.0
        let now = Double(dateFormatter.string(from: Date())) ?? 0.0
        
        var previousEnd = max(startOfDay, now)
        
        for event in eventsForDay.sorted(by: { $0.startTime < $1.startTime }) {
            let eventStart = Double(dateFormatter.string(from: event.startTime)) ?? 0.0
            let eventEnd = Double(dateFormatter.string(from: event.endTime)) ?? 0.0
            
            if previousEnd < eventStart && eventStart > now {
                intervals.append(Interval(debut: previousEnd, fin: eventStart))
            }
            previousEnd = max(previousEnd, eventEnd)
        }
        
        if previousEnd < endOfDay {
            intervals.append(Interval(debut: previousEnd, fin: endOfDay))
        }
        
        freeIntervals = intervals.filter { $0.fin > now }
        
        // Mettre à jour nextFreeInterval
        if let currentInterval = freeIntervals.first(where: { $0.debut <= now && now <= $0.fin }) {
            nextFreeInterval = Interval(debut: now, fin: currentInterval.fin)
        } else if let upcomingInterval = freeIntervals.first(where: { $0.debut > now }) {
            nextFreeInterval = upcomingInterval
        } else {
            nextFreeInterval = Interval(debut: endOfDay, fin: endOfDay)
        }
        
        sendFreeintervals()
        sendCurentFreeInterval()
    }
    
    private func sendCurentFreeInterval(){
        guard let url = URL(string: "https://beetle-exact-truly.ngrok-free.app/current_free_interval") else {
            print("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONEncoder().encode(nextFreeInterval)
            request.httpBody = jsonData
        } catch {
            print("Error encoding Free Intervals: \(error)")
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Invalid response")
                return
            }

            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString)")
            }
        }

        task.resume()
    }
    
    private func sendFreeintervals() {
        guard let url = URL(string: "https://beetle-exact-truly.ngrok-free.app/free_interval") else {
            print("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONEncoder().encode(freeIntervals)
            request.httpBody = jsonData
        } catch {
            print("Error encoding Free Intervals: \(error)")
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Invalid response")
                return
            }

            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString)")
            }
        }

        task.resume()
    }
}

struct CalendarView: View {
    @Binding var events: [Date: [Event]]
    @Binding var selectedDate: Date
    @Binding var tasks : [Task]
    @Binding var isAddingEvent: Bool
    @Binding var freeIntervals: [Interval]
    var majFreeIntervals: () -> Void

    var body: some View {
        NavigationView {
            VStack {
                FSCalendarView(events: $events, selectedDate: $selectedDate)
                    .frame(height: 300)
                    .padding()
                    
                HStack{
                    Button("One Slot", action: fillOneSlot)
                    Button("One Day", action: fillOneSlot)
                }.buttonStyle(.bordered)
                Section(header: Text("Events of the Day").font(.headline) ){
                    List(events[selectedDate] ?? [], id: \.self) { event in
                        NavigationLink(destination: EventDetailView(event: event)) {
                            Text("\(event.title) - \(event.startTimeString) à \(event.endTimeString)")
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteEvent(event)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
                
                
            }
            .navigationBarTitle("Calendar")
            .navigationBarItems(
                leading:HStack{
                    Button(action: {
                        // Action pour revenir à la date d'aujourd'hui
                        selectedDate = Date()
                        majFreeIntervals()
                    }) {
                        Text("Today")
                            .padding()
                    }
                },
                trailing:
                HStack {
                    Button(action: exportEventsToIcal) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Button(action: {
                        self.isAddingEvent = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                        .font(.title)
                    }
                    .sheet(isPresented: $isAddingEvent) {
                    AddEventView(events: self.$events, selectedDate: self.$selectedDate, isPresented: self.$isAddingEvent, majFreeIntervals: majFreeIntervals)
                        .onDisappear {
                            majFreeIntervals()
                        }
                }
                }
            )
        }
    }

    
    private func deleteEvent(_ event: Event) {
        if let index = events[selectedDate]?.firstIndex(of: event) {
            events[selectedDate]?.remove(at: index)
            majFreeIntervals()
        }
        ContentView.saveEvents(events: events)
    }

    func exportEventsToIcal() {
            let icalContent = generateIcalContent(events: events)
            saveIcalToDocuments(icalContent: icalContent)
        }
    
    func generateIcalContent(events: [Date: [Event]]) -> String {
        var icalString = "BEGIN:VCALENDAR\nVERSION:2.0\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss"

        for (_, eventsOnDate) in events {
            for event in eventsOnDate {
                icalString += "BEGIN:VEVENT\n"
                icalString += "SUMMARY:\(event.title)\n"
                icalString += "DESCRIPTION:\(event.description)\n"
                icalString += "DTSTART:\(dateFormatter.string(from: event.startTime))\n"
                icalString += "DTEND:\(dateFormatter.string(from: event.endTime))\n"
                icalString += "END:VEVENT\n"
            }
        }

        icalString += "END:VCALENDAR"
        return icalString
    }
    
    func saveIcalToDocuments(icalContent: String) {
            let fileManager = FileManager.default
            let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            guard let documentDirectory = urls.first else { return }

            let icalFileURL = documentDirectory.appendingPathComponent("events.ics")

            do {
                try icalContent.write(to: icalFileURL, atomically: true, encoding: .utf8)
                print("iCal file saved to: \(icalFileURL)")
                shareIcalFile(url: icalFileURL)
            } catch {
                print("Error saving iCal file: \(error)")
            }
        }
    
    func shareIcalFile(url: URL) {
            let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.first?.rootViewController?.present(activityViewController, animated: true, completion: nil)
            }
        }
    
    private func fillOneSlot() {
            guard let url = URL(string: "https://beetle-exact-truly.ngrok-free.app/fill_one_slot") else {
                print("Invalid URL")
                return
            }
            
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    print("Error: \(error)")
                    return
                }
                
                guard let data = data else {
                    print("No data received")
                    return
                }
                
                do {
                    if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                        DispatchQueue.main.async {
                            self.addEventsFromJSON(jsonArray)
                        }
                    }
                } catch {
                    print("Error parsing JSON: \(error)")
                }
            }
            
            task.resume()
        }
    private func addEventsFromJSON(_ jsonArray: [[String: Any]]) {
            let today_temp = Date()
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day], from: today_temp)
            let today = calendar.date(from:components)
            print(today!)
            var newEvents: [Event] = []
            var tasksToRemove : [Task] = []
            for jsonEvent in jsonArray {
                if let title = jsonEvent["title"] as? String,
                   let idString = jsonEvent["id"] as? String,
                   let id = UUID(uuidString: idString),
                   let description = jsonEvent["description"] as? String,
                   let debut = jsonEvent["debut"] as? Double,
                   let fin = jsonEvent["fin"] as? Double {
                    var startTime = today!.addingTimeInterval(TimeInterval(Int(debut) * 3600))
                    var endTime = today!.addingTimeInterval(TimeInterval(Int(fin) * 3600))
                    startTime.addTimeInterval(TimeInterval((debut-Double(Int(debut))) * 6000))
                    endTime.addTimeInterval(TimeInterval((fin-Double(Int(fin)))*6000))
                    let event = Event(title: title, description: description, date: today!, startTime: startTime, endTime: endTime)
                    newEvents.append(event)
                    if let taskIndex = tasks.firstIndex(where: {$0.id == id}) {
                                    tasksToRemove.append(tasks[taskIndex])
                                }
                }
            }
            
            if !newEvents.isEmpty {
                print(newEvents)
                if events[selectedDate] != nil {
                    events[selectedDate]?.append(contentsOf: newEvents)
                } else {
                    events[selectedDate] = newEvents
                }
                ContentView.saveEvents(events: events)
                majFreeIntervals()
                for task in tasksToRemove {
                        if let index = tasks.firstIndex(of: task) {
                            tasks.remove(at: index)
                        }
                    }
                
                ContentView.saveTasks(tasks: tasks)
            }
        }

}

struct EventDetailView: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading) {
            Text(event.title)
                .font(.largeTitle)
                .padding(.bottom, 10)
            Text("Description")
                .font(.headline)
            Text(event.description)
                .padding(.bottom, 10)
            Text("Begins at")
                .font(.headline)
            Text(event.startTimeString)
                .padding(.bottom, 10)
            Text("Ends at")
                .font(.headline)
            Text(event.endTimeString)
                .padding(.bottom, 10)
            Spacer()
        }
        .padding()
        .navigationBarTitle("Event details", displayMode: .inline)
    }
}

struct AddTaskView: View {
    @Binding var tasks: [Task]
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var description = ""
    @State private var priority: Priority = .normal
    @State private var queryIntervals: [Interval] = [Interval(debut: 0.0, fin: 24.0)] // Initial interval
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task details")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                    Picker(selection: $priority, label: Text("Priority")) {
                        ForEach(Priority.allCases, id: \.self) { priority in
                            Text(priority.rawValue).tag(priority)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section {
                    Button("Add the task") {
                        let newTask = Task(title: title, description: description, priority: priority,updated:false, queryInterval: queryIntervals)
                        tasks.append(newTask)
                        isPresented = false
                    }
                }
            }
            .navigationBarTitle("Add a task")
            .navigationBarItems(trailing: Button("Close") {
                isPresented = false
            })
        }
        
    }
}


struct TaskDetailView: View {
    let task: Task

    var body: some View {
        VStack(alignment: .leading) {
            Text(task.title)
                .font(.largeTitle)
                .padding(.bottom, 10)
            Text("Description")
                .font(.headline)
            Text(task.description)
                .padding(.bottom, 10)
            Text("Priority")
                .font(.headline)
            Text(task.priority.rawValue)
                .foregroundColor(task.priorityColor)
            Spacer()
        }
        .padding()
        .navigationBarTitle("Task details", displayMode: .inline)
    }
}

struct TaskListView: View {
    @Binding var tasks: [Task]
    @State private var showingAddTaskView = false
    @State private var Editing = false
    @State private var selectedTask: Task = Task(title: "", description: "", priority: .normal,updated:false, queryInterval: [])

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Urgent").foregroundColor(.red)) {
                    ForEach(tasks.filter { $0.priority == .urgent }) { task in
                        NavigationLink(destination: TaskDetailView(task: task)) {
                            Text(task.title)
                        }
                        .swipeActions(edge: .leading) {
                            Button(action: {
                                selectedTask = task
                                Editing = true
                            }) {
                                Image(systemName: "pencil")
                            }
                            .tint(.blue)
                        }
                    }.onDelete(perform: deleteTask)
                }
                .sheet(isPresented: $Editing) {
                        EditTaskView(task: $selectedTask, tasks: $tasks, Editing: $Editing)
                }
                Section(header: Text("Normal").foregroundColor(.blue)) {
                    ForEach(tasks.filter { $0.priority == .normal }) { task in
                        NavigationLink(destination: TaskDetailView(task: task)) {
                            Text(task.title)
                        }
                    }.onDelete(perform: deleteTask)
                }
                Section(header: Text("Can wait").foregroundColor(.gray)) {
                    ForEach(tasks.filter { $0.priority == .canWait }) { task in
                        NavigationLink(destination: TaskDetailView(task: task)) {
                            Text(task.title)
                        }
                    }.onDelete(perform: deleteTask)
                }
            }
            .navigationBarTitle("Task list")
            .navigationBarItems(trailing:
                Button(action: {
                    showingAddTaskView.toggle()
                }) {
                    Image(systemName: "plus.circle.fill")
                    .font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/)
                }
            )
            .sheet(isPresented: $showingAddTaskView) {
                AddTaskView(tasks: $tasks, isPresented: $showingAddTaskView)
                    .onDisappear {
                        ContentView.saveTasks(tasks: tasks)
                        sendTasksToServer()
                        // Sauvegarde des tâches lors de la disparition de la vue
                    }
            }
        }
    }
    
    func sendTasksToServer() {
            guard let url = URL(string: "https://beetle-exact-truly.ngrok-free.app/tasks") else {
                print("Invalid URL")
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            do {
                let jsonData = try JSONEncoder().encode(tasks)
                request.httpBody = jsonData
            } catch {
                print("Error encoding tasks: \(error)")
                return
            }

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error: \(error)")
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    print("Invalid response")
                    return
                }

                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Response: \(responseString)")
                }
            }

            task.resume()
        for index in tasks.indices {
                    tasks[index].updated = true
                }
        }
    
    func deleteTaskServer(tasksToDelete: [Task]) {
        guard let url = URL(string: "https://beetle-exact-truly.ngrok-free.app/delete_task") else {
            print("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST" // Utilisez POST pour envoyer les données
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONEncoder().encode(tasksToDelete)
            request.httpBody = jsonData
        } catch {
            print("Error encoding tasks: \(error)")
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Invalid response")
                return
            }

            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString)")
            }

        }

        task.resume()
    }

    
    private func deleteTask(at offsets: IndexSet) {
            let tasksToDelete = offsets.map { tasks[$0] }
            tasks.remove(atOffsets: offsets)
            ContentView.saveTasks(tasks: tasks)
            deleteTaskServer(tasksToDelete: tasksToDelete)
            // Sauvegarder les tâches après la suppression
        }
    
}

struct EditTaskView: View {
    @Binding var task: Task
    @Binding var tasks: [Task]
    @Binding var Editing: Bool
    @State private var title = ""
    @State private var description = ""
    @State private var priority: Priority = .normal
    @State private var queryIntervals: [Interval] = [Interval(debut: 0.0, fin: 24.0)] // Initial interval
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task details")) {
                    TextField("New Title", text: $title)
                    TextField("New Description", text: $description)
                    Picker(selection: $priority, label: Text("Priority")) {
                        ForEach(Priority.allCases, id: \.self) { priority in
                            Text(priority.rawValue).tag(priority)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                
                Section {
                    Button("Edit the task") {
                        task.title = title
                        task.priority = priority
                        if(description != ""){
                            task.description = description
                        }
                        task.updated = false
                        ContentView.saveTasks(tasks:tasks)
                        Editing = false
                    }
                }
            }
            .navigationBarTitle("Edit a task")
            .navigationBarItems(trailing: Button("Close") {
                Editing = false
            })
        }
    }
}

struct FSCalendarView: UIViewRepresentable {
    @Binding var events: [Date: [Event]]
    @Binding var selectedDate: Date
    
    func makeUIView(context: Context) -> FSCalendar {
        let calendar = FSCalendar(frame: .zero)
        calendar.dataSource = context.coordinator
        calendar.delegate = context.coordinator
        calendar.scope = .month
        return calendar
    }
    
    func updateUIView(_ uiView: FSCalendar, context: Context) {
        uiView.reloadData()
        uiView.select(selectedDate)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, FSCalendarDataSource, FSCalendarDelegate {
        var parent: FSCalendarView
        
        init(parent: FSCalendarView) {
            self.parent = parent
        }
        
        func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
            parent.selectedDate = date
        }
        
        func calendar(_ calendar: FSCalendar, numberOfEventsFor date: Date) -> Int {
            return parent.events[date]?.count ?? 0
        }
    }
}

struct AddEventView: View {
    @Binding var events: [Date: [Event]]
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var description = ""
    @State private var startTime = Date()
    @State private var endTime = Date()
    var majFreeIntervals: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Event details")) {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                    DatePicker("Starts at", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Finishes at", selection: $endTime, displayedComponents: .hourAndMinute)
                }
                
                Section {
                    Button("Add the event") {
                        let newEvent = Event(title: title, description: description, date: selectedDate, startTime: startTime, endTime: endTime)
                        if events[selectedDate] != nil {
                            events[selectedDate]?.append(newEvent)
                        } else {
                            events[selectedDate] = [newEvent]
                        }
                        ContentView.saveEvents(events: events)
                        majFreeIntervals()
                        isPresented = false
                    }
                }
            }
            .navigationBarTitle("Add an event")
            .navigationBarItems(trailing: Button("Close") {
                isPresented = false
            })
        }
    }
}

struct Interval: Hashable, Codable {
    var debut: Double
    var fin: Double
}

struct Event: Hashable, Codable {
    var title: String
    var description: String
    var date: Date
    var startTime: Date
    var endTime: Date
    
    var startTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: startTime)
    }
    
    var endTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: endTime)
    }
}

struct Task: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var description: String
    var priority: Priority
    var updated: Bool
    var queryInterval: [Interval]
}

enum Priority: String, CaseIterable, Codable {
    case urgent = "Urgent"
    case normal = "Normal"
    case canWait = "Peut attendre"
}

extension Task {
    var priorityColor: Color {
        switch priority {
        case .urgent:
            return .red
        case .normal:
            return .blue
        case .canWait:
            return .gray
        }
    }
}

extension ContentView {
    static func loadEvents() -> [Date: [Event]] {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: "events"),
           let events = try? decoder.decode([Date: [Event]].self, from: data) {
            return events
        }
        return [:]
    }
    
    static func saveEvents(events: [Date: [Event]]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(events) {
            UserDefaults.standard.set(encoded, forKey: "events")
        }
    }
    
    static func loadTasks() -> [Task] {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: "tasks"),
           let tasks = try? decoder.decode([Task].self, from: data) {
            return tasks
        }
        return []
    }
    
    static func saveTasks(tasks: [Task]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: "tasks")
        }
    }
}
