import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ggclassroom/l10n/app_localizations.dart';

class CalendarScreen extends StatefulWidget {
  final List<Map<String, dynamic>> courses;
  const CalendarScreen({super.key, required this.courses});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final List<String> weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  late Map<String, bool> courseFilter;
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    courseFilter = {for (var c in widget.courses) c['title']: true};
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).maybePop();
          },
        ),
        title: Text(
          loc?.calendarTitle ?? 'Lịch học',
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          _buildFilterBar(loc),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: _buildCalendarGrid(loc),
            ),
          ),
        ],
      ),
    );
  }

  /// ───────────────────────────── FILTER BAR ─────────────────────────────
  Widget _buildFilterBar(AppLocalizations? loc) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            ElevatedButton.icon(
              onPressed: _showSubjectFilterDialog,
              icon: const Icon(Icons.filter_alt_outlined, size: 18),
              label: Text(loc?.subjects ?? 'Subjects'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                foregroundColor: Colors.blueAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildMonthDropdown(loc),
                  const SizedBox(width: 8),
                  _buildYearDropdown(loc),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubjectFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text("Select Subjects"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: widget.courses.map((course) {
                  final title = course['title'];
                  return CheckboxListTile(
                    value: courseFilter[title] ?? false,
                    activeColor: course['color'],
                    title: Text(title),
                    onChanged: (v) {
                      setDialogState(() {
                        courseFilter[title] = v!;
                      });
                      setState(() {}); // update main UI
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthDropdown(AppLocalizations? loc) {
    return DropdownButton<int>(
      value: selectedMonth,
      onChanged: (v) => setState(() => selectedMonth = v!),
      items: List.generate(12, (i) {
        final month = DateFormat.MMMM(loc?.localeName ?? 'en').format(DateTime(0, i + 1));
        return DropdownMenuItem(value: i + 1, child: Text(month));
      }),
    );
  }

  Widget _buildYearDropdown(AppLocalizations? loc) {
    final currentYear = DateTime.now().year;
    return DropdownButton<int>(
      value: selectedYear,
      onChanged: (v) => setState(() => selectedYear = v!),
      items: List.generate(
        5,
        (i) => DropdownMenuItem(
          value: currentYear - 2 + i,
          child: Text('${currentYear - 2 + i}'),
        ),
      ),
    );
  }

  /// ───────────────────────────── CALENDAR GRID ─────────────────────────────
  Widget _buildCalendarGrid(AppLocalizations? loc) {
    final hours = List.generate(11, (i) => 7 + i); // 7h–17h
    final dayWidth = (MediaQuery.of(context).size.width - 76) / 7;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Left: time labels
          Column(
            children: [
              const SizedBox(height: 40),
              ...hours.map(
                (h) => Container(
                  alignment: Alignment.topCenter,
                  height: 80,
                  width: 60,
                  child: Text(
                    '$h:00',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),

          // Right: days × times grid
          SizedBox(
            width: dayWidth * 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day headers
                Row(
                  children: weekdays.map((d) {
                    final date = _getDateOfWeekday(d);
                    return Container(
                      alignment: Alignment.center,
                      width: dayWidth,
                      height: 40,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        color: Colors.white,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            d.substring(0, 3),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            DateFormat('d/M').format(date),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                // Time slots grid + course overlay
                SizedBox(
                  height: 80.0 * hours.length,
                  child: Stack(
                    children: [
                      Column(
                        children: hours.map((_) {
                          return Row(
                            children: weekdays.map((_) {
                              return Container(
                                width: dayWidth,
                                height: 80,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.grey.shade200),
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                          );
                        }).toList(),
                      ),
                      ..._buildCourseBlocks(dayWidth, hours),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ───────────────────────────── COURSE BLOCKS ─────────────────────────────
  List<Widget> _buildCourseBlocks(double dayWidth, List<int> hours) {
    final List<Widget> blocks = [];
    final selectedDate = DateTime(selectedYear, selectedMonth);

    for (final course in widget.courses) {
      if (!(courseFilter[course["title"]] ?? false)) continue;

      final DateTime start = course['startDate'];
      final DateTime end = course['endDate'];

      // Skip if this month/year outside the course period
      if (selectedDate.isBefore(DateTime(start.year, start.month)) ||
          selectedDate.isAfter(DateTime(end.year, end.month))) {
        continue;
      }

      for (final s in course["schedule"]) {
        final dayIndex = weekdays.indexOf(s["day"]);
        if (dayIndex == -1) continue;

        final startHour = int.tryParse(s["time"].split(':')[0]) ?? hours.first;
        final slotIndex = startHour - hours.first;

        blocks.add(Positioned(
          left: dayWidth * dayIndex,
          top: 80 * slotIndex + 40,
          width: dayWidth,
          height: 80,
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: (course["color"] as Color).withOpacity(0.85),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course["title"],
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    s["topic"],
                    style:
                        const TextStyle(fontSize: 10, color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    s["time"],
                    style:
                        const TextStyle(fontSize: 9, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ));
      }
    }

    return blocks;
  }

  /// ───────────────────────────── HELPER ─────────────────────────────
  DateTime _getDateOfWeekday(String day) {
    final now = DateTime(selectedYear, selectedMonth, DateTime.now().day);
    int weekdayIndex = weekdays.indexOf(day);
    int todayIndex = now.weekday - 1;
    return now.add(Duration(days: weekdayIndex - todayIndex));
  }
}
