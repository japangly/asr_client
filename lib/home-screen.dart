import 'dart:async';
import 'dart:io' as io;
import 'dart:io';

import 'package:chunked_stream/chunked_stream.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_audio_recorder/flutter_audio_recorder.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'theme.dart';

const _APP_BAR_SIZE = 160.0;

class HomeSreen extends StatefulWidget {
  const HomeSreen({
    Key key,
    @required this.channel,
  }) : super(key: key);

  final WebSocketChannel channel;

  @override
  _HomeSreenState createState() => _HomeSreenState();
}

class _HomeSreenState extends State<HomeSreen> {
  // ignore: unused_field
  String _alert;

  File _audioFile;
  var _buttonColor = myTheme.primaryColor;
  Widget _buttonIcon = Row(
    children: <Widget>[
      Icon(Icons.mic),
      SizedBox(width: 16.0),
      Text('ចុចដើម្បីនិយាយ'),
    ],
  );

  FlutterAudioRecorder _recorder;
  Recording _recording;
  FilePickerResult _result;
  Timer _t;

  @override
  void dispose() {
    widget.channel.sink.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _prepare();
    });
  }

  void _opt() async {
    switch (_recording.status) {
      case RecordingStatus.Initialized:
        {
          await _startRecording();
          break;
        }
      case RecordingStatus.Recording:
        {
          await _stopRecording();
          break;
        }
      case RecordingStatus.Stopped:
        {
          await _prepare();
          break;
        }

      default:
        break;
    }

    setState(() {
      _buttonIcon = _playerIcon(_recording.status);
      _buttonColor = _playerColor(_recording.status);
    });
  }

  Future _startRecording() async {
    await _recorder.start();
    var current = await _recorder.current();
    setState(() {
      _recording = current;
    });

    _t = Timer.periodic(Duration(milliseconds: 10), (Timer t) async {
      var current = await _recorder.current();
      setState(() {
        _recording = current;
        _t = t;
      });
    });
  }

  Future _stopRecording() async {
    var result = await _recorder.stop();
    _t.cancel();

    setState(() {
      _recording = result;
      _sendMessage(_recording.path);
    });
  }

  Future _prepare() async {
    var hasPermission = await FlutterAudioRecorder.hasPermissions;
    if (hasPermission) {
      await _init();
      var result = await _recorder.current();
      setState(() {
        _recording = result;
        _buttonIcon = _playerIcon(_recording.status);
        _alert = '';
      });
    } else {
      setState(() {
        _alert = 'Permission Required.';
      });
    }
  }

  Widget _playerIcon(RecordingStatus status) {
    switch (status) {
      case RecordingStatus.Initialized:
        {
          return Row(
            children: <Widget>[
              Icon(Icons.mic),
              SizedBox(width: 16.0),
              Text('ចុចដើម្បីនិយាយ'),
            ],
          );
        }
      case RecordingStatus.Recording:
        {
          return Row(
            children: <Widget>[
              Icon(Icons.check),
              SizedBox(width: 16.0),
              Text('បញ្ចប់ការនិយាយ'),
            ],
          );
        }
      case RecordingStatus.Stopped:
        {
          return Row(
            children: <Widget>[
              Icon(Icons.replay),
              SizedBox(width: 16.0),
              Text('និយាយម្តងទៀត'),
            ],
          );
        }
      default:
        return Row(
          children: <Widget>[
            Icon(Icons.mic),
            SizedBox(width: 16.0),
            Text('ចុចដើម្បីនិយាយ'),
          ],
        );
    }
  }

  Color _playerColor(RecordingStatus status) {
    switch (status) {
      case RecordingStatus.Initialized:
        {
          return _buttonColor = myTheme.primaryColor;
        }
      case RecordingStatus.Recording:
        {
          return _buttonColor = myTheme.errorColor;
        }
      case RecordingStatus.Stopped:
        {
          return _buttonColor = Color(0xffF29205);
        }
      default:
        return _buttonColor = myTheme.primaryColor;
    }
  }

  Future _init() async {
    String customPath = '/flutter_audio_recorder_';
    io.Directory appDocDirectory;
    if (io.Platform.isIOS) {
      appDocDirectory = await getApplicationDocumentsDirectory();
    } else {
      appDocDirectory = await getExternalStorageDirectory();
    }

    // can add extension like ".mp4" ".wav" ".m4a" ".aac"
    customPath = appDocDirectory.path +
        customPath +
        DateTime.now().millisecondsSinceEpoch.toString();

    // .wav <---> AudioFormat.WAV
    // .mp4 .m4a .aac <---> AudioFormat.AAC
    // AudioFormat is optional, if given value, will overwrite path extension when there is conflicts.

    _recorder = FlutterAudioRecorder(
      customPath,
      audioFormat: AudioFormat.WAV,
      sampleRate: 16000,
    );
    await _recorder.initialized;
  }

  Future<void> _sendMessage(String filePath) async {
    final reader = ChunkedStreamIterator(File(filePath).openRead());
    // While the reader has a next byte
    while (true) {
      // read one byte
      var data = await reader.read(4000);
      if (data.length == 0) {
        print('End of file reached');
        break;
      }
      print('next byte: ${data[0]}');
      widget.channel.sink.add(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: Text('កម្មវិធីបំលែងសំលេងទៅអត្ថបទ'),
        ),
        actions: [
          IconButton(
            padding: EdgeInsets.all(16.0),
            icon: Icon(Icons.upload_file),
            onPressed: () async {
              _result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['wav'],
              );
              if (_result != null) {
                _audioFile = File(_result.files.single.path);
                _sendMessage(_audioFile.path);
              } else {
                // User canceled the picker
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              height: 256,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: StreamBuilder<Object>(
                    stream: widget.channel.stream,
                    builder: (context, snapshot) {
                      return Text(snapshot.hasData ? '${snapshot.data}' : '');
                    },
                  ),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  '${_recording?.duration ?? "-"}',
                  style: TextStyle(
                    fontSize: 32.0,
                    color: myTheme.errorColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _buttonColor,
        label: _buttonIcon,
        onPressed: _opt,
      ),
    );
  }
}
