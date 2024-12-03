import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'globals.dart' as globals;
import 'database_helper.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';


final dbHelper = DatabaseHelper.instance;

class Notes extends StatefulWidget {
  final int index;
  const Notes({
    Key? key,
    required this.index
  }) : super(key: key);

  @override
  State<Notes> createState() => _NotesState();
}

class _NotesState extends State<Notes> {
  late int index;
  late String titleOfPage;
  String sanitizedName = '';
  late String tableName = '';
  String? audioPath;
  
  late AudioPlayer player;
  late AudioRecorder record;

  @override
  void initState() {
    super.initState();
    player = AudioPlayer();
    record = AudioRecorder();
    index = widget.index;
    titleOfPage = globals.notes[index]['name'];
    globals.initialContent = '';
    _contentInitialiserAndLoader();
    sanitizedName = globals.notes[index]['name'].replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    tableName = 'contentOf_${sanitizedName}_${globals.notes[index]['id']}';
  }

  @override
  void dispose() {
    player.dispose();
    record.dispose();
    super.dispose();
  }

  Future<String> getAudioFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  Future<void> _contentInitialiserAndLoader() async {
    bool itemExists = await dbHelper.tableExists(tableName);
    
    if (!itemExists) {
      await dbHelper.createTableInCurrentDataBase(tableName, ['content']);
      await dbHelper.insertRow(tableName, {'content': ''});
    }
    bool checkIfEmpty = await dbHelper.ifEmpty(tableName);

    if (checkIfEmpty) {
      await dbHelper.insertRow(tableName, {'content': ''});
    }

    globals.initialContent = (await dbHelper.readAll(tableName))[0]['content'];
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> startRecording() async {
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      audioPath = await getAudioFilePath();
      if (audioPath != null) {
        await record.start(RecordConfig(), path: audioPath!);
        setState(() {
          globals.isMicOn = true;
        });
      }
    } else {
      // Handle permission denial
    }
  }


  Future<void> stopRecording() async {
    try {
      await record.stop();
      if (mounted) {
        setState(() {
          globals.isMicOn = false;
        });
      }
      
      if (audioPath != null && await File(audioPath!).exists()) {
        await player.play(DeviceFileSource(audioPath!));
      } else {
        print('File not found at path: $audioPath');
      }
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titleOfPage)
      ),
      body: Stack(
        children:[ 
          TextField(
            keyboardType: TextInputType.multiline,
            minLines: 35,
            maxLines: null,
            controller: TextEditingController(text: globals.initialContent),
            onChanged: (val) async {
              await dbHelper.updateRow(tableName, 1, {'content': val});
            }
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.1,
            right: MediaQuery.of(context).size.width/2 - 50,
            child: FloatingActionButton(
              child: Icon(globals.isMicOn ? Icons.mic : Icons.mic_off),
              onPressed: () async {
                if (globals.isMicOn) {
                  await stopRecording();
                } else {
                  await startRecording();
                }
              },
            )
          )
        ]
      )
    );
  }
}