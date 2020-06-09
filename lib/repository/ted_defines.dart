import 'dart:convert';

class Cue {
  var time = 0;
  var text = '';
  var duration = 0;
  Cue.fromJson(Map<String, dynamic> json)
      : time = json['time'],
        text = json['text'];

  Map toMap() {
    return {
      'time': time,
      'text': text,
    };
  }

  static Cue deserialize(String str) {
    Map jsonMap = json.decode(str);
    return Cue.fromJson(jsonMap);
  }

  String serialize() {
    return json.encode(toMap());
  }
}

class Paragraph {
  List<Cue> cues = [];
  Paragraph.fromJson(Map<String, dynamic> json) {
    cues = [];
    if (json.containsKey('cues') && json['cues'] != null)
      for (var item in json['cues']) {
        cues.add(Cue.fromJson(item));
      }
  }
  Map toMap() {
    return {
      'cues': cues,
    };
  }

  static Paragraph deserialize(String str) {
    Map jsonMap = json.decode(str);
    return Paragraph.fromJson(jsonMap);
  }

  String serialize() {
    return json.encode(toMap());
  }
}

class Transcript {
  List<Paragraph> paragraphs = [];
  Transcript.fromJson(Map<String, dynamic> json) {
    paragraphs = [];
    if (json.containsKey('paragraphs') && json['paragraphs'] != null)
      for (var item in json['paragraphs']) {
        paragraphs.add(Paragraph.fromJson(item));
      }
  }
  Map toMap() {
    return {
      'paragraphs': paragraphs,
    };
  }

  static Transcript deserialize(String str) {
    Map jsonMap = json.decode(str);
    return Transcript.fromJson(jsonMap);
  }

  String serialize() {
    return json.encode(toMap());
  }

  String _toDigits(int hour, int len) {
    String h = hour.toString();
    while (h.length < len) {
      h = '0' + h;
    }
    return h;
  }

  String _msToFormatedTime(int ms) {
    ms += 17000; // skip the introduction voice
    int microSec = ms % 1000;
    ms = ms ~/ 1000;
    int hour = (ms.toDouble() ~/ 3600.0).toInt();
    ms -= hour * 3600;
    int min = ((ms.toDouble()) ~/ 60.0).toInt();
    ms -= min * 60;
    int sec = ms;

    return _toDigits(min, 2) +
        ":" +
        _toDigits(sec, 2) +
        '.' +
        _toDigits(microSec, 3);
  }

  String toLryic() {
    List<String> lines = [];
    for (var para in this.paragraphs) {
      for (var cue in para.cues) {
        var line = '[' + this._msToFormatedTime(cue.time) + ']';
        line += cue.text;
        lines.add(line);
      }
    }
    return lines.join('\n');
  }
}

class Policy {
  var paragraphRepeat = 1;
  var cueRepeat = 1;
  var cueGapTime = 0;

  Policy({this.paragraphRepeat, this.cueRepeat, this.cueGapTime});
  Policy.fromJson(Map<String, dynamic> json)
      : paragraphRepeat = json['paragraphRepeat'],
        cueRepeat = json['cueRepeat'],
        cueGapTime = json['cueGapTime'];

  Map toMap() {
    return {
      'paragraphRepeat': paragraphRepeat,
      'cueRepeat': cueRepeat,
      'cueGapTime': cueGapTime,
    };
  }

  static Policy deserialize(String str) {
    Map jsonMap = json.decode(str);
    return Policy.fromJson(jsonMap);
  }

  String serialize() {
    return json.encode(toMap());
  }
}
