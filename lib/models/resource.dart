class Resource {
  late double cpuInUseByApp;
  late double memoryInUseByApp;

  Resource.fromMap(Map map) {
    cpuInUseByApp = map['cpuInUseByApp'];
    memoryInUseByApp = map['memoryInUseByApp'];
  }
}
