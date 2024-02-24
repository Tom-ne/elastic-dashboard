import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/combo_box_chooser.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class SplitButtonChooser extends NTWidget {
  static const String widgetType = 'Split Button Chooser';
  @override
  String type = widgetType;

  late String _optionsTopicName;
  late String _selectedTopicName;
  late String _activeTopicName;
  late String _defaultTopicName;

  String? _selectedChoice;

  StringChooserData? _previousData;

  NT4Topic? _selectedTopic;

  SplitButtonChooser({
    super.key,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  SplitButtonChooser.fromJson({super.key, required super.jsonData})
      : super.fromJson();

  @override
  void init() {
    super.init();

    _optionsTopicName = '$topic/options';
    _selectedTopicName = '$topic/selected';
    _activeTopicName = '$topic/active';
    _defaultTopicName = '$topic/default';
  }

  @override
  void resetSubscription() {
    _optionsTopicName = '$topic/options';
    _selectedTopicName = '$topic/selected';
    _activeTopicName = '$topic/active';
    _defaultTopicName = '$topic/default';

    _selectedTopic = null;

    super.resetSubscription();
  }

  void _publishSelectedValue(String? selected) {
    if (selected == null || !ntConnection.isNT4Connected) {
      return;
    }

    _selectedTopic ??= ntConnection.nt4Client
        .publishNewTopic(_selectedTopicName, NT4TypeStr.kString);

    ntConnection.updateDataFromTopic(_selectedTopic!, selected);
  }

  @override
  List<Object> getCurrentData() {
    List<Object?> rawOptions = ntConnection
            .getLastAnnouncedValue(_optionsTopicName)
            ?.tryCast<List<Object?>>() ??
        [];

    List<String> options = rawOptions.whereType<String>().toList();

    String active =
        tryCast(ntConnection.getLastAnnouncedValue(_activeTopicName)) ?? '';

    String selected =
        tryCast(ntConnection.getLastAnnouncedValue(_selectedTopicName)) ?? '';

    String defaultOption =
        tryCast(ntConnection.getLastAnnouncedValue(_defaultTopicName)) ?? '';

    return [options, active, selected, defaultOption];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetModel>();

    return StreamBuilder(
      stream: multiTopicPeriodicStream,
      builder: (context, snapshot) {
        List<Object?> rawOptions = ntConnection
                .getLastAnnouncedValue(_optionsTopicName)
                ?.tryCast<List<Object?>>() ??
            [];

        List<String> options = rawOptions.whereType<String>().toList();

        String? active =
            tryCast(ntConnection.getLastAnnouncedValue(_activeTopicName));
        if (active != null && active == '') {
          active = null;
        }

        String? selected =
            tryCast(ntConnection.getLastAnnouncedValue(_selectedTopicName));
        if (selected != null && selected == '') {
          selected = null;
        }

        String? defaultOption =
            tryCast(ntConnection.getLastAnnouncedValue(_defaultTopicName));
        if (defaultOption != null && defaultOption == '') {
          defaultOption = null;
        }

        if (!ntConnection.isNT4Connected) {
          active = null;
          selected = null;
          defaultOption = null;
        }

        StringChooserData currentData = StringChooserData(
            options: options,
            active: active,
            defaultOption: defaultOption,
            selected: selected);

        // If a choice has been selected previously but the topic on NT has no value, publish it
        // This can happen if NT happens to restart
        if (currentData.selectedChanged(_previousData)) {
          if (selected != null && _selectedChoice != selected) {
            _selectedChoice = selected;
          }
        } else if (currentData.activeChanged(_previousData) || active == null) {
          if (selected == null && _selectedChoice != null) {
            if (options.contains(_selectedChoice!)) {
              _publishSelectedValue(_selectedChoice!);
            } else if (options.isNotEmpty) {
              _selectedChoice = active;
            }
          }
        }

        // If nothing is selected but NT has an active value, set the selected to the NT value
        // This happens on program startup
        if (active != null && _selectedChoice == null) {
          _selectedChoice = active;
        }

        _previousData = currentData;

        bool showWarning = active != _selectedChoice;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const AlwaysScrollableScrollPhysics(),
                child: ToggleButtons(
                  onPressed: (index) {
                    _selectedChoice = options[index];

                    _publishSelectedValue(_selectedChoice!);
                  },
                  isSelected: options.map((String option) {
                    if (option == _selectedChoice) {
                      return true;
                    }
                    return false;
                  }).toList(),
                  children: options.map((String option) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(option),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 5),
            (showWarning)
                ? const Tooltip(
                    message:
                        'Selected value has not been published to Network Tables.\nRobot code will not be receiving the correct value.',
                    child: Icon(Icons.priority_high, color: Colors.red),
                  )
                : const Icon(Icons.check, color: Colors.green),
          ],
        );
      },
    );
  }
}
