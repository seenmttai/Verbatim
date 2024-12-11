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
import 'recording_service.dart';
import 'apiKeyPrompt.dart';
import 'package:markdown_editor_plus/markdown_editor_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class Notes extends StatefulWidget {
  final int index;
  final int subjectIndex;
  const Notes({Key? key, required this.subjectIndex, required this.index})
      : super(key: key);

  @override
  State<Notes> createState() => _NotesState();
}

class _NotesState extends State<Notes> with WidgetsBindingObserver {
  late RecordingService _recordingService;
  String? audioPath;
  bool _isTranscribing = false;

  late int index;
  String titleOfPage = '';
  String sanitizedName = '';
  String sanitizedSubjectName = '';
  late String tableName = '';
  late int subjectIndex;
  final TextEditingController _textController = TextEditingController();
  Database? _database;
  bool _isLoading = true;

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
    _recordingService = GetIt.instance<RecordingService>();
    WidgetsBinding.instance.addObserver(this);
    _initData();
  }

  Future<void> _initData() async {
    await _initDatabase();
    await _initializeComponents();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, 'my_database.db');

    _database = await openDatabase(
      path,
    );
  }

  Future<void> _initializeComponents() async {
    index = widget.index;
    subjectIndex = widget.subjectIndex;
    titleOfPage = globals.notes[index]['name'];
    sanitizedName = globals.notes[index]['name']
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    sanitizedSubjectName = globals.subjects[subjectIndex]['Name']
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    tableName = 'contentOf_${sanitizedSubjectName}_${sanitizedName}_'
        '${globals.notes[index]['id']}';

    await createAPITable();
    await _contentInitialiserAndLoader();
  }

  Future<void> createAPITable() async {
    if (_database == null) return;
    bool apiTableExists = await _checkTableExists('APITable');
    if (!apiTableExists) {
      await _createAPITableInDatabase();
    }
    bool noApi = await _checkIfAPITableEmpty();
    if (noApi) {
      globals.test = false;
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ApiKeyPrompt()),
        );
      }
    }
    globals.APIKey = (await _getAPIKeyFromTable())[0]['APIKey'];
  }

  Future<bool> _checkTableExists(String tableName) async {
    final List<Map<String, dynamic>> tables = await _database!.query(
      'sqlite_master',
      where: 'type = ? AND name = ?',
      whereArgs: ['table', tableName],
    );
    return tables.isNotEmpty;
  }

  Future<void> _createAPITableInDatabase() async {
    await _database!.execute('''
      CREATE TABLE APITable (
        APIKey TEXT
      )
    ''');
  }

  Future<bool> _checkIfAPITableEmpty() async {
    final result = await _database!.query('APITable');
    return result.isEmpty;
  }

  Future<List<Map<String, dynamic>>> _getAPIKeyFromTable() async {
    return await _database!.query('APITable');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_recordingService.isRecording) {
      if (state == AppLifecycleState.resumed) {
        setState(() {});
      }
    }
  }

  Future<void> _contentInitialiserAndLoader() async {
    if (_database == null) return;
    bool itemExists = await _checkTableExists(tableName);

    if (!itemExists) {
      await _createContentTable(tableName);
      await _insertInitialContent(tableName, {'content': ''});
    }
    String initialContent =
        (await _getContentFromTable(tableName))[0]['content'];
    _textController.text = initialContent;
  }

  Future<void> _createContentTable(String tableName) async {
    await _database!.execute('''
      CREATE TABLE $tableName (
        content TEXT
      )
    ''');
  }

  Future<void> _insertInitialContent(
      String tableName, Map<String, dynamic> row) async {
    await _database!.insert(tableName, row);
  }

  Future<List<Map<String, dynamic>>> _getContentFromTable(
      String tableName) async {
    return await _database!.query(tableName);
  }

  Future<String?> getAudioFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  Future<void> startRecording() async {
    var micPermission = await Permission.microphone.request();
    var storagePermission = await Permission.storage.request();

    if (!micPermission.isGranted || !storagePermission.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Required permissions not granted')));
      return;
    }
    try {
      audioPath = await getAudioFilePath();
      if (audioPath != null) {
        await _recordingService.startRecording(audioPath!);
        setState(() {
          globals.isMicOn = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Recording started'),
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')));
    }
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
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to stop recording: $e')));
    }
  }

  Future<void> _transcribeAudioWithGemini({required String prompt}) async {
    if (audioPath == null || !await File(audioPath!).exists()) {
      _showErrorSnackbar('No audio recorded');
      return;
    }

    setState(() {
      _isTranscribing = true;
    });

    try {
      final File audioFile = File(audioPath!);
      List<int> audioBytes = await audioFile.readAsBytes();

      final response = await http.post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$_selectedModel:generateContent?key=${globals.APIKey}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
                {
                  'inline_data': {
                    'mime_type': 'audio/mp4',
                    'data': base64Encode(audioBytes)
                  }
                }
              ]
            }
          ]
        }),
      );

      setState(() {
        _isTranscribing = false;
      });

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        String? transcription = responseBody['candidates'][0]['content']
            ['parts'][0]['text'];

        if (transcription != null) {
          _updateContentWithTranscription(transcription);
        } else {
          _showErrorSnackbar('No transcription received');
        }
      } else {
        _showErrorSnackbar(
            'Transcription failed:${response.body} ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isTranscribing = false;
      });
      _showErrorSnackbar('Transcription error: $e');
    }
  }

  Future<void> _continueTranscribingAudio({required String prompt}) async {
    if (audioPath == null || !await File(audioPath!).exists()) {
      _showErrorSnackbar('No audio recorded');
      return;
    }
    String memory = (await _getContentFromTable(tableName))[0]['content'];

    setState(() {
      _isTranscribing = true;
    });

    try {
      final File audioFile = File(audioPath!);
      List<int> audioBytes = await audioFile.readAsBytes();

      final response = await http.post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$_selectedModel:generateContent?key=${globals.APIKey}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [
            {
              'parts': [
                {
                  'text':
                      'The current audio given is continution of previous audio, whose transcription was $memory \n\n Now, $prompt'
                },
                {
                  'inline_data': {
                    'mime_type': 'audio/mp4',
                    'data': base64Encode(audioBytes)
                  }
                }
              ]
            }
          ]
        }),
      );
      setState(() {
        _isTranscribing = false;
      });

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        String? transcription = responseBody['candidates'][0]['content']
            ['parts'][0]['text'];

        if (transcription != null) {
          _updateContentWithTranscription(transcription);
        } else {
          _showErrorSnackbar('No transcription received');
        }
      } else {
        _showErrorSnackbar(
            'Transcription failed:${response.body} ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isTranscribing = false;
      });
      _showErrorSnackbar('Transcription error: $e');
    }
  }

  void _updateContentWithTranscription(String transcription) async {
    if (_database == null) return;
    String currentContent = _textController.text;
    String updatedContent =
        '$currentContent\n\n[Transcription ${DateTime.now().toString()}]:\n$transcription';

    await _updateContentInTable(tableName, {'content': updatedContent});
    setState(() {
      _textController.text = updatedContent;
    });
  }

  Future<void> _updateContentInTable(
      String tableName, Map<String, dynamic> updatedValues) async {
    await _database!.update(tableName, updatedValues);
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    ));
  }

  void _showModelSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select AI Model'),
          content: SingleChildScrollView(
            child: Column(
              children: _availableModels
                  .map((model) => ListTile(
                        title: Text(model),
                        selected: model == _selectedModel,
                        onTap: () {
                          setState(() {
                            _selectedModel = model;
                          });
                          Navigator.of(context).pop();
                        },
                      ))
                  .toList(),
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
    _database?.close();
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
      child: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.blue.shade300,
                title:
                    Text(titleOfPage, style: TextStyle(color: Colors.white)),
                actions: [
                  IconButton(
                    icon: Icon(Icons.model_training, color: Colors.white),
                    onPressed: _showModelSelectionDialog,
                    tooltip: 'Select AI Model (Current: $_selectedModel)',
                  ),
                  IconButton(
                    icon: Icon(Icons.info_outline, color: Colors.white),
                    onPressed: () {
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
                                Navigator.of(context).pop();
                              },
                              child: Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.key, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ApiKeyPrompt()));
                    },
                    tooltip: 'Change API Key',
                  ),
                ],
              ),
              body: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: MarkdownAutoPreview(
                          controller: _textController,
                          minLines: null,
                          maxLines: null,
                          style: TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0)),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            hintText: 'Start typing your notes...',
                            hintStyle: TextStyle(color: Colors.grey),
                          ),
                          onChanged: (val) async {
                            if (_database == null) return;
                            await _updateContentInTable(
                                tableName, {'content': val});
                          },
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: Offset(0, -3),
                            ),
                          ],
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20))),
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          FloatingActionButton(
                            heroTag: 'micButton',
                            backgroundColor: globals.isMicOn
                                ? Colors.red.shade300
                                : Colors.blue.shade300,
                            child: Icon(
                              globals.isMicOn ? Icons.mic : Icons.mic_off,
                              color: Colors.white,
                            ),
                            onPressed: () async {
                              if (globals.isMicOn) {
                                await stopRecording();
                              } else {
                                await startRecording();
                              }
                            },
                            tooltip: globals.isMicOn
                                ? 'Stop Recording'
                                : 'Start Recording',
                          ),
                          GestureDetector(
                              onLongPress: _isTranscribing
                                  ? null
                                  : () {
                                      _continueTranscribingAudio(
                                          prompt:
                                              'Write detailed notes of the given audio as a student might, organizing the content clearly and maintaining all technical accuracy. Include all information from the audio without omitting anything.');
                                    },
                              child: FloatingActionButton(
                                heroTag: 'studentNotesButton',
                                backgroundColor: _isTranscribing
                                    ? Colors.grey
                                    : Colors.blue.shade300,
                                child: _isTranscribing
                                    ? CircularProgressIndicator(
                                        color: Colors.white)
                                    : Icon(Icons.school, color: Colors.white),
                                onPressed: _isTranscribing
                                    ? null
                                    : () {
                                        _transcribeAudioWithGemini(
                                            prompt:
                                                'Write detailed notes of the given audio as a student might, organizing the content clearly and maintaining all technical accuracy. Include all information from the audio without omitting anything.');
                                      },
                              )),
                          GestureDetector(
                              onLongPress: _isTranscribing
                                  ? null
                                  : () {
                                      _continueTranscribingAudio(
                                          prompt:
                                              'Transcribe this audio with high accuracy, being comfortably multilingual(english and hindi mainly). Include timestamps where context shifts significantly.');
                                    },
                              child: FloatingActionButton(
                                heroTag: 'aiButton',
                                backgroundColor: _isTranscribing
                                    ? Colors.grey
                                    : Colors.blue.shade300,
                                child: _isTranscribing
                                    ? CircularProgressIndicator(
                                        color: Colors.white)
                                    : Icon(Icons.auto_fix_high,
                                        color: Colors.white),
                                onPressed: _isTranscribing
                                    ? null
                                    : () {
                                        _transcribeAudioWithGemini(
                                            prompt:
                                                'Transcribe this audio with high accuracy, being comfortably multilingual(english and hindi mainly). Include timestamps where context shifts significantly.');
                                      },
                              )),
                        ],
                      ),
                    ),
                    if (globals.isMicOn)
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.fiber_manual_record,
                                color: Colors.red, size: 16),
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