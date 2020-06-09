import 'package:quiet/repository/ted_defines.dart';

enum PolicyActionType { playAt, pause, goOn }

class PolicyAction {
  PolicyActionType type = PolicyActionType.goOn;
  PolicyAction({this.type, this.position, this.duration});
  int position;
  int duration; //ms
}

class PolicyCtrl {
  Policy _policy;

  int curParagId = 0;
  int curCueId = 0;
  int curParagRepeated = 0;
  int curCueRepeated = 0;

  int curCuePosition = 0;
  int playingCuePosition = 0;

  int playingParagId = 0;
  int playingCueId = 0;

  getCurPosition(Transcript script, int pos) {
    int _curP = -1;
    int _curC = -1;
    for (var p in script.paragraphs) {
      _curP++;
      for (var c in p.cues) {
        _curC++;
        if (c.time <= pos) {
          curParagId = _curP;
          curCueId = _curC;
          curCuePosition = c.time;
          return true;
        }
      }
    }
    return false;
  }

  execute(Transcript script, int pos) {
    if (_policy == null) {
      _policy = Policy(paragraphRepeat: 2, cueRepeat: 2, cueGapTime: 0);
    }
    if (!getCurPosition(script, pos)) {
      return PolicyAction(type: PolicyActionType.goOn);
    }
    if (curParagId == playingParagId) {
      if (curCueId > playingCueId) {
        curCueRepeated++;
        if (_policy.cueRepeat <= curCueRepeated) {
          //play next cue
          playingCueId = curCueId;
          playingCuePosition = curCuePosition;
          return PolicyAction(type: PolicyActionType.goOn);
        } else {
          //repeat cue
          return PolicyAction(
              type: PolicyActionType.playAt, position: playingCuePosition);
        }
      }
    } else if (curParagId > playingParagId) {
      print('curParagId > playingParagId');
    }
    return PolicyAction(type: PolicyActionType.goOn);
  }
}
