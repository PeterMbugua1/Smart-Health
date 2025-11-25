// [MODIFIED] Imports: Removed flutter_secure_storage, added sqflite and path
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; 
import 'package:crypto/crypto.dart';
import 'dart:async';
import 'package:sqflite/sqflite.dart'; // Added
import 'package:path/path.dart' as p; // Added

void main() {
  runApp(SmartHealthTrackerApp());
}

class SmartHealthTrackerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Health Tracker Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        primaryColor: Color(0xFF00897B),
        scaffoldBackgroundColor: Color(0xFFF5F5F5),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF00897B),
          elevation: 0,
        ),
      ),
      home: SplashScreen(),
    );
  }
}

// ==================== MODELS ====================
class User {
  String id;
  String username;
  String passwordHash;
  String email;
  String role;
  String? specialization;
  String? doctorId;
  DateTime createdAt;
  String? phoneNumber;
  String? profileImage;
  String? securityQuestion;
  String? securityAnswerHash;
  User({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.email,
    this.role = 'patient',
    this.specialization,
    this.doctorId,
    required this.createdAt,
    this.phoneNumber,
    this.profileImage,
    this.securityQuestion,
    this.securityAnswerHash,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'passwordHash': passwordHash,
    'email': email,
    'role': role,
    'specialization': specialization,
    'doctorId': doctorId,
    'createdAt': createdAt.toIso8601String(),
    'phoneNumber': phoneNumber,
    'profileImage': profileImage,
    'securityQuestion': securityQuestion,
    'securityAnswerHash': securityAnswerHash,
  };
  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    username: json['username'],
    passwordHash: json['passwordHash'],
    email: json['email'],
    role: json['role'] ?? 'patient',
    specialization: json['specialization'],
    doctorId: json['doctorId'],
    createdAt: DateTime.parse(json['createdAt']),
    phoneNumber: json['phoneNumber'],
    profileImage: json['profileImage'],
    securityQuestion: json['securityQuestion'],
    securityAnswerHash: json['securityAnswerHash'],
  );
}

// [MODIFIED] HealthRecord model updated for SQL (List/Map conversion)
class HealthRecord {
  String id;
  String userId;
  double weight;
  double height;
  int systolic;
  int diastolic;
  int heartRate;
  double temperature;
  DateTime timestamp;
  String notes;
  String? location;
  double? latitude;
  double? longitude;
  List<String> sharedWith;
  Map<String, String> doctorAdvice;

  HealthRecord({
    required this.id,
    required this.userId,
    required this.weight,
    required this.height,
    required this.systolic,
    required this.diastolic,
    required this.heartRate,
    required this.temperature,
    required this.timestamp,
    this.notes = '',
    this.location,
    this.latitude,
    this.longitude,
    List<String>? sharedWith,
    Map<String, String>? doctorAdvice,
  }) : this.sharedWith = sharedWith ?? [],
       this.doctorAdvice = doctorAdvice ?? {};

  double get bmi => weight / ((height / 100) * (height / 100));
  String get bmiCategory {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  String get healthStatus {
    bool normalBP =
        systolic >= 90 && systolic <= 120 && diastolic >= 60 && diastolic <= 80;
    bool normalHR = heartRate >= 60 && heartRate <= 100;
    bool normalTemp = temperature >= 36.5 && temperature <= 37.5;
    bool normalBMI = bmi >= 18.5 && bmi < 25;
    if (normalBP && normalHR && normalTemp && normalBMI) return 'Excellent';
    if (!normalBP || !normalHR) return 'Needs Attention';
    return 'Good';
  }

  // [MODIFIED] toJson to convert list/map to JSON strings
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'weight': weight,
    'height': height,
    'systolic': systolic,
    'diastolic': diastolic,
    'heartRate': heartRate,
    'temperature': temperature,
    'timestamp': timestamp.toIso8601String(),
    'notes': notes,
    'location': location,
    'latitude': latitude,
    'longitude': longitude,
    // Convert List to JSON String
    'sharedWith': jsonEncode(sharedWith),
    // Convert Map to JSON String
    'doctorAdvice': jsonEncode(doctorAdvice),
  };

  // [MODIFIED] fromJson to parse JSON strings back to list/map
  factory HealthRecord.fromJson(Map<String, dynamic> json) => HealthRecord(
    id: json['id'],
    userId: json['userId'],
    weight: json['weight'].toDouble(),
    height: json['height'].toDouble(),
    systolic: json['systolic'],
    diastolic: json['diastolic'],
    heartRate: json['heartRate'],
    temperature: json['temperature'].toDouble(),
    timestamp: DateTime.parse(json['timestamp']),
    notes: json['notes'] ?? '',
    location: json['location'],
    latitude: json['latitude']?.toDouble(),
    longitude: json['longitude']?.toDouble(),
    // Parse JSON String back to List
    sharedWith: List<String>.from(jsonDecode(json['sharedWith'] ?? '[]')),
    // Parse JSON String back to Map
    doctorAdvice: Map<String, String>.from(
      jsonDecode(json['doctorAdvice'] ?? '{}'),
    ),
  );
}

// [MODIFIED] Message model updated for SQL (bool conversion)
class Message {
  String id;
  String senderId;
  String receiverId;
  String content;
  DateTime timestamp;
  bool isRead;
  String? recordId;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.recordId,
  });

  // [MODIFIED] Updated for SQL (bool to INTEGER)
  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'receiverId': receiverId,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead ? 1 : 0, // Convert bool to 1 or 0
    'recordId': recordId,
  };

  // [MODIFIED] Updated for SQL (INTEGER to bool)
  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'],
    senderId: json['senderId'],
    receiverId: json['receiverId'],
    content: json['content'],
    timestamp: DateTime.parse(json['timestamp']),
    isRead: json['isRead'] == 1, // Convert 1 or 0 to bool
    recordId: json['recordId'],
  );
}

// [MODIFIED] DoctorPatientConnection model updated for SQL (bool conversion)
class DoctorPatientConnection {
  String id;
  String patientId;
  String doctorId;
  DateTime connectedAt;
  bool isActive;

  DoctorPatientConnection({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.connectedAt,
    this.isActive = true,
  });

  // [MODIFIED] Updated for SQL (bool to INTEGER)
  Map<String, dynamic> toJson() => {
    'id': id,
    'patientId': patientId,
    'doctorId': doctorId,
    'connectedAt': connectedAt.toIso8601String(),
    'isActive': isActive ? 1 : 0, // Convert bool to 1 or 0
  };

