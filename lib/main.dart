import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Syncfusion DataGrid with Bloc',
      theme: ThemeData(primarySwatch: Colors.blue),
      navigatorKey: navigatorKey,
      home: BlocProvider(
        create: (context) => EmployeeBloc(),
        child: MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MyHomePageState createState() => _MyHomePageState();
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
StreamController<bool> loadingController = StreamController<bool>();
int _rowsPerPage = 10;
int totalCount = 1;

class _MyHomePageState extends State<MyHomePage> {
  late EmployeeDataSource _employeeDataSource;

  @override
  void initState() {
    super.initState();
    _employeeDataSource = EmployeeDataSource(context);

    // Fetch totalCount when the widget initializes.
    _fetchTotalCount();
  }

  void _fetchTotalCount() {
    final currentState = BlocProvider.of<EmployeeBloc>(context).state;
    // Directly access the total count from state.
    if (currentState is EmployeeInitial) {
      setState(() {
        totalCount = currentState.totalCount;
      });
    }
  }

  @override
  void dispose() {
    loadingController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Syncfusion DataGrid with Bloc'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
                stream: loadingController.stream,
                builder: (context, snapshot) {
                  return Stack(children: [
                    SfDataGrid(
                      source: _employeeDataSource,
                      columnWidthMode: ColumnWidthMode.fill,
                      columns: <GridColumn>[
                        GridColumn(
                          columnName: 'id',
                          label: Container(
                              padding: EdgeInsets.all(8.0),
                              alignment: Alignment.center,
                              child: Text(
                                'ID',
                              )),
                        ),
                        GridColumn(
                          columnName: 'name',
                          label: Container(
                              padding: EdgeInsets.all(8.0),
                              alignment: Alignment.center,
                              child: Text(
                                'Name',
                              )),
                        ),
                        GridColumn(
                          columnName: 'designation',
                          label: Container(
                              padding: EdgeInsets.all(8.0),
                              alignment: Alignment.center,
                              child: Text(
                                'Designation',
                              )),
                        ),
                        GridColumn(
                          columnName: 'salary',
                          label: Container(
                              padding: EdgeInsets.all(8.0),
                              alignment: Alignment.center,
                              child: Text(
                                'Salary',
                              )),
                        ),
                      ],
                    ),
                    if (snapshot.data == true)
                      const Center(
                        child: CircularProgressIndicator(),
                      ),
                  ]);
                }),
          ),
          SfDataPager(
            delegate: _employeeDataSource,
            pageCount: (totalCount / _rowsPerPage).ceilToDouble(),
            availableRowsPerPage: [10, 20, 30],
            onRowsPerPageChanged: (int? rowsPerPage) {
              setState(() {
                _rowsPerPage = rowsPerPage!;
                _employeeDataSource.updateDataGriDataSource();
              });
            },
          ),
        ],
      ),
    );
  }
}

class Employee {
  Employee(this.id, this.name, this.designation, this.salary);

  final int id;
  final String name;
  final String designation;
  final int salary;
}

class EmployeeDataSource extends DataGridSource {
  final BuildContext context;
  List<Employee> _employees = [];
  List<DataGridRow> _dataGridRows = [];
  bool _isLoading = false; // Flag to track loading state
  StreamSubscription<EmployeeState>? _streamSubscription;

  EmployeeDataSource(this.context);

  @override
  List<DataGridRow> get rows => _dataGridRows;

  Future<void> _fetchData(int startIndex, int endIndex) async {
    // If a fetch is already in progress, prevent another fetch.
    if (_isLoading) return;

    _isLoading = true;
    loadingController.add(_isLoading);

    final completer = Completer<void>();

    // Dispatch the fetch event to the bloc using BuildContext.
    BlocProvider.of<EmployeeBloc>(context)
        .add(FetchEmployees(startIndex: startIndex, endIndex: endIndex));

    // Cancel the previous stream subscription before creating a new one.
    await _streamSubscription?.cancel();

    // Create a new stream subscription for the current page request.
    _streamSubscription =
        BlocProvider.of<EmployeeBloc>(context).stream.listen((state) {
      if (!context.mounted) return;
      if (state is EmployeeLoaded) {
        _employees = state.employees;
        _buildRows();
        completer.complete();
        _isLoading = false;
        loadingController.add(_isLoading);
      } else if (state is EmployeeError) {
        completer.completeError(state.error);
        _isLoading = false;
      }
    });

    return completer.future;
  }

