
import 'package:flutter/material.dart';
import 'package:mysql1/mysql1.dart';


class MyHomePageGuest extends StatefulWidget {
  const MyHomePageGuest({super.key, required this.title});

  final String title;

  @override
  State<MyHomePageGuest> createState() => _MyHomePageGuestState();
}

class _MyHomePageGuestState extends State<MyHomePageGuest> {
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
    // _createTableIfNotExists();
    _fetchBookings();
  }

  // Future<void> _createTableIfNotExists() async {
  //   var conn = await MySqlConnection.connect(mysqlConfig);
  //   await conn.query('''CREATE TABLE IF NOT EXISTS bookings (
  //       id INT AUTO_INCREMENT PRIMARY KEY,
  //       name VARCHAR(255),
  //       number_of_people VARCHAR(255),
  //       booking_date DATE,
  //       start_time TIME,
  //       end_time TIME
  //     )''');
  //   await conn.close();
  // }

  Future<void> _fetchBookings() async {
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
  }

  Future<bool> _isRoomAvailable(DateTime date, TimeOfDay startTime, TimeOfDay endTime) async {
    var conn = await MySqlConnection.connect(mysqlConfig);
    var results = await conn.query(
      '''
      SELECT * FROM bookings 
      WHERE booking_date = ? 
      AND (start_time < ? AND end_time > ?)
      ''',
      [date.toString(), _formatTimeOfDay(endTime), _formatTimeOfDay(startTime)],
    );
    await conn.close();
    return results.isEmpty;
  }

  Future<void> _insertBooking(String name, String numberOfPeople, DateTime date, TimeOfDay startTime, TimeOfDay endTime) async {
    var conn = await MySqlConnection.connect(mysqlConfig);
    await conn.query(
      '''
      INSERT INTO bookings (name, number_of_people, booking_date, start_time, end_time)
      VALUES (?, ?, ?, ?, ?)
      ''',
      [name, numberOfPeople, date.toString(), _formatTimeOfDay(startTime), _formatTimeOfDay(endTime)],
    );
    await conn.close();
  }

  Future<void> _deleteBooking(int bookingId) async {
    var conn = await MySqlConnection.connect(mysqlConfig);
    await conn.query('DELETE FROM bookings WHERE id = ?', [bookingId]);
    await conn.close();
    _fetchBookings();
  }

  Future<void> _submitBooking() async {
    if (_formKey.currentState?.validate() ?? false) {
      // Ensure end time is later than start time
      if (_startTime.hour > _endTime.hour || (_startTime.hour == _endTime.hour && _startTime.minute >= _endTime.minute)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be later than start time!')),
        );
        return;
      }

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
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select the number of people';
                          }
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ListTile(
                        title: Text('Booking Date: ${_bookingDate.toLocal()}'.split(' ')[0]),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () => _selectDate(context),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ListTile(
                        title: Text('Start Time: ${_startTime.format(context)}'),
                        trailing: const Icon(Icons.access_time),
                        onTap: () => _selectStartTime(context),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ListTile(
                        title: Text('End Time: ${_endTime.format(context)}'),
                        trailing: const Icon(Icons.access_time),
                        onTap: () => _selectEndTime(context),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _submitBooking,
                      child: const Text('Book Room'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24.0),
              const Text(
                'Existing Bookings',
                style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              SizedBox(
                height: 300.0, // Set the height for the scrollable container
                child: SingleChildScrollView(
                  child: Column(
                    children: _existingBookings.map((booking) {
                      return ListTile(
                        title: Text('${booking['name']} - ${booking['number_of_people']}'),
                        subtitle: Text('${booking['booking_date']} ${booking['start_time']} to ${booking['end_time']}'),
                        // trailing: IconButton(
                        //   icon: const Icon(Icons.delete),
                        //   onPressed: () async {
                        //     await _deleteBooking(booking['id']);
                        //   },
                        // ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
