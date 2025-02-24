import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:web_socket_channel/web_socket_channel.dart';

class DispatchEvent {
  final String type;
  final dynamic data;

  const DispatchEvent(this.type, this.data);

  factory DispatchEvent.fromPayload(Map<String, dynamic> payload) {
    if (payload["op"] != 0) {
      throw Exception("Payload wasn't a dispatch event (OP-code 0)");
    }
    return DispatchEvent(payload["t"], payload["d"]);
  }
}

class GatewayChannel {
  late WebSocketChannel _channel;

  void send(Map<String, dynamic> data) {
    _channel.sink.add(jsonEncode(data));
  }

  StreamSubscription<DispatchEvent> listen(
    Function(DispatchEvent event) listener,
  ) {
    return _eventController.stream.listen(listener);
  }

  final StreamController<DispatchEvent> _eventController =
      StreamController<DispatchEvent>.broadcast();

  final String _initialUrl;
  final String _token;

  late int _heartbeatInterval;
  late String _sessionId;
  late String _resumeUrl;
  Timer? _heartbeatTimer;
  int? _lastSequence;
  bool _lastHeartbeatAcknowledged = true;
  bool _isResuming = false;
  bool selfClosed = false;

  GatewayChannel(
    this._initialUrl,
    this._token, {
    Function(String data)? rawLifeCycleListener,
  }) {
    _initializeConnection(lifeCycleListener: rawLifeCycleListener);
  }

  void _initializeConnection({
    String? url,
    Function(String)? lifeCycleListener,
  }) async {
    selfClosed = false;
    _channel = WebSocketChannel.connect(
      Uri.parse(
        url ?? _initialUrl,
      ).replace(queryParameters: {"v": "9", "encoding": "json"}),
    );
    _channel.stream.listen(
      (event) {
        _lifeCycleHandler(event);
        lifeCycleListener?.call(event);
      },
      onDone: _handleDisconnect,
      onError: (error) => log("Gateway error: $error"),
    );
    log("Started new connection.");
  }

  void _identify() {
    log("Identifying to the server.");
    _channel.sink.add(
      jsonEncode({
        "op": 2, // Identify
        "d": {
          "token": _token,
          // this looks like useless telemetry but can't connect without it
          "properties": {"os": "linux", "device": "disco", "browser": "disco"},
        },
      }),
    );
  }

  void _heartbeat() {
    if (!_lastHeartbeatAcknowledged) {
      log("Previous heartbeat was not acknowledged!");
    }

    _channel.sink.add(jsonEncode({"op": 1, "d": _lastSequence}));

    _lastHeartbeatAcknowledged = false;
  }

  void _startBeating() {
    _heartbeatTimer?.cancel();

    _lastHeartbeatAcknowledged = true;
    _heartbeat();
    _heartbeatTimer = Timer.periodic(
      Duration(milliseconds: _heartbeatInterval),
      (t) => _heartbeat(),
    );
  }

  void _stopBeating() {
    _heartbeatTimer?.cancel();
  }

  void _sendResumeRequest() {
    _channel.sink.add(
      jsonEncode({
        "op": 6, // Resume
        "d": {"token": _token, "session_id": _sessionId, "seq": _lastSequence},
      }),
    );
    log("Sent resume request.");
  }

  void _attemptResume() async {
    log("Resuming...");
    _isResuming = true;
    _initializeConnection(url: _resumeUrl);
  }

  void _lifeCycleHandler(String event) async {
    final Map<String, dynamic> payload = jsonDecode(event);
    switch (payload["op"]) {
      case 0: // Dispatch
        _lastSequence = payload["s"] ?? _lastSequence;
        log("Received a ${payload["t"]} event.");
        switch (payload["t"]) {
          case "READY":
            final data = payload["d"];
            _sessionId = data["session_id"];
            _resumeUrl = data["resume_gateway_url"];
            break;
          case "RESUMED":
            log("Successfully resumed connection with the gateway!");
            break;
          default:
            break;
        }

        _eventController.add(DispatchEvent.fromPayload(payload));

        break;
      case 11: // Heartbeat ACK
        _lastHeartbeatAcknowledged = true;
        log("Heartbeat acknowledged.");
        break;
      case 10: // Hello
        log("Hello!");
        _heartbeatInterval = payload["d"]["heartbeat_interval"];
        _startBeating();
        if (_isResuming) {
          _sendResumeRequest();
        } else {
          _identify();
        }
        _isResuming = false;
        break;
      case 1: // Heartbeat
        _heartbeat();
        break;
      case 7: // Reconnect
        log("Reconnecting as per an opcode 7 payload.");
        await close();
        _attemptResume();
        break;
      case 9: // Invalid session
        log("Invalid session.");
        await close();
        if (payload["d"]) {
          log("Disconnecting and resuming.");
          _attemptResume();
        } else {
          log("Restarting connection.");
          _initializeConnection();
        }
        break;
      default:
        log("Received payload: $payload");
        break;
    }
  }

  void _handleDisconnect() async {
    _stopBeating();
    final int? code = _channel.closeCode;
    log("Gateway disconnected with code $code.");

    if (selfClosed) {
      log("Whoops, my bad.");
      return;
    }

    // these codes require initializing a new connection
    if (code == 4009 || code == 4007 || code == 4004) {
      log("Initializing new connection...");
      _initializeConnection();
    } else {
      log("Attempting to resume connection...");
      _attemptResume();
    }
  }

  Future<void> close({int? closeCode}) async {
    _stopBeating();
    selfClosed = true;
    log("Client disconnected.");
    await _channel.sink.close(closeCode);
  }

  void dispose() {
    close();
    _eventController.close();
  }
}
