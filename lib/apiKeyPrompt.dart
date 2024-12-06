import 'package:flutter/material.dart';
import 'package:organiser/main.dart';
import 'note.dart';
import 'globals.dart' as globals;

class ApiKeyPrompt extends StatefulWidget{
  const ApiKeyPrompt({super.key});

  @override
  State<ApiKeyPrompt> createState() => _ApiKeyPromptState();
}

class _ApiKeyPromptState extends State<ApiKeyPrompt>{
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: Text('Enter API Key'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            onChanged: (val) async{
              await dbHelper.insertRow('APITable', {'APIKey': val});
              print("updated value to $val");
              },
          ),
          FloatingActionButton(
            onPressed: () async{
              globals.APIKey=(await dbHelper.readAll('APITable'))[0]['APIKey'];
              print(globals.APIKey);
              Navigator.pop(context);
            }, 
            child: Icon(Icons.check)
            )
        ],
      ),
    );
  }
}