  // [MODIFIED] Updated for SQL (INTEGER to bool)
  factory DoctorPatientConnection.fromJson(Map<String, dynamic> json) =>
      DoctorPatientConnection(
        id: json['id'],
        patientId: json['patientId'],
        doctorId: json['doctorId'],
        connectedAt: DateTime.parse(json['connectedAt']),
        isActive: json['isActive'] == 1, // Convert 1 or 0 to bool
      );
}

// ==================== DATABASE SERVICE ====================
// [REPLACED] SecureStorageService is replaced with DatabaseService
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path =p.join(await getDatabasesPath(), 'smart_health.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create Users Table
    await db.execute('''
      CREATE TABLE users(
        id TEXT PRIMARY KEY,
        username TEXT,
        passwordHash TEXT,
        email TEXT UNIQUE,
        role TEXT,
        specialization TEXT,
        doctorId TEXT,
        createdAt TEXT,
        phoneNumber TEXT,
        profileImage TEXT,
        securityQuestion TEXT,
        securityAnswerHash TEXT
      )
    ''');

    // Create Health Records Table
    await db.execute('''
      CREATE TABLE health_records(
        id TEXT PRIMARY KEY,
        userId TEXT,
        weight REAL,
        height REAL,
        systolic INTEGER,
        diastolic INTEGER,
        heartRate INTEGER,
        temperature REAL,
        timestamp TEXT,
        notes TEXT,
        location TEXT,
        latitude REAL,
        longitude REAL,
        sharedWith TEXT,
        doctorAdvice TEXT,
        FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Create Messages Table
    await db.execute('''
      CREATE TABLE messages(
        id TEXT PRIMARY KEY,
        senderId TEXT,
        receiverId TEXT,
        content TEXT,
        timestamp TEXT,
        isRead INTEGER,
        recordId TEXT
      )
    ''');

    // Create Connections Table
    await db.execute('''
      CREATE TABLE connections(
        id TEXT PRIMARY KEY,
        patientId TEXT,
        doctorId TEXT,
        connectedAt TEXT,
        isActive INTEGER,
        FOREIGN KEY (patientId) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (doctorId) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
  }

  // ===== User CRUD =====
  Future<void> insertUser(User user) async {
    final db = await database;
    await db.insert(
      'users',
      user.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateUser(User user) async {
    final db = await database;
    await db.update(
      'users',
      user.toJson(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users');
    return List.generate(maps.length, (i) => User.fromJson(maps[i]));
  }

  // ===== HealthRecord CRUD =====
  Future<void> insertRecord(HealthRecord record) async {
    final db = await database;
    await db.insert(
      'health_records',
      record.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateRecord(HealthRecord record) async {
    final db = await database;
    await db.update(
      'health_records',
      record.toJson(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<List<HealthRecord>> getAllRecords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('health_records');
    return List.generate(maps.length, (i) => HealthRecord.fromJson(maps[i]));
  }

  // ===== Message CRUD =====
  Future<void> insertMessage(Message message) async {
    final db = await database;
    await db.insert(
      'messages',
      message.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateMessage(Message message) async {
    final db = await database;
    await db.update(
      'messages',
      message.toJson(),
      where: 'id = ?',
      whereArgs: [message.id],
    );
  }

  Future<List<Message>> getAllMessages() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('messages');
    return List.generate(maps.length, (i) => Message.fromJson(maps[i]));
  }

  // ===== Connection CRUD =====
  Future<void> insertConnection(DoctorPatientConnection connection) async {
    final db = await database;
    await db.insert(
      'connections',
      connection.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateConnection(DoctorPatientConnection connection) async {
    final db = await database;
    await db.update(
      'connections',
      connection.toJson(),
      where: 'id = ?',
      whereArgs: [connection.id],
    );
  }

  Future<List<DoctorPatientConnection>> getAllConnections() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('connections');
    return List.generate(
      maps.length,
      (i) => DoctorPatientConnection.fromJson(maps[i]),
    );
  }

  // Helper for password hashing, moved from SecureStorageService
  static String hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }
}

// ==================== DATA SERVICE ====================
// [MODIFIED] DataService now uses DatabaseService
class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  // [MODIFIED] Add instance of new DB service
  final DatabaseService _db = DatabaseService();

  List<User> users = [];
  List<HealthRecord> records = [];
  List<Message> messages = [];
  List<DoctorPatientConnection> connections = [];
  Future<void>? _initializationFuture;
  final StreamController<void> _dataUpdateController =
      StreamController.broadcast();
  Stream<void> get dataUpdates => _dataUpdateController.stream;

  Future<void> loadData() async {
    if (_initializationFuture != null) {
      return _initializationFuture;
    }
    _initializationFuture = _loadDataInternal();
    return _initializationFuture;
  }

  // [MODIFIED] Load from SQL database
  Future<void> _loadDataInternal() async {
    print(' 🔄  Loading data from SQL database...');
    try {
      await _db.database; // Ensures DB is created
      users = await _db.getAllUsers();
      records = await _db.getAllRecords();
      messages = await _db.getAllMessages();
      connections = await _db.getAllConnections();

      print(
        ' ✅  Data loaded: ${users.length} users, ${records.length} records',
      );
      _dataUpdateController.add(null);
    } catch (e) {
      print(' ❌  Error loading data: $e');
      users = [];
      records = [];
      messages = [];
      connections = [];
    }
  }

  Future<void> ensureInitialized() async {
    if (_initializationFuture == null) {
      await loadData();
    } else {
      await _initializationFuture;
    }
  }

  Future<User?> authenticateUser(String username, String password) async {
    await ensureInitialized();

    // Use the hashing method from DatabaseService
    final passwordHash = DatabaseService.hashPassword(password);

    try {
      final user = users.firstWhere(
        (u) =>
            u.username.toLowerCase() == username.toLowerCase() &&
            u.passwordHash == passwordHash,
      );
      return user;
    } catch (e) {
      return null;
    }
  }

  // [MODIFIED] Register user inserts into DB
  Future<bool> registerUser(User user) async {
    await ensureInitialized();

    final usernameExists = users.any(
      (u) => u.username.toLowerCase() == user.username.toLowerCase(),
    );
    final emailExists = users.any(
      (u) => u.email.toLowerCase() == user.email.toLowerCase(),
    );

    if (usernameExists || emailExists) {
      return false;
    }

    users.add(user); // Add to in-memory list
    await _db.insertUser(user); // Add to DB
    _dataUpdateController.add(null);
    return true;
  }

  // [MODIFIED] Add record inserts into DB
  Future<void> addHealthRecord(HealthRecord record) async {
    await ensureInitialized();

    // Modify record *before* saving
    final patient = users.firstWhere((u) => u.id == record.userId);
    if (patient.doctorId != null) {
      record.sharedWith.add(patient.doctorId!);
    }

    records.add(record); // Add to in-memory list
    await _db.insertRecord(record); // Add to DB

    // Send notification if doctor exists
    if (patient.doctorId != null) {
      await sendMessage(
        Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderId: 'system',
          receiverId: patient.doctorId!,
          content: '${patient.username} has shared a new health record.',
          timestamp: DateTime.now(),
        ),
      );
    }
    _dataUpdateController.add(null);
  }

  // [MODIFIED] Add advice updates the record in DB
  Future<void> addDoctorAdvice(
    String recordId,
    String doctorId,
    String advice,
  ) async {
    await ensureInitialized();
    final record = records.firstWhere((r) => r.id == recordId);
    final doctor = users.firstWhere((u) => u.id == doctorId);

    record.doctorAdvice[doctorId] = advice; // Update in-memory
    await _db.updateRecord(record); // Update in DB

    await sendMessage(
      Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: doctorId,
        receiverId: record.userId,
        content:
            'Dr. ${doctor.username} has provided advice on your health record.',
        timestamp: DateTime.now(),
        recordId: recordId,
      ),
    );
    _dataUpdateController.add(null);
  }

  // [NEW METHOD] For saving password reset
  Future<void> updateUserProfile(User user) async {
    await ensureInitialized();
    // Find the user in the list and update it
    int index = users.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      users[index] = user; // Update in-memory
    }
    await _db.updateUser(user); // Update in DB
    _dataUpdateController.add(null);
  }

  List<HealthRecord> getRecordsForUser(String userId) {
    return records.where((r) => r.userId == userId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  List<HealthRecord> getSharedRecordsForDoctor(String doctorId) {
    return records.where((r) => r.sharedWith.contains(doctorId)).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  List<User> getAllDoctors() {
    return users.where((u) => u.role == 'doctor').toList();
  }

  // [MODIFIED] Connect patient inserts/updates in DB
  Future<void> connectPatientToDoctor(String patientId, String doctorId) async {
    await ensureInitialized();
    final connection = DoctorPatientConnection(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: patientId,
      doctorId: doctorId,
      connectedAt: DateTime.now(),
    );
    connections.add(connection); // Add to in-memory list

    final patient = users.firstWhere((u) => u.id == patientId);
    patient.doctorId = doctorId; // Update in-memory

    await _db.insertConnection(connection); // Add to DB
    await _db.updateUser(patient); // Update in DB
    _dataUpdateController.add(null);
  }

  List<User> getPatientsForDoctor(String doctorId) {
    final patientIds = connections
        .where((c) => c.doctorId == doctorId && c.isActive)
        .map((c) => c.patientId)
        .toSet();
    return users.where((u) => patientIds.contains(u.id)).toList();
  }

  User? getDoctorForPatient(String patientId) {
    final patient = users.firstWhere((u) => u.id == patientId);
    if (patient.doctorId != null) {
      try {
        return users.firstWhere((u) => u.id == patient.doctorId);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // [MODIFIED] Send message inserts into DB
  Future<void> sendMessage(Message message) async {
    await ensureInitialized();
    messages.add(message); // Add to in-memory list
    await _db.insertMessage(message); // Add to DB
    _dataUpdateController.add(null);
  }

  // [MODIFIED] Mark message as read updates DB
  Future<void> markMessageAsRead(String messageId) async {
    await ensureInitialized();
    final message = messages.firstWhere((m) => m.id == messageId);
    message.isRead = true; // Update in-memory
    await _db.updateMessage(message); // Update in DB
    _dataUpdateController.add(null);
  }

  List<Message> getConversation(String userId1, String userId2) {
    return messages
        .where(
          (m) =>
              (m.senderId == userId1 && m.receiverId == userId2) ||
              (m.senderId == userId2 && m.receiverId == userId1),
        )
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  int getUnreadMessageCount(String userId) {
    return messages.where((m) => m.receiverId == userId && !m.isRead).length;
  }

  Future<Map<String, dynamic>> fetchHealthTips() async {
    try {
      final response = await http
          .get(Uri.parse('https://api.quotable.io/random?tags=health|wellness'))
          .timeout(Duration(seconds: 5));
      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(response.body)};
      }
    } catch (e) {
      print('API Error: $e');
    }
    return {
      'success': false,
      'tips': [
        'Stay hydrated - Drink at least 8 glasses of water daily',
        'Exercise regularly - Aim for 30 minutes of activity',
        'Get 7-8 hours of quality sleep each night',
      ],
    };
  }
}

// ==================== LOCATION SERVICE ====================
// [No changes needed]
class LocationService {
  static Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {'error': 'Location services are disabled'};
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return {'error': 'Location permissions are denied'};
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return {'error': 'Location permissions are permanently denied'};
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      String locationName = await _getLocationName(
        position.latitude,
        position.longitude,
      );
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'location': locationName,
      };
    } catch (e) {
      return {'error': 'Failed to get location: $e'};
    }
  }

  static Future<String> _getLocationName(double lat, double lon) async {
  try {
    // 1. Use the geocoding package to convert lat/lon to Placemark objects
    List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);

    // 2. Check if any results were returned
    if (placemarks.isNotEmpty) {
      Placemark place = placemarks.first;

      // 3. Construct the desired address string from placemark components
      // This format includes street, sub-locality (e.g., neighborhood), city, and country.
      String address =
          '${place.street}, ${place.subLocality}, ${place.locality}, ${place.country}';
      
      // If you only want City and Country, you can simplify it to:
      // String address = '${place.locality}, ${place.country}';

      return address;
    } else {
      // If no placemarks are found, fall back to the generic error handling
      throw Exception('No address found for coordinates');
    }
  } catch (e) {
    print('Geocoding error: $e');
  }
  return 'Location: $lat, $lon'; // Fallback: returns coordinates if geocoding fails
}
}

// ==================== SPLASH SCREEN ====================
// [No changes needed]
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await DataService().loadData();
    await Future.delayed(Duration(seconds: 2));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AuthenticationScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF00897B), Color(0xFF004D40)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite, size: 100, color: Colors.white),
              SizedBox(height: 24),
              Text(
                'Smart Health Tracker',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Your Health, Our Priority',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              SizedBox(height: 40),
              CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== AUTHENTICATION SCREEN ====================
// [MODIFIED] Uses new hashing method from DatabaseService
class AuthenticationScreen extends StatefulWidget {
  @override
  _AuthenticationScreenState createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _specializationController = TextEditingController();
  final _securityAnswerController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedRole = 'patient';
  String? _selectedSecurityQuestion;
  final List<String> _securityQuestions = [
    'What was the name of your first pet?',
    'In what city were you born?',
    'What is your mother\'s maiden name?',
    'What was your childhood nickname?',
    'What is the name of your favorite teacher?',
  ];
  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    _securityAnswerController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        final user = await DataService().authenticateUser(
          _usernameController.text.trim(),
          _passwordController.text,
        );
        setState(() => _isLoading = false);
        if (user != null && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen(user: user)),
          );
        } else {
          _showMessage('Invalid username or password', isError: true);
        }
      } else {
        final user = User(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          username: _usernameController.text.trim(),
          // [MODIFIED] Use hashing from DatabaseService
          passwordHash: DatabaseService.hashPassword(_passwordController.text),
          email: _emailController.text.trim(),
          role: _selectedRole,
          specialization: _selectedRole == 'doctor'
              ? _specializationController.text.trim()
              : null,
          createdAt: DateTime.now(),
          phoneNumber: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          securityQuestion: _selectedSecurityQuestion,
          // [MODIFIED] Use hashing from DatabaseService
          securityAnswerHash: DatabaseService.hashPassword(
            _securityAnswerController.text.trim().toLowerCase(),
          ),
        );
        final success = await DataService().registerUser(user);
        setState(() => _isLoading = false);
        if (success) {
          _showMessage(
            'Registration successful! Please login.',
            isError: false,
          );
          setState(() => _isLogin = true);
          _clearFields();
        } else {
          _showMessage('Username or email already exists', isError: true);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('An error occurred. Please try again.', isError: true);
    }
  }

  void _clearFields() {
    _usernameController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _emailController.clear();
    _phoneController.clear();
    _specializationController.clear();
    _securityAnswerController.clear();
    setState(() {
      _selectedSecurityQuestion = null;
    });
  }

  void _showMessage(String message, {required bool isError}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _navigateToPasswordReset() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PasswordResetScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF00897B), Color(0xFF004D40)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Card(
                margin: EdgeInsets.zero,
                child: Container(
                  constraints: BoxConstraints(maxWidth: 500),
                  padding: EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite,
                          size: 64,
                          color: Theme.of(context).primaryColor,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Smart Health Tracker',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          _isLogin ? 'Welcome Back' : 'Create Account',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 32),
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) {
                            if (v?.trim().isEmpty ?? true)
                              return 'Username is required';
                            if (!_isLogin && v!.trim().length < 3) {
                              return 'Username must be at least 3 characters';
                            }
                            return null;
                          },
                        ),
                        if (!_isLogin) ...[
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) {
                              if (v?.trim().isEmpty ?? true)
                                return 'Email is required';
                              if (!RegExp(
                                r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(v!)) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Phone Number (Optional)',
                              prefixIcon: Icon(Icons.phone),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) {
                            if (v?.isEmpty ?? true)
                              return 'Password is required';
                            if (!_isLogin && v!.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        if (!_isLogin) ...[
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) {
                              if (v?.isEmpty ?? true)
                                return 'Please confirm your password';
                              if (v != _passwordController.text)
                                return 'Passwords do not match';
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedRole,
                            decoration: InputDecoration(
                              labelText: 'Role',
                              prefixIcon: Icon(Icons.work),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'patient',
                                child: Text('Patient'),
                              ),
                              DropdownMenuItem(
                                value: 'doctor',
                                child: Text('Doctor'),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _selectedRole = v!),
                          ),
                          if (_selectedRole == 'doctor') ...[
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _specializationController,
                              decoration: InputDecoration(
                                labelText: 'Specialization',
                                prefixIcon: Icon(Icons.medical_services),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                helperText:
                                    'e.g., Cardiologist, General Practitioner',
                              ),
                              validator: (v) => (v?.trim().isEmpty ?? true)
                                  ? 'Required for doctors'
                                  : null,
                            ),
                          ],
                          SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedSecurityQuestion,
                            decoration: InputDecoration(
                              labelText: 'Security Question',
                              prefixIcon: Icon(Icons.security),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              helperText: 'For password recovery',
                            ),
                            items: _securityQuestions.map((q) {
                              return DropdownMenuItem(
                                value: q,
                                child: Text(q, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedSecurityQuestion = v),
                            validator: (v) => v == null
                                ? 'Please select a security question'
                                : null,
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _securityAnswerController,
                            decoration: InputDecoration(
                              labelText: 'Security Answer',
                              prefixIcon: Icon(Icons.question_answer),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) {
                              if (v?.trim().isEmpty ?? true)
                                return 'Security answer is required';
                              if (v!.trim().length < 2)
                                return 'Answer too short';
                              return null;
                            },
                          ),
                        ],
                        SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    _isLogin ? 'LOGIN' : 'REGISTER',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        if (_isLogin) ...[
                          SizedBox(height: 12),
                          TextButton(
                            onPressed: _navigateToPasswordReset,
                            child: Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() => _isLogin = !_isLogin);
                            _clearFields();
                            _formKey.currentState?.reset();
                          },
                          child: Text(
                            _isLogin
                                ? 'Don\'t have an account? Register'
                                : 'Already have an account? Login',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== PASSWORD RESET SCREEN ====================
// [MODIFIED] Uses new hashing method and new DataService.updateUserProfile
class PasswordResetScreen extends StatefulWidget {
  @override
  _PasswordResetScreenState createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _securityAnswerController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  int _currentStep = 0;
  User? _foundUser;
  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _securityAnswerController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await DataService().ensureInitialized();

      final username = _usernameController.text.trim();
      final email = _emailController.text.trim();
      final user = DataService().users.firstWhere(
        (u) =>
            u.username.toLowerCase() == username.toLowerCase() &&
            u.email.toLowerCase() == email.toLowerCase(),
        orElse: () => throw Exception('User not found'),
      );
      if (user.securityQuestion == null || user.securityAnswerHash == null) {
        _showMessage(
          'This account has no security questions set up.',
          isError: true,
        );
        setState(() => _isLoading = false);
        return;
      }
      setState(() {
        _foundUser = user;
        _currentStep = 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage(
        'User not found. Please check your credentials.',
        isError: true,
      );
    }
  }

  Future<void> _verifySecurityAnswer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final answer = _securityAnswerController.text.trim().toLowerCase();
    // [MODIFIED] Use hashing from DatabaseService
    final answerHash = DatabaseService.hashPassword(answer);
    if (answerHash == _foundUser!.securityAnswerHash) {
      setState(() {
        _currentStep = 2;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      _showMessage('Incorrect answer. Please try again.', isError: true);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      // [MODIFIED] Use hashing from DatabaseService
      _foundUser!.passwordHash = DatabaseService.hashPassword(
        _newPasswordController.text,
      );

      // [MODIFIED] Call the new DataService method to update the user in the DB
      await DataService().updateUserProfile(_foundUser!);

      setState(() => _isLoading = false);
      _showMessage('Password reset successful!', isError: false);

      await Future.delayed(Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('Failed to reset password.', isError: true);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reset Password')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF00897B).withOpacity(0.1), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Card(
                margin: EdgeInsets.zero,
                child: Container(
                  constraints: BoxConstraints(maxWidth: 500),
                  padding: EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_reset,
                          size: 64,
                          color: Theme.of(context).primaryColor,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Reset Your Password',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        SizedBox(height: 32),
                        if (_currentStep == 0) ...[
                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) => (v?.trim().isEmpty ?? true)
                                ? 'Username is required'
                                : null,
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) {
                              if (v?.trim().isEmpty ?? true)
                                return 'Email is required';
                              if (!RegExp(
                                r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(v!)) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _verifyUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Text(
                                      'Continue',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                        if (_currentStep == 1) ...[
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.teal[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Security Question:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  _foundUser!.securityQuestion!,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _securityAnswerController,
                            decoration: InputDecoration(
                              labelText: 'Your Answer',
                              prefixIcon: Icon(Icons.question_answer),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) => (v?.trim().isEmpty ?? true)
                                ? 'Answer is required'
                                : null,
                          ),
                          SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _currentStep = 0;
                                      _foundUser = null;
                                      _securityAnswerController.clear();
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text('Back'),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _verifySecurityAnswer,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).primaryColor,
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          'Verify',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_currentStep == 2) ...[
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _obscureNewPassword,
                            decoration: InputDecoration(
                              labelText: 'New Password',
                              prefixIcon: Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureNewPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () => setState(
                                  () => _obscureNewPassword =
                                      !_obscureNewPassword,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) {
                              if (v?.isEmpty ?? true)
                                return 'Password is required';
                              if (v!.length < 6)
                                return 'Password must be at least 6 characters';
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              labelText: 'Confirm New Password',
                              prefixIcon: Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) {
                              if (v?.isEmpty ?? true)
                                return 'Please confirm your password';
                              if (v != _newPasswordController.text)
                                return 'Passwords do not match';
                              return null;
                            },
                          ),
                          SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _resetPassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Text(
                                      'Reset Password',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== HOME SCREEN ====================
// [No changes needed]
class HomeScreen extends StatefulWidget {
  final User user;
  HomeScreen({required this.user});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late List<Widget> _screens;
  StreamSubscription? _dataSubscription;
  @override
  void initState() {
    super.initState();
    _screens = widget.user.role == 'patient'
        ? [
            DashboardScreen(user: widget.user),
            AddRecordScreen(user: widget.user),
            RecordsScreen(user: widget.user),
            MyDoctorsScreen(user: widget.user),
            MessagesScreen(user: widget.user),
          ]
        : [
            DoctorDashboardScreen(user: widget.user),
            DoctorPatientsScreen(user: widget.user),
            MessagesScreen(user: widget.user),
          ];
    _dataSubscription = DataService().dataUpdates.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = DataService().getUnreadMessageCount(widget.user.id);

    return Scaffold(
      appBar: AppBar(
        title: Text('Smart Health Tracker'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications),
                onPressed: _showNotifications,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$unreadCount',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => AuthenticationScreen()),
              );
            },
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        items: widget.user.role == 'patient'
            ? [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Add'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history),
                  label: 'Records',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.medical_services),
                  label: 'Doctors',
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    children: [
                      Icon(Icons.message),
                      if (unreadCount > 0)
                        Positioned(
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: BoxConstraints(
                              minWidth: 12,
                              minHeight: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: 'Messages',
                ),
              ]
            : [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people),
                  label: 'Patients',
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    children: [
                      Icon(Icons.message),
                      if (unreadCount > 0)
                        Positioned(
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: BoxConstraints(
                              minWidth: 12,
                              minHeight: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: 'Messages',
                ),
              ],
      ),
    );
  }

  void _showNotifications() {
    final unreadMessages = DataService().messages
        .where((m) => m.receiverId == widget.user.id && !m.isRead)
        .toList();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Notifications'),
        content: unreadMessages.isEmpty
            ? Text('No new notifications')
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: unreadMessages.map((msg) {
                    final sender = DataService().users.firstWhere(
                      (u) => u.id == msg.senderId,
                    );
                    return ListTile(
                      leading: Icon(Icons.message, color: Colors.teal),
                      title: Text(sender.username),
                      subtitle: Text(
                        msg.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        DateFormat('MMM dd').format(msg.timestamp),
                        style: TextStyle(fontSize: 12),
                      ),
                    );
                  }).toList(),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ==================== PATIENT DASHBOARD ====================
// [No changes needed]
class DashboardScreen extends StatefulWidget {
  final User user;
  DashboardScreen({required this.user});
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _healthTips;
  bool _loadingTips = true;
  @override
  void initState() {
    super.initState();
    _loadHealthTips();
  }

  Future<void> _loadHealthTips() async {
    final tips = await DataService().fetchHealthTips();
    if (mounted) {
      setState(() {
        _healthTips = tips;
        _loadingTips = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = DataService().getRecordsForUser(widget.user.id);
    final latestRecord = records.isNotEmpty ? records.first : null;
    final doctor = DataService().getDoctorForPatient(widget.user.id);
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, ${widget.user.username}!',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Here\'s your health summary',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          SizedBox(height: 24),
          if (doctor != null)
            Card(
              color: Colors.teal[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.medical_services, color: Colors.teal, size: 40),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Doctor',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            'Dr. ${doctor.username}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (doctor.specialization != null)
                            Text(
                              doctor.specialization!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.teal[700],
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.message, color: Colors.teal),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              currentUser: widget.user,
                              otherUser: doctor,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(height: 16),
          if (latestRecord != null) ...[
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.monitor_weight,
                        size: 32,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BMI',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            latestRecord.bmi.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            latestRecord.bmiCategory,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: latestRecord.healthStatus == 'Excellent'
                            ? Colors.green.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        latestRecord.healthStatus,
                        style: TextStyle(
                          color: latestRecord.healthStatus == 'Excellent'
                              ? Colors.green[700]
                              : Colors.orange[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.favorite, color: Colors.red, size: 28),
                          SizedBox(height: 12),
                          Text(
                            'Blood Pressure',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${latestRecord.systolic}/${latestRecord.diastolic}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.monitor_heart,
                            color: Colors.pink,
                            size: 28,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Heart Rate',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${latestRecord.heartRate} bpm',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (latestRecord.doctorAdvice.isNotEmpty) ...[
              SizedBox(height: 16),
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.medical_information, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Doctor\'s Advice',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      ...latestRecord.doctorAdvice.entries.map((entry) {
                        final doc = DataService().users.firstWhere(
                          (u) => u.id == entry.key,
                        );
                        return Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dr. ${doc.username}:',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(entry.value),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ],
          ] else ...[
            Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.add_chart, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No health records yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Add your first record to get started'),
                    ],
                  ),
                ),
              ),
            ),
          ],
          SizedBox(height: 24),
          Text(
            'Health Tips',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          _loadingTips
              ? Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              : Card(
                  color: Colors.amber[50],
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb, color: Colors.amber[700]),
                            SizedBox(width: 8),
                            Text(
                              'Daily Health Tips',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Spacer(),
                            IconButton(
                              icon: Icon(Icons.refresh, size: 20),
                              onPressed: () {
                                setState(() => _loadingTips = true);
                                _loadHealthTips();
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          _healthTips?['data']?['content'] ??
                              _healthTips?['tips']?.first ??
                              'Stay healthy and active!',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ==================== ADD RECORD SCREEN ====================
// [No changes needed]
class AddRecordScreen extends StatefulWidget {
  final User user;
  AddRecordScreen({required this.user});
  @override
  _AddRecordScreenState createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;
  bool _includeLocation = false;
  Map<String, dynamic>? _locationData;
  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _heartRateController.dispose();
    _temperatureController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _isSubmitting = true);
    final location = await LocationService.getCurrentLocation();
    setState(() {
      _locationData = location;
      _isSubmitting = false;
    });
    if (location != null && location.containsKey('error')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(location['error'])));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location captured: ${location?['location']}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _submitRecord() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final record = HealthRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: widget.user.id,
      weight: double.parse(_weightController.text),
      height: double.parse(_heightController.text),
      systolic: int.parse(_systolicController.text),
      diastolic: int.parse(_diastolicController.text),
      heartRate: int.parse(_heartRateController.text),
      temperature: double.parse(_temperatureController.text),
      timestamp: DateTime.now(),
      notes: _notesController.text,
      location: _includeLocation && _locationData != null
          ? _locationData!['location']
          : null,
      latitude: _includeLocation && _locationData != null
          ? _locationData!['latitude']
          : null,
      longitude: _includeLocation && _locationData != null
          ? _locationData!['longitude']
          : null,
    );
    await DataService().addHealthRecord(record);
    setState(() => _isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Health record added and shared with your doctor!'),
        backgroundColor: Colors.green,
      ),
    );
    _formKey.currentState!.reset();
    _weightController.clear();
    _heightController.clear();
    _systolicController.clear();
    _diastolicController.clear();
    _heartRateController.clear();
    _temperatureController.clear();
    _notesController.clear();
    setState(() {
      _includeLocation = false;
      _locationData = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Health Record',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            TextFormField(
              controller: _weightController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Weight (kg)',
                prefixIcon: Icon(Icons.monitor_weight),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) {
                if (v?.isEmpty ?? true) return 'Required';
                final val = double.tryParse(v!);
                if (val == null || val <= 0) return 'Invalid';
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _heightController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Height (cm)',
                prefixIcon: Icon(Icons.height),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) {
                if (v?.isEmpty ?? true) return 'Required';
                final val = double.tryParse(v!);
                if (val == null || val <= 0) return 'Invalid';
                return null;
              },
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _systolicController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Systolic',
                      prefixIcon: Icon(Icons.favorite),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _diastolicController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Diastolic',
                      prefixIcon: Icon(Icons.favorite_border),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _heartRateController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Heart Rate (bpm)',
                prefixIcon: Icon(Icons.monitor_heart),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _temperatureController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Temperature (°C)',
                prefixIcon: Icon(Icons.thermostat),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            SizedBox(height: 16),
            Card(
              child: CheckboxListTile(
                value: _includeLocation,
                onChanged: (val) {
                  setState(() => _includeLocation = val!);
                  if (val! && _locationData == null) {
                    _getLocation();
                  }
                },
                title: Text('Include GPS Location'),
                subtitle:
                    _locationData != null &&
                        !_locationData!.containsKey('error')
                    ? Text(' 📍  ${_locationData!['location']}')
                    : null,
                secondary: Icon(Icons.location_on, color: Colors.teal),
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: 'Any additional information...',
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRecord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Save Record',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== RECORDS SCREEN ====================
// [No changes needed]
class RecordsScreen extends StatelessWidget {
  final User user;
  RecordsScreen({required this.user});
  @override
  Widget build(BuildContext context) {
    final records = DataService().getRecordsForUser(user.id);
    return Scaffold(
      body: records.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No health records yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _showRecordDetails(context, record, user),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat(
                                  'MMM dd, yyyy',
                                ).format(record.timestamp),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: record.healthStatus == 'Excellent'
                                      ? Colors.green.withOpacity(0.2)
                                      : record.healthStatus == 'Good'
                                      ? Colors.blue.withOpacity(0.2)
                                      : Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  record.healthStatus,
                                  style: TextStyle(
                                    color: record.healthStatus == 'Excellent'
                                        ? Colors.green[700]
                                        : record.healthStatus == 'Good'
                                        ? Colors.blue[700]
                                        : Colors.orange[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'BMI: ${record.bmi.toStringAsFixed(1)} | BP: ${record.systolic}/${record.diastolic} | HR: ${record.heartRate} bpm',
                          ),
                          if (record.location != null) ...[
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    record.location!,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (record.doctorAdvice.isNotEmpty) ...[
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.medical_information,
                                  size: 16,
                                  color: Colors.blue,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Doctor\'s advice available',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showRecordDetails(
    BuildContext context,
    HealthRecord record,
    User user,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Health Record Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(record.timestamp)}',
              ),
              Divider(),
              Text('Weight: ${record.weight} kg'),
              Text('Height: ${record.height} cm'),
              Text(
                'BMI: ${record.bmi.toStringAsFixed(2)} (${record.bmiCategory})',
              ),
              Divider(),
              Text(
                'Blood Pressure: ${record.systolic}/${record.diastolic} mmHg',
              ),
              Text('Heart Rate: ${record.heartRate} bpm'),
              Text('Temperature: ${record.temperature}°C'),
              Text('Status: ${record.healthStatus}'),
              if (record.location != null) ...[
                Divider(),
                Text('Location: ${record.location}'),
              ],
              if (record.notes.isNotEmpty) ...[
                Divider(),
                Text('Notes: ${record.notes}'),
              ],
              if (record.doctorAdvice.isNotEmpty) ...[
                Divider(),
                Text(
                  'Doctor\'s Advice:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                ...record.doctorAdvice.entries.map((entry) {
                  final doc = DataService().users.firstWhere(
                    (u) => u.id == entry.key,
                  );
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dr. ${doc.username}:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(entry.value),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ==================== MY DOCTORS SCREEN ====================
// [No changes needed]
class MyDoctorsScreen extends StatefulWidget {
  final User user;
  MyDoctorsScreen({required this.user});
  @override
  _MyDoctorsScreenState createState() => _MyDoctorsScreenState();
}

class _MyDoctorsScreenState extends State<MyDoctorsScreen> {
  @override
  Widget build(BuildContext context) {
    final currentDoctor = DataService().getDoctorForPatient(widget.user.id);
    final allDoctors = DataService().getAllDoctors();
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Doctors',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 24),
          if (currentDoctor != null) ...[
            Text(
              'Connected Doctor',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.medical_services, color: Colors.white),
                ),
                title: Text('Dr. ${currentDoctor.username}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (currentDoctor.specialization != null)
                      Text(currentDoctor.specialization!),
                    Text(currentDoctor.email),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(Icons.message, color: Colors.teal),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          currentUser: widget.user,
                          otherUser: currentDoctor,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: 24),
          ],
          Text(
            'Available Doctors',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          if (allDoctors.isEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No doctors registered yet')),
              ),
            )
          else
            ...allDoctors.map((doctor) {
              final isConnected = currentDoctor?.id == doctor.id;
              return Card(
                margin: EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isConnected ? Colors.teal : Colors.grey,
                    child: Icon(Icons.medical_services, color: Colors.white),
                  ),
                  title: Text('Dr. ${doctor.username}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (doctor.specialization != null)
                        Text(doctor.specialization!),
                      Text(doctor.email, style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  trailing: isConnected
                      ? Chip(
                          label: Text('Connected'),
                          backgroundColor: Colors.teal[100],
                        )
                      : ElevatedButton(
                          onPressed: () => _connectToDoctor(doctor),
                          child: Text('Connect'),
                        ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Future<void> _connectToDoctor(User doctor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Connect to Doctor'),
        content: Text(
          'Connect with Dr. ${doctor.username}? They will have access to your health records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Connect'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DataService().connectPatientToDoctor(widget.user.id, doctor.id);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to Dr. ${doctor.username}!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

// ==================== MESSAGES SCREEN ====================
// [No changes needed]
class MessagesScreen extends StatefulWidget {
  final User user;
  MessagesScreen({required this.user});
  @override
  _MessagesScreenState createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  @override
  Widget build(BuildContext context) {
    final conversations = _getConversations();
    return Scaffold(
      body: conversations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.message, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conv = conversations[index];
                final unreadCount = conv['unreadCount'] as int;
                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(
                      conv['otherUser'].username,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      conv['lastMessage'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          conv['time'],
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        if (unreadCount > 0) ...[
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$unreadCount',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            currentUser: widget.user,
                            otherUser: conv['otherUser'],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  List<Map<String, dynamic>> _getConversations() {
    final messages = DataService().messages;
    final otherUserIds = <String>{};
    for (var msg in messages) {
      if (msg.senderId == widget.user.id) {
        otherUserIds.add(msg.receiverId);
      } else if (msg.receiverId == widget.user.id) {
        otherUserIds.add(msg.senderId);
      }
    }
    final conversations = otherUserIds.map((userId) {
      final otherUser = DataService().users.firstWhere((u) => u.id == userId);
      final conversation = DataService().getConversation(
        widget.user.id,
        userId,
      );
      final lastMessage = conversation.isNotEmpty ? conversation.last : null;
      final unreadCount = conversation
          .where((m) => m.receiverId == widget.user.id && !m.isRead)
          .length;
      return {
        'otherUser': otherUser,
        'lastMessage': lastMessage?.content ?? 'No messages',
        'time': lastMessage != null
            ? DateFormat('MMM dd').format(lastMessage.timestamp)
            : '',
        'unreadCount': unreadCount,
      };
    }).toList();
    // Sort conversations by last message timestamp
    conversations.sort((a, b) {
      final userA = a['otherUser'] as User;
      final userB = b['otherUser'] as User;
      final conversationA = DataService().getConversation(
        widget.user.id,
        userA.id,
      );
      final conversationB = DataService().getConversation(
        widget.user.id,
        userB.id,
      );

      if (conversationA.isEmpty || conversationB.isEmpty) return 0;

      final aMsg = conversationA.last;
      final bMsg = conversationB.last;
      return bMsg.timestamp.compareTo(aMsg.timestamp);
    });
    return conversations;
  }
}

// ==================== CHAT SCREEN ====================
// [No changes needed]
class ChatScreen extends StatefulWidget {
  final User currentUser;
  final User otherUser;
  ChatScreen({required this.currentUser, required this.otherUser});
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  late List<Message> _messages;
  late StreamSubscription _dataSubscription;
  @override
  void initState() {
    super.initState();
    _loadMessages();
    _dataSubscription = DataService().dataUpdates.listen((_) {
      _loadMessages();
    });
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _dataSubscription.cancel();
    super.dispose();
  }

  void _loadMessages() {
    if (mounted) {
      setState(() {
        _messages = DataService().getConversation(
          widget.currentUser.id,
          widget.otherUser.id,
        );
      });
    }
  }

  Future<void> _markMessagesAsRead() async {
    final unreadMessages = _messages.where(
      (m) => m.receiverId == widget.currentUser.id && !m.isRead,
    );
    for (var msg in unreadMessages) {
      await DataService().markMessageAsRead(msg.id);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: widget.currentUser.id,
      receiverId: widget.otherUser.id,
      content: _messageController.text.trim(),
      timestamp: DateTime.now(),
    );
    await DataService().sendMessage(message);
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUser.username),
            Text(
              widget.otherUser.role == 'doctor' ? 'Doctor' : 'Patient',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet. Start a conversation!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message.senderId == widget.currentUser.id;
                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: EdgeInsets.only(bottom: 12),
                          padding: EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.7,
                          ),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.teal : Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.content,
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                DateFormat('hh:mm a').format(message.timestamp),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMe
                                      ? Colors.white70
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== DOCTOR DASHBOARD ====================
// [No changes needed]
class DoctorDashboardScreen extends StatelessWidget {
  final User user;
  DoctorDashboardScreen({required this.user});
  @override
  Widget build(BuildContext context) {
    final patients = DataService().getPatientsForDoctor(user.id);
    final sharedRecords = DataService().getSharedRecordsForDoctor(user.id);
    final recentRecords = sharedRecords.take(5).toList();
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, Dr. ${user.username}',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          if (user.specialization != null)
            Text(
              user.specialization!,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.people, size: 40, color: Colors.blue),
                        SizedBox(height: 12),
                        Text(
                          '${patients.length}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Patients',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Card(
                  color: Colors.green[50],
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.history, size: 40, color: Colors.green),
                        SizedBox(height: 12),
                        Text(
                          '${sharedRecords.length}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Records',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Text(
            'Recent Patient Records',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          if (recentRecords.isEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No patient records yet')),
              ),
            )
          else
            ...recentRecords.map((record) {
              final patient = DataService().users.firstWhere(
                (u) => u.id == record.userId,
              );
              return Card(
                margin: EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: record.healthStatus == 'Excellent'
                        ? Colors.green
                        : record.healthStatus == 'Good'
                        ? Colors.blue
                        : Colors.orange,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(patient.username),
                  subtitle: Text(
                    'BMI: ${record.bmi.toStringAsFixed(1)} | BP: ${record.systolic}/${record.diastolic} | ${DateFormat('MMM dd').format(record.timestamp)}',
                  ),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DoctorRecordDetailScreen(
                          doctor: user,
                          record: record,
                          patient: patient,
                        ),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}

// ==================== DOCTOR PATIENTS SCREEN ====================
// [No changes needed]
class DoctorPatientsScreen extends StatelessWidget {
  final User user;
  DoctorPatientsScreen({required this.user});
  @override
  Widget build(BuildContext context) {
    final patients = DataService().getPatientsForDoctor(user.id);
    return Scaffold(
      body: patients.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No patients yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: patients.length,
              itemBuilder: (context, index) {
                final patient = patients[index];
                final records = DataService().getRecordsForUser(patient.id);
                final latestRecord = records.isNotEmpty ? records.first : null;
                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(patient.username),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(patient.email),
                        if (latestRecord != null)
                          Text(
                            'Last check: ${DateFormat('MMM dd, yyyy').format(latestRecord.timestamp)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.history, color: Colors.teal),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PatientRecordsForDoctorScreen(
                                      doctor: user,
                                      patient: patient,
                                    ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.message, color: Colors.teal),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  currentUser: user,
                                  otherUser: patient,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ==================== PATIENT RECORDS FOR DOCTOR ====================
// [No changes needed]
class PatientRecordsForDoctorScreen extends StatelessWidget {
  final User doctor;
  final User patient;
  PatientRecordsForDoctorScreen({required this.doctor, required this.patient});
  @override
  Widget build(BuildContext context) {
    final records = DataService()
        .getRecordsForUser(patient.id)
        .where((r) => r.sharedWith.contains(doctor.id))
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text('${patient.username}\'s Records')),
      body: records.isEmpty
          ? Center(child: Text('No shared records'))
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: record.healthStatus == 'Excellent'
                            ? Colors.green.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.favorite,
                        color: record.healthStatus == 'Excellent'
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                    title: Text(
                      DateFormat('MMM dd, yyyy').format(record.timestamp),
                    ),
                    subtitle: Text(
                      'BMI: ${record.bmi.toStringAsFixed(1)} | BP: ${record.systolic}/${record.diastolic}',
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DoctorRecordDetailScreen(
                            doctor: doctor,
                            record: record,
                            patient: patient,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

// ==================== DOCTOR RECORD DETAIL ====================
// [No changes needed]
class DoctorRecordDetailScreen extends StatefulWidget {
  final User doctor;
  final HealthRecord record;
  final User patient;
  DoctorRecordDetailScreen({
    required this.doctor,
    required this.record,
    required this.patient,
  });
  @override
  _DoctorRecordDetailScreenState createState() =>
      _DoctorRecordDetailScreenState();
}

class _DoctorRecordDetailScreenState extends State<DoctorRecordDetailScreen> {
  final _adviceController = TextEditingController();
  @override
  void initState() {
    super.initState();
    final existingAdvice = widget.record.doctorAdvice[widget.doctor.id];
    if (existingAdvice != null) {
      _adviceController.text = existingAdvice;
    }
  }

  @override
  void dispose() {
    _adviceController.dispose();
    super.dispose();
  }

  Future<void> _saveAdvice() async {
    if (_adviceController.text.trim().isEmpty) return;
    await DataService().addDoctorAdvice(
      widget.record.id,
      widget.doctor.id,
      _adviceController.text.trim(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Advice saved and patient notified!'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Health Record')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.teal,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.patient.username,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(widget.patient.email),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 24),
                    Text(
                      'Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(widget.record.timestamp)}',
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vital Signs',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Divider(),
                    _buildVitalRow('Weight', '${widget.record.weight} kg'),
                    _buildVitalRow('Height', '${widget.record.height} cm'),
                    _buildVitalRow(
                      'BMI',
                      '${widget.record.bmi.toStringAsFixed(2)} (${widget.record.bmiCategory})',
                    ),
                    _buildVitalRow(
                      'Blood Pressure',
                      '${widget.record.systolic}/${widget.record.diastolic} mmHg',
                    ),
                    _buildVitalRow(
                      'Heart Rate',
                      '${widget.record.heartRate} bpm',
                    ),
                    _buildVitalRow(
                      'Temperature',
                      '${widget.record.temperature}°C',
                    ),
                    _buildVitalRow('Status', widget.record.healthStatus),
                    if (widget.record.location != null)
                      _buildVitalRow('Location', widget.record.location!),
                    if (widget.record.notes.isNotEmpty) ...[
                      Divider(),
                      Text(
                        'Patient Notes:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(widget.record.notes),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medical Advice',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _adviceController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText:
                            'Enter your medical advice for the patient...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _saveAdvice,
                        icon: Icon(Icons.save, color: Colors.white),
                        label: Text(
                          'Save Advice',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.record.doctorAdvice.isNotEmpty) ...[
              SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Previous Advice',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Divider(),
                      ...widget.record.doctorAdvice.entries.map((entry) {
                        final doc = DataService().users.firstWhere(
                          (u) => u.id == entry.key,
                        );
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dr. ${doc.username}:',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(entry.value),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVitalRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
