// ============================================================
// 文件：services/api_service.dart
// 作用：统一 HTTP 请求封装 + 各业务服务类
//
// 使用说明：
//   - baseUrl 改成你的后端地址
//   - 安卓模拟器访问本地：http://10.0.2.2:8080/api
//   - 真机/局域网：http://192.168.x.x:8080/api
// ============================================================

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// ============================================================
// 后端地址配置（只需改这一行）
// ============================================================
const String _baseUrl = 'http://8.163.127.102:8080/api';

// ============================================================
// ApiService：单例，封装 Dio 请求
// ============================================================
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late final Dio _dio;
  bool _initialized = false;

  /// 初始化（在 main.dart 里调用一次）
  Future<void> init() async {
    if (_initialized) return;
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    // 请求拦截器：自动附加 token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ));
    _initialized = true;
  }

  /// 检查是否联网
  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// GET 请求
  Future<Map<String, dynamic>?> get(String path,
      {Map<String, dynamic>? params}) async {
    try {
      final resp = await _dio.get(path, queryParameters: params);
      return resp.data is Map ? Map<String, dynamic>.from(resp.data) : null;
    } on DioException {
      return null;
    }
  }

  /// POST 请求
  Future<Map<String, dynamic>?> post(String path,
      {Map<String, dynamic>? body}) async {
    try {
      final resp = await _dio.post(path, data: body);
      return resp.data is Map ? Map<String, dynamic>.from(resp.data) : null;
    } on DioException {
      return null;
    }
  }

  /// GET 请求，返回原始 Response（用于分页等复杂结构）
  Future<Response?> getRaw(String path,
      {Map<String, dynamic>? params}) async {
    try {
      return await _dio.get(path, queryParameters: params);
    } on DioException {
      return null;
    }
  }

  /// POST 请求，返回原始 Response
  Future<Response?> postRaw(String path,
      {Map<String, dynamic>? body}) async {
    try {
      return await _dio.post(path, data: body);
    } on DioException {
      return null;
    }
  }
}

// ============================================================
// AuthService：用户认证（注册 / 登录 / 退出）
// ============================================================
class AuthService {
  final _api = ApiService();

  /// 注册
  Future<AuthResult> register({
    required String phone,
    required String password,
    String? nickname,
    bool isFemale = false,
  }) async {
    final resp = await _api.post('/auth/register', body: {
      'phone': phone,
      'password': password,
      if (nickname != null) 'nickname': nickname,
      'isFemale': isFemale,
    });
    if (resp == null) return AuthResult.networkError();
    if (resp['token'] != null) {
      await _saveToken(resp['token'], resp);
      return AuthResult.success(resp);
    }
    return AuthResult.fail(resp['msg'] ?? '注册失败');
  }

  /// 手机号+密码登录
  Future<AuthResult> login({
    required String phone,
    required String password,
  }) async {
    final resp = await _api.post('/auth/login', body: {
      'phone': phone,
      'password': password,
    });
    if (resp == null) return AuthResult.networkError();
    if (resp['token'] != null) {
      await _saveToken(resp['token'], resp);
      return AuthResult.success(resp);
    }
    return AuthResult.fail(resp['msg'] ?? '登录失败');
  }

  Future<void> _saveToken(String token, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    if (data['userId'] != null) {
      await prefs.setInt('user_id', (data['userId'] as num).toInt());
    }
    if (data['nickname'] != null) {
      await prefs.setString('user_name', data['nickname']);
    }
    if (data['isAdmin'] != null) {
      await prefs.setBool('is_admin', data['isAdmin'] == true);
    }
    if (data['isFemale'] != null) {
      await prefs.setString(
          'user_gender', data['isFemale'] == true ? 'female' : 'male');
    }
    if (data['starLevel'] != null) {
      await prefs.setInt('study_level', (data['starLevel'] as num).toInt());
    }
  }
}

/// 认证结果
class AuthResult {
  final bool success;
  final String? errorMsg;
  final Map<String, dynamic>? data;

  const AuthResult._({required this.success, this.errorMsg, this.data});

  factory AuthResult.success(Map<String, dynamic> data) =>
      AuthResult._(success: true, data: data);

  factory AuthResult.fail(String msg) =>
      AuthResult._(success: false, errorMsg: msg);

  factory AuthResult.networkError() =>
      AuthResult._(success: false, errorMsg: '网络连接失败，请检查网络');
}

// ============================================================
// LevelService：等级 & 经验
// ============================================================
class LevelApiService {
  final _api = ApiService();

  Future<Map<String, dynamic>?> getLevelInfo(int userId) =>
      _api.get('/level/info', params: {'userId': userId});

  Future<Map<String, dynamic>?> addExp(String action) =>
      _api.post('/level/add-exp', body: {'action': action});
}

// ============================================================
// QAApiService：答疑
// ============================================================
class QAApiService {
  final _api = ApiService();

  Future<Response?> listQuestions({int page = 0, String? category}) =>
      _api.getRaw('/qa/list',
          params: {'page': page, 'size': 20, if (category != null) 'category': category});

  Future<Map<String, dynamic>?> getDetail(int postId) =>
      _api.get('/qa/detail/$postId');

  Future<Map<String, dynamic>?> ask(
          {required String content, String category = '其他'}) =>
      _api.post('/qa/ask', body: {'content': content, 'category': category});

  Future<Map<String, dynamic>?> reply(
          {required int parentId, required String content}) =>
      _api.post('/qa/reply', body: {'parentId': parentId, 'content': content});

  Future<Map<String, dynamic>?> like(int postId) =>
      _api.post('/qa/$postId/like');
}

// ============================================================
// ResourceService：学习资源 + 语录 + 学习计划
// ============================================================
class ResourceService {
  final _api = ApiService();

  /// 首页推荐资源
  Future<List<dynamic>> getRecommendations({int limit = 5}) async {
    final resp = await _api.get('/resource/list', params: {'size': limit, 'page': 0});
    if (resp == null) return [];
    final content = resp['content'];
    return content is List ? content : [];
  }

  /// 我的学习计划（首页展示当前进行中的计划）
  // 注：今日推荐暖句已迁移到 HitokotoService（一言公开 API + 24h 本地缓存），
  // 不再走后端 /quote/today。
  Future<List<dynamic>> getMyStudyPlans() async {
    final resp = await _api.get('/study/plans/active');
    if (resp == null) return [];
    return resp is List ? resp : (resp['plans'] ?? []);
  }

  /// 资源列表（知识小馆）
  Future<List<dynamic>> getResources({int page = 0, int size = 20}) async {
    final resp = await _api.get('/resource/list', params: {'page': page, 'size': size});
    if (resp == null) return [];
    final content = resp['content'];
    return content is List ? content : [];
  }

  /// 上传资源（需登录）
  Future<Map<String, dynamic>?> uploadResource({
    required String title,
    required String description,
    required String fileUrl,
    String category = '其他',
  }) =>
      _api.post('/resource/upload', body: {
        'title': title,
        'description': description,
        'fileUrl': fileUrl,
        'category': category,
      });
}

// ============================================================
// FeedbackApiService：意见反馈
// ============================================================
class FeedbackApiService {
  final _api = ApiService();

  Future<Map<String, dynamic>?> submit(
          {required String content, String category = '其他'}) =>
      _api.post('/feedback/submit',
          body: {'content': content, 'category': category});

  Future<Response?> listFeedback({int page = 0, bool? handled}) =>
      _api.getRaw('/feedback/list', params: {
        'page': page,
        'size': 20,
        if (handled != null) 'handled': handled,
      });
}
