import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class PlayerAya {
  int? sura, aya;
  PlayerAya(a) {
    sura = a["sura"];
    aya = a["aya"];
  }
}

class Sound {
  String? url, path, name, ename, mode;
  Sound(p) {
    name = p["name"];
    ename = p["ename"] ?? p["name"];
    url = p["url"];
    path = p["path"];
    mode = p["mode"];
  }
  String getURL(int sura, int aya) {
    return "$url/${fill(sura + 1)}${fill(aya + 1)}.mp3";
  }

  String fill(int number) {
    if (number < 10) return "00$number";
    if (number < 100) return "0$number";
    return "$number";
  }
}

/// This task defines logic for playing a list of podcast episodes.
class AudioPlayerTask extends BackgroundAudioTask {
  AudioPlayer _player = new AudioPlayer();
  AudioProcessingState? _skipState;
  Seeker? _seeker;
  // ignore: cancel_subscriptions
  StreamSubscription<PlaybackEvent>? _eventSubscription;
  MediaItem? mediaItem;
  int index = 0;
  int soundIndex = 0;
  List<PlayerAya>? ayas;
  List<Sound>? sounds;
  List<String>? suras;

  @override
  Future<void> onStart(Map<String, dynamic>? params) async {
    ayas = <PlayerAya>[];
    var list = json.decode(params!["ayas"]);
    for (var a in list) ayas!.add(PlayerAya(a));

    AudioServiceBackground.setQueue(<MediaItem>[]);
    // We configure the audio session for speech since we're playing a podcast.
    // You can also put this in your app's initialisation if your app doesn't
    // switch between two types of audio as this example does.
    // final session = await AudioSession.instance;
    // await session.configure(AudioSessionConfiguration.speech());
    // Propagate all events from the audio player to AudioService clients.
    _eventSubscription = _player.playbackEventStream.listen((event) {
      _broadcastState();
    });

    // Special processing for state transitions.
    _player.processingStateStream.listen((state) {
      switch (state) {
        case ProcessingState.completed:
          if (index >= ayas!.length - 1) {
            onStop();
            break;
          }
          if (soundIndex >= sounds!.length - 1) {
            soundIndex = 0;
            index++;
          } else {
            soundIndex++;
          }
          select(index, soundIndex);
          // In this example, the service stops when reaching the end.
          // onStop();
          break;
        case ProcessingState.ready:
          // If we just came from skipping between tracks, clear the skip
          // state now that we're ready to play.
          _skipState = null;
          break;
        default:
          break;
      }
    });
    AudioServiceBackground.sendCustomEvent('{"type":"start"}');
  }

  @override
  onCustomAction(String name, dynamic args) async {
    switch (name) {
      case 'update':
        sounds = <Sound>[];
        var list = json.decode(args!["sounds"]);
        for (var s in list) sounds!.add(Sound(s));

        var _suras = args["suras"];
        suras = <String>[];
        for (var s in _suras) suras!.add(s);
        break;

      case 'setVolume':
        _player.setVolume(args);
        break;

      case 'select':
        index = args!["index"];
        select(index, 0);
        break;
    }
  }

  Future<void> select(int index, int soundIndex) async {
    var aya = ayas![index];
    var sound = sounds![soundIndex];
    var url = sound.getURL(aya.sura!, aya.aya!);
    var duration = await _player.setUrl(url);
    mediaItem = MediaItem(
        artUri: Uri.parse("https://hidaya.sarand.net/images/${sound.path}.png"),
        title: "${suras![aya.sura!]} (${aya.aya! + 1})",
        artist: sound.name,
        album: sound.ename!,
        id: url,
        duration: duration);
    AudioServiceBackground.setMediaItem(mediaItem!);
    AudioServiceBackground.sendCustomEvent(
        '{"type":"select", "data":[$index, $soundIndex]}');
    onPlay();
  }

