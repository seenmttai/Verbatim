import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'globals.dart' as globals;
import 'selectNotes.dart';
import 'package:get_it/get_it.dart';
import 'recording_service.dart';
import 'apiKeyPrompt.dart';

final dbHelper = DatabaseHelper.instance;

void setupServiceLocator() {
  print("[DEBUG] setupServiceLocator: Starting service locator setup");
  GetIt.instance.registerLazySingleton(() => RecordingService());
  print("[DEBUG] setupServiceLocator: RecordingService registered");
  print("[DEBUG] setupServiceLocator: Service locator setup complete");
}

void main() {
  print("[DEBUG] main: Starting application");
  WidgetsFlutterBinding.ensureInitialized();
  print("[DEBUG] main: WidgetsFlutterBinding initialized");
  setupServiceLocator();
  print("[DEBUG] main: Service locator setup called");

  if (kIsWeb) {
    print("[DEBUG] main: Running on Web - throwing UnsupportedError");
    throw UnsupportedError('Web is not supported yet.');
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    print(
        "[DEBUG] main: Running on Windows, Linux, or macOS - initializing sqflite FFI");
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    print("[DEBUG] main: sqflite FFI initialized, databaseFactory set");
  }

  print("[DEBUG] main: Running runApp");
  runApp(const MainApp());
  print("[DEBUG] main: runApp executed");
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    print("[DEBUG] MainApp.build: Building MainApp");
    return const MaterialApp(
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _subjects = [];

  @override
  void initState() {
    super.initState();
    print("[DEBUG] HomePageState.initState: Initializing HomePageState");
    _loadAndInitialize();
    print(
        "[DEBUG] HomePageState.initState: _loadAndInitialize completed, HomePageState initialized");
  }

  Future<void> _loadAndInitialize() async {
    print(
        "[DEBUG] HomePageState._loadAndInitialize: Starting _loadAndInitialize");
    await _loadSubjects();
    print(
        "[DEBUG] HomePageState._loadAndInitialize: _loadSubjects completed, creating toggle list");
    createToggleList();
    print(
        "[DEBUG] HomePageState._loadAndInitialize: createToggleList completed");
    print("[DEBUG] HomePageState._loadAndInitialize: _loadAndInitialize complete");
  }

  void createToggleList() {
    print('[DEBUG] HomePageState.createToggleList: Creating toggle list');
    print(
        '[DEBUG] HomePageState.createToggleList: Current number of subjects: ${globals.numberOfSubjects}');
    globals.subjectToggledList.clear();
    for (int i = 0; i < globals.numberOfSubjects; i++) {
      globals.subjectToggledList.add(false);
    }
    print(
        '[DEBUG] HomePageState.createToggleList: Toggle list created: ${globals.subjectToggledList}');
  }

  Future<void> _loadSubjects() async {
    print("[DEBUG] HomePageState._loadSubjects: Loading subjects");
    bool exists = await dbHelper.tableExists('SubjectList');
    print(
        "[DEBUG] HomePageState._loadSubjects: SubjectList table exists: $exists");
    if (!exists) {
      print(
          "[DEBUG] HomePageState._loadSubjects: SubjectList table does not exist, creating table");
      await dbHelper.createSubjectTable();
      print(
          "[DEBUG] HomePageState._loadSubjects: SubjectList table created successfully");
    }
    globals.subjects = await dbHelper.readAll('SubjectList');
    print(
        "[DEBUG] HomePageState._loadSubjects: Subjects loaded: ${globals.subjects}");
    globals.numberOfSubjects = globals.subjects.length;
    print(
        "[DEBUG] HomePageState._loadSubjects: Number of subjects: ${globals.numberOfSubjects}");
    setState(() {
      _subjects = globals.subjects;
    });
    print("[DEBUG] HomePageState._loadSubjects: State updated with new subjects");
  }

  @override
  Widget build(BuildContext context) {
    print("[DEBUG] HomePageState.build: Building HomePage");
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Subject',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 2, 105, 6),
            fontFamily: 'Roboto',
            letterSpacing: 2,
            wordSpacing: 3,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: Column(
        children: [
          Expanded(
            child: _subjects.isEmpty
                ? const Center(child: Text('No subjects added yet'))
                : ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _subjects.length,
                    itemBuilder: (context, index) {
                      print(
                          "[DEBUG] HomePageState.build: Building ListTile for subject index: $index");
                      if (_subjects.isNotEmpty) {
                        if (globals.subjectToggledList[index] != true) {
                          return ListTile(
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(_subjects[index]['Name'] ??
                                      'Unnamed Subject'),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () async {
                                    print(
                                        "[DEBUG] HomePageState.build: Delete button pressed for subject index: $index");
                                    await dbHelper.deleteRowById(
                                        'SubjectList',
                                        _subjects[index]['id']);
                                    print(
                                        "[DEBUG] HomePageState.build: Subject deleted, reloading subjects");
                                    await _loadSubjects();
                                    print(
                                        "[DEBUG] HomePageState.build: Subjects reloaded after deletion");
                                  },
                                ),
                              ],
                            ),
                            subtitle: Text(_subjects[index]['Desc'] ?? ''),
                            onTap: () {
                              print(
                                  '[DEBUG] HomePageState.build: Tapped item $index');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      SelectNotes(index: index),
                                ),
                              );
                            },
                            onLongPress: () {
                              createToggleList();
                              print(
                                  '[DEBUG] HomePageState.build: Long tapped item $index');
                              toggleSubjectEdit(index);
                            },
                          );
                        } else {
                          print(
                              "[DEBUG] HomePageState.build: Building editable Card for subject index: $index");
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  TextField(
                                    controller: TextEditingController(
                                        text: _subjects[index]['Name']),
                                    decoration: const InputDecoration(
                                      labelText: 'Subject Name',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      isDense: true,
                                    ),
                                    onChanged: (val) async {
                                      print(
                                          "[DEBUG] HomePageState.build: Subject name changed for index: $index");
                                      await dbHelper.updateRow(
                                        'SubjectList',
                                        _subjects[index]['id'],
                                        {'Name': val},
                                      );
                                      print(
                                          "[DEBUG] HomePageState.build: Subject name updated in database");
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: TextEditingController(
                                        text: _subjects[index]['Desc']),
                                    decoration: const InputDecoration(
                                      labelText: 'Description',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      isDense: true,
                                    ),
                                    onChanged: (val) async {
                                      print(
                                          "[DEBUG] HomePageState.build: Subject description changed for index: $index");
                                      await dbHelper.updateRow(
                                        'SubjectList',
                                        _subjects[index]['id'],
                                        {'Desc': val},
                                      );
                                      print(
                                          "[DEBUG] HomePageState.build: Subject description updated in database");
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  // Done button
                                  IconButton(
                                    icon: const Icon(Icons.check,
                                        color: Colors.green),
                                    onPressed: () async {
                                      print(
                                          "[DEBUG] HomePageState.build: Done button pressed for subject index: $index");
                                      setState(() {
                                        globals.subjectToggledList[index] =
                                            false;
                                      });
                                      print(
                                          "[DEBUG] HomePageState.build: Subject toggle state updated");
                                      await _loadSubjects();
                                      print(
                                          "[DEBUG] HomePageState.build: Subjects reloaded after update");
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      } else {
                        return const Center(
                            child: Text('No subjects added yet'));
                      }
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: _addNewSubject,
              icon: const Icon(Icons.add),
              label: const Text('Add Subject'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addNewSubject() async {
    print("[DEBUG] HomePageState._addNewSubject: Adding new subject");
    createToggleList();
    await dbHelper.insertRow('SubjectList', {
      'Name': 'New Subject ${_subjects.length + 1}',
      'Desc': 'Description for new subject',
      'Img': ''
    });
    globals.subjectToggledList.add(true);
    print(
        "[DEBUG] HomePageState._addNewSubject: New subject added, reloading subjects");
    await _loadSubjects();
    print(
        "[DEBUG] HomePageState._addNewSubject: Subjects reloaded after adding new subject");
  }

  void toggleSubjectEdit(int index) {
    print(
        "[DEBUG] HomePageState.toggleSubjectEdit: Toggling edit mode for subject index: $index");
    setState(() {
      globals.subjectToggledList[index] = !globals.subjectToggledList[index];
    });
    print(
        "[DEBUG] HomePageState.toggleSubjectEdit: Edit mode toggled, new state: ${globals.subjectToggledList[index]}");
  }
}