import 'package:flutter/material.dart';
import 'globals.dart' as globals;
import 'database_helper.dart';
import 'note.dart';

final dbHelper = DatabaseHelper.instance;

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

  @override
  void initState() {
    super.initState();
    index = widget.index;
    titleOfPage = globals.subjects[index]['Name'];
    _loadAndInitialize();
  }

  Future<void> _loadAndInitialize() async {
    await _notesInitialiserAndLoader();
    createToggleList();
  }

  Future<void> _notesInitialiserAndLoader() async {
    String tableName = 'itemList_${globals.subjects[index]['id']}';
    bool itemExists = await dbHelper.tableExists(tableName);
    
    if (!itemExists) {
      await dbHelper.createTableInCurrentDataBase(tableName, ['name', 'desc']);
    }
    
    globals.notes = await dbHelper.readAll(tableName);
    setState(() {});
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
    String tableName = 'itemList_${globals.subjects[index]['id']}';
    await dbHelper.insertRow(tableName, {
      'name': 'Lecture: ${globals.notes.length + 1}',
      'desc': 'Description for new lecture',
    });
    globals.subjectToggledList.add(true);
    await _notesInitialiserAndLoader();
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
                                  String tableName = 'itemList_${globals.subjects[this.index]['id']}';
                                  await dbHelper.deleteRowById(
                                      tableName,
                                      globals.notes[index]['id']);
                                  await _notesInitialiserAndLoader();
                                },
                              ),
                            ],
                          ),
                          subtitle: Text(globals.notes[index]['desc'] ?? ''),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => Notes(subjectIndex: this.index, index: index))
                            );
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
                                    String tableName = 'itemList_${globals.subjects[this.index]['id']}';
                                    await dbHelper.updateRow(
                                      tableName,
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
                                    String tableName = 'itemList_${globals.subjects[this.index]['id']}';
                                    await dbHelper.updateRow(
                                      tableName,
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
                                    await _notesInitialiserAndLoader();
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