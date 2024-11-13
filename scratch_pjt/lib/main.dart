// main.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/io.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: WebRTCTextChat());
  }
}

class WebRTCTextChat extends StatefulWidget {
  @override
  _WebRTCTextChatState createState() => _WebRTCTextChatState();
}

class _WebRTCTextChatState extends State<WebRTCTextChat> {
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  final _channel = IOWebSocketChannel.connect('ws://localhost:3000');
  final _textController = TextEditingController();
  final List<String> _messages = [];

  @override
  void initState() {
    super.initState();
    _connectSignaling();
  }

  @override
  void dispose() {
    _channel.sink.close();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _connectSignaling() async {
    _channel.stream.listen((message) async {
      final data = jsonDecode(message);

      if (data['type'] == 'offer') {
        await _createAnswer(data['sdp']);
      } else if (data['type'] == 'answer') {
        await _peerConnection?.setRemoteDescription(
          RTCSessionDescription(data['sdp'], 'answer'),
        );
      } else if (data['type'] == 'candidate') {
        final candidate = RTCIceCandidate(
          data['candidate'],
          '',
          data['sdpMLineIndex'],
        );
        await _peerConnection?.addCandidate(candidate);
      }
    });
  }

  Future<void> _createOffer() async {
    _peerConnection = await _createPeerConnection();
    _dataChannel = await _peerConnection!.createDataChannel(
      'chat',
      RTCDataChannelInit(),
    );
    _setupDataChannel();

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    _channel.sink.add(jsonEncode({
      'type': 'offer',
      'sdp': offer.sdp,
    }));
  }

  Future<void> _createAnswer(String sdp) async {
    _peerConnection = await _createPeerConnection();
    _peerConnection!.onDataChannel = (RTCDataChannel channel) {
      _dataChannel = channel;
      _setupDataChannel();
    };

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdp, 'offer'),
    );

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    _channel.sink.add(jsonEncode({
      'type': 'answer',
      'sdp': answer.sdp,
    }));
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final Map<String, dynamic> config = {
      //'iceServers': [
      //  {'urls': 'stun:stun.l.google.com:19302'}
      //]
    };

    final pc = await createPeerConnection(config);

    pc.onIceCandidate = (candidate) {
      if (candidate != null) {
        _channel.sink.add(jsonEncode({
          'type': 'candidate',
          'candidate': candidate.candidate,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }));
      }
    };

    return pc;
  }

  void _setupDataChannel() {
    _dataChannel?.onMessage = (RTCDataChannelMessage message) {
      setState(() {
        _messages.add("Received: ${message.text}");
      });
    };
  }

  void _sendMessage() {
    final message = _textController.text;
    if (message.isNotEmpty && _dataChannel != null) {
      _dataChannel!.send(RTCDataChannelMessage(message));
      setState(() {
        _messages.add("Sent: $message");
        _textController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter WebRTC Text Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_messages[index]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Enter message',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _createOffer,
            child: Text('Create Offer'),
          ),
        ],
      ),
    );
  }
}
