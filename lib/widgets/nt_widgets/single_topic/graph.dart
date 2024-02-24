import 'dart:async';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class GraphWidget extends NTWidget {
  static const String widgetType = 'Graph';
  @override
  String type = widgetType;

  late double _timeDisplayed;
  double? _minValue;
  double? _maxValue;
  late Color _mainColor;
  late double _lineWidth;

  List<_GraphPoint> _graphData = [];
  _GraphWidgetGraph? _graphWidget;

  GraphWidget({
    super.key,
    required super.topic,
    double timeDisplayed = 5.0,
    double? minValue,
    double? maxValue,
    Color mainColor = Colors.cyan,
    double lineWidth = 2.0,
    super.dataType,
    super.period,
  })  : _timeDisplayed = timeDisplayed,
        _minValue = minValue,
        _maxValue = maxValue,
        _mainColor = mainColor,
        _lineWidth = lineWidth,
        super();

  GraphWidget.fromJson({super.key, required Map<String, dynamic> jsonData})
      : super.fromJson(jsonData: jsonData) {
    _timeDisplayed = tryCast(jsonData['time_displayed']) ??
        tryCast(jsonData['visibleTime']) ??
        5.0;
    _minValue = tryCast(jsonData['min_value']);
    _maxValue = tryCast(jsonData['max_value']);
    _mainColor = Color(tryCast(jsonData['color']) ?? Colors.cyan.value);
    _lineWidth = tryCast(jsonData['line_width']) ?? 2.0;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'time_displayed': _timeDisplayed,
      'min_value': _minValue,
      'max_value': _maxValue,
      'color': _mainColor.value,
      'line_width': _lineWidth,
    };
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            child: DialogColorPicker(
                onColorPicked: (color) {
                  _mainColor = color;

                  refresh();
                },
                label: 'Graph Color',
                initialColor: _mainColor),
          ),
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                double? newTime = double.tryParse(value);

                if (newTime == null) {
                  return;
                }
                _timeDisplayed = newTime;
                refresh();
              },
              formatter: Constants.decimalTextFormatter(),
              label: 'Time Displayed (Seconds)',
              initialText: _timeDisplayed.toString(),
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                double? newMinimum = double.tryParse(value);
                bool refreshGraph = newMinimum != _minValue;

                _minValue = newMinimum;

                if (refreshGraph) {
                  refresh();
                }
              },
              formatter: Constants.decimalTextFormatter(allowNegative: true),
              label: 'Minimum',
              initialText: _minValue?.toString(),
              allowEmptySubmission: true,
            ),
          ),
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                double? newMaximum = double.tryParse(value);
                bool refreshGraph = newMaximum != _maxValue;

                _maxValue = newMaximum;

                if (refreshGraph) {
                  refresh();
                }
              },
              formatter: Constants.decimalTextFormatter(allowNegative: true),
              label: 'Maximum',
              initialText: _maxValue?.toString(),
              allowEmptySubmission: true,
            ),
          ),
          Flexible(
            child: DialogTextInput(
              onSubmit: (value) {
                double? newWidth = double.tryParse(value);

                if (newWidth == null || newWidth < 0.01) {
                  return;
                }

                _lineWidth = newWidth;
                refresh();
              },
              formatter: Constants.decimalTextFormatter(),
              label: 'Line Width',
              initialText: _lineWidth.toString(),
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    notifier = context.watch<NTWidgetModel>();

    List<_GraphPoint>? currentGraphData = _graphWidget?.getCurrentData();

    if (currentGraphData != null) {
      _graphData = currentGraphData;
    }

    return _graphWidget = _GraphWidgetGraph(
      initialData: _graphData,
      subscription: subscription,
      timeDisplayed: _timeDisplayed,
      lineWidth: _lineWidth,
      mainColor: _mainColor,
      minValue: _minValue,
      maxValue: _maxValue,
    );
  }
}

class _GraphWidgetGraph extends StatefulWidget {
  final NT4Subscription? subscription;
  final double? minValue;
  final double? maxValue;
  final Color mainColor;
  final double timeDisplayed;
  final double lineWidth;

  final List<_GraphPoint> initialData;

  final List<_GraphPoint> _currentData;

  set currentData(List<_GraphPoint> data) {
    _currentData.clear();
    _currentData.addAll(data);
  }

  const _GraphWidgetGraph({
    required this.initialData,
    required this.subscription,
    required this.timeDisplayed,
    required this.mainColor,
    required this.lineWidth,
    this.minValue,
    this.maxValue,
  }) : _currentData = initialData;

  List<_GraphPoint> getCurrentData() {
    return _currentData;
  }

  @override
  State<_GraphWidgetGraph> createState() => _GraphWidgetGraphState();
}

