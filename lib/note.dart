import 'package:flutter/material.dart';
import 'package:organiser/main.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:get_it/get_it.dart';
import 'globals.dart' as globals;
import 'database_helper.dart';
import 'recording_service.dart';
import 'apiKeyPrompt.dart';
import 'package:markdown_editor_plus/markdown_editor_plus.dart';


class Notes extends StatefulWidget {
  final int index;
  final int subjectIndex;
  const Notes({Key? key, required this.subjectIndex, required this.index}) 
      : super(key: key);

  @override
  State<Notes> createState() => _NotesState();
}

class _NotesState extends State<Notes> with WidgetsBindingObserver {

  // Recording related variables
  late RecordingService _recordingService;
  String? audioPath;
  bool _isTranscribing = false;

  // Database and content related variables
  late int index;
  late String titleOfPage;
  String sanitizedName = '';
  String sanitizedSubjectName = '';
  late String tableName = '';
  late int subjectIndex;
  final TextEditingController _textController = TextEditingController();

  // List of models
  String _selectedModel = 'gemini-1.5-pro';
  final List<String> _availableModels = [
    'gemini-exp-1121',
    'gemini-exp-1114',
    'gemini-exp-1206',
    'learnlm-1.5-pro-experimental',
    'gemini-1.5-pro',
    'gemini-1.5-flash-8b',
    'gemini-1.5-flash'
  ];

  @override
  void initState() {
    super.initState();
    createAPITable();
    _recordingService = GetIt.instance<RecordingService>();
    WidgetsBinding.instance.addObserver(this);
    _initializeComponents();
  }

  Future<void> _initializeComponents() async {
    print('debug 1');
    index = widget.index;
    subjectIndex = widget.subjectIndex;
    titleOfPage = globals.notes[index]['name'];
    sanitizedName = globals.notes[index]['name']
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    sanitizedSubjectName = globals.subjects[subjectIndex]['Name']
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    tableName = 'contentOf_${sanitizedSubjectName}_${sanitizedName}_'
        '${globals.notes[index]['id']}';
    print('debug 2');
    
    await _contentInitialiserAndLoader();
  }

