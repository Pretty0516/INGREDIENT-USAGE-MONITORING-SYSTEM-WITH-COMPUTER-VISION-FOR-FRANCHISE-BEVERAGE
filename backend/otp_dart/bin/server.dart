import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:googleapis/firestore/v1.dart' as fs;
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/identitytoolkit/v3.dart' as id;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:uuid/uuid.dart';

Future<fs.FirestoreApi> _firestore() async {
  final client = await clientViaApplicationDefaultCredentials(scopes: [fs.FirestoreApi.cloudPlatformScope]);
  return fs.FirestoreApi(client);
}

Future<id.IdentityToolkitApi> _identity() async {
  final client = await clientViaApplicationDefaultCredentials(scopes: ['https://www.googleapis.com/auth/cloud-platform']);
  return id.IdentityToolkitApi(client);
}

String _projectId() {
  final fromEnv = Platform.environment['PROJECT_ID'] ?? Platform.environment['GOOGLE_CLOUD_PROJECT'] ?? '';
  return fromEnv.isNotEmpty ? fromEnv : 'ingredient-usage';
}

String _hash(String s) => sha256.convert(utf8.encode(s)).toString();

fs.Value _str(String v) => fs.Value()..stringValue = v;
fs.Value _int(int v) => fs.Value()..integerValue = v.toString();
fs.Value _bool(bool v) => fs.Value()..booleanValue = v;
fs.Value _ts(DateTime d) => fs.Value()..timestampValue = d.toUtc().toIso8601String();

Future<Response> _sendOtp(Request req) async {
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final channel = (body['channel'] ?? '').toString();
  final email = (body['email'] ?? '').toString();
  final phone = (body['phone'] ?? '').toString();
  final context = (body['context'] ?? 'login').toString();

  if (channel != 'email' && channel != 'sms') {
    return Response(400, body: jsonEncode({'message': 'invalid channel'}));
  }
  if (channel == 'email' && email.isEmpty) {
    return Response(400, body: jsonEncode({'message': 'email required'}));
  }
  if (channel == 'sms' && phone.isEmpty) {
    return Response(400, body: jsonEncode({'message': 'phone required'}));
  }

  final code = (100000 + (DateTime.now().microsecondsSinceEpoch % 900000)).toString();
  final expires = DateTime.now().add(const Duration(minutes: 5));
  final projectId = _projectId();
  if (projectId.isEmpty) {
    return Response(500, body: jsonEncode({'message': 'PROJECT_ID not set'}));
  }

  final api = await _firestore();
  final parent = 'projects/$projectId/databases/(default)/documents';
  final docId = const Uuid().v4();
  final target = channel == 'email' ? email.toLowerCase().trim() : phone;
  final doc = fs.Document();
  doc.fields = {
    'channel': _str(channel),
    'target': _str(target),
    'context': _str(context),
    'codeHash': _str(_hash(code)),
    'expiresAt': _ts(expires),
    'attempts': _int(0),
    'used': _bool(false),
    'createdAt': _ts(DateTime.now()),
  };
  await api.projects.databases.documents.createDocument(
    doc,
    parent,
    'otp_requests',
    documentId: docId,
  );

  if (channel == 'email') {
    final user = Platform.environment['MAIL_USER'] ?? '';
    final pass = (Platform.environment['MAIL_PASS'] ?? '').replaceAll(' ', '');
    if (user.isEmpty || pass.isEmpty) {
      return Response(500, body: jsonEncode({'message': 'MAIL_USER or MAIL_PASS missing'}));
    }
    final smtp = gmail(user, pass);
    final message = Message()
      ..from = Address(user, 'OTP Service')
      ..recipients.add(target)
      ..subject = 'Your verification code'
      ..html = '<p>Your OTP is <b>$code</b>. It expires in 5 minutes.</p>';
    try {
      await send(message, smtp);
    } catch (e) {
      return Response(500, body: jsonEncode({'message': 'email send failed: $e'}));
    }
  }

  return Response.ok(jsonEncode({'requestId': docId, 'message': 'sent'}), headers: {'Content-Type': 'application/json'});
}