  void _buildRows() {
    _dataGridRows = _employees.map<DataGridRow>((e) {
      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'id', value: e.id),
        DataGridCell<String>(columnName: 'name', value: e.name),
        DataGridCell<String>(columnName: 'designation', value: e.designation),
        DataGridCell<int>(columnName: 'salary', value: e.salary),
      ]);
    }).toList();
  }

  @override
  Future<bool> handlePageChange(int oldPageIndex, int newPageIndex) async {
    // Prevent duplicate fetch calls.
    if (_isLoading) return false;

    int startIndex = newPageIndex * _rowsPerPage;
    int endIndex = (startIndex + _rowsPerPage).clamp(0, totalCount);

    // Ensure startIndex does not exceed totalCount.
    if (startIndex >= totalCount) {
      startIndex = max(0, totalCount - _rowsPerPage);
    }

    await _fetchData(startIndex, endIndex);
    notifyListeners();

    return true;
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((e) {
        return Container(
          alignment: Alignment.center,
          padding: EdgeInsets.all(8.0),
          child: Text(e.value.toString()),
        );
      }).toList(),
    );
  }

  void updateDataGriDataSource() {
    notifyListeners();
  }

  // Dispose the stream subscription when the data source is disposed.
  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}

abstract class EmployeeEvent {}

class FetchEmployees extends EmployeeEvent {
  final int startIndex;
  final int endIndex;

  FetchEmployees({required this.startIndex, required this.endIndex});
}

abstract class EmployeeState {}

class EmployeeInitial extends EmployeeState {
  final int totalCount = 60;
}

class EmployeeLoaded extends EmployeeState {
  final List<Employee> employees;

  EmployeeLoaded({required this.employees});
}

class EmployeeError extends EmployeeState {
  final String error;

  EmployeeError({required this.error});
}

class EmployeeBloc extends Bloc<EmployeeEvent, EmployeeState> {
  static const int totalCount = 60;
  final List<String> names = [
    'Alice Johnson',
    'Bob Smith',
    'Charlie Brown',
    'David Wilson',
    'Emma Davis',
    'Frank Miller',
    'Grace Lee',
    'Hannah White',
    'Isaac Clark',
    'Jack Turner',
    'Katherine Hall',
    'Liam Scott',
    'Mia Young',
    'Nathan Adams',
    'Olivia Baker',
    'Paul Carter',
    'Quinn Murphy',
    'Rachel Evans',
    'Samuel Collins',
    'Taylor Martin'
  ];

  final List<String> designations = [
    'Software Engineer',
    'Senior Developer',
    'Project Manager',
    'Business Analyst',
    'QA Engineer',
    'UI/UX Designer',
    'Database Administrator',
    'System Architect',
    'HR Manager',
    'Technical Lead'
  ];

  EmployeeBloc() : super(EmployeeInitial()) {
    on<FetchEmployees>((event, emit) async {
      try {
        // Simulate network delay.
        await Future.delayed(const Duration(seconds: 2));

        // Ensure endIndex does not exceed total count.
        int adjustedEndIndex =
            event.endIndex > totalCount ? totalCount : event.endIndex;

        final random = Random();

        // Mock employee data generation.
        final employees = List.generate(
          adjustedEndIndex - event.startIndex,
          (index) => Employee(
            event.startIndex + index + 1,
            names[random.nextInt(names.length)],
            designations[random.nextInt(designations.length)],
            random.nextInt(5000) + 3000,
          ),
        );

        // Emit the loaded state with employees and the total count.
        emit(EmployeeLoaded(employees: employees));
      } catch (e) {
        emit(EmployeeError(error: e.toString()));
      }
    });
  }
}
