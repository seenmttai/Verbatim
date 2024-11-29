import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'globals.dart' as globals;
import 'selectNotes.dart';

final dbHelper = DatabaseHelper.instance;




void main() {
  if (kIsWeb) {
    throw UnsupportedError('Web is not supported yet.');
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const MainApp());

}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
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
    _loadAndInitialize();
  }

  Future<void> _loadAndInitialize() async {
    await _loadSubjects();
    createToggleList();
  }

    void createToggleList(){
    print('I am in createToggleList!');
    print(globals.numberOfSubjects);
    globals.subjectToggledList.clear();
    for(int i=0;i<globals.numberOfSubjects;i++){
      globals.subjectToggledList.add(false);}
    print(globals.subjectToggledList);
  }

  Future<void> _loadSubjects() async {
    bool exists = await dbHelper.tableExists('SubjectList');
    if (!exists) {
      await dbHelper.createSubjectTable();
    }
    globals.subjects = await dbHelper.readAll('SubjectList');
    globals.numberOfSubjects = globals.subjects.length;
    setState(() {
      _subjects = globals.subjects;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                                    await dbHelper.deleteRowById(
                                        'SubjectList',
                                        _subjects[index]['id']);
                                    await _loadSubjects();
                                  },
                                ),
                              ],
                            ),
                            subtitle: Text(_subjects[index]['Desc'] ?? ''),
                            onTap: () {
                              print('Tapped item $index');
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
                              print('Long tapped item $index');
                              toggleSubjectEdit(index);
                            },
                          );
                        } else {
                                                    return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Name TextField
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
                                      await dbHelper.updateRow(
                                        'SubjectList',
                                        _subjects[index]['id'],
                                        {'Name': val},
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  // Description TextField
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
                                      await dbHelper.updateRow(
                                        'SubjectList',
                                        _subjects[index]['id'],
                                        {'Desc': val},
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  // Done button
                                  IconButton(
                                    icon: const Icon(Icons.check,
                                        color: Colors.green),
                                    onPressed: () async {
                                      setState(() {
                                        globals.subjectToggledList[index] = false;
                                      });
                                      await _loadSubjects();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );}
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
    createToggleList();
    await dbHelper.insertRow('SubjectList', {
      'Name': 'New Subject ${_subjects.length + 1}',
      'Desc': 'Description for new subject',
      'Img': ''
    });
    globals.subjectToggledList.add(true);
    await _loadSubjects();
  }

  void toggleSubjectEdit(int index) {
    setState(() {
      globals.subjectToggledList[index] = !globals.subjectToggledList[index];
    });
  }
}