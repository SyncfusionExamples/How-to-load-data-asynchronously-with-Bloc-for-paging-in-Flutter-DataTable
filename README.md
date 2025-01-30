# How to load data asynchronously with Bloc for paging in Flutter DataTable?

In this article, we will show you how to load data asynchronously with Bloc for paging in [Flutter DataTable](https://www.syncfusion.com/flutter-widgets/flutter-datagrid).

## Steps to asynchronous data loading using Bloc: 

### Step 1:  Creating the Bloc for Data Fetching

The Bloc (Business Logic Component) is responsible for managing state and handling asynchronous data loading. Bloc uses events to trigger data fetching. Here, we define a FetchEmployees event that specifies the range of data to fetch. This event takes startIndex and endIndex as parameters to determine the required records. This Bloc fetches a batch of employees asynchronously when a new page is requested. 

```dart
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
```

### Step 2: Implementing Data Source

The [DataGridSource](https://pub.dev/documentation/syncfusion_flutter_datagrid/latest/datagrid/DataGridSource-class.html) class is responsible for fetching data and managing the data grid's rows. It uses a [StreamSubscription](https://api.flutter.dev/flutter/dart-async/StreamSubscription-class.html) to listen for state changes from the EmployeeBloc. When a page change is requested, it fetches the required data asynchronously and updates the data grid's rows. The [handlePageChange](https://pub.dev/documentation/syncfusion_flutter_datagrid/latest/datagrid/DataGridSource/handlePageChange.html) method ensures that data is fetched only when necessary, preventing duplicate fetch calls.

```dart
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
```

### Step 3: Creating SfDataGrid and SfDataPager

Initialize the [SfDataGrid](https://pub.dev/documentation/syncfusion_flutter_datagrid/latest/datagrid/SfDataGrid-class.html) and [SfDataPager](https://pub.dev/documentation/syncfusion_flutter_datagrid/latest/datagrid/SfDataPager-class.html) widget with all the necessary properties. The [StreamBuilder](https://api.flutter.dev/flutter/widgets/StreamBuilder-class.html) listens to the loading state and displays a loading indicator when data is being fetched.

```dart
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
```

You can download this example on [GitHub](https://github.com/SyncfusionExamples/How-to-load-data-asynchronously-with-Bloc-for-paging-in-Flutter-DataTable).