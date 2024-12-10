import 'package:flutter/material.dart';
import 'package:mysql1/mysql1.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Conference Room Booking',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 12, 2, 27),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
            backgroundColor: Colors.greenAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.0),
            ),
          ),
        ),
      ),
      home: const MyHomePage(title: 'Conference Room Booking'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _formKey = GlobalKey<FormState>();
  String _selectedName = '';
  String _selectedNumberOfPeople = 'Single Person';
  DateTime _bookingDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now();
  List<Map<String, dynamic>> _existingBookings = [];

  final List<String> _names = [
    'Aniket',
    'Amit',
    'Mustali',
    'Tanya',
    'Rishu',
  ];

  final List<String> _numberOfPeopleOptions = [
    'Single Person',
    '2 Persons',
    '3 Persons',
    '4 Persons or More',
  ];

  // MySQL connection config
  final ConnectionSettings mysqlConfig = ConnectionSettings(
    host: '10.5.53.147',
    port: 3306,
    user: 'adminuser',
    password: 'QweEFGSSF#@3d8d%87#0',
    db: 'adfalcon',
  );

  @override
  void initState() {
    super.initState();
    _createTableIfNotExists();
    _fetchBookings();
  }

  Future<void> _createTableIfNotExists() async {
    try {
      var conn = await MySqlConnection.connect(mysqlConfig);
      await conn.query('''  
        CREATE TABLE IF NOT EXISTS bookings (
          id INT AUTO_INCREMENT PRIMARY KEY,
          name VARCHAR(255),
          number_of_people VARCHAR(255),
          booking_date DATE,
          start_time TIME,
          end_time TIME
        )
      ''');
      await conn.close();
    } catch (e) {
      print("Error creating table: $e");
    }
  }

  Future<void> _fetchBookings() async {
    try {
      var conn = await MySqlConnection.connect(mysqlConfig);
      var results = await conn.query('SELECT * FROM bookings');
      setState(() {
        _existingBookings = results
            .map((row) => {
                  'id': row['id'],
                  'name': row['name'],
                  'number_of_people': row['number_of_people'],
                  'booking_date': row['booking_date'],
                  'start_time': row['start_time'],
                  'end_time': row['end_time'],
                })
            .toList();
      });
      await conn.close();
    } catch (e) {
      print("Error fetching bookings: $e");
    }
  }

  Future<bool> _isRoomAvailable(DateTime date, TimeOfDay startTime, TimeOfDay endTime) async {
    try {
      var conn = await MySqlConnection.connect(mysqlConfig);
      var results = await conn.query(
        '''
        SELECT * FROM bookings 
        WHERE booking_date = ? 
        AND (start_time < ? AND end_time > ?)
        ''',
        [date.toString().split(' ')[0], _formatTimeOfDay(endTime), _formatTimeOfDay(startTime)],
      );
      await conn.close();
      return results.isEmpty;
    } catch (e) {
      print("Error checking room availability: $e");
      return false;
    }
  }

  Future<void> _insertBooking(String name, String numberOfPeople, DateTime date, TimeOfDay startTime, TimeOfDay endTime) async {
    try {
      var conn = await MySqlConnection.connect(mysqlConfig);
      await conn.query(
        '''
        INSERT INTO bookings (name, number_of_people, booking_date, start_time, end_time)
        VALUES (?, ?, ?, ?, ?)
        ''',
        [name, numberOfPeople, date.toString().split(' ')[0], _formatTimeOfDay(startTime), _formatTimeOfDay(endTime)],
      );
      await conn.close();
    } catch (e) {
      print("Error inserting booking: $e");
    }
  }

  Future<void> _deleteBooking(int bookingId) async {
    try {
      var conn = await MySqlConnection.connect(mysqlConfig);
      await conn.query('DELETE FROM bookings WHERE id = ?', [bookingId]);
      await conn.close();
      _fetchBookings();
    } catch (e) {
      print("Error deleting booking: $e");
    }
  }

  Future<void> _submitBooking() async {
    if (_formKey.currentState?.validate() ?? false) {
      bool isAvailable = await _isRoomAvailable(_bookingDate, _startTime, _endTime);
      if (isAvailable) {
        await _insertBooking(_selectedName, _selectedNumberOfPeople, _bookingDate, _startTime, _endTime);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking confirmed for $_selectedName')),
        );
        _fetchBookings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room is already booked for the selected time!')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _bookingDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (selectedDate != null && selectedDate != _bookingDate) {
      setState(() {
        _bookingDate = selectedDate;
      });
    }
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (selectedTime != null && selectedTime != _startTime) {
      setState(() {
        _startTime = selectedTime;
      });
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (selectedTime != null && selectedTime != _endTime) {
      setState(() {
        _endTime = selectedTime;
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hours = time.hour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    return '$hours:$minutes:00';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 165, 0, 0),
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              Form(
                key: _formKey,
                child: Column(
                  children: <Widget>[
                    DropdownButtonFormField<String>(
                      value: _selectedName.isNotEmpty ? _selectedName : null,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                      ),
                      items: _names.map((name) {
                        return DropdownMenuItem<String>(
                          value: name,
                          child: Text(name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedName = value ?? '';
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a name';
                        }
                        return null;
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: DropdownButtonFormField<String>(
                        value: _selectedNumberOfPeople,
                        decoration: const InputDecoration(
                          labelText: 'Number of People',
                        ),
                        items: _numberOfPeopleOptions.map((option) {
                          return DropdownMenuItem<String>(
                            value: option,
                            child: Text(option),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedNumberOfPeople = value ?? '';
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: TextButton(
                              onPressed: () => _selectDate(context),
                              child: Text(
                                  'Date: ${_bookingDate.toLocal().toString().split(' ')[0]}'),
                            ),
                          ),
                          Expanded(
                            child: TextButton(
                              onPressed: () => _selectStartTime(context),
                              child: Text('Start Time: ${_startTime.format(context)}'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: TextButton(
                              onPressed: () => _selectEndTime(context),
                              child: Text('End Time: ${_endTime.format(context)}'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _submitBooking,
                      child: const Text('Book Room'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Existing Bookings', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                itemCount: _existingBookings.length,
                itemBuilder: (context, index) {
                  final booking = _existingBookings[index];
                  return Card(
                    child: ListTile(
                      title: Text('Room Booked by ${booking['name']}'),
                      subtitle: Text(
                          'Date: ${booking['booking_date']} | Time: ${booking['start_time']} - ${booking['end_time']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteBooking(booking['id']),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
