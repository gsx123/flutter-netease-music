export 'package:async/async.dart' show Result;
export 'package:async/async.dart' show ValueResult;
export 'package:async/async.dart' show ErrorResult;
import 'dart:async';
import 'dart:convert';

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:netease_music_api/netease_cloud_music.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quiet/part/part.dart';
import 'package:quiet/repository/ted_defines.dart';
import 'package:quiet/repository/ted_policy_ctrl.dart';

Future<HttpClientResponse> _doRequest(
    String url, Map<String, String> headers, Map data, String method) {
  return HttpClient().openUrl(method, Uri.parse(url)).then((request) {
    if (headers != null) {
      headers.forEach(request.headers.add);
    }
    request.write(Uri(queryParameters: data.cast()).query);
    return request.close();
  });
}

const API_TED_HOST = "http://192.168.0.173:8080";
const API_TED_METADATA = "https://www.ted.com/talks/{}/metadata.json";
const API_TED_TRANSCRIPT =
    "https://www.ted.com/talks/{}/transcript.json?language=en";
const API_TED_TALKS = API_TED_HOST + '/ted/talks';
TedRepository tedRepository;

class TedRepository {
  Transcript _transcript;
  PolicyCtrl _policyCtrl = PolicyCtrl();
  playingControl(BuildContext context, int position) {
    if (_transcript == null) {
      print('[playingControl] _transcript is null');
      return;
    }

    PolicyAction act = _policyCtrl.execute(_transcript, position);
    if (act.type == PolicyActionType.playAt) {
      print('[playingControl] play at:' + act.position.toString());
      context.transportControls
        ..seekTo(act.position.round())
        ..play();
    } else if (act.type == PolicyActionType.pause) {
      print('[playingControl] pause:' + act.duration.toString());
      context.transportControls.pause();
    }
  }

  getMetaDataUrl(idOrTitle) {
    return API_TED_METADATA.replaceAll('{}', idOrTitle);
  }

  ///[path] request path
  ///[data] parameter
  Future<Result<Map<String, dynamic>>> doRequest(String url,
      [Map param = const {}]) async {
    Answer result;
    try {
      // convert all params to string
      final Map<String, String> convertedParams =
          param.map((k, v) => MapEntry(k.toString(), v.toString()));
      final headers = {};
      final method = 'GET';
      HttpClientResponse response =
          await _doRequest(url, null, convertedParams, method);
      var ans = Answer(cookie: response.cookies);

      final content =
          await response.cast<List<int>>().transform(utf8.decoder).join();
      final body = json.decode(content);
      ans = ans.copy(
          status: /*int.parse(body['code'].toString()) ??*/ response.statusCode,
          body: body);

      ans = ans.copy(
          status: ans.status > 100 && ans.status < 600 ? ans.status : 400);
      result = ans;
    } catch (e, stacktrace) {
      // debugPrint("request error : $e \n $stacktrace");
      return Result.error(e, stacktrace);
    }
    final map = result.body;

    if (result.status == 200) {}
    if (map == null) {
      return Result.error('请求失败了');
    }
    // } else if (map['code'] == _CODE_NEED_LOGIN) {
    //   return Result.error('需要登陆才能访问哦~');
    // } else if (map['code'] != _CODE_SUCCESS) {
    //   return Result.error(map['msg'] ?? '请求失败了~');
    // }
    return Result.value(map);
  }

  Future<Result<Map>> talkDetail(int mvId) {
    return doRequest(getMetaDataUrl(mvId.toString()));
  }

  Future<Result<Map>> getTalks() {
    final jsonstr = '{}';

    var map = json.decode(jsonstr);
    // return Result(map);
    return doRequest(API_TED_TALKS);
  }

  Future<Result<Map>> getTranscript() {
    return doRequest(API_TED_TRANSCRIPT.replaceAll('{}', '1888'));
  }

  Music mapJsonToMusic(Map song) {
    Map album = song['album'] as Map;
    List<Artist> artists = (song['artists'] as List).cast<Map>().map((e) {
      return Artist(
        name: e["name"],
        id: e["id"],
      );
    }).toList();

    return Music(
        id: song["id"],
        title: song["title"],
        mvId: song['mv'],
        url: song['url'],
        album: Album(
            id: album["id"],
            name: album["name"],
            coverImageUrl: album["picUrl"]),
        artist: artists);
  }

  _LyricCache __lyricCache;

  Future<_LyricCache> _lyricCache() async {
    if (__lyricCache != null) {
      return __lyricCache;
    }
    var temp = await getTemporaryDirectory();
    var dir = Directory(temp.path + "/lyrics/");
    if (!(await dir.exists())) {
      dir = await dir.create();
    }
    __lyricCache = _LyricCache._(dir);
    return __lyricCache;
  }

  ///根据音乐id获取歌词
  Future<String> lyric(int id) async {
    final lyricCache = await _lyricCache();
    final key = _LyricCacheKey(id);
    //check cache first
    String cached = await lyricCache.get(key);
    if (cached != null) {
      // return cached;
    }
    var result =
        await doRequest(API_TED_TRANSCRIPT.replaceAll('{}', id.toString()));
    if (result.isError) {
      return Future.error(result.asError.error);
    }

    _transcript = Transcript.fromJson(result.asValue.value);
    if (_transcript == null) {
      return null;
    }
    final content = _transcript.toLryic();

    //update cache
    await lyricCache.update(key, content);
    return content;
  }
}

class _LyricCacheKey implements CacheKey {
  final int musicId;

  _LyricCacheKey(this.musicId) : assert(musicId != null);

  @override
  String getKey() {
    return musicId.toString();
  }
}

class _LyricCache implements Cache<String> {
  _LyricCache._(Directory dir)
      : provider =
            FileCacheProvider(dir, maxSize: 20 * 1024 * 1024 /* 20 Mb */);

  final FileCacheProvider provider;

  @override
  Future<String> get(CacheKey key) async {
    final file = provider.getFile(key);
    if (await file.exists()) {
      return file.readAsStringSync();
    }
    provider.touchFile(file);
    return null;
  }

  @override
  Future<bool> update(CacheKey key, String t) async {
    var file = provider.getFile(key);
    if (await file.exists()) {
      file.delete();
    }
    file = await file.create();
    await file.writeAsString(t);
    try {
      return await file.exists();
    } finally {
      provider.checkSize();
    }
  }
}
