import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // RTC video renderer
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  // RTC Connections
  RTCPeerConnection _peerConnection;
  MediaStream _localStream;
  bool _isOffer = false;

  final _sdpController = TextEditingController();
  final _candidateController = TextEditingController();

  void _initRenderer() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<MediaStream> _getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': false,
      'video': {
        'mandatory': {
          'minWidth': '640', // Provide your own width, height and frame rate here
          'minHeight': '480',
          'minFrameRate' : '30',
        },
        'facingMode': 'user',
        'optional': [],
      }
    };

    MediaStream stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localRenderer.srcObject = stream;
    //_remoteRenderer.srcObject = stream;

    return stream;
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final Map<String, dynamic> configuration = {
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
      ]
    };

    final Map<String, dynamic> offerSDPConstraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true,
      },
      'optional': [],
    };

    _localStream = await _getUserMedia();
    setState(() {});

    // Create peer connection
    final pc = await createPeerConnection(configuration, offerSDPConstraints);

    await pc.addStream(_localStream);

    pc.onIceCandidate = (e) {
      if (e.candidate != null) {
        final candidate = json.encode({
          'candidate': e.candidate,
          'sdpMid': e.sdpMid,
          'sdpMLineIndex': e.sdpMlineIndex,
        });
        print(candidate);
        if(_candidateController.text.isEmpty) {
          _candidateController.text = candidate;
        }
      }
    };

    pc.onIceConnectionState = (e) {
      print(e);
    };

    pc.onAddStream = (stream) {
      print('addStream: ' + stream.id);
      _remoteRenderer.srcObject = stream;
    };

    return pc;
  }

  void _createOffer() async {
    var desc = await _peerConnection.createOffer({'OfferToReceiveVideo': 1});

    // Testing Purpose
    _sdpController.text = desc.sdp;

    _isOffer = true;
    _peerConnection.setLocalDescription(desc);
  }

  void _createAnswer() async {
    var desc = await _peerConnection.createAnswer({'offerToReceiveVideo': 1});

    // Testing Purpose
    _sdpController.text = desc.sdp;

    _peerConnection.setLocalDescription(desc);
  }

  _setRemoteDescription() async {
    String sdp = '${_sdpController.text}';

    var remoteDesc = RTCSessionDescription(sdp, _isOffer ? 'answer' : 'offer');

    await _peerConnection.setRemoteDescription(remoteDesc);

    // Testing Purpose
    _sdpController.clear();
  }

  _setCandidate() async {
    String jsonString = _sdpController.text;
    var session = await json.decode(jsonString);
    print(session['candidate']);

    var candidate = RTCIceCandidate(
        session['candidate'], session['sdpMid'], session['sdpMlineIndex']);

    await _peerConnection.addCandidate(candidate);

    _sdpController.clear();
  }

  @override
  void initState() {
    super.initState();
    _initRenderer();
    _createPeerConnection().then((pc) => this._peerConnection = pc);
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();

    _localStream.dispose();
    _sdpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: Text('Call Video Demo'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            getVideoRenderer(size),
            offerAndAnswerButton(),
            sdpCandidateTF(_sdpController),
            sdpCandidateTF(_candidateController),
            sdpCandidateButtons(),
            SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget getVideoRenderer(Size size) {
    return Column(
      children: [
        Container(
          height: size.height / 3,
          color: Colors.grey,
          margin: EdgeInsets.all(10),
          child: RTCVideoView(_localRenderer),
        ),
        Container(
          height: size.height / 3,
          color: Colors.grey,
          margin: EdgeInsets.all(10),
          child: RTCVideoView(_remoteRenderer),
        ),
      ],
    );
  }

  Widget offerAndAnswerButton() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ElevatedButton(
            onPressed: _createOffer,
            child: Text('Offer'),
          ),
          ElevatedButton(
            onPressed: _createAnswer,
            child: Text('Answer'),
          ),
        ],
      );

  Widget sdpCandidateTF(TextEditingController controller) => Padding(
        padding: EdgeInsets.all(10),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.multiline,
          maxLines: 4,
          maxLength: TextField.noMaxLength,
        ),
      );

  Widget sdpCandidateButtons() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ElevatedButton(
            onPressed: _setRemoteDescription,
            child: Text('Set Remote Desc'),
          ),
          ElevatedButton(
            onPressed: _setCandidate,
            child: Text('Set Candidate'),
          ),
        ],
      );
}
