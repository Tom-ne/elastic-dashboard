import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class NumberBar extends NTWidget {
  static const String widgetType = 'Number Bar';
  @override
  String type = widgetType;

  late double _minValue;
  late double _maxValue;
  late int? _divisions;
  late bool _inverted;
  late String _orientation;

  NumberBar({
    super.key,
    required super.topic,
    double minValue = -1.0,
    double maxValue = 1.0,
    int? divisions = 5,
    bool inverted = false,
    String orientation = 'horizontal',
    super.dataType,
    super.period,
  })  : _orientation = orientation,
        _divisions = divisions,
        _inverted = inverted,
        _maxValue = maxValue,
        _minValue = minValue,
        super();

  NumberBar.fromJson({super.key, required Map<String, dynamic> jsonData})
      : super.fromJson(jsonData: jsonData) {
    _minValue = tryCast(jsonData['min_value']) ?? -1.0;
    _maxValue = tryCast(jsonData['max_value']) ?? 1.0;
    _divisions = tryCast(jsonData['divisions']);
    _inverted = tryCast(jsonData['inverted']) ?? false;
    _orientation = tryCast(jsonData['orientation']) ?? 'horizontal';
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'min_value': _minValue,
      'max_value': _maxValue,
      'divisions': _divisions,
      'inverted': _inverted,
      'orientation': _orientation,
    };
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      // Orientation
      Column(
        children: [
          const Text('Orientation'),
          DialogDropdownChooser<String>(
            initialValue:
                '${_orientation[0].toUpperCase()}${_orientation.substring(1)}',
            choices: const ['Horizontal', 'Vertical'],
            onSelectionChanged: (value) {
              if (value == null) {
                return;
              }

              _orientation = value.toLowerCase();
              refresh();
            },
          ),
        ],
      ),
      const SizedBox(height: 5),
      // Min and max values
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                double? newMin = double.tryParse(value);
                if (newMin == null) {
                  return;
                }
                _minValue = newMin;
                refresh();
              },
              formatter: Constants.decimalTextFormatter(allowNegative: true),
              label: 'Min Value',
              initialText: _minValue.toString(),
            ),
          ),
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                double? newMax = double.tryParse(value);
                if (newMax == null) {
                  return;
                }
                _maxValue = newMax;
                refresh();
              },
              formatter: Constants.decimalTextFormatter(allowNegative: true),
              label: 'Max Value',
              initialText: _maxValue.toString(),
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      // Number of divisions and orientation
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: DialogTextInput(
              onSubmit: (value) {
                int? newDivisions = int.tryParse(value);
                if (newDivisions != null && newDivisions < 2) {
                  return;
                }
                _divisions = newDivisions;
                refresh();
              },
              formatter: FilteringTextInputFormatter.digitsOnly,
              label: 'Divisions',
              initialText: (_divisions != null) ? _divisions.toString() : '',
              allowEmptySubmission: true,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Center(
              child: DialogToggleSwitch(
                initialValue: _inverted,
                label: 'Inverted',
                onToggle: (value) {
                  _inverted = value;
                  refresh();
                },
              ),
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetModel>();

    return StreamBuilder(
      stream: subscription?.periodicStream(yieldAll: false),
      initialData: ntConnection.getLastAnnouncedValue(topic),
      builder: (context, snapshot) {
        double value = tryCast(snapshot.data) ?? 0.0;

        double clampedValue = value.clamp(_minValue, _maxValue);

        double? divisionInterval = (_divisions != null)
            ? (_maxValue - _minValue) / (_divisions! - 1)
            : null;

        LinearGaugeOrientation gaugeOrientation = (_orientation == 'vertical')
            ? LinearGaugeOrientation.vertical
            : LinearGaugeOrientation.horizontal;

        List<Widget> children = [
          Text(
            value.toStringAsFixed(2),
            style: Theme.of(context).textTheme.bodyLarge,
            overflow: TextOverflow.ellipsis,
          ),
          const Flexible(
            child: SizedBox(width: 5.0, height: 5.0),
          ),
          SfLinearGauge(
            key: UniqueKey(),
            maximum: _maxValue,
            minimum: _minValue,
            barPointers: [
              LinearBarPointer(
                value: clampedValue,
                animationDuration: 0,
                thickness: 7.5,
                edgeStyle: LinearEdgeStyle.bothCurve,
              ),
            ],
            axisTrackStyle: const LinearAxisTrackStyle(
              thickness: 7.5,
              edgeStyle: LinearEdgeStyle.bothCurve,
            ),
            orientation: gaugeOrientation,
            isAxisInversed: _inverted,
            interval: divisionInterval,
          ),
        ];

        if (gaugeOrientation == LinearGaugeOrientation.vertical) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          );
        } else {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          );
        }
      },
    );
  }
}
