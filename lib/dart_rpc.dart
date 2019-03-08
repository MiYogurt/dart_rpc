import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

sayHello(SendPort sendPort) async{
  // 交换 sendPort 引用，通过 sendPort 发送数据到 ReceivePort
  var port = new ReceivePort();
  sendPort.send(port.sendPort);

  await for(var data in port) {
    var msg = data[0];
    SendPort replyPort = data[1];
    replyPort.send("hello $msg");
    port.close();
  }

}

Future sendReceive(SendPort port, msg) {
  ReceivePort response = new ReceivePort();
  port.send([msg, response.sendPort]);
  return response.first;
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
        SendPort sendPort = await receivePort.first;
        var data = await sendReceive(sendPort, map['param']);
        socket.writeln('{"msg": "$data"}');
      }
    });

    await Future.delayed(Duration(milliseconds: 2000));
    socket.writeln('close');
  }
}