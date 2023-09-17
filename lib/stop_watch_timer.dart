import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:rxdart/rxdart.dart';

class StopWatchRecord {
  StopWatchRecord({
    this.rawValue,
    this.hours,
    this.minute,
    this.second,
    this.displayTime,
  });
  int? rawValue;
  int? hours;
  int? minute;
  int? second;
  String? displayTime;
}

enum StopWatchExecute { start, stop, reset, lap }

enum StopWatchMode { countUp, countDown }

class StopWatchTimer {
  StopWatchTimer({
    this.isLapHours = true,
    this.mode = StopWatchMode.countUp,
    int presetMillisecond = 0,
    this.onChange,
    this.onChangeRawSecond,
    this.onChangeRawMinute,
    this.onStopped,
    this.onEnded,
  }) {

    _presetTime = presetMillisecond;
    _initialPresetTime = presetMillisecond;

    if (mode == StopWatchMode.countDown) {
      final value = presetMillisecond;
      _rawTimeController = BehaviorSubject<int>.seeded(value);
      _secondTimeController = BehaviorSubject<int>.seeded(getRawSecond(value));
      _minuteTimeController = BehaviorSubject<int>.seeded(getRawMinute(value));
    } else {
      _rawTimeController = BehaviorSubject<int>.seeded(0);
      _secondTimeController = BehaviorSubject<int>.seeded(0);
      _minuteTimeController = BehaviorSubject<int>.seeded(0);
    }

    _elapsedTime.listen((value) {
      _rawTimeController.add(value);
      if (onChange != null) {
        onChange!(value);
      }
      final latestSecond = getRawSecond(value);
      if (_second != latestSecond) {
        _secondTimeController.add(latestSecond);
        _second = latestSecond;
        if (onChangeRawSecond != null) {
          onChangeRawSecond!(latestSecond);
        }
      }
      final latestMinute = getRawMinute(value);
      if (_minute != latestMinute) {
        _minuteTimeController.add(latestMinute);
        _minute = latestMinute;
        if (onChangeRawMinute != null) {
          onChangeRawMinute!(latestMinute);
        }
      }
    });
  }

  final bool isLapHours;
  final StopWatchMode mode;
  final Function(int)? onChange;
  final Function(int)? onChangeRawSecond;
  final Function(int)? onChangeRawMinute;
  final VoidCallback? onStopped;
  final VoidCallback? onEnded;

  final PublishSubject<int> _elapsedTime = PublishSubject<int>();

  late BehaviorSubject<int> _rawTimeController;
  ValueStream<int> get rawTime => _rawTimeController;

  late BehaviorSubject<int> _secondTimeController;
  ValueStream<int> get secondTime => _secondTimeController;

  late BehaviorSubject<int> _minuteTimeController;
  ValueStream<int> get minuteTime => _minuteTimeController;

  final BehaviorSubject<List<StopWatchRecord>> _recordsController =
  BehaviorSubject<List<StopWatchRecord>>.seeded([]);
  ValueStream<List<StopWatchRecord>> get records => _recordsController;

  final PublishSubject<bool> _onStoppedController = PublishSubject<bool>();
  Stream<bool> get fetchStopped => _onStoppedController;

  final PublishSubject<bool> _onEndedController = PublishSubject<bool>();
  Stream<bool> get fetchEnded => _onEndedController;

  bool get isRunning => _timer != null && _timer!.isActive;
  int get initialPresetTime => _initialPresetTime;

  Timer? _timer;
  int _startTime = 0;
  int _stopTime = 0;
  late int _presetTime;
  int? _second;
  int? _minute;
  List<StopWatchRecord> _records = [];
  late int _initialPresetTime;

  static String getDisplayTime(
      int value, {
        bool hours = true,
        bool minute = true,
        bool second = true,
        bool milliSecond = true,
        String hoursRightBreak = ':',
        String minuteRightBreak = ':',
        String secondRightBreak = '.',
      }) {
    final hoursStr = getDisplayTimeHours(value);
    final mStr = getDisplayTimeMinute(value, hours: hours);
    final sStr = getDisplayTimeSecond(value);
    final msStr = getDisplayTimeMillisecond(value);
    var result = '';
    if (hours) {
      result += '$hoursStr';
    }
    if (minute) {
      if (hours) {
        result += hoursRightBreak;
      }
      result += '$mStr';
    }
    if (second) {
      if (minute) {
        result += minuteRightBreak;
      }
      result += '$sStr';
    }
    if (milliSecond) {
      if (second) {
        result += secondRightBreak;
      }
      result += '$msStr';
    }
    return result;
  }

  static String getDisplayTimeHours(int mSec) {
    return getRawHours(mSec).floor().toString().padLeft(2, '0');
  }

  static String getDisplayTimeMinute(int mSec, {bool hours = false}) {
    if (hours) {
      return getMinute(mSec).floor().toString().padLeft(2, '0');
    } else {
      return getRawMinute(mSec).floor().toString().padLeft(2, '0');
    }
  }

  static String getDisplayTimeSecond(int mSec) {
    final s = (mSec % 60000 / 1000).floor();
    return s.toString().padLeft(2, '0');
  }

