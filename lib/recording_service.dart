import 'package:record/record.dart';
import 'dart:async';
import 'package:flutter/services.dart';  
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


class RecordingService {
  static final RecordingService _instance = RecordingService._internal();
  factory RecordingService() => _instance;
  RecordingService._internal();

  bool _isRecording = false; 
  String? _currentAudioPath; 
  AudioRecorder _recorder = AudioRecorder(); 

  bool get isRecording => _isRecording; 
  String? get currentAudioPath => _currentAudioPath; 



  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
      'recording_channel', 
      'Recording Notification', 
      description: 'Notification shown during recording',
      importance: Importance.high);


  Future<void> initializeNotifications() async {
     await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);


  }


  Future<void> startRecording(String path) async {
    if (_isRecording) return; 

    try {
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 16000,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );

      _isRecording = true;
      _currentAudioPath = path;


       const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'recording_channel', 
        'Recording Notification', 
        channelDescription: 'Recording in progress',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: true, 
        showWhen: false,
        icon: 'ic_launcher',
      );

      const DarwinNotificationDetails iosNotificationDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false
      );


      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics, iOS: iosNotificationDetails);


      await _flutterLocalNotificationsPlugin.show(
          0, 'Recording...', 'Tap to stop', platformChannelSpecifics);

    } catch (e) {
      print("Start recording error: $e");
      rethrow; 
    }
  }





  Future<void> stopRecording() async {
    if (!_isRecording) return; 

    try {

      await _recorder.stop();

      _isRecording = false;

  
      await _flutterLocalNotificationsPlugin.cancel(0);
    } catch (e) {
      print("Stop recording error: $e");

      rethrow; 
    }
  }



  Future<void> dispose() async {
    try {
      await stopRecording();
      _recorder.dispose();
    } catch (e) {
      print("Error during dispose: $e");
    }
  }
}