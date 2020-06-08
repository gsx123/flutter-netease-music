export 'package:async/async.dart' show Result;
export 'package:async/async.dart' show ValueResult;
export 'package:async/async.dart' show ErrorResult;
import 'dart:async';
import 'dart:convert';

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:netease_music_api/netease_cloud_music.dart';
import 'package:quiet/part/part.dart';

Future<HttpClientResponse> _doRequest(
    String url, Map<String, String> headers, Map data, String method) {
  return HttpClient().openUrl(method, Uri.parse(url)).then((request) {
    headers.forEach(request.headers.add);
    request.write(Uri(queryParameters: data.cast()).query);
    return request.close();
  });
}

const API_TED_METADATA = "https://www.ted.com/talks/{}/metadata.json";

class TedRepository {
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
          await _doRequest(url, headers, convertedParams, method);
      var ans = Answer(cookie: response.cookies);

      final content =
          await response.cast<List<int>>().transform(utf8.decoder).join();
      final body = json.decode(content);
      ans = ans.copy(
          status: int.parse(body['code'].toString()) ?? response.statusCode,
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

  Future<Result<Map>> talkList() {
    final jsonstr = '{}';

    var map = json.decode(jsonstr);
    // return Result(map);
    // return doRequest(getMetaDataUrl(mvId.toString()));
  }
}