Future<Response> _verifyOtp(Request req) async {
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final requestId = (body['requestId'] ?? '').toString();
  final code = (body['code'] ?? '').toString();
  if (requestId.isEmpty || code.isEmpty) {
    return Response(400, body: jsonEncode({'valid': false, 'message': 'invalid input'}));
  }
  final projectId = _projectId();
  final api = await _firestore();
  final name = 'projects/$projectId/databases/(default)/documents/otp_requests/$requestId';
  fs.Document doc;
  try {
    doc = await api.projects.databases.documents.get(name);
  } catch (_) {
    return Response(404, body: jsonEncode({'valid': false, 'message': 'not found'}));
  }
  Map<String, fs.Value> f = doc.fields ?? {};
  bool used = f['used']?.booleanValue ?? false;
  int attempts = int.tryParse(f['attempts']?.integerValue ?? '0') ?? 0;
  final expiresAtStr = f['expiresAt']?.timestampValue ?? '';
  final expiresAt = DateTime.tryParse(expiresAtStr)?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0).toUtc();
  if (used) return Response(400, body: jsonEncode({'valid': false, 'message': 'already used'}));
  if (DateTime.now().toUtc().isAfter(expiresAt)) return Response(400, body: jsonEncode({'valid': false, 'message': 'expired'}));
  attempts += 1;
  if (attempts > 5) return Response(429, body: jsonEncode({'valid': false, 'message': 'too many attempts'}));
  final ok = (f['codeHash']?.stringValue ?? '') == _hash(code);
  final update = fs.Document();
  update.fields = {
    'attempts': _int(attempts),
    'used': _bool(ok),
  };
  await api.projects.databases.documents.patch(update, name, updateMask_fieldPaths: ['attempts', 'used']);
  return Response.ok(jsonEncode({'valid': ok, 'message': ok ? 'ok' : 'invalid'}), headers: {'Content-Type': 'application/json'});
}

Future<Response> _resetPasswordViaEmailOtp(Request req) async {
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final email = (body['email'] ?? '').toString().toLowerCase().trim();
  final newPassword = (body['newPassword'] ?? '').toString();
  if (email.isEmpty || newPassword.isEmpty) {
    return Response(400, body: jsonEncode({'message': 'invalid input'}));
  }
  final projectId = _projectId();
  final api = await _firestore();
  final vName = 'projects/$projectId/databases/(default)/documents/email_verifications/$email';
  fs.Document vdoc;
  try {
    vdoc = await api.projects.databases.documents.get(vName);
  } catch (_) {
    return Response(404, body: jsonEncode({'message': 'verification not found'}));
  }
  final vf = vdoc.fields ?? {};
  final status = vf['status']?.stringValue ?? '';
  final expStr = vf['expiresAt']?.timestampValue ?? '';
  final exp = DateTime.tryParse(expStr)?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0).toUtc();
  if (status != 'verified') {
    return Response(400, body: jsonEncode({'message': 'not verified'}));
  }
  if (DateTime.now().toUtc().isAfter(exp)) {
    return Response(400, body: jsonEncode({'message': 'code expired'}));
  }

  // Get UID by email and update password via Identity Toolkit
  final idApi = await _identity();
  final infoReq = id.IdentitytoolkitRelyingpartyGetAccountInfoRequest()..email = [email];
  id.GetAccountInfoResponse info;
  try {
    info = await idApi.relyingparty.getAccountInfo(infoReq);
  } catch (e) {
    return Response(500, body: jsonEncode({'message': 'lookup failed', 'error': e.toString()}));
  }
  if (info.users == null || info.users!.isEmpty) {
    return Response(404, body: jsonEncode({'message': 'account not found'}));
  }
  final localId = info.users!.first.localId;
  final setReq = id.IdentitytoolkitRelyingpartySetAccountInfoRequest()
    ..localId = localId
    ..password = newPassword;
  try {
    await idApi.relyingparty.setAccountInfo(setReq);
  } catch (e) {
    return Response(500, body: jsonEncode({'message': 'update failed', 'error': e.toString()}));
  }

  // Store hashed password in Firestore metadata and clear temp hash
  final usersDoc = 'projects/$projectId/databases/(default)/documents/users/$localId';
  final upd = fs.Document();
  final hashed = _hash(newPassword);
  upd.fields = {
    'status': _str('active'),
    'isTemporaryPassword': _bool(false),
    'metadata': fs.Value()
      ..mapValue = (fs.MapValue()
        ..fields = {
          'hashedPassword': _str(hashed),
          'lastPasswordUpdatedAt': _ts(DateTime.now()),
        }),
  };
  try {
    await api.projects.databases.documents.patch(
      upd,
      usersDoc,
      updateMask_fieldPaths: [
        'status',
        'isTemporaryPassword',
        'metadata.hashedPassword',
        'metadata.lastPasswordUpdatedAt',
      ],
    );
  } catch (_) {
    // best-effort; ignore failures
  }

  // Mark verification used
  try {
    final vupdate = fs.Document()..fields = {'status': _str('used')};
    await api.projects.databases.documents.patch(vupdate, vName, updateMask_fieldPaths: ['status']);
  } catch (_) {}

  return Response.ok(jsonEncode({'message': 'password updated'}), headers: {'Content-Type': 'application/json'});
}

