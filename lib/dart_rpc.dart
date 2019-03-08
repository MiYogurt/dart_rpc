import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:mirrors';
import 'funcs.dart';


// main(List<String> args) async {
//   var ret = await invoke('sayHello', []);
//   print(ret);
// }

Future invoke(name, param) {
  var completer = Completer<String>();
  currentMirrorSystem().libraries.forEach((uri, lib) {
    if(uri.path.contains('funcs')){
      lib.declarations.forEach((_name, dc){
        if (Symbol(name) == _name) {
          InstanceMirror result;
          try {
            if (param is List) {
              result = lib.invoke(_name, param);
            } else {
              result = lib.invoke(_name, [param]);
            }
            completer.complete('{"msg":"${result.reflectee}"}');
          } catch (e) {
            completer.complete('{"msg":"${e.toString()}"}');
          }
        }
      });
    }
  });
  return completer.future;
}

sayHello(SendPort sendPort) async{
  // 交换 sendPort 引用，通过 sendPort 发送数据到 ReceivePort
  var port = new ReceivePort();
  sendPort.send(port.sendPort);

  await for(var data in port) {
    Map msg = data[0];
    SendPort replyPort = data[1];
    replyPort.send(await invoke(msg['method'], msg['param']));
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
    

    Stream<dynamic> transformd;
    
    transformd = socket.transform(StreamTransformer.fromHandlers(handleData: (value, sink){
      var jsonData = json.decode(String.fromCharCodes(value));
      sink.add(jsonData);
    }));

    // transformd = socket.map((value){
    //   var jsonData = json.decode(String.fromCharCodes(value));
    //   return jsonData;
    // });

    // var a = socket.transform(const Utf8Decoder()).transform(const JsonDecoder()).cast<Map>();
    // await for (var jsonData in a) {
    //   // when client is close the will be output
    //   print(jsonData);
    // }

    // a.listen(print); // output

    // transformd = socket.transform(const Utf8Decoder()).transform(const JsonDecoder());
    
    await for (var jsonData in transformd) {
        var receivePort = new ReceivePort();
        await Isolate.spawn(sayHello, receivePort.sendPort);
        SendPort sendPort = await receivePort.first;
        var data = await sendReceive(sendPort, jsonData);
        socket.writeln(data);
    }


    await Future.delayed(Duration(milliseconds: 2000));
    socket.writeln('close');
  }
}