class _GraphWidgetGraphState extends State<_GraphWidgetGraph> {
  ChartSeriesController? _seriesController;
  late List<_GraphPoint> _graphData;
  StreamSubscription<Object?>? _subscriptionListener;

  @override
  void initState() {
    super.initState();

    _graphData = widget.initialData.toList();

    if (_graphData.isEmpty) {
      // This could cause data to be displayed slightly off if the time is 12:00 am on January 1st, 1970.
      // However if that were the case, then the user would either have secretly invented a modern 64 bit
      // operating system that can't even run on hardware from their time, or they invented time travel,
      // which according to the second law of thermodynamics is literally impossible. In summary, this
      // won't be causing issues unless if the user finds a way of violating the laws of thermodynamics,
      // or for some reason they change their time on their device
      _graphData.add(_GraphPoint(x: 0, y: widget.minValue ?? 0.0));
    } else if (_graphData.length > 1) {
      _graphData.removeLast();
    }

    widget.currentData = _graphData;

    _initializeListener();
  }

  @override
  void dispose() {
    _subscriptionListener?.cancel();

    super.dispose();
  }

  @override
  void didUpdateWidget(_GraphWidgetGraph oldWidget) {
    if (oldWidget.subscription != widget.subscription) {
      _resetGraphData();
      _subscriptionListener?.cancel();
      _initializeListener();
    }

    super.didUpdateWidget(oldWidget);
  }

  void _resetGraphData() {
    int oldLength = _graphData.length;

    _graphData.clear();
    _graphData.add(_GraphPoint(x: 0, y: widget.minValue ?? 0.0));

    _seriesController?.updateDataSource(
      removedDataIndexes: List.generate(oldLength, (index) => index),
      addedDataIndex: 0,
    );
  }

  void _initializeListener() {
    _subscriptionListener?.cancel();
    _subscriptionListener =
        widget.subscription?.periodicStream(yieldAll: true).listen((data) {
      if (_seriesController == null) {
        return;
      }
      if (data != null) {
        List<int> addedIndexes = [];
        List<int> removedIndexes = [];

        double currentTime = DateTime.now().microsecondsSinceEpoch.toDouble();

        _graphData.add(_GraphPoint(x: currentTime, y: tryCast(data) ?? 0.0));

        int indexOffset = 0;

        while (currentTime - _graphData[0].x > widget.timeDisplayed * 1e6 &&
            _graphData.length > 1) {
          _graphData.removeAt(0);
          removedIndexes.add(indexOffset++);
        }

        int existingIndex = _graphData.indexWhere((e) => e.x == currentTime);
        while (existingIndex != -1 &&
            existingIndex != _graphData.length - 1 &&
            _graphData.length > 1) {
          removedIndexes.add(existingIndex + indexOffset++);
          _graphData.removeAt(existingIndex);

          existingIndex = _graphData.indexWhere((e) => e.x == currentTime);
        }

        if (_graphData.last.x - _graphData.first.x <
            widget.timeDisplayed * 1e6) {
          _graphData.insert(
              0,
              _GraphPoint(
                x: _graphData.last.x - widget.timeDisplayed * 1e6,
                y: _graphData.first.y,
              ));
          addedIndexes.add(0);
        }

        addedIndexes.add(_graphData.length - 1);

        _seriesController?.updateDataSource(
          addedDataIndexes: addedIndexes,
          removedDataIndexes: removedIndexes,
        );
      } else if (_graphData.length > 1) {
        _resetGraphData();
      }

      widget.currentData = _graphData;
    });
  }

  List<FastLineSeries<_GraphPoint, num>> _getChartData() {
    return <FastLineSeries<_GraphPoint, num>>[
      FastLineSeries<_GraphPoint, num>(
        animationDuration: 0.0,
        animationDelay: 0.0,
        sortingOrder: SortingOrder.ascending,
        onRendererCreated: (controller) => _seriesController = controller,
        color: widget.mainColor,
        width: widget.lineWidth,
        dataSource: _graphData,
        xValueMapper: (value, index) {
          return value.x;
        },
        yValueMapper: (value, index) {
          return value.y;
        },
        sortFieldValueMapper: (datum, index) {
          return datum.x;
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SfCartesianChart(
      series: _getChartData(),
      margin: const EdgeInsets.only(top: 8.0),
      primaryXAxis: NumericAxis(
        labelStyle: const TextStyle(color: Colors.transparent),
        desiredIntervals: 5,
      ),
      primaryYAxis: NumericAxis(
        minimum: widget.minValue,
        maximum: widget.maxValue,
      ),
    );
  }
}

class _GraphPoint {
  final double x;
  final double y;

  const _GraphPoint({required this.x, required this.y});
}
