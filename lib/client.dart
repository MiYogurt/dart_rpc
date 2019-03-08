import 'dart:io';

main(List<String> args) async {
  var socket = await Socket.connect(InternetAddress.loopbackIPv4, 9292);
  socket.listen((data) async {
    var str = String.fromCharCodes(data);

    if (str.contains('close')) {
      print('I am closing');
      await socket.destroy();
      return;
    }

    print('client: ${str.toString()}');
  });
  socket.write('{ "method": "sayHello", "param": "bob" }');
}