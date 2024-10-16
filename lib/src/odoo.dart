import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import 'model/connection.dart';
import 'model/credential.dart';
import 'model/session.dart';
import 'model/user_logged_in.dart';

enum _OdooMethod { create, read, update, delete }

const _uuid = Uuid();

abstract class IDatabaseOperation {
  Future<int> insert(String tableName, Map<String, dynamic> args);
  Future<bool> update(String tableName, int id, Map<String, dynamic> args);
  Future<bool> delete(String tableName, int id);
  Future<List<dynamic>> query(
      {required String from,
      List<String> select = const [],
      List<dynamic> where = const [],
      String orderBy = "",
      int offset = 0,
      bool count = false,
      int limit = 50});
  Future<Map<String, dynamic>?> read(String tableName, int id,
      [List<String> columns = const []]);
}

abstract class IConnection {
  SessionController get session;
  Future<UserLoggedIn> connect(Credential credential);
  void disconnect();
}

class SessionController {
  final Dio dio;
  final _controller = StreamController<Session?>();
  Stream<Session?> get stream => _controller.stream;

  SessionController(this.dio);

  void update(Session? session) {
    dio.options.headers["Cookie"] =
        "session_id=${session?.id}; cids=${session?.companyId}";
    _controller.add(session);
  }
}

class Odoo implements IDatabaseOperation, IConnection {
  final Connection connection;
  late final Dio dio;
  late final SessionController session;

  Odoo(this.connection) {
    this.dio = Dio(BaseOptions(baseUrl: connection.url.toString()));
    this.session = SessionController(dio);
  }

  Future<UserLoggedIn> connect(Credential credential) async {
    try {
      Response resp = await dio.post("/web/session/authenticate",
          data: _withDefaultParams({
            "db": connection.db,
            "login": credential.username,
            "password": credential.password
          }));

      Map<String, dynamic> _resp = _transformResponse(resp);

      String sessionId = _getSessionId(resp.headers['set-cookie']!.first);
      _resp["session_id"] = sessionId;
      UserLoggedIn _user = UserLoggedIn.fromJson(_resp);

      session.update(
          Session(sessionId, _user, "${_user.user_companies.current_company}"));

      return _user;
    } catch (e) {
      throw e;
    }
  }

  Future<dynamic> _crud(String tableName, _OdooMethod method, dynamic args,
      [dynamic kwargs]) async {
    try {
      String _method = "";
      if (method == _OdooMethod.delete) {
        _method = "unlink";
      } else if (method == _OdooMethod.update) {
        _method = "write";
      } else if (method == _OdooMethod.create) {
        _method = "create";
      } else if (method == _OdooMethod.read) {
        _method = "read";
      }

      Response resp = await dio.post("/web/dataset/call_kw",
          data: _withDefaultParams({
            "args": args,
            "kwargs": {"context": {}},
            "method": _method,
            "model": tableName
          }));

      return _transformResponse(resp);
    } catch (e) {
      throw e;
    }
  }

  Future<int> insert(String tableName, Map<String, dynamic> args) async {
    int resp = await _crud(tableName, _OdooMethod.create, [args]);
    return resp;
  }

  Future<Map<String, dynamic>?> read(String tableName, int id,
      [List<String> columns = const []]) async {
    List resp = await _crud(tableName, _OdooMethod.read, [
      [id],
      columns
    ]) as List;

    if (resp.isEmpty) {
      return null;
    }

    return resp[0];
  }

  Future<bool> update(
      String tableName, int id, Map<String, dynamic> args) async {
    bool resp = await _crud(tableName, _OdooMethod.update, [
      [id],
      args
    ]);

    return resp;
  }

  Future<bool> delete(String tableName, int id) async {
    bool resp = await _crud(tableName, _OdooMethod.delete, [
      [id]
    ]);

    return resp;
  }

  Future<List<dynamic>> query({
    required String from,
    List<String> select = const [],
    List<dynamic> where = const [],
    String orderBy = "",
    int offset = 0,
    bool count = false,
    int limit = 50,
    dynamic context = const {},
  }) async {
    final resp =
        _transformResponseQuery(await dio.post("/web/dataset/search_read",
            data: _withDefaultParams({
              "context": context,
              "domain": where,
              "fields": select,
              "limit": limit,
              "model": from,
              "sort": orderBy,
              "offset": offset,
              "count": count
            })));
    return resp;
  }

  List _transformResponseQuery(Response resp) {
    Map<String, dynamic> _resp = _transformResponse(resp);
    if (_resp['length'] == 0) {
      return [];
    }

    return _resp['records'];
  }

  dynamic _transformResponse(Response resp) {
    if (resp.statusCode != 200) {
      throw Exception(resp.statusMessage);
    }

    Map _resp = jsonDecode(resp.toString());
    if (_resp.containsKey("error")) {
      if (_resp["error"]["data"]["name"] == "odoo.exceptions.AccessDenied") {
        throw Exception("username or password wrong");
      } else if (_resp["error"]["data"]["name"] ==
          "odoo.http.SessionExpiredException") {
        session.update(null);
        throw Exception("Session expired");
      }
      throw Exception(_resp['error'].toString());
    }

    return _resp['result'];
  }

  Map<String, dynamic> _withDefaultParams(Map<String, dynamic> params) {
    return {
      "id": _uuid.v4(),
      "jsonrpc": "2.0",
      "method": "call",
      "params": params
    };
  }

  String _getSessionId(String cookies) {
    return (Cookie.fromSetCookieValue(cookies)).value;
  }

  void disconnect() {
    session.update(null);
  }
}
