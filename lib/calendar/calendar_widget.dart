import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import '/flutter_flow/flutter_flow_calendar.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'calendar_model.dart';
export 'calendar_model.dart';

class CalendarWidget extends StatefulWidget {
  const CalendarWidget({super.key});

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  late CalendarModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Calendar
  final TextEditingController eventTitleController = TextEditingController();
  final TextEditingController eventDescriptionController =
      TextEditingController();

  // Track if a manual date selection was made
  bool hasManuallySelectedDate = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CalendarModel());

    // Fetch events from Firestore when the page loads
    _model.fetchEvents();
  }

  @override
  void dispose() {
    _model.dispose();
    eventTitleController.dispose();
    eventDescriptionController.dispose();
    super.dispose();
  }

  /// Add a new event to the Firestore database
Future<void> _addEvent(DateTime selectedDate) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text('You must be logged in to add events.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
    return;
  }

  // Clear the fields before showing the dialog
  eventTitleController.clear();
  eventDescriptionController.clear();

  TimeOfDay? selectedTime;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Add Event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: eventTitleController,
              decoration: InputDecoration(labelText: 'Event Title'),
            ),
            TextField(
              controller: eventDescriptionController,
              decoration: InputDecoration(labelText: 'Event Description (optional)'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                // Show the Time Picker
                selectedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );

                if (selectedTime != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Time Selected: ${selectedTime!.format(context)}')),
                  );
                }
              },
              child: Text('Select Time (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final title = eventTitleController.text.trim();
              final description = eventDescriptionController.text.trim();

              if (title.isEmpty) {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Invalid Input'),
                      content: Text('Event name cannot be empty. Please provide a valid title.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('OK'),
                        ),
                      ],
                    );
                  },
                );
                return;
              }

              // Combine date and time, or use only date if no time is selected
              final eventDateTime = selectedTime == null
                  ? DateTime(selectedDate.year, selectedDate.month, selectedDate.day)
                  : DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime?.hour ?? 0, // Safely access hour
                      selectedTime?.minute ?? 0, // Safely access minute
                    );

              // Add event to Firestore
              await _model.addEvent(
                user.uid, // Pass the userId
                title, // Title
                description, // Description
                eventDateTime, // Always a valid DateTime
              );

              // Clear input fields
              eventTitleController.clear();
              eventDescriptionController.clear();

              Navigator.of(context).pop(); // Close dialog

              // Refresh events
              await _model.fetchEvents();
            },
            child: Text('Add'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
            },
            child: Text('Cancel'),
          ),
        ],
      );
    },
  );
}





  /// Show dialog for editing an existing event
  void _showEditEventDialog(Map<String, dynamic> event) {
    eventTitleController.text = event['eventName'];
    eventDescriptionController.text = event['eventDetails'] ?? '';

    // Ensure eventDate is treated as DateTime
    final eventDateTime = event['eventDate'] is Timestamp
        ? event['eventDate'].toDate()
        : event['eventDate'] as DateTime;

    TimeOfDay? selectedTime = TimeOfDay(
      hour: eventDateTime.hour,
      minute: eventDateTime.minute,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Event'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: eventTitleController,
                decoration: const InputDecoration(labelText: 'Event Title'),
              ),
              TextField(
                controller: eventDescriptionController,
                decoration: const InputDecoration(
                    labelText: 'Event Description (optional)'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  // Show the Time Picker
                  TimeOfDay? pickedTime = await showTimePicker(
                    context: context,
                    initialTime: selectedTime ?? TimeOfDay.now(),
                  );

                  if (pickedTime != null) {
                    selectedTime = pickedTime;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Time Selected: ${selectedTime!.format(context)}'),
                      ),
                    );
                  }
                },
                child: Text(
                  selectedTime != null
                      ? 'Time: ${selectedTime!.format(context)}'
                      : 'Select Time',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final newTitle = eventTitleController.text.trim();
                final newDescription = eventDescriptionController.text.trim();

                if (newTitle.isEmpty || selectedTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Event title and time cannot be empty.')),
                  );
                  return;
                }

                // Combine date and time for the updated event date
                final updatedDateTime = DateTime(
                  eventDateTime.year,
                  eventDateTime.month,
                  eventDateTime.day,
                  selectedTime!.hour,
                  selectedTime!.minute,
                );

                // Update event in Firestore
                await FirebaseFirestore.instance
                    .collection('events')
                    .doc(event['id'])
                    .update({
                  'eventName': newTitle,
                  'eventDetails': newDescription,
                  'eventDate': Timestamp.fromDate(updatedDateTime),
                });

                // Update local list of events
                setState(() {
                  final index = _model.upcomingEvents
                      .indexWhere((e) => e['id'] == event['id']);
                  if (index != -1) {
                    _model.upcomingEvents[index]['eventName'] = newTitle;
                    _model.upcomingEvents[index]['eventDetails'] =
                        newDescription;
                    _model.upcomingEvents[index]['eventDate'] =
                        Timestamp.fromDate(updatedDateTime);
                  }
                });

                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final veryLightGrey = const Color(0xFFF5F5F5); // Very light grey color
    final mediumGreen = const Color(0xFF7B9076); // Medium green color

    return ChangeNotifierProvider.value(
      value: _model,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          key: scaffoldKey,
          backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
          appBar: AppBar(
            backgroundColor: const Color(0xFF104036),
            automaticallyImplyLeading: false,
            title: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'assets/images/S_logoo.png',
                    fit: BoxFit.cover,
                  ),
                ),
                Align(
                  alignment: const AlignmentDirectional(0, 0),
                  child: Text(
                    'SummAIze ',
                    textAlign: TextAlign.center,
                    style: FlutterFlowTheme.of(context).headlineMedium.override(
                          fontFamily: 'Inknut Antiqua',
                          color: Colors.white,
                          fontSize: 22,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
          ),
          body: Consumer<CalendarModel>(
            builder: (context, model, child) {
              return Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Calendar view
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                      boxShadow: [
                        const BoxShadow(
                          blurRadius: 3,
                          color: Color(0x33000000),
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: FlutterFlowCalendar(
                      color: FlutterFlowTheme.of(context).primary,
                      weekFormat: false,
                      weekStartsMonday: true,
                      onChange: (DateTimeRange? newSelectedDate) {
                        if (newSelectedDate != null &&
                            hasManuallySelectedDate) {
                          _addEvent(newSelectedDate.start);
                        }
                        hasManuallySelectedDate = true;
                      },
                    ),
                  ),
                  // "Coming Up" Section with unified background
                  Expanded(
                    child: Container(
                      color: veryLightGrey, // Unified background for the section
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // "Coming Up" Header
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12.0, horizontal: 16.0),
                            child: Text(
                              'Coming Up',
                              style: FlutterFlowTheme.of(context)
                                  .titleLarge
                                  .override(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.bold,
                                    color: mediumGreen,
                                  ),
                            ),
                          ),
                          // Event List
                          Expanded(
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: model.upcomingEvents.length,
                              itemBuilder: (context, index) {
                                final event = model.upcomingEvents[index];
                                final eventDetails = event['eventDetails'];
                                return Padding(
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                      16, 8, 16, 8),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white, // Card background
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: mediumGreen, // Medium green border
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(2, 2),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16, horizontal: 12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                event['eventName'],
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .titleMedium
                                                    .override(
                                                      fontFamily:
                                                          'Inter Tight',
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: const Color(
                                                          0xFF14181B),
                                                    ),
                                              ),
                                              if (eventDetails != null &&
                                                  eventDetails.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 8.0,
                                                          bottom: 8.0),
                                                  child: Text(
                                                    eventDetails,
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodySmall
                                                        .override(
                                                          fontFamily: 'Inter',
                                                          color: mediumGreen,
                                                        ),
                                                  ),
                                                ),
                                            Row(
  children: [
    if (event['eventDate'] != null) ...[
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: const Color.fromARGB(77, 238, 202, 96),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Text(
          DateFormat('h:mm a').format(
            CalendarModel.convertToDateTime(event['eventDate']),
          ),
          style: FlutterFlowTheme.of(context).bodyMedium.override(
                fontFamily: 'Inter',
                color: const Color(0xFFC62828),
              ),
        ),
      ),
      const SizedBox(width: 8.0),
    ] else ...[
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: const Color.fromARGB(77, 238, 202, 96),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Text(
          'No time selected',
          style: FlutterFlowTheme.of(context).bodyMedium.override(
                fontFamily: 'Inter',
                color: const Color(0xFF7B9076),
              ),
        ),
      ),
    ],
    Text(
      DateFormat('EEE, MMM d, yyyy').format(
        CalendarModel.convertToDateTime(event['eventDate']),
      ),
      style: FlutterFlowTheme.of(context).bodySmall.override(
        fontFamily: 'Inter',
        color: mediumGreen,
      ),
    ),
  ],
),

                                            ],
                                          ),
                                        ),
                                        // Positioned edit icon
                                        Positioned(
                                          right: 16,
                                          top: 0,
                                          bottom: 0,
                                          child: Center(
                                            child: IconButton(
                                              icon: const Icon(Icons.edit,
                                                  color: Color(0xFF104036)),
                                              onPressed: () {
                                                _showEditEventDialog(event);
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
