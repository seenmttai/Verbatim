import 'package:flutter/material.dart';
import 'globals.dart' as globals;

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
  @override
  void initState() {
    super.initState();
    index = widget.index;
    titleOfPage = globals.notes[index]['name'];
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
          ),
          Positioned(
            bottom:MediaQuery.of(context).size.height*0.1,
            right: MediaQuery.of(context).size.width*0.1,
            child: FloatingActionButton(
              child: const Icon(Icons.save),
              onPressed: (){
                Navigator.pop(
                  context
                );
              }
              ) 
          )
          ]
        )
    );
  }
}