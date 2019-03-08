import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

sayHello(SendPort sendPort) async{
  // 交换 sendPort 引用，通过 sendPort 发送数据到 ReceivePort
  var port = new ReceivePort();
  sendPort.send(port.sendPort);

  String name = await port.first;
  sendPort.send('hello $name');
  port.close();
}

main(List<String> args) async {
  ServerSocket server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 9292);
  await for(var socket in server) {
    socket.writeln('{"msg": "hello"}');
    
    socket.listen((data) async {
      var str = String.fromCharCodes(data);
      var map = json.decode(str);
      if (map['method'] == 'sayHello') {

        var receivePort = new ReceivePort();
        await Isolate.spawn(sayHello, receivePort.sendPort);
        SendPort sendPort;
        var isFirst = true;
        receivePort.listen((data){
          if (isFirst) {
            sendPort = data;
            isFirst = false;
            sendPort.send(map['param']);
            return;
          }
          socket.writeln('{"msg": "$data"}');
        });
      }
    });

    await Future.delayed(Duration(milliseconds: 2000));
    socket.writeln('close');
  }
}