  Future<void> createAPITable() async {
    bool apiTableExists= await dbHelper.tableExists('APITable');
    print('debug 3');
    print(apiTableExists);
    if(!apiTableExists){
      dbHelper.createTableInCurrentDataBase('APITable', ['APIKey']);
    }
    print('debug 4');
    bool noApi= await dbHelper.ifEmpty('APITable');
    print('debug 5');
    print(noApi);
    if(noApi){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ApiKeyPrompt())
      );
    }
    print('debug 6');
    globals.APIKey= (await dbHelper.readAll('APITable'))[0]['APIKey'];
    List<Map<String,dynamic>> tableAPIKey=(await dbHelper.readAll('APITable'));
    print('I am checking');
    print(tableAPIKey);
    print(globals.APIKey);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('debug 7');
    super.didChangeAppLifecycleState(state);
    if (_recordingService.isRecording) {
      if (state == AppLifecycleState.resumed) {
        setState(() {}); 
      }
    }
    print('debug 8');
  }



  Future<void> _contentInitialiserAndLoader() async {
    final dbHelper = DatabaseHelper.instance;
    bool itemExists = await dbHelper.tableExists(tableName);

    if (!itemExists) {
      await dbHelper.createTableInCurrentDataBase(tableName, ['content']);
      await dbHelper.insertRow(tableName, {'content': ''});
    }
    print('debug 9');
    String initialContent = (await dbHelper.readAll(tableName))[0]['content'];
    _textController.text = initialContent;
    
    if (mounted) {
      setState(() {});
    }
    print('debug 10');
  }

  Future<String?> getAudioFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
    print('debug 11');
  }

  Future<void> startRecording() async {
    print('debug 12');
    var micPermission = await Permission.microphone.request();
    var storagePermission = await Permission.storage.request();
    print('debug 13');
    
    if (!micPermission.isGranted || !storagePermission.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Required permissions not granted'))
      );
      return;
    }
    print('debug 14');
    try {
      audioPath = await getAudioFilePath();
      if (audioPath != null) {
        await _recordingService.startRecording(audioPath!);
        setState(() {
          globals.isMicOn = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording started with high quality settings'),
            duration: Duration(seconds: 2),
          )
        );
      }
    } catch (e) {
      print('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start recording: $e'))
      );
    }
    print('debug 15');
  }

  Future<void> stopRecording() async {
    try {
      await _recordingService.stopRecording();
      setState(() {
        globals.isMicOn = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recording stopped'),
          duration: Duration(seconds: 2),
        )
      );
    } catch (e) {
      print('Error stopping recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to stop recording: $e'))
      );
    }
    print('debug 16');
  }


  Future<void> _transcribeAudioWithGemini({required String prompt}) async {
    print('debug 17');
    if (audioPath == null || !await File(audioPath!).exists()) {
      _showErrorSnackbar('No audio recorded');
      return;
    }


    setState(() {
      _isTranscribing = true;
    });

    print('debug 18');

    try {
      final File audioFile = File(audioPath!);
      List<int> audioBytes = await audioFile.readAsBytes();
      
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_selectedModel:generateContent?key=${globals.APIKey}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [{
            'parts': [
              {'text': prompt},
              {
                'inline_data': {
                  'mime_type': 'audio/mp4',
                  'data': base64Encode(audioBytes)
                }
              }
            ]
          }]
        }),
      );
      print('debug 19');

      setState(() {
        _isTranscribing = false;
      });

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        String? transcription = responseBody['candidates'][0]['content']['parts'][0]['text'];
        print('debug 20');
        
        if (transcription != null) {
          _updateContentWithTranscription(transcription);
        } else {
          _showErrorSnackbar('No transcription received');
        }
      } else {
        print('Gemini API error: ${response.body}');
        _showErrorSnackbar('Transcription failed:${response.body} ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isTranscribing = false;
      });
      _showErrorSnackbar('Transcription error: $e');
      print('debug 21');
    }
  }

  Future<void> _continueTranscribingAudio({required String prompt}) async {
    print('debug 22');
    if (audioPath == null || !await File(audioPath!).exists()) {
      _showErrorSnackbar('No audio recorded');
      return;
    }
    String memory= (await dbHelper.readAll(tableName))[0]['content'];

    setState(() {
      _isTranscribing = true;
    });
    print('debug 23');

    try {
      final File audioFile = File(audioPath!);
      List<int> audioBytes = await audioFile.readAsBytes();
      
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_selectedModel:generateContent?key=${globals.APIKey}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [{
            'parts': [
              {'text': 'The current audio given is continution of previous audio, whose transcription was $memory \n\n Now, $prompt'},
              {
                'inline_data': {
                  'mime_type': 'audio/mp4',
                  'data': base64Encode(audioBytes)
                }
              }
            ]
          }]
        }),
      );

      print('debug 24');
      setState(() {
        _isTranscribing = false;
      });

      print('debug 25');
      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        String? transcription = responseBody['candidates'][0]['content']['parts'][0]['text'];
        
        if (transcription != null) {
          _updateContentWithTranscription(transcription);
        } else {
          _showErrorSnackbar('No transcription received');
        }
      } else {
        print('Gemini API error: ${response.body}');
        _showErrorSnackbar('Transcription failed:${response.body} ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isTranscribing = false;
      });
      _showErrorSnackbar('Transcription error: $e');
    }
    print('debug 26');
  }


  void _updateContentWithTranscription(String transcription) async {
    final dbHelper = DatabaseHelper.instance;
    
    String currentContent = _textController.text;
    String updatedContent = '$currentContent\n\n[Transcription ${DateTime.now().toString()}]:\n$transcription';
    
    await dbHelper.updateRow(tableName, 1, {'content': updatedContent});
    print('debug 27');
    setState(() {
      _textController.text = updatedContent;
    });
    print('debug 28');
  }

  void _showErrorSnackbar(String message) {
    print('debug 29');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      )
    );
  }

  void _showModelSelectionDialog() {
    print('debug 30');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select AI Model'),
          content: SingleChildScrollView(
            child: Column(
              children: _availableModels.map((model) => 
                ListTile(
                  title: Text(model),
                  selected: model == _selectedModel,
                  onTap: () {
                    print('debug 31');
                    setState(() {
                      _selectedModel = model;
                    });
                    print('debug 32');
                    Navigator.of(context).pop();
                  },
                )
              ).toList(),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingService.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (globals.isMicOn) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Recording in Progress'),
              content: Text('Stop recording and leave the page?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    print('debug 33');
                    await stopRecording();
                    Navigator.of(context).pop(true);
                  },
                  child: Text('Stop and Leave'),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(titleOfPage),
          actions: [
            IconButton(
              icon: Icon(Icons.model_training),
              onPressed: _showModelSelectionDialog,
              tooltip: 'Select AI Model (Current: $_selectedModel)',
            ),
            IconButton(
              icon: Icon(Icons.info_outline),
              onPressed: () {
                print('debug 34');
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Recording Information'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Audio Quality Settings:'),
                        Text('• Sample Rate: 48kHz'),
                        Text('• Bit Rate: 320kbps'),
                        Text('• Channels: Stereo'),
                        Text('• Format: AAC/M4A'),
                        SizedBox(height: 8),
                        Text('Maximum recording duration: 3 hours'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () { 
                          print('debug 35');
                          Navigator.of(context).pop();
                          },
                        child: Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: MarkdownAutoPreview(
                      controller: _textController,
                      //keyboardType: TextInputType.multiline,
                      minLines: null,
                      maxLines: null,
                      style: TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Start typing your notes...',
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      onChanged: (val) async {
                        print('debug 36');
                        final dbHelper = DatabaseHelper.instance;
                        await dbHelper.updateRow(tableName, 1, {'content': val});
                      },
                    ),
                  ),
                ),
              ),
              Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FloatingActionButton(
                      heroTag: 'micButton',
                      child: Icon(
                        globals.isMicOn ? Icons.mic : Icons.mic_off,
                        color: globals.isMicOn ? Colors.red : null,
                      ),
                      onPressed: () async {
                        print('debug 37');
                        if (globals.isMicOn) {
                          await stopRecording();
                          print('debug 38');
                        } else {
                          await startRecording();
                          print('debug 39');
                        }
                      },
                      tooltip: globals.isMicOn ? 'Stop Recording' : 'Start Recording',
                    ),
                    GestureDetector(
                      onLongPress: _isTranscribing 
                        ? null 
                        : () {
                          _continueTranscribingAudio(
                            prompt: 'Write detailed notes of the given audio as a student might, organizing the content clearly and maintaining all technical accuracy. Include all information from the audio without omitting anything.'
                          );
                          print('debug 40');
                          },
                      child:FloatingActionButton(
                      heroTag: 'studentNotesButton',
                      backgroundColor: _isTranscribing ? Colors.grey : null,
                      child: _isTranscribing 
                        ? CircularProgressIndicator(color: Colors.white)
                        : Icon(Icons.school),
                      onPressed: _isTranscribing 
                        ? null 
                        : () {
                          _transcribeAudioWithGemini(
                            prompt: 'Write detailed notes of the given audio as a student might, organizing the content clearly and maintaining all technical accuracy. Include all information from the audio without omitting anything.'
                          );
                          print('debug 41');
                          },
                    )),
                    GestureDetector(
                      onLongPress: _isTranscribing 
                        ? null 
                        : () {
                          _continueTranscribingAudio(
                            prompt: 'Transcribe this audio with high accuracy, being comfortably multilingual(english and hindi mainly). Include timestamps where context shifts significantly.'
                          );
                          print('debug 42');
                          },
                      child: FloatingActionButton(
                      heroTag: 'aiButton',
                      backgroundColor: _isTranscribing ? Colors.grey : null,
                      child: _isTranscribing 
                        ? CircularProgressIndicator(color: Colors.white)
                        : Icon(Icons.auto_fix_high),
                      onPressed: _isTranscribing 
                        ? null 
                        : () { _transcribeAudioWithGemini(
                            prompt: 'Transcribe this audio with high accuracy, being comfortably multilingual(english and hindi mainly). Include timestamps where context shifts significantly.'
                          );
                          print('debug 43');
                          },
                    )),
                  ],
                ),
              ),
              if (globals.isMicOn)
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  color: Colors.red.withOpacity(0.1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Recording in Progress',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}