  @override
  Future<void> onSkipToQueueItem(String mediaId) async {
    // print("------------------------------ onSkipToQueueItem");

    // Then default implementations of onSkipToNext and onSkipToPrevious will
    // delegate to this method.
    final newIndex =
        AudioServiceBackground.queue!.indexWhere((item) => item.id == mediaId);
    if (newIndex == -1) return;
    // During a skip, the player may enter the buffering state. We could just
    // propagate that state directly to AudioService clients but AudioService
    // has some more specific states we could use for skipping to next and
    // previous. This variable holds the preferred state to send instead of
    // buffering during a skip, and it is cleared as soon as the player exits
    // buffering (see the listener in onStart).
    _skipState = newIndex > index
        ? AudioProcessingState.skippingToNext
        : AudioProcessingState.skippingToPrevious;
    // This jumps to the beginning of the queue item at newIndex.
    _player.seek(Duration.zero, index: newIndex);
    // Demonstrate custom events.
    AudioServiceBackground.sendCustomEvent('skip to $newIndex');
  }

  @override
  Future<void> onPlay() {
    print("onPlay ==");

    return _player.play();
  }

  @override
  Future<void> onPause() => _player.pause();

  @override
  Future<void> onSeekTo(Duration position) {
    // print("onSeekTo ====> $position");
    return _player.seek(position);
  }

  @override
  Future<void> onFastForward() => _seekRelative(fastForwardInterval);

  @override
  Future<void> onRewind() => _seekRelative(-rewindInterval);

  @override
  Future<void> onSeekForward(bool begin) async {
    // print("onSeekForward ====> $begin");
    _seekContinuously(begin, 1);
  }

  @override
  Future<void> onSeekBackward(bool begin) async => _seekContinuously(begin, -1);

  @override
  Future<void> onStop() async {
    AudioServiceBackground.sendCustomEvent('{"type":"stop"}');
    // print("------------------------------ onStop");

    await _player.dispose();
    _eventSubscription!.cancel();
    // It is important to wait for this state to be broadcast before we shut
    // down the task. If we don't, the background task will be destroyed before
    // the message gets sent to the UI.
    await _broadcastState();
    // Shut down this task
    await super.onStop();
  }

  /// Jumps away from the current position by [offset].
  Future<void> _seekRelative(Duration offset) async {
    // print("_seekRelative $offset");

    var newPosition = _player.position + offset;
    // Make sure we don't jump out of bounds.
    if (newPosition < Duration.zero) newPosition = Duration.zero;
    if (newPosition > mediaItem!.duration!) newPosition = mediaItem!.duration!;
    // Perform the jump via a seek.
    await _player.seek(newPosition);
  }

  /// Begins or stops a continuous seek in [direction]. After it begins it will
  /// continue seeking forward or backward by 10 seconds within the audio, at
  /// intervals of 1 second in app time.
  void _seekContinuously(bool begin, int direction) {
    _seeker?.stop();
    if (begin) {
      _seeker = Seeker(_player, Duration(seconds: 10 * direction),
          Duration(seconds: 1), mediaItem!)
        ..start();
    }
  }

  /// Broadcasts the current state to all clients.
  Future<void> _broadcastState() async {
    await AudioServiceBackground.setState(
      controls: [
        // MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        // MediaControl.skipToNext,
      ],
      systemActions: [
        MediaAction.seekTo,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      ],
      androidCompactActions: [0, 1],
      processingState: _getProcessingState(),
      playing: _player.playing,
      position: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    );
  }

  /// Maps just_audio's processing state into into audio_service's playing
  /// state. If we are in the middle of a skip, we use [_skipState] instead.
  AudioProcessingState _getProcessingState() {
    if (_skipState != null) return _skipState!;
    switch (_player.processingState) {
      case ProcessingState.idle:
        return AudioProcessingState.stopped;
      case ProcessingState.loading:
        return AudioProcessingState.connecting;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
      default:
        throw Exception("Invalid state: ${_player.processingState}");
    }
  }
}

class Seeker {
  final AudioPlayer player;
  final Duration positionInterval;
  final Duration stepInterval;
  final MediaItem mediaItem;
  bool _running = false;

  Seeker(
    this.player,
    this.positionInterval,
    this.stepInterval,
    this.mediaItem,
  );

  start() async {
    _running = true;
    while (_running) {
      Duration newPosition = player.position + positionInterval;
      if (newPosition < Duration.zero) newPosition = Duration.zero;
      if (newPosition > mediaItem.duration!) newPosition = mediaItem.duration!;
      player.seek(newPosition);
      await Future.delayed(stepInterval);
    }
  }

  stop() {
    _running = false;
  }
}
