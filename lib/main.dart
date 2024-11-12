import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: TaskListScreen(),
    );
  }
}

class Task {
  String id;
  String title;
  bool isCompleted;
  String day; // New field for the day of the week
  String timeSlot; // New field for the time slot

  Task({
    required this.id,
    required this.title,
    this.isCompleted = false,
    required this.day,
    required this.timeSlot,
  });

  factory Task.fromMap(Map<String, dynamic> data, String documentId) {
    return Task(
      id: documentId,
      title: data['title'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      day: data['day'] ?? '',
      timeSlot: data['timeSlot'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'isCompleted': isCompleted,
      'day': day,
      'timeSlot': timeSlot,
    };
  }
}

class TaskListScreen extends StatelessWidget {
  final CollectionReference tasksCollection =
      FirebaseFirestore.instance.collection('tasks');

  // Add a task
  Future<void> addTask(String title, String day, String timeSlot) async {
    final task = Task(id: '', title: title, day: day, timeSlot: timeSlot);
    await tasksCollection.add(task.toMap());
  }

  // Get tasks from Firestore
  Stream<List<Task>> getTasks() {
    return tasksCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Task.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  // Update task's completion status
  Future<void> updateTask(String taskId, bool isCompleted) async {
    await tasksCollection.doc(taskId).update({'isCompleted': isCompleted});
  }

  // Delete a task
  Future<void> deleteTask(String taskId) async {
    await tasksCollection.doc(taskId).delete();
  }

  // Show dialog to add a task
  Future<void> addTaskDialog(BuildContext context) async {
    final controller = TextEditingController();
    String day = 'Monday'; // Default to Monday
    String timeSlot = '9 am - 10 am'; // Default time slot

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Task'),
          content: Column(
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(hintText: 'Enter task title'),
              ),
              TextField(
                controller: TextEditingController(text: day),
                decoration: InputDecoration(hintText: 'Enter day (e.g., Monday)'),
                onChanged: (value) {
                  day = value;
                },
              ),
              TextField(
                controller: TextEditingController(text: timeSlot),
                decoration: InputDecoration(hintText: 'Enter time slot (e.g., 9 am - 10 am)'),
                onChanged: (value) {
                  timeSlot = value;
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Add'),
              onPressed: () {
                addTask(controller.text, day, timeSlot);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Task Manager'),
      ),
      body: StreamBuilder<List<Task>>(
        stream: getTasks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No tasks available.'));
          }

          // Group tasks by day
          final tasks = snapshot.data!;
          Map<String, List<Task>> groupedTasks = {};
          for (var task in tasks) {
            if (!groupedTasks.containsKey(task.day)) {
              groupedTasks[task.day] = [];
            }
            groupedTasks[task.day]!.add(task);
          }

          return ListView(
            children: groupedTasks.entries.map((entry) {
              String day = entry.key;
              List<Task> tasksForDay = entry.value;

              return ExpansionTile(
                title: Text(day),
                children: tasksForDay.map((task) {
                  return ListTile(
                    title: Text(
                      task.title,
                      style: TextStyle(
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none),
                    ),
                    subtitle: Text(task.timeSlot),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        deleteTask(task.id);
                      },
                    ),
                    onTap: () {
                      updateTask(task.id, !task.isCompleted);
                    },
                  );
                }).toList(),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => addTaskDialog(context),
        child: Icon(Icons.add),
      ),
    );
  }
}