  static String getDisplayTimeMillisecond(int mSec) {
    final ms = (mSec % 1000 / 10).floor();
    return ms.toString().padLeft(2, '0');
  }

  static int getRawHours(int milliSecond) =>
      (milliSecond / (3600 * 1000)).floor();

  static int getMinute(int milliSecond) =>
      (milliSecond / (60 * 1000) % 60).floor();

  static int getRawMinute(int milliSecond) => (milliSecond / 60000).floor();

  static int getRawSecond(int milliSecond) => (milliSecond / 1000).floor();

  static int getMilliSecFromHour(int hour) => (hour * (3600 * 1000)).floor();

  static int getMilliSecFromMinute(int minute) => (minute * 60000).floor();

  static int getMilliSecFromSecond(int second) => (second * 1000).floor();

  Future<void> dispose() async {
    if (_elapsedTime.isClosed) {
      throw Exception(
        'This instance is already disposed. Please re-create StopWatchTimer instance.',
      );
    }

    final timer = _timer;
    if (timer != null && timer.isActive) {
      timer.cancel();
    }

    await Future.wait<void>([
      _elapsedTime.close(),
      _rawTimeController.close(),
      _secondTimeController.close(),
      _minuteTimeController.close(),
      _recordsController.close(),
      _onStoppedController.close(),
      _onEndedController.close(),
    ]);
  }

  void onStartTimer() => _start();

  void onStopTimer() => _stop();

  void onResetTimer() => _reset();

  void onAddLap() => _lap();

  void setPresetHoursTime(int value, {bool add = true}) =>
      setPresetTime(mSec: value * 3600 * 1000, add: add);

  void setPresetMinuteTime(int value, {bool add = true}) =>
      setPresetTime(mSec: value * 60 * 1000, add: add);

  void setPresetSecondTime(int value, {bool add = true}) =>
      setPresetTime(mSec: value * 1000, add: add);

  void setPresetTime({required int mSec, bool add = true}) {
    if (add) {
      if (mSec < 0) {
        final nowRawTime = _rawTimeController.value;
        if ((nowRawTime + mSec) > 0) {
          _presetTime += mSec;
        } else {
          _presetTime = 0;
        }
      } else {

        _presetTime += mSec;
      }
    } else {
      _presetTime = mSec;
    }
    _elapsedTime.add(_presetTime);
  }

  void clearPresetTime() {
    if (mode == StopWatchMode.countUp) {
      _presetTime = _initialPresetTime;
      _elapsedTime.add(isRunning ? _getCountUpTime(_presetTime) : _presetTime);
    } else if (mode == StopWatchMode.countDown) {
      _presetTime = _initialPresetTime;
      _elapsedTime
          .add(isRunning ? _getCountDownTime(_presetTime) : _presetTime);
    } else {
      throw Exception('No support mode');
    }
  }

  void _handle(Timer timer) {
    if (mode == StopWatchMode.countUp) {
      _elapsedTime.add(_getCountUpTime(_presetTime));
    } else if (mode == StopWatchMode.countDown) {
      final time = _getCountDownTime(_presetTime);
      _elapsedTime.add(time);
      if (time == 0) {
        _stop();
        _onEndedController.add(true);
        if (onEnded != null) {
          onEnded!();
        }
      }
    } else {
      throw Exception('No support mode');
    }
  }

  int _getCountUpTime(int presetTime) =>
      DateTime.now().millisecondsSinceEpoch -
          _startTime +
          _stopTime +
          presetTime;

  int _getCountDownTime(int presetTime) => max(
    presetTime -
        (DateTime.now().millisecondsSinceEpoch - _startTime + _stopTime),
    0,
  );

  void _start() {
    if (!isRunning) {
      _startTime = DateTime.now().millisecondsSinceEpoch;
      _timer = Timer.periodic(const Duration(milliseconds: 1), _handle);
    }
  }

  bool _stop() {
    if (isRunning) {
      _timer!.cancel();
      _timer = null;
      _stopTime += DateTime.now().millisecondsSinceEpoch - _startTime;
      _onStoppedController.add(true);
      if (onStopped != null) {
        onStopped!();
      }
      return true;
    } else {
      return false;
    }
  }

  void _reset() {
    if (isRunning) {
      _timer!.cancel();
      _timer = null;
    }
    if (isRunning || _startTime > 0) {
      _onStoppedController.add(true);
      if (onStopped != null) {
        onStopped!();
      }
      _onEndedController.add(true);
      if (onEnded != null) {
        onEnded!();
      }
    }

    _startTime = 0;
    _stopTime = 0;
    _second = null;
    _minute = null;
    _records = [];
    _recordsController.add(_records);
    _elapsedTime.add(_presetTime);
  }

  void _lap() {
    if (isRunning) {
      final rawValue = _rawTimeController.value;
      _records.add(StopWatchRecord(
        rawValue: rawValue,
        hours: getRawHours(rawValue),
        minute: getRawMinute(rawValue),
        second: getRawSecond(rawValue),
        displayTime: getDisplayTime(rawValue, hours: isLapHours),
      ));
      _recordsController.add(_records);
    }
  }
}
