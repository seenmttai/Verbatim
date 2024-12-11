import 'package:flutter/material.dart';
import 'globals.dart' as globals;
import 'note.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class SelectNotes extends StatefulWidget {
  final int index;
  const SelectNotes({
    Key? key,
    required this.index,
  }) : super(key: key);

  @override
  State<SelectNotes> createState() => _SelectNotesState();
}

class _SelectNotesState extends State<SelectNotes> {
  late int index;
  late String titleOfPage;
  Database? _database;

  @override
  void initState() {
    super.initState();
    index = widget.index;
    titleOfPage = globals.subjects[index]['Name'];
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'my_database.db'); // Updated database name

    _database = await openDatabase(path);
    await _loadAndInitialize();
  }

  Future<void> _loadAndInitialize() async {
    await _notesInitializerAndLoader();
    createToggleList();
  }

  Future<void> _notesInitializerAndLoader() async {
    if (_database == null) return;

    String tableName = 'itemList_${globals.subjects[index]['id']}';
    bool tableExists = await _checkTableExists(tableName);

    if (!tableExists) {
      await _createNotesTable(tableName);
    }

    globals.notes = await _database!.query(tableName);
    setState(() {});
  }

  Future<bool> _checkTableExists(String tableName) async {
    final List<Map<String, dynamic>> tables = await _database!.query(
      'sqlite_master',
      where: 'type = ? AND name = ?',
      whereArgs: ['table', tableName],
    );
    return tables.isNotEmpty;
  }

  Future<void> _createNotesTable(String tableName) async {
    await _database!.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        desc TEXT
      )
    ''');
  }

  void createToggleList() {
    globals.subjectToggledList.clear();
    for (int i = 0; i < globals.notes.length; i++) {
      globals.subjectToggledList.add(false);
    }
  }

  void toggleNoteEdit(int index) {
    setState(() {
      globals.subjectToggledList[index] = !globals.subjectToggledList[index];
    });
  }

  Future<void> _addNewNote() async {
    if (_database == null) return;

    String tableName = 'itemList_${globals.subjects[index]['id']}';
    await _database!.insert(tableName, {
      'name': 'Lecture: ${globals.notes.length + 1}',
      'desc': 'Description for new lecture',
    });
    globals.subjectToggledList.add(true);
    await _notesInitializerAndLoader();
  }

  Future<void> _deleteNote(int noteId) async {
    if (_database == null) return;

    String tableName = 'itemList_${globals.subjects[index]['id']}';
    await _database!.delete(tableName, where: 'id = ?', whereArgs: [noteId]);
    await _notesInitializerAndLoader();
  }

  Future<void> _updateNote(
      int noteId, Map<String, dynamic> updatedValues) async {
    if (_database == null) return;

    String tableName = 'itemList_${globals.subjects[index]['id']}';
    await _database!
        .update(tableName, updatedValues, where: 'id = ?', whereArgs: [noteId]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titleOfPage),
      ),
      body: Column(
        children: [
          Expanded(
            child: globals.notes.isEmpty
                ? const Center(child: Text('No notes added yet'))
                : ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: globals.notes.length,
                    itemBuilder: (context, index) {
                      if (globals.subjectToggledList[index] != true) {
                        return ListTile(
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(globals.notes[index]['name'] ??
                                    'Unnamed Note'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red),
                                onPressed: () async {
                                  await _deleteNote(globals.notes[index]['id']);
                                },
                              ),
                            ],
                          ),
                          subtitle: Text(globals.notes[index]['desc'] ?? ''),
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => Notes(
                                        subjectIndex: this.index,
                                        index: index)));
                          },
                          onLongPress: () {
                            toggleNoteEdit(index);
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
                                TextField(
                                  controller: TextEditingController(
                                      text: globals.notes[index]['name']),
                                  decoration: const InputDecoration(
                                    labelText: 'Note Name',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    isDense: true,
                                  ),
                                  onChanged: (val) async {
                                    await _updateNote(
                                      globals.notes[index]['id'],
                                      {'name': val},
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: TextEditingController(
                                      text: globals.notes[index]['desc']),
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
                                    await _updateNote(
                                      globals.notes[index]['id'],
                                      {'desc': val},
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                IconButton(
                                  icon: const Icon(Icons.check,
                                      color: Colors.green),
                                  onPressed: () async {
                                    setState(() {
                                      globals.subjectToggledList[index] = false;
                                    });
                                    await _notesInitializerAndLoader();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: _addNewNote,
              icon: const Icon(Icons.add),
              label: const Text('Add Note'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}