Future<Response> _resetPasswordDirect(Request req) async {
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final email = (body['email'] ?? '').toString().toLowerCase().trim();
  final newPassword = (body['newPassword'] ?? '').toString();
  if (email.isEmpty || newPassword.isEmpty) {
    return Response(400, body: jsonEncode({'message': 'invalid input'}));
  }
  final projectId = _projectId();
  final api = await _firestore();

  final idApi = await _identity();
  final infoReq = id.IdentitytoolkitRelyingpartyGetAccountInfoRequest()..email = [email];
  id.GetAccountInfoResponse info;
  try {
    info = await idApi.relyingparty.getAccountInfo(infoReq);
  } catch (e) {
    return Response(500, body: jsonEncode({'message': 'lookup failed', 'error': e.toString()}));
  }
  if (info.users == null || info.users!.isEmpty) {
    return Response(404, body: jsonEncode({'message': 'account not found'}));
  }
  final localId = info.users!.first.localId;
  final setReq = id.IdentitytoolkitRelyingpartySetAccountInfoRequest()
    ..localId = localId
    ..password = newPassword;
  try {
    await idApi.relyingparty.setAccountInfo(setReq);
  } catch (e) {
    return Response(500, body: jsonEncode({'message': 'update failed', 'error': e.toString()}));
  }

  final usersDoc = 'projects/$projectId/databases/(default)/documents/users/$localId';
  final upd = fs.Document();
  final hashed = _hash(newPassword);
  upd.fields = {
    'status': _str('active'),
    'isTemporaryPassword': _bool(false),
    'metadata': fs.Value()
      ..mapValue = (fs.MapValue()
        ..fields = {
          'hashedPassword': _str(hashed),
          'lastPasswordUpdatedAt': _ts(DateTime.now()),
        }),
  };
  try {
    await api.projects.databases.documents.patch(
      upd,
      usersDoc,
      updateMask_fieldPaths: [
        'status',
        'isTemporaryPassword',
        'metadata.hashedPassword',
        'metadata.lastPasswordUpdatedAt',
      ],
    );
  } catch (_) {}

  return Response.ok(jsonEncode({'message': 'password updated'}), headers: {'Content-Type': 'application/json'});
}

void main(List<String> args) async {
  final router = Router()
    ..post('/sendOtp', _sendOtp)
    ..options('/sendOtp', (Request _) => Response(204))
    ..post('/verifyOtp', _verifyOtp)
    ..options('/verifyOtp', (Request _) => Response(204))
    ..get('/health', (Request _) => Response.ok('ok'))
    ..post('/relayEmail', (Request req) async {
      final payload = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final to = (payload['to'] ?? '').toString();
      final subject = (payload['subject'] ?? '').toString();
      final html = (payload['html'] ?? '').toString();
      if (to.isEmpty || subject.isEmpty || html.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'invalid input'}));
      }
      final user = Platform.environment['MAIL_USER'] ?? '';
      final pass = (Platform.environment['MAIL_PASS'] ?? '').replaceAll(' ', '');
      if (user.isEmpty || pass.isEmpty) {
        return Response(500, body: jsonEncode({'message': 'MAIL_USER or MAIL_PASS missing'}));
      }
      final smtp = gmail(user, pass);
      final message = Message()
        ..from = Address(user, 'OTP Service')
        ..recipients.add(to)
        ..subject = subject
        ..html = html;
      try {
        await send(message, smtp);
        return Response.ok(jsonEncode({'success': true}), headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response(500, body: jsonEncode({'message': 'email send failed: $e'}));
      }
    })
    ..options('/relayEmail', (Request _) => Response(204));

  router
    ..post('/resetPasswordViaEmailOtp', _resetPasswordViaEmailOtp)
    ..options('/resetPasswordViaEmailOtp', (Request _) => Response(204));
  router
    ..post('/resetPasswordDirect', _resetPasswordDirect)
    ..options('/resetPasswordDirect', (Request _) => Response(204));

  final corsAll = createMiddleware(
    responseHandler: (Response resp) => resp.change(headers: {
      ...resp.headers,
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
      'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
    }),
  );

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsAll)
      .addHandler(router);

  final port = int.tryParse(Platform.environment['PORT'] ?? '8081') ?? 8081;
  try {
    await serve(handler, InternetAddress.loopbackIPv4, port);
  } catch (_) {
    await serve(handler, InternetAddress.loopbackIPv6, port);
  }
  // no prints per project rules
}
