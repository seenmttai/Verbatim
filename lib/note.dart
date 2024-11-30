import 'package:flutter/material.dart';
import 'globals.dart' as globals;
import 'database_helper.dart';


final dbHelper = DatabaseHelper.instance;


class Notes extends StatefulWidget {
  final int index;
  const Notes({
    Key? key,
    required this.index
  }) :super (key:key);

  @override
  State<Notes> createState() => _NotesState();
}

class _NotesState extends State<Notes> {
  late int index;
  late String titleOfPage;
  String sanitizedName='';
  late String tableName = '';

  @override
  void initState() {
    super.initState();
    index = widget.index;
    titleOfPage = globals.notes[index]['name'];
    globals.initialContent = '';
    _contentInitialiserAndLoader();
    sanitizedName=globals.notes[index]['name'].replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    tableName = 'contentOf_${sanitizedName}_${globals.notes[index]['id']}';

  }

  Future<void> _contentInitialiserAndLoader() async {
    bool itemExists = await dbHelper.tableExists(tableName);
    
    if (!itemExists) {
      await dbHelper.createTableInCurrentDataBase(tableName, ['content']);
      await dbHelper.insertRow(tableName,{'content':''});
    }
    bool checkIfEmpty= await dbHelper.ifEmpty(tableName);

    if (checkIfEmpty) {
      await dbHelper.insertRow(tableName,{'content':''});
    }

    globals.initialContent = (await dbHelper.readAll(tableName))[0]['content'];
    setState(() {});
  }


  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: Text(titleOfPage)
      ),
      body:  
        Stack(
          children:[ 
          TextField(
            keyboardType: TextInputType.multiline,
            minLines: 35,
            maxLines: null,
            controller: TextEditingController(text: globals.initialContent),
            onChanged: (val) async {
              await dbHelper.updateRow(tableName, 1, {'content':val});
            }
          ),
          Positioned(
            bottom:MediaQuery.of(context).size.height*0.1,
            right: MediaQuery.of(context).size.width/2-50,
            child: globals.isMicOn ? FloatingActionButton(
              child: const Icon(Icons.mic),
              onPressed: (){
                setState(() {
                    globals.isMicOn=false;

                  }
                );
              }
              ) 
              : FloatingActionButton(
                child: const Icon(Icons.mic_off),
                onPressed: (){
                  setState(() {
                    globals.isMicOn=true;
                  });
                }
                )
          )
          ]
        )
    );